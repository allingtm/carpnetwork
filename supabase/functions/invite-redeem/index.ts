import { z } from "npm:zod@^3.23.0";
import { corsHeaders } from "../_shared/cors.ts";
import { supabaseAdmin } from "../_shared/supabase-admin.ts";
import { AuthError, getUser } from "../_shared/auth.ts";
import { rateLimit } from "../_shared/rate-limit.ts";
import { validate, ValidationError } from "../_shared/validate.ts";

const InputSchema = z.object({
  invite_token: z.string(),
});

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Rate limit by IP
    const ip =
      req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
    const { allowed } = await rateLimit(`invite-redeem:${ip}`, 5, 900);
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
    const { invite_token } = validate(InputSchema, body);

    // Look up invitation (service role bypasses RLS)
    const { data: invitation, error: lookupError } = await supabaseAdmin
      .from("invitations")
      .select("id, group_id, status, expires_at")
      .eq("invite_token", invite_token)
      .single();

    // Generic error — don't leak whether token exists, is expired, or used
    if (lookupError || !invitation) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired invitation" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (
      invitation.status !== "pending" ||
      new Date(invitation.expires_at) < new Date()
    ) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired invitation" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Check if user is already a member
    const { data: existing } = await supabaseAdmin
      .from("group_memberships")
      .select("id")
      .eq("group_id", invitation.group_id)
      .eq("user_id", user.id)
      .maybeSingle();

    if (existing) {
      return new Response(
        JSON.stringify({ error: "Already a member of this group" }),
        {
          status: 409,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Create membership
    const { error: memberError } = await supabaseAdmin
      .from("group_memberships")
      .insert({
        group_id: invitation.group_id,
        user_id: user.id,
        role: "member",
      });

    if (memberError) throw memberError;

    // Update invitation status
    const { error: updateError } = await supabaseAdmin
      .from("invitations")
      .update({
        status: "accepted",
        redeemed_by: user.id,
        redeemed_at: new Date().toISOString(),
      })
      .eq("id", invitation.id);

    if (updateError) throw updateError;

    // Get group name for the response
    const { data: group } = await supabaseAdmin
      .from("groups")
      .select("name")
      .eq("id", invitation.group_id)
      .single();

    return new Response(
      JSON.stringify({
        group_id: invitation.group_id,
        group_name: group?.name ?? "Unknown",
      }),
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
    console.error("invite-redeem error:", e);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
