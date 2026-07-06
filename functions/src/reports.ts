// functions/src/reports.ts
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, DocumentReference } from "firebase-admin/firestore";

if (getApps().length === 0) initializeApp();

/** 신고 문서 생성/삭제 delta: 생기면 +1, 사라지면 -1, 그 외 0. */
export function reportDelta(before: boolean, after: boolean): number {
  if (!before && after) return 1;
  if (before && !after) return -1;
  return 0;
}

/** 신고 수가 임계에 도달하면 숨김. */
export function shouldHide(count: number, threshold = 5): boolean {
  return count >= threshold;
}

/** 대상의 reportCount를 delta만큼 조정하고, 임계 도달 시 hidden=true(latch). */
async function applyReport(
  target: DocumentReference,
  delta: number,
): Promise<void> {
  const db = getFirestore();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(target);
    if (!snap.exists) return;
    const cur = (snap.data()?.reportCount ?? 0) as number;
    const next = cur + delta;
    const wasHidden = (snap.data()?.hidden ?? false) as boolean;
    tx.update(target, { reportCount: next, hidden: wasHidden || shouldHide(next) });
  });
}

export const onPostReportWrite = onDocumentWritten(
  "posts/{postId}/reports/{uid}",
  async (event) => {
    const before = event.data?.before.exists ?? false;
    const after = event.data?.after.exists ?? false;
    const delta = reportDelta(before, after);
    if (delta === 0) return;
    const postId = event.params.postId as string;
    await applyReport(getFirestore().collection("posts").doc(postId), delta);
  },
);

export const onCommentReportWrite = onDocumentWritten(
  "posts/{postId}/comments/{commentId}/reports/{uid}",
  async (event) => {
    const before = event.data?.before.exists ?? false;
    const after = event.data?.after.exists ?? false;
    const delta = reportDelta(before, after);
    if (delta === 0) return;
    const postId = event.params.postId as string;
    const commentId = event.params.commentId as string;
    await applyReport(
      getFirestore()
        .collection("posts")
        .doc(postId)
        .collection("comments")
        .doc(commentId),
      delta,
    );
  },
);
