// functions/src/likes.ts
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

if (getApps().length === 0) initializeApp();

/** 좋아요 문서 생성/삭제 delta: 생기면 +1, 사라지면 -1, 그 외 0. */
export function likeDelta(before: boolean, after: boolean): number {
  if (!before && after) return 1;
  if (before && !after) return -1;
  return 0;
}

export const onLikeWrite = onDocumentWritten(
  "posts/{postId}/likes/{uid}",
  async (event) => {
    const before = event.data?.before.exists ?? false;
    const after = event.data?.after.exists ?? false;
    const delta = likeDelta(before, after);
    if (delta === 0) return;
    const postId = event.params.postId as string;
    const db = getFirestore();
    const postRef = db.collection("posts").doc(postId);
    // 게시물이 삭제된 뒤(캐스케이드 삭제 중)엔 카운터 갱신을 건너뛴다.
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(postRef);
      if (!snap.exists) return;
      tx.update(postRef, { likeCount: FieldValue.increment(delta) });
    });
  },
);
