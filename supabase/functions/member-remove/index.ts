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
  user_id: z.string().uuid(),
});

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Rate limit by IP
    const ip =
      req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
    const { allowed } = await rateLimit(`member-remove:${ip}`, 10, 900);
    if (!allowed) {
      return new Response(JSON.stringify({ error: "Too many requests" }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Authenticate
    const caller = await getUser(req);

    // Validate input
    const body = await req.json();
    const { group_id, user_id } = validate(InputSchema, body);

    // Cannot remove yourself (use "leave group" instead)
    if (caller.id === user_id) {
      return new Response(
        JSON.stringify({
          error: "Cannot remove yourself. Use leave group instead.",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Verify caller is admin
    await requireGroupAdmin(caller.id, group_id);

    // Verify target is a non-admin member
    const { data: targetMembership, error: targetError } = await supabaseAdmin
      .from("group_memberships")
      .select("role")
      .eq("group_id", group_id)
      .eq("user_id", user_id)
      .single();

    if (targetError || !targetMembership) {
      return new Response(
        JSON.stringify({ error: "User is not a member of this group" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (targetMembership.role === "admin") {
      return new Response(
        JSON.stringify({ error: "Cannot remove an admin" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Insert audit record into removed_members
    const { error: auditError } = await supabaseAdmin
      .from("removed_members")
      .insert({
        group_id,
        user_id,
        removed_by: caller.id,
        reason: "removed",
        export_available_until: new Date(
          Date.now() + 30 * 24 * 60 * 60 * 1000,
        ).toISOString(),
      });

    if (auditError) throw auditError;

    // Delete from group_memberships (hard delete — trigger decrements member_count)
    const { error: deleteError } = await supabaseAdmin
      .from("group_memberships")
      .delete()
      .eq("group_id", group_id)
      .eq("user_id", user_id);

    if (deleteError) throw deleteError;

    // Invalidate the removed user's sessions
    await supabaseAdmin.auth.admin.signOut(user_id);

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
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
    console.error("member-remove error:", e);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
