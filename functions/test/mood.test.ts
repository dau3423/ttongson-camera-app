import { describe, it, expect } from "vitest";
import { parseMoodKey, parseMoodParams } from "../src/mood.js";

describe("parseMoodKey", () => {
  it("화이트리스트 값은 그대로", () => {
    expect(parseMoodKey("warm")).toBe("warm");
    expect(parseMoodKey("bw")).toBe("bw");
  });
  it("이상값은 warm 폴백", () => {
    expect(parseMoodKey("xyz")).toBe("warm");
    expect(parseMoodKey(undefined)).toBe("warm");
  });
});

describe("parseMoodParams", () => {
  it("범위를 벗어난 수치는 -1~1로 클램프", () => {
    const p = parseMoodParams(
      JSON.stringify({
        brightness: 9, contrast: -9, saturation: 0.2,
        temperature: 2, tint: -2, grayscale: true,
      }),
    );
    expect(p.brightness).toBe(1);
    expect(p.contrast).toBe(-1);
    expect(p.temperature).toBe(1);
    expect(p.tint).toBe(-1);
    expect(p.grayscale).toBe(true);
  });
  it("누락 필드는 0/false로 방어", () => {
    const p = parseMoodParams(JSON.stringify({ brightness: 0.1 }));
    expect(p.contrast).toBe(0);
    expect(p.grayscale).toBe(false);
  });
  it("JSON이 아니면 throw", () => {
    expect(() => parseMoodParams("not json")).toThrow();
  });
});
