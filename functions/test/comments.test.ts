import { describe, it, expect } from "vitest";
import { commentDelta } from "../src/comments.js";

describe("commentDelta", () => {
  it("생성(+1)", () => expect(commentDelta(false, true)).toBe(1));
  it("삭제(-1)", () => expect(commentDelta(true, false)).toBe(-1));
  it("변화 없음(0)", () => {
    expect(commentDelta(true, true)).toBe(0);
    expect(commentDelta(false, false)).toBe(0);
  });
});
