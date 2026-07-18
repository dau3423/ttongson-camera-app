// functions/src/openai.ts
// OpenAI 비전+구조화 출력 공통 호출. advise/enhance/포즈추천이 공유한다.
import OpenAI from "openai";

/** 통일 모델. 정확한 마이너 버전 고정이 필요하면 여기만 바꾼다. */
export const OPENAI_MODEL = "gpt-5-mini";

/**
 * system 지시 + userText + 이미지 1장을 보내 JSON 문자열을 돌려준다.
 * response_format(json_schema, strict)로 스키마를 강제한다. 파싱은 호출측 책임.
 */
export async function visionJson(params: {
  apiKey: string;
  system: string;
  userText: string;
  imageBase64: string;
  schemaName: string;
  schema: { [key: string]: unknown };
}): Promise<string> {
  const client = new OpenAI({ apiKey: params.apiKey });
  const response = await client.chat.completions.create({
    model: OPENAI_MODEL,
    // GPT-5는 추론 모델 — 추론 토큰이 max_completion_tokens에 포함된다.
    // 추론을 낮추고(작은 JSON 출력엔 충분) 상한을 넉넉히 줘 빈 응답을 막는다.
    reasoning_effort: "low",
    max_completion_tokens: 4096,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: params.schemaName,
        schema: params.schema,
        strict: true,
      },
    },
    messages: [
      { role: "system", content: params.system },
      {
        role: "user",
        content: [
          { type: "text", text: params.userText },
          {
            type: "image_url",
            image_url: {
              url: `data:image/jpeg;base64,${params.imageBase64}`,
            },
          },
        ],
      },
    ],
  });
  const text = response.choices[0]?.message?.content;
  if (!text) {
    // 진단: 빈 응답 원인(길이 초과·거부 등)을 로그로 남긴다.
    console.error("visionJson empty content", {
      finishReason: response.choices[0]?.finish_reason,
      usage: response.usage,
    });
    throw new Error("모델 응답이 비어 있습니다");
  }
  return text;
}
