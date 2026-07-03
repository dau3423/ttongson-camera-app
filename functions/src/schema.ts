import type { OnDeviceMetrics } from "./advice.js";

export const COMPOSITION_SCHEMA = {
  type: "object",
  properties: {
    headline: { type: "string" },
    directions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          axis: { type: "string", enum: ["move", "tilt", "zoom", "angle"] },
          instruction: { type: "string" },
        },
        required: ["axis", "instruction"],
        additionalProperties: false,
      },
    },
    rationale: { type: "string" },
  },
  required: ["headline", "directions", "rationale"],
  additionalProperties: false,
} as const;

export const SYSTEM_PROMPT =
  "당신은 사진 구도 코치입니다. 사용자가 카메라로 보고 있는 장면 사진 한 장을 받고, " +
  "인물·배경·위치를 고려해 더 좋은 구도로 찍는 방법을 제안합니다. " +
  "반드시 한국어로, 간결하고 바로 실행 가능한 조언만 제공합니다. " +
  "headline은 한 줄 핵심, directions는 실행 힌트 목록(axis: move=이동, tilt=수평 기울기, zoom=줌/거리, angle=촬영 각도), " +
  "rationale은 한 문장 이유입니다. 이미 좋은 부분은 굳이 바꾸라고 하지 마세요.";

export function buildUserText(metrics?: OnDeviceMetrics): string {
  const lines = ["이 장면을 더 좋은 구도로 찍는 방법을 제안해 주세요."];
  if (metrics) {
    if (metrics.hasPerson && metrics.personCenterX != null && metrics.personCenterY != null) {
      lines.push(
        `참고(온디바이스 감지): 인물 중심이 정규화 좌표 (${metrics.personCenterX}, ${metrics.personCenterY})에 있습니다.`,
      );
    }
    if (metrics.tiltDeg != null) {
      lines.push(`참고: 현재 좌우 기울기 약 ${metrics.tiltDeg}도.`);
    }
  }
  return lines.join("\n");
}
