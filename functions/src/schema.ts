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

// OpenAI Structured Outputs(strict)용 스키마. strict는 모든 프로퍼티가 required여야 하므로
// targetBox를 required로 두되 null 허용(자연 모드 등 박스 없음)으로 표현한다.
// 클라이언트/서버 파서는 null·누락을 모두 "박스 없음"으로 처리한다.
export const COMPOSITION_OUTPUT_SCHEMA = {
  type: "object",
  properties: {
    headline: { type: "string" },
    targetBox: {
      anyOf: [
        {
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
        { type: "null" },
      ],
    },
    rationale: { type: "string" },
  },
  required: ["headline", "targetBox", "rationale"],
  additionalProperties: false,
} as const;

const _BASE =
  "당신은 사진을 잘 못 찍는 초보자를 돕는 촬영 코치입니다. 반드시 한국어로 답합니다. " +
  "headline은 한 줄 핵심 조언, rationale은 한 문장 이유입니다. " +
  "아주 쉬운 일상어만 씁니다. '3분할선·구도·교차점·프레임·수평선' 같은 전문용어를 절대 쓰지 마세요. " +
  "대신 '화면 가운데', '조금 아래로', '왼쪽으로 조금', '뒤로 한 걸음'처럼 " +
  "위치·방향·동작을 구체적이고 쉬운 말로 알려 줍니다. ";

const _TARGETBOX_RULE =
  "targetBox는 목표 영역을 정규화 좌표(0~1, 원점 좌상단)로 나타낸 사각형입니다. " +
  "x,y는 좌상단, width,height는 크기이며 모두 0~1 사이입니다. " +
  "보기 좋은 위치(화면을 세 등분한 지점 부근)에 두되 대상 전체가 화면에 담기게 합니다. " +
  "이 좌표·용어 규칙은 내부용이며, headline/rationale 문장에는 노출하지 마세요. ";

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
        "풍경 사진을 쉬운 말로 코치합니다. 하늘과 땅의 비율, 주요 대상을 어디에 둘지를 " +
        "일상어로 알려 줍니다. 배치할 단일 피사체 박스가 없으므로 targetBox는 반환하지 마세요."
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
