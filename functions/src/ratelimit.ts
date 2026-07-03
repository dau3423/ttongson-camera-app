/** 고정 윈도우 시작 시각(ms). */
export function windowStart(nowMs: number, windowMs: number): number {
  return Math.floor(nowMs / windowMs) * windowMs;
}

/** 현재 카운트가 상한 이상인지. */
export function overLimit(count: number, max: number): boolean {
  return count >= max;
}
