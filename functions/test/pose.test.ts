import { describe, it, expect } from "vitest";
import {
  parseCandidates, buildPoseSchema, parsePoseResult, buildPoseUser,
} from "../src/pose.js";

describe("parseCandidates", () => {
  it("유효 후보 배열을 파싱", () => {
    const c = parseCandidates([
      { id: "selfie_01", label: "턱 괴기", category: "selfie" },
    ]);
    expect(c).toHaveLength(1);
    expect(c[0].id).toBe("selfie_01");
  });
  it("빈 배열/비배열은 throw", () => {
    expect(() => parseCandidates([])).toThrow();
    expect(() => parseCandidates("x")).toThrow();
  });
  it("필드 누락 항목이 있으면 throw", () => {
    expect(() => parseCandidates([{ id: "a", label: "b" }])).toThrow();
  });
});

describe("buildPoseSchema", () => {
  it("poseId를 후보 id enum으로 제약", () => {
    const s = buildPoseSchema(["a", "b"]) as any;
    expect(s.properties.poseId.enum).toEqual(["a", "b"]);
    expect(s.required).toEqual(["poseId", "reason"]);
    expect(s.additionalProperties).toBe(false);
  });
});

describe("buildPoseUser", () => {
  it("후보 라벨과 카테고리를 프롬프트에 포함", () => {
    const t = buildPoseUser([{ id: "couple_01", label: "어깨동무", category: "couple" }]);
    expect(t).toContain("couple_01");
    expect(t).toContain("어깨동무");
  });
});

describe("parsePoseResult", () => {
  it("유효 poseId를 파싱", () => {
    const r = parsePoseResult(
      JSON.stringify({ poseId: "a", reason: "두 명이라 커플 포즈" }),
      ["a", "b"],
    );
    expect(r.poseId).toBe("a");
    expect(r.reason).toContain("커플");
  });
  it("validIds에 없는 poseId면 throw", () => {
    expect(() =>
      parsePoseResult(JSON.stringify({ poseId: "z", reason: "r" }), ["a"]),
    ).toThrow();
  });
  it("JSON이 아니면 throw", () => {
    expect(() => parsePoseResult("no", ["a"])).toThrow();
  });
});
