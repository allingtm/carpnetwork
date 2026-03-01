import { Redis } from "npm:@upstash/redis@^1.34.0";
import { Ratelimit } from "npm:@upstash/ratelimit@^2.0.0";

const redis = new Redis({
  url: Deno.env.get("UPSTASH_REDIS_REST_URL")!,
  token: Deno.env.get("UPSTASH_REDIS_REST_TOKEN")!,
});

export async function rateLimit(
  key: string,
  limit: number,
  windowSeconds: number,
): Promise<{ allowed: boolean; remaining: number }> {
  const ratelimit = new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(limit, `${windowSeconds} s`),
    prefix: "carp",
  });
  const { success, remaining } = await ratelimit.limit(key);
  return { allowed: success, remaining };
}
