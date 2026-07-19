export const DESCRIBE_SCHEMA = {
  type: "object",
  properties: {
    name: { type: "string" },
    tags: { type: "array", items: { type: "string" } },
  },
  required: ["name", "tags"],
  additionalProperties: false,
} as const;

export function buildDescribeSystem(): string {
  return (
    "당신은 사진에 이름을 붙이는 작가입니다. 반드시 한국어로 답합니다. " +
    "사진을 보고 짧고 재밌는 제목(20자 이내)과 검색용 태그 3~5개를 짓습니다. " +
    "제목은 위트 있게, 태그는 사진 속 사물·장소·분위기를 담은 짧은 명사로."
  );
}

export function buildDescribeUser(): string {
  return "이 사진의 재밌는 제목 하나와 검색용 태그 3~5개를 지어 주세요.";
}

export function parseDescribe(text: string): { name: string; tags: string[] } {
  const raw = JSON.parse(text);
  if (raw === null || typeof raw !== "object") {
    throw new Error("describe 결과 JSON 형식 오류");
  }
  const o = raw as Record<string, unknown>;
  const name = typeof o.name === "string" ? o.name : "";
  const tags = Array.isArray(o.tags)
    ? o.tags.filter((t): t is string => typeof t === "string").slice(0, 5)
    : [];
  return { name, tags };
}
