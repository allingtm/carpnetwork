import { z } from "npm:zod@^3.23.0";
import { Redis } from "npm:@upstash/redis@^1.34.0";
import { corsHeaders } from "../_shared/cors.ts";
import { AuthError, getUser } from "../_shared/auth.ts";
import { rateLimit } from "../_shared/rate-limit.ts";
import { validate, ValidationError } from "../_shared/validate.ts";

const InputSchema = z.object({
  r2_key: z.string(),
});

const redis = new Redis({
  url: Deno.env.get("UPSTASH_REDIS_REST_URL")!,
  token: Deno.env.get("UPSTASH_REDIS_REST_TOKEN")!,
});

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Authenticate
    const user = await getUser(req);

    // Rate limit by user
    const { allowed } = await rateLimit(
      `photos-confirm:${user.id}`,
      30,
      900,
    );
    if (!allowed) {
      return new Response(JSON.stringify({ error: "Too many requests" }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Validate input
    const body = await req.json();
    const { r2_key } = validate(InputSchema, body);

    // Look up presign record in Redis
    const raw = await redis.get(`presign:${r2_key}`);
    if (!raw) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired upload" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const redisData = typeof raw === "string" ? JSON.parse(raw) : raw;

    // Verify user matches
    if (redisData.user_id !== user.id) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired upload" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Dispatch Inngest event for photo processing via REST API
    const inngestEventKey = Deno.env.get("INNGEST_EVENT_KEY");
    if (!inngestEventKey) {
      throw new Error("INNGEST_EVENT_KEY not configured");
    }

    const inngestResponse = await fetch("https://inn.gs/e/" + inngestEventKey, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: "photo/process",
        data: {
          r2_key,
          catch_report_id: redisData.catch_report_id,
          group_id: redisData.group_id,
          user_id: redisData.user_id,
        },
      }),
    });

    if (!inngestResponse.ok) {
      console.error(
        "Failed to dispatch Inngest event:",
        await inngestResponse.text(),
      );
      throw new Error("Failed to dispatch photo processing job");
    }

    // Delete presign record from Redis
    await redis.del(`presign:${r2_key}`);

    return new Response(JSON.stringify({ status: "processing" }), {
      status: 202,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    if (e instanceof AuthError) {
      return new Response(JSON.stringify({ error: e.message }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (e instanceof ValidationError) {
      return new Response(
        JSON.stringify({ error: "Invalid input", details: e.issues }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    console.error("photos-confirm error:", e);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
