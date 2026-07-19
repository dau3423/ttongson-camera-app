// functions/src/enhance.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { visionJson } from "./openai.js";
import { requireAuthUid } from "./auth_guard.js";
import { windowStart, overLimit } from "./ratelimit.js";
import {
  parseMoodKey, MOOD_SCHEMA, buildMoodSystem, buildMoodUser, parseMoodParams,
} from "./mood.js";

if (getApps().length === 0) initializeApp();

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

const MAX_IMAGE_BYTES = 4 * 1024 * 1024;
const RATE_MAX = 30;
const RATE_WINDOW_MS = 60_000;

export const enhance = onCall(
  {
    region: "asia-northeast3",
    secrets: [OPENAI_API_KEY],
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "512MiB",
  },
  async (request) => {
    requireAuthUid(request.auth);
    const data = request.data as {
      imageBase64?: string; mediaType?: string; deviceId?: string; mood?: unknown;
    };

    if (typeof data.imageBase64 !== "string" || data.imageBase64.length === 0) {
      throw new HttpsError("invalid-argument", "imageBase64가 필요합니다");
    }
    if (data.imageBase64.length > MAX_IMAGE_BYTES) {
      throw new HttpsError("invalid-argument", "이미지가 너무 큽니다");
    }
    if (data.mediaType !== "image/jpeg") {
      throw new HttpsError("invalid-argument", "mediaType은 image/jpeg만 지원합니다");
    }
    const deviceId = data.deviceId;
    if (typeof deviceId !== "string" || deviceId.length === 0 || deviceId.length > 64) {
      throw new HttpsError("invalid-argument", "deviceId가 필요합니다");
    }
    const mood = parseMoodKey(data.mood);

    const now = Date.now();
    const win = windowStart(now, RATE_WINDOW_MS);
    const ref = getFirestore().collection("rate_limits").doc(`enhance_${deviceId}_${win}`);
    const count = await getFirestore().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const current = (snap.exists ? (snap.data()?.count as number) : 0) ?? 0;
      tx.set(ref, { count: current + 1, expiresAt: win + RATE_WINDOW_MS }, { merge: true });
      return current + 1;
    });
    if (overLimit(count, RATE_MAX)) {
      throw new HttpsError("resource-exhausted", "요청이 너무 잦습니다. 잠시 후 다시 시도해 주세요.");
    }

    try {
      const text = await visionJson({
        apiKey: OPENAI_API_KEY.value(),
        system: buildMoodSystem(mood),
        userText: buildMoodUser(mood),
        imageBase64: data.imageBase64,
        schemaName: "mood_params",
        schema: MOOD_SCHEMA as { [key: string]: unknown },
      });
      return parseMoodParams(text);
    } catch (err) {
      console.error("enhance failed", err);
      throw new HttpsError("internal", "보정값 생성에 실패했습니다");
    }
  },
);
