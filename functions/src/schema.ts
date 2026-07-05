import type { Mode, OnDeviceMetrics } from "./advice.js";

export const COMPOSITION_SCHEMA = {
  type: "object",
  properties: {
    headline: { type: "string" },
    targetBox: {
      type: "object",
      properties: {
        x: { type: "number" },
        y: { type: "number" },
        width: { type: "number" },
        height: { type: "number" },
      },
      required: ["x", "y", "width", "height"],
      additionalProperties: false,
    },
    rationale: { type: "string" },
  },
  required: ["headline", "rationale"],
  additionalProperties: false,
} as const;

const _BASE =
  "당신은 사진 구도 코치입니다. 반드시 한국어로 간결하게 답합니다. " +
  "headline은 한 줄 핵심 조언, rationale은 한 문장 이유입니다. ";

const _TARGETBOX_RULE =
  "targetBox는 목표 영역을 정규화 좌표(0~1, 원점 좌상단)로 나타낸 사각형입니다. " +
  "x,y는 좌상단, width,height는 크기이며 모두 0~1 사이입니다. " +
  "가능하면 3분할선/교차점에 맞추고, 대상 전체가 프레임에 담기도록 정합니다. ";

/** 모드별 시스템 프롬프트. */
export function buildSystemPrompt(mode: Mode): string {
  switch (mode) {
    case "object":
      return (
        _BASE +
        "사진 속 주요 사물을 놓을 '더 좋은 목표 위치'를 정합니다. " +
        _TARGETBOX_RULE +
        "이미 구도가 좋으면 현재 사물 위치와 비슷한 목표를 반환하세요."
      );
    case "nature":
      return (
        _BASE +
        "풍경/자연 사진의 구도를 코치합니다. 수평선 위치·3분할·전경/원경 균형을 위주로 조언합니다. " +
        "배치할 단일 피사체 박스가 없으므로 targetBox는 반환하지 마세요."
      );
    case "person":
    default:
      return (
        _BASE +
        "인물·배경·위치를 고려해 인물을 놓을 '더 좋은 목표 위치'를 정합니다. " +
        _TARGETBOX_RULE +
        "이미 구도가 좋으면 현재 인물 위치와 비슷한 목표를 반환하세요."
      );
  }
}

/** 모드별 사용자 텍스트. 온디바이스 지표는 인물 모드에서만 참고로 덧붙인다. */
export function buildUserText(mode: Mode, metrics?: OnDeviceMetrics): string {
  const lines: string[] = [];
  switch (mode) {
    case "object":
      lines.push("이 장면에서 주요 사물을 놓을 더 좋은 목표 위치를 targetBox로 제안해 주세요.");
      break;
    case "nature":
      lines.push("이 풍경 사진의 구도를 어떻게 잡으면 좋을지 조언해 주세요. targetBox는 생략하세요.");
      break;
    case "person":
    default:
      lines.push("이 장면에서 인물을 놓을 더 좋은 목표 위치를 targetBox로 제안해 주세요.");
      if (
        metrics?.hasPerson &&
        metrics.personCenterX != null &&
        metrics.personCenterY != null
      ) {
        lines.push(
          `참고(온디바이스 감지): 현재 인물 중심이 정규화 좌표 (${metrics.personCenterX}, ${metrics.personCenterY})에 있습니다.`,
        );
      }
  }
  if (metrics?.tiltDeg != null) {
    lines.push(`참고: 현재 좌우 기울기 약 ${metrics.tiltDeg}도.`);
  }
  return lines.join("\n");
}
