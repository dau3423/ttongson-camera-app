import { describe, it, expect } from "vitest";
import { likeDelta } from "../src/likes.js";

describe("likeDelta", () => {
  it("생성(+1)", () => expect(likeDelta(false, true)).toBe(1));
  it("삭제(-1)", () => expect(likeDelta(true, false)).toBe(-1));
  it("변화 없음(0)", () => {
    expect(likeDelta(true, true)).toBe(0);
    expect(likeDelta(false, false)).toBe(0);
  });
});
