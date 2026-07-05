import { describe, it, expect } from "vitest";
import { buildSystemPrompt, buildUserText, COMPOSITION_SCHEMA } from "../src/schema.js";

describe("모드별 프롬프트", () => {
  it("자연 모드는 targetBox 를 만들지 않도록 지시", () => {
    expect(buildSystemPrompt("nature")).toContain("targetBox는 반환하지 마세요");
    expect(buildUserText("nature")).toContain("targetBox는 생략");
  });
  it("사물 모드는 사물 목표 위치를 지시", () => {
    expect(buildSystemPrompt("object")).toContain("주요 사물");
    expect(buildUserText("object")).toContain("사물");
  });
  it("인물 모드는 인물 중심 지표를 참고에 포함", () => {
    const text = buildUserText("person", {
      hasPerson: true,
      personCenterX: 0.5,
      personCenterY: 0.4,
    });
    expect(text).toContain("현재 인물 중심");
  });
});

describe("스키마", () => {
  it("targetBox 는 required 가 아니다", () => {
    expect(COMPOSITION_SCHEMA.required).toEqual(["headline", "rationale"]);
  });
});
