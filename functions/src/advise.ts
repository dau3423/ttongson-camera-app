// functions/src/advise.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { requestAdvice } from "./claude.js";
import type { OnDeviceMetrics } from "./advice.js";

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

const MAX_IMAGE_BYTES = 4 * 1024 * 1024; // base64 기준 대략 상한

export const advise = onCall(
  {
    secrets: [ANTHROPIC_API_KEY],
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "512MiB",
  },
  async (request) => {
    const data = request.data as {
      imageBase64?: string;
      mediaType?: string;
      metrics?: OnDeviceMetrics;
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

    try {
      return await requestAdvice(
        ANTHROPIC_API_KEY.value(),
        data.imageBase64,
        "image/jpeg",
        data.metrics,
      );
    } catch (err) {
      console.error("advise failed", err);
      throw new HttpsError("internal", "구도 추천 생성에 실패했습니다");
    }
  },
);
