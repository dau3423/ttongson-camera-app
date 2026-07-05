import { describe, it, expect } from "vitest";
import { parseAdvice } from "../src/advice.js";
import { buildUserText } from "../src/schema.js";

describe("parseAdvice", () => {
  it("유효한 JSON을 CompositionAdvice로 파싱(targetBox 포함)", () => {
    const text = JSON.stringify({
      headline: "인물을 오른쪽 3분할선으로",
      targetBox: { x: 0.55, y: 0.3, width: 0.3, height: 0.6 },
      rationale: "여백이 넓어 답답합니다",
    });
    const a = parseAdvice(text);
    expect(a.headline).toBe("인물을 오른쪽 3분할선으로");
    expect(a.targetBox).toEqual({ x: 0.55, y: 0.3, width: 0.3, height: 0.6 });
    expect(a.rationale).toContain("여백");
  });

  it("targetBox 누락이면 throw", () => {
    expect(() =>
      parseAdvice(JSON.stringify({ headline: "x", rationale: "z" })),
    ).toThrow();
  });

  it("targetBox 필드가 숫자가 아니면 throw", () => {
    const bad = JSON.stringify({
      headline: "x",
      targetBox: { x: "a", y: 0.3, width: 0.3, height: 0.6 },
      rationale: "z",
    });
    expect(() => parseAdvice(bad)).toThrow();
  });

  it("headline/rationale 누락이면 throw", () => {
    const bad = JSON.stringify({
      targetBox: { x: 0.5, y: 0.3, width: 0.3, height: 0.6 },
    });
    expect(() => parseAdvice(bad)).toThrow();
  });

  it("JSON이 아니면 throw", () => {
    expect(() => parseAdvice("not json")).toThrow();
  });
});

describe("buildUserText", () => {
  it("인물 지표가 있으면 프롬프트에 위치를 포함", () => {
    const t = buildUserText({
      hasPerson: true,
      personCenterX: 0.2,
      personCenterY: 0.5,
      tiltDeg: 3,
    });
    expect(t).toContain("인물");
    expect(t).toContain("0.2");
  });

  it("지표가 없어도 유효한 지시문을 만든다", () => {
    const t = buildUserText(undefined);
    expect(t.length).toBeGreaterThan(0);
  });
});
