import { HttpsError } from "firebase-functions/v2/https";

/** 인증 컨텍스트에서 uid를 꺼낸다. 없으면 unauthenticated 예외. */
export function requireAuthUid(auth: { uid?: string } | undefined): string {
  const uid = auth?.uid;
  if (typeof uid !== "string" || uid.length === 0) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다");
  }
  return uid;
}
