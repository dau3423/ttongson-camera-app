import type { OnDeviceMetrics } from "./advice.js";

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
  required: ["headline", "targetBox", "rationale"],
  additionalProperties: false,
} as const;

export const SYSTEM_PROMPT =
  "당신은 사진 구도 코치입니다. 사용자가 카메라로 보고 있는 장면 사진 한 장을 받고, " +
  "인물·배경·위치를 고려해 인물을 놓을 '더 좋은 목표 위치'를 정합니다. " +
  "반드시 한국어로 간결하게 답합니다. " +
  "headline은 한 줄 핵심 조언, rationale은 한 문장 이유입니다. " +
  "targetBox는 인물이 들어갈 목표 영역을 정규화 좌표(0~1, 원점 좌상단)로 나타낸 사각형입니다. " +
  "x,y는 좌상단, width,height는 크기이며 모두 0~1 사이입니다. " +
  "가능하면 3분할선/교차점에 맞추고, 인물 전체가 프레임에 담기도록 정합니다. " +
  "이미 구도가 좋으면 현재 인물 위치와 비슷한 목표를 반환하세요.";

export function buildUserText(metrics?: OnDeviceMetrics): string {
  const lines = [
    "이 장면에서 인물을 놓을 더 좋은 목표 위치를 targetBox로 제안해 주세요.",
  ];
  if (metrics) {
    if (
      metrics.hasPerson &&
      metrics.personCenterX != null &&
      metrics.personCenterY != null
    ) {
      lines.push(
        `참고(온디바이스 감지): 현재 인물 중심이 정규화 좌표 (${metrics.personCenterX}, ${metrics.personCenterY})에 있습니다.`,
      );
    }
    if (metrics.tiltDeg != null) {
      lines.push(`참고: 현재 좌우 기울기 약 ${metrics.tiltDeg}도.`);
    }
  }
  return lines.join("\n");
}
