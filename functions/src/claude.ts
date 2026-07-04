// functions/src/claude.ts
import Anthropic from "@anthropic-ai/sdk";
import { COMPOSITION_SCHEMA, SYSTEM_PROMPT, buildUserText } from "./schema.js";
import { parseAdvice, type CompositionAdvice, type OnDeviceMetrics } from "./advice.js";

export async function requestAdvice(
  apiKey: string,
  imageBase64: string,
  mediaType: "image/jpeg",
  metrics: OnDeviceMetrics | undefined,
): Promise<CompositionAdvice> {
  const client = new Anthropic({ apiKey });
  // 구조화 출력: output_config.format(json_schema). (구 output_format 필드는 폐기됨)
  const response = await client.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    system: SYSTEM_PROMPT,
    output_config: {
      format: {
        type: "json_schema",
        schema: COMPOSITION_SCHEMA as { [key: string]: unknown },
      },
    },
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image",
            source: { type: "base64", media_type: mediaType, data: imageBase64 },
          },
          { type: "text", text: buildUserText(metrics) },
        ],
      },
    ],
  });
  const textBlock = response.content.find((b) => b.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new Error("모델 응답에 텍스트 블록이 없습니다");
  }
  return parseAdvice(textBlock.text);
}
