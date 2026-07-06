import { describe, it, expect } from "vitest";
import { reportDelta, shouldHide } from "../src/reports.js";

describe("reportDelta", () => {
  it("생성(+1)", () => expect(reportDelta(false, true)).toBe(1));
  it("삭제(-1)", () => expect(reportDelta(true, false)).toBe(-1));
  it("변화 없음(0)", () => {
    expect(reportDelta(true, true)).toBe(0);
    expect(reportDelta(false, false)).toBe(0);
  });
});

describe("shouldHide", () => {
  it("임계 미만은 false", () => expect(shouldHide(4)).toBe(false));
  it("임계 도달은 true", () => expect(shouldHide(5)).toBe(true));
  it("임계 초과는 true", () => expect(shouldHide(6)).toBe(true));
  it("커스텀 임계", () => {
    expect(shouldHide(2, 3)).toBe(false);
    expect(shouldHide(3, 3)).toBe(true);
  });
});
