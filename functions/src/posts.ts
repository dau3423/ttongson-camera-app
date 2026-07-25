// functions/src/posts.ts
import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

if (getApps().length === 0) initializeApp();

/**
 * 게시물이 삭제되면 하위 컬렉션(좋아요·댓글, 댓글의 신고, 게시물 신고 등)을
 * 재귀 삭제한다. Firestore는 문서 삭제 시 하위 컬렉션을 자동 삭제하지 않으므로
 * 클라이언트가 posts/{postId} 문서를 지운 뒤 이 트리거가 잔여 데이터를 정리한다.
 *
 * recursiveDelete는 이미 삭제된 문서에 대해서도 하위 컬렉션을 훑어 지운다.
 * 이때 발생하는 좋아요/댓글 문서 삭제 이벤트는 카운터 트리거를 다시 부르지만,
 * 그 트리거들은 게시물이 없으면 no-op이므로 재귀나 오류 폭주가 없다.
 */
export const onPostDeleted = onDocumentDeleted(
  "posts/{postId}",
  async (event) => {
    const postId = event.params.postId as string;
    const db = getFirestore();
    await db.recursiveDelete(db.collection("posts").doc(postId));
  },
);
