export interface TargetBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface CompositionAdvice {
  headline: string;
  targetBox: TargetBox;
  rationale: string;
}

export interface OnDeviceMetrics {
  tiltDeg?: number;
  personCenterX?: number;
  personCenterY?: number;
  hasPerson?: boolean;
}

function parseTargetBox(raw: unknown): TargetBox {
  const t = raw as Record<string, unknown>;
  if (
    !t ||
    typeof t.x !== "number" ||
    typeof t.y !== "number" ||
    typeof t.width !== "number" ||
    typeof t.height !== "number"
  ) {
    throw new Error("targetBox 누락 또는 형식 오류");
  }
  return { x: t.x, y: t.y, width: t.width, height: t.height };
}

/** 모델이 반환한 JSON 텍스트를 CompositionAdvice로 검증·파싱. 위반 시 throw. */
export function parseAdvice(text: string): CompositionAdvice {
  const raw = JSON.parse(text); // JSON 아니면 SyntaxError throw
  if (typeof raw.headline !== "string" || typeof raw.rationale !== "string") {
    throw new Error("headline/rationale 누락");
  }
  const targetBox = parseTargetBox(raw.targetBox);
  return { headline: raw.headline, targetBox, rationale: raw.rationale };
}
