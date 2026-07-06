// functions/src/kakao.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

if (getApps().length === 0) initializeApp();

/** 카카오 사용자 id → Firebase uid. */
export function kakaoUid(id: unknown): string {
  if (typeof id !== "number" && typeof id !== "string") {
    throw new HttpsError("unauthenticated", "카카오 사용자 정보를 확인할 수 없습니다");
  }
  return `kakao:${id}`;
}

export const kakaoCustomToken = onCall(
  { region: "asia-northeast3", enforceAppCheck: true },
  async (request) => {
  const accessToken = (request.data as { accessToken?: string })?.accessToken;
  if (typeof accessToken !== "string" || accessToken.length === 0) {
    throw new HttpsError("invalid-argument", "accessToken이 필요합니다");
  }
  const res = await fetch("https://kapi.kakao.com/v2/user/me", {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) {
    throw new HttpsError("unauthenticated", "카카오 토큰 검증에 실패했습니다");
  }
  const data = (await res.json()) as { id?: number };
  const uid = kakaoUid(data.id);
  const token = await getAuth().createCustomToken(uid, { provider: "kakao" });
  return { token };
});
