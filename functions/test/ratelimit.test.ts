import { describe, it, expect } from "vitest";
import { windowStart, overLimit } from "../src/ratelimit.js";

describe("windowStart", () => {
  it("윈도우 경계로 내림", () => {
    expect(windowStart(12_345, 60_000)).toBe(0);
    expect(windowStart(65_000, 60_000)).toBe(60_000);
    expect(windowStart(120_000, 60_000)).toBe(120_000);
  });
});

describe("overLimit", () => {
  it("count가 max 이상이면 true", () => {
    expect(overLimit(5, 5)).toBe(true);
    expect(overLimit(6, 5)).toBe(true);
    expect(overLimit(4, 5)).toBe(false);
  });
});
