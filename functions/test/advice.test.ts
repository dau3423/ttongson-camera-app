import { describe, it, expect } from "vitest";
import { parseAdvice } from "../src/advice.js";
import { buildUserText } from "../src/schema.js";

describe("parseAdvice", () => {
  it("유효한 JSON을 CompositionAdvice로 파싱", () => {
    const text = JSON.stringify({
      headline: "인물을 오른쪽 3분할선으로",
      directions: [{ axis: "move", instruction: "오른쪽으로 한 걸음" }],
      rationale: "여백이 넓어 답답합니다",
    });
    const a = parseAdvice(text);
    expect(a.headline).toBe("인물을 오른쪽 3분할선으로");
    expect(a.directions).toHaveLength(1);
    expect(a.directions[0].axis).toBe("move");
    expect(a.rationale).toContain("여백");
  });

  it("필수 필드 누락이면 throw", () => {
    expect(() => parseAdvice(JSON.stringify({ headline: "x" }))).toThrow();
  });

  it("잘못된 axis 값이면 throw", () => {
    const bad = JSON.stringify({
      headline: "x",
      directions: [{ axis: "spin", instruction: "y" }],
      rationale: "z",
    });
    expect(() => parseAdvice(bad)).toThrow();
  });

  it("JSON이 아니면 throw", () => {
    expect(() => parseAdvice("not json")).toThrow();
  });
});

describe("buildUserText", () => {
  it("인물 지표가 있으면 프롬프트에 위치를 포함", () => {
    const t = buildUserText({ hasPerson: true, personCenterX: 0.2, personCenterY: 0.5, tiltDeg: 3 });
    expect(t).toContain("인물");
    expect(t).toContain("0.2");
  });

  it("지표가 없어도 유효한 지시문을 만든다", () => {
    const t = buildUserText(undefined);
    expect(t.length).toBeGreaterThan(0);
  });
});
