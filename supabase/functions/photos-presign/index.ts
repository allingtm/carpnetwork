import { z } from "npm:zod@^3.23.0";
import { S3Client, PutObjectCommand } from "npm:@aws-sdk/client-s3@^3.600.0";
import { getSignedUrl } from "npm:@aws-sdk/s3-request-presigner@^3.600.0";
import { Redis } from "npm:@upstash/redis@^1.34.0";
import { corsHeaders } from "../_shared/cors.ts";
import { supabaseAdmin } from "../_shared/supabase-admin.ts";
import { AuthError, getUser } from "../_shared/auth.ts";
import { rateLimit } from "../_shared/rate-limit.ts";
import { validate, ValidationError } from "../_shared/validate.ts";

const MAX_FILE_SIZE = 4_194_304; // 4MB

const InputSchema = z.object({
  catch_report_id: z.string().uuid(),
  group_id: z.string().uuid(),
  file_type: z.literal("image/jpeg"),
  file_size: z.number().int().positive().max(MAX_FILE_SIZE),
});

const s3 = new S3Client({
  region: "auto",
  endpoint: Deno.env.get("CLOUDFLARE_R2_ENDPOINT")!,
  credentials: {
    accessKeyId: Deno.env.get("CLOUDFLARE_R2_ACCESS_KEY_ID")!,
    secretAccessKey: Deno.env.get("CLOUDFLARE_R2_SECRET_ACCESS_KEY")!,
  },
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
      `photos-presign:${user.id}`,
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
    const { catch_report_id, group_id, file_size } = validate(
      InputSchema,
      body,
    );

    // Verify user is a member of the group
    const { data: membership, error: memberError } = await supabaseAdmin
      .from("group_memberships")
      .select("id")
      .eq("group_id", group_id)
      .eq("user_id", user.id)
      .maybeSingle();

    if (memberError || !membership) {
      return new Response(
        JSON.stringify({ error: "Not a member of this group" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Generate R2 object key
    const fileId = crypto.randomUUID();
    const r2Key =
      `groups/${group_id}/catches/${catch_report_id}/${fileId}.jpg`;

    // Create presigned PutObject URL (10 minute expiry)
    const command = new PutObjectCommand({
      Bucket: Deno.env.get("CLOUDFLARE_R2_BUCKET_NAME")!,
      Key: r2Key,
      ContentType: "image/jpeg",
      ContentLength: file_size,
    });
    const presignedUrl = await getSignedUrl(s3, command, { expiresIn: 600 });

    // Store presign record in Redis with 10-minute TTL
    await redis.set(
      `presign:${r2Key}`,
      JSON.stringify({ user_id: user.id, catch_report_id, group_id }),
      { ex: 600 },
    );

    return new Response(
      JSON.stringify({ presigned_url: presignedUrl, r2_key: r2Key }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
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
    console.error("photos-presign error:", e);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
