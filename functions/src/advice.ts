export interface AdviceDirection {
  axis: "move" | "tilt" | "zoom" | "angle";
  instruction: string;
}

export interface CompositionAdvice {
  headline: string;
  directions: AdviceDirection[];
  rationale: string;
}

export interface OnDeviceMetrics {
  tiltDeg?: number;
  personCenterX?: number;
  personCenterY?: number;
  hasPerson?: boolean;
}

const VALID_AXES = new Set(["move", "tilt", "zoom", "angle"]);

/** 모델이 반환한 JSON 텍스트를 CompositionAdvice로 검증·파싱. 위반 시 throw. */
export function parseAdvice(text: string): CompositionAdvice {
  const raw = JSON.parse(text); // JSON 아니면 SyntaxError throw
  if (typeof raw.headline !== "string" || typeof raw.rationale !== "string") {
    throw new Error("headline/rationale 누락");
  }
  if (!Array.isArray(raw.directions)) {
    throw new Error("directions 누락");
  }
  const directions: AdviceDirection[] = raw.directions.map((d: unknown) => {
    const dir = d as Record<string, unknown>;
    if (!VALID_AXES.has(dir.axis as string) || typeof dir.instruction !== "string") {
      throw new Error(`잘못된 direction: ${JSON.stringify(d)}`);
    }
    return { axis: dir.axis as AdviceDirection["axis"], instruction: dir.instruction };
  });
  return { headline: raw.headline, directions, rationale: raw.rationale };
}
