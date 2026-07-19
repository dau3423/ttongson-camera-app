import { describe, it, expect } from "vitest";
import { DESCRIBE_SCHEMA, parseDescribe, buildDescribeUser } from "../src/describe.js";

describe("DESCRIBE_SCHEMA", () => {
  it("name·tags required, additionalProperties false", () => {
    const s = DESCRIBE_SCHEMA as any;
    expect(s.required).toEqual(["name", "tags"]);
    expect(s.additionalProperties).toBe(false);
    expect(s.properties.tags.type).toBe("array");
  });
});

describe("buildDescribeUser", () => {
  it("한국어 제목·태그 지시를 포함", () => {
    const t = buildDescribeUser();
    expect(t).toContain("제목");
    expect(t).toContain("태그");
  });
});

describe("parseDescribe", () => {
  it("유효 JSON 파싱", () => {
    const r = parseDescribe(JSON.stringify({ name: "노을 커피", tags: ["커피", "노을"] }));
    expect(r.name).toBe("노을 커피");
    expect(r.tags).toEqual(["커피", "노을"]);
  });
  it("태그는 최대 5개로 제한, 비문자열 제거", () => {
    const r = parseDescribe(
      JSON.stringify({ name: "x", tags: ["a", "b", "c", "d", "e", "f", 3] }),
    );
    expect(r.tags).toEqual(["a", "b", "c", "d", "e"]);
  });
  it("name 비문자열이면 빈 문자열, tags 비배열이면 빈 배열", () => {
    const r = parseDescribe(JSON.stringify({ name: 1, tags: "no" }));
    expect(r.name).toBe("");
    expect(r.tags).toEqual([]);
  });
  it("JSON이 아니면 throw", () => {
    expect(() => parseDescribe("nope")).toThrow();
  });
});
