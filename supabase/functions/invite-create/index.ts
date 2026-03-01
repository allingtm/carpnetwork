import { z } from "npm:zod@^3.23.0";
import { corsHeaders } from "../_shared/cors.ts";
import { supabaseAdmin } from "../_shared/supabase-admin.ts";
import {
  AuthError,
  ForbiddenError,
  getUser,
  requireGroupAdmin,
} from "../_shared/auth.ts";
import { rateLimit } from "../_shared/rate-limit.ts";
import { validate, ValidationError } from "../_shared/validate.ts";

const InputSchema = z.object({
  group_id: z.string().uuid(),
});

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Rate limit by IP
    const ip =
      req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
    const { allowed } = await rateLimit(`invite-create:${ip}`, 5, 900);
    if (!allowed) {
      return new Response(JSON.stringify({ error: "Too many requests" }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Authenticate
    const user = await getUser(req);

    // Validate input
    const body = await req.json();
    const { group_id } = validate(InputSchema, body);

    // Verify caller is admin of the group
    await requireGroupAdmin(user.id, group_id);

    // Generate 128-bit cryptographic invite token (base64url)
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    const invite_token = btoa(String.fromCharCode(...bytes))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=/g, "");

    // Expiry: 7 days from now
    const expires_at = new Date(
      Date.now() + 7 * 24 * 60 * 60 * 1000,
    ).toISOString();

    // Insert invitation
    const { error } = await supabaseAdmin.from("invitations").insert({
      group_id,
      invited_by: user.id,
      invite_token,
      expires_at,
      status: "pending",
    });

    if (error) throw error;

    return new Response(
      JSON.stringify({
        invite_token,
        invite_url: `https://carp.network/invite/${invite_token}`,
        expires_at,
      }),
      {
        status: 201,
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
    if (e instanceof ForbiddenError) {
      return new Response(JSON.stringify({ error: e.message }), {
        status: 403,
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
    console.error("invite-create error:", e);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
