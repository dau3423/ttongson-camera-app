// functions/src/claude.ts
import Anthropic from "@anthropic-ai/sdk";
import { COMPOSITION_SCHEMA, buildSystemPrompt, buildUserText } from "./schema.js";
import { parseAdvice, type CompositionAdvice, type Mode, type OnDeviceMetrics } from "./advice.js";

export async function requestAdvice(
  apiKey: string,
  imageBase64: string,
  mediaType: "image/jpeg",
  metrics: OnDeviceMetrics | undefined,
  mode: Mode,
): Promise<CompositionAdvice> {
  const client = new Anthropic({ apiKey });
  // 구조화 출력: output_config.format(json_schema).
  const response = await client.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    system: buildSystemPrompt(mode),
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
          { type: "text", text: buildUserText(mode, metrics) },
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
