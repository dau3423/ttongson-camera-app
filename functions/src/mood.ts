export type MoodKey = "warm" | "cool" | "film" | "moody" | "vivid" | "bw";

const MOODS: MoodKey[] = ["warm", "cool", "film", "moody", "vivid", "bw"];

export function parseMoodKey(raw: unknown): MoodKey {
  return MOODS.includes(raw as MoodKey) ? (raw as MoodKey) : "warm";
}

export const MOOD_SCHEMA = {
  type: "object",
  properties: {
    brightness: { type: "number" },
    contrast: { type: "number" },
    saturation: { type: "number" },
    temperature: { type: "number" },
    tint: { type: "number" },
    grayscale: { type: "boolean" },
  },
  required: ["brightness", "contrast", "saturation", "temperature", "tint", "grayscale"],
  additionalProperties: false,
} as const;

const DIRECTION: Record<MoodKey, string> = {
  warm: "따뜻하고 아늑한 분위기(색온도를 약간 앰버 쪽으로).",
  cool: "시원하고 차분한 분위기(색온도를 약간 블루 쪽으로).",
  film: "아날로그 필름 감성(대비를 살짝 낮추고 약간 바랜 톤).",
  moody: "채도를 낮춘 차분하고 무게감 있는 톤.",
  vivid: "선명하고 화사한 톤(채도·대비를 살짝 올림).",
  bw: "분위기 있는 흑백(grayscale=true).",
};

export function buildMoodSystem(mood: MoodKey): string {
  return (
    "당신은 사진 색보정 전문가입니다. 입력 사진을 분석해 요청한 분위기를 " +
    "'자연스럽고 과하지 않게' 내는 보정값을 정합니다. " +
    "brightness/contrast/saturation/temperature/tint 는 모두 -1.0~1.0, " +
    "temperature 양수=따뜻(앰버)·음수=시원(블루), tint 양수=마젠타·음수=그린. " +
    "grayscale 은 흑백일 때만 true. 값은 대체로 -0.5~0.5 범위의 은은한 보정을 권장합니다. " +
    `목표 분위기: ${DIRECTION[mood]}`
  );
}

export function buildMoodUser(mood: MoodKey): string {
  return `이 사진에 '${mood}' 분위기를 입히기 위한 보정값을 정해 주세요.`;
}

export function parseMoodParams(text: string): {
  brightness: number; contrast: number; saturation: number;
  temperature: number; tint: number; grayscale: boolean;
} {
  const raw = JSON.parse(text);
  if (raw === null || typeof raw !== "object") {
    throw new Error("보정값 JSON 형식 오류");
  }
  const c = (v: unknown): number =>
    typeof v === "number" ? Math.max(-1, Math.min(1, v)) : 0;
  return {
    brightness: c(raw.brightness),
    contrast: c(raw.contrast),
    saturation: c(raw.saturation),
    temperature: c(raw.temperature),
    tint: c(raw.tint),
    grayscale: raw.grayscale === true,
  };
}
