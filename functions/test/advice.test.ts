import { describe, it, expect } from "vitest";
import { parseAdvice, parseMode } from "../src/advice.js";
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

  it("targetBox 누락이면 undefined(선택 필드)", () => {
    const result = parseAdvice(JSON.stringify({ headline: "x", rationale: "z" }));
    expect(result.targetBox).toBeUndefined();
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
    const t = buildUserText("person", {
      hasPerson: true,
      personCenterX: 0.2,
      personCenterY: 0.5,
      tiltDeg: 3,
    });
    expect(t).toContain("인물");
    expect(t).toContain("0.2");
  });

  it("지표가 없어도 유효한 지시문을 만든다", () => {
    const t = buildUserText("person", undefined);
    expect(t.length).toBeGreaterThan(0);
  });
});

describe("parseMode", () => {
  it("유효한 모드는 그대로", () => {
    expect(parseMode("person")).toBe("person");
    expect(parseMode("nature")).toBe("nature");
    expect(parseMode("object")).toBe("object");
  });
  it("이상값/누락은 person 폴백", () => {
    expect(parseMode("bogus")).toBe("person");
    expect(parseMode(undefined)).toBe("person");
    expect(parseMode(123)).toBe("person");
  });
});

describe("parseAdvice targetBox 선택화", () => {
  it("targetBox 없어도 성공(자연 모드)", () => {
    const advice = parseAdvice(
      JSON.stringify({ headline: "수평선을 아래 1/3에", rationale: "하늘을 넓게" }),
    );
    expect(advice.headline).toBe("수평선을 아래 1/3에");
    expect(advice.targetBox).toBeUndefined();
  });
  it("targetBox 있으면 검증해 포함", () => {
    const advice = parseAdvice(
      JSON.stringify({
        headline: "오른쪽으로",
        rationale: "3분할",
        targetBox: { x: 0.6, y: 0.3, width: 0.2, height: 0.4 },
      }),
    );
    expect(advice.targetBox).toEqual({ x: 0.6, y: 0.3, width: 0.2, height: 0.4 });
  });
  it("targetBox 형식이 틀리면 에러", () => {
    expect(() =>
      parseAdvice(JSON.stringify({ headline: "h", rationale: "r", targetBox: { x: "no" } })),
    ).toThrow();
  });
});
