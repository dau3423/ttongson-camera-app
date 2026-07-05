import { describe, it, expect } from "vitest";
import { kakaoUid } from "../src/kakao.js";

describe("kakaoUid", () => {
  it("숫자 id를 kakao: 접두 uid로", () => {
    expect(kakaoUid(12345)).toBe("kakao:12345");
  });
  it("문자열 id도 허용", () => {
    expect(kakaoUid("abc")).toBe("kakao:abc");
  });
  it("id가 없거나 객체면 예외", () => {
    expect(() => kakaoUid(undefined)).toThrow();
    expect(() => kakaoUid({})).toThrow();
    expect(() => kakaoUid(null)).toThrow();
  });
});
