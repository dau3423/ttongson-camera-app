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
    await getFirestore()
      .collection("posts")
      .doc(postId)
      .update({ likeCount: FieldValue.increment(delta) });
  },
);
