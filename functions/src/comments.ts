// functions/src/comments.ts
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

if (getApps().length === 0) initializeApp();

/** 댓글 문서 생성/삭제 delta: 생기면 +1, 사라지면 -1, 그 외 0. */
export function commentDelta(before: boolean, after: boolean): number {
  if (!before && after) return 1;
  if (before && !after) return -1;
  return 0;
}

export const onCommentWrite = onDocumentWritten(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const before = event.data?.before.exists ?? false;
    const after = event.data?.after.exists ?? false;
    const delta = commentDelta(before, after);
    if (delta === 0) return;
    const postId = event.params.postId as string;
    const db = getFirestore();
    const postRef = db.collection("posts").doc(postId);
    // 게시물이 삭제된 뒤(캐스케이드 삭제 중)엔 카운터 갱신을 건너뛴다.
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(postRef);
      if (!snap.exists) return;
      tx.update(postRef, { commentCount: FieldValue.increment(delta) });
    });
  },
);
