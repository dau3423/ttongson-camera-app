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
    await getFirestore()
      .collection("posts")
      .doc(postId)
      .update({ commentCount: FieldValue.increment(delta) });
  },
);
