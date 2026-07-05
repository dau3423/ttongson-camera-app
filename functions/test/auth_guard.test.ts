import { describe, it, expect } from "vitest";
import { requireAuthUid } from "../src/auth_guard.js";

describe("requireAuthUid", () => {
  it("uid가 있으면 그대로 반환", () => {
    expect(requireAuthUid({ uid: "abc" })).toBe("abc");
  });
  it("auth가 없으면 예외", () => {
    expect(() => requireAuthUid(undefined)).toThrow();
  });
  it("uid가 빈 값이면 예외", () => {
    expect(() => requireAuthUid({ uid: "" })).toThrow();
  });
});
