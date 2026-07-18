export type PoseCandidate = { id: string; label: string; category: string };

export function parseCandidates(raw: unknown): PoseCandidate[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new Error("candidates가 필요합니다");
  }
  return raw.map((c) => {
    const o = c as Record<string, unknown>;
    if (
      typeof o.id !== "string" ||
      typeof o.label !== "string" ||
      typeof o.category !== "string"
    ) {
      throw new Error("candidate 형식 오류");
    }
    return { id: o.id, label: o.label, category: o.category };
  });
}

export function buildPoseSchema(candidateIds: string[]): { [key: string]: unknown } {
  return {
    type: "object",
    properties: {
      poseId: { type: "string", enum: candidateIds },
      reason: { type: "string" },
    },
    required: ["poseId", "reason"],
    additionalProperties: false,
  };
}

export function buildPoseSystem(): string {
  return (
    "당신은 사진 포즈를 추천하는 코치입니다. 반드시 한국어로 답합니다. " +
    "입력 사진 속 인원수와 구도를 보고, 후보 목록 중 이 장면에 가장 어울리는 포즈 하나를 고릅니다. " +
    "예: 두 명이면 커플, 여러 명이면 우정, 상반신 위주면 셀카, 전신이 보이면 전신 포즈. " +
    "poseId는 반드시 후보 목록의 id 중 하나여야 하고, reason은 왜 그 포즈가 어울리는지 한 문장입니다."
  );
}

export function buildPoseUser(candidates: PoseCandidate[]): string {
  const list = candidates
    .map((c) => `- ${c.id} (${c.category}): ${c.label}`)
    .join("\n");
  return `이 사진에 어울리는 포즈를 아래 후보 중에서 하나 골라 주세요.\n${list}`;
}

export function parsePoseResult(
  text: string,
  validIds: string[],
): { poseId: string; reason: string } {
  const raw = JSON.parse(text);
  if (raw === null || typeof raw !== "object") {
    throw new Error("포즈 결과 JSON 형식 오류");
  }
  const poseId = (raw as Record<string, unknown>).poseId;
  const reason = (raw as Record<string, unknown>).reason;
  if (typeof poseId !== "string" || !validIds.includes(poseId)) {
    throw new Error("poseId가 후보에 없습니다");
  }
  return { poseId, reason: typeof reason === "string" ? reason : "" };
}
