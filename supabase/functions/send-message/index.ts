import { z } from "npm:zod@^3.23.0";
import { corsHeaders } from "../_shared/cors.ts";
import { supabaseAdmin } from "../_shared/supabase-admin.ts";
import { AuthError, getUser } from "../_shared/auth.ts";
import { rateLimit } from "../_shared/rate-limit.ts";
import { validate, ValidationError } from "../_shared/validate.ts";

const InputSchema = z.object({
  group_id: z.string().uuid(),
  content: z.string().min(1).max(2000),
  reply_to_id: z.string().uuid().optional(),
});

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Authenticate
    const user = await getUser(req);

    // Rate limit: 30 per user per minute
    const { allowed } = await rateLimit(`send-message:${user.id}`, 30, 60);
    if (!allowed) {
      return new Response(JSON.stringify({ error: "Too many requests" }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Validate input
    const body = await req.json();
    const { group_id, content, reply_to_id } = validate(InputSchema, body);

    // Verify user is a member of the group
    const { data: membership } = await supabaseAdmin
      .from("group_memberships")
      .select("id")
      .eq("group_id", group_id)
      .eq("user_id", user.id)
      .maybeSingle();

    if (!membership) {
      return new Response(
        JSON.stringify({ error: "Not a member of this group" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // If reply_to_id, verify the replied message exists in the same group
    if (reply_to_id) {
      const { data: replyTarget } = await supabaseAdmin
        .from("messages")
        .select("id")
        .eq("id", reply_to_id)
        .eq("group_id", group_id)
        .maybeSingle();

      if (!replyTarget) {
        return new Response(
          JSON.stringify({ error: "Reply target not found in this group" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
    }

    // Insert message
    const { data: message, error: insertError } = await supabaseAdmin
      .from("messages")
      .insert({
        group_id,
        user_id: user.id,
        content,
        reply_to_id: reply_to_id ?? null,
      })
      .select()
      .single();

    if (insertError || !message) {
      throw insertError ?? new Error("Failed to insert message");
    }

    // Send Broadcast event to group channel
    const channel = supabaseAdmin.channel(`group:${group_id}`);
    await channel.send({
      type: "broadcast",
      event: "new_message",
      payload: {
        id: message.id,
        group_id: message.group_id,
        user_id: message.user_id,
        content: message.content,
        reply_to_id: message.reply_to_id,
        created_at: message.created_at,
      },
    });
    await supabaseAdmin.removeChannel(channel);

    // Get group members (excluding sender) for push notifications
    const { data: members } = await supabaseAdmin
      .from("group_memberships")
      .select("user_id")
      .eq("group_id", group_id)
      .neq("user_id", user.id);

    if (members && members.length > 0) {
      const memberIds = members.map((m) => m.user_id);

      // Get sender name for notification
      const { data: sender } = await supabaseAdmin
        .from("users")
        .select("full_name")
        .eq("id", user.id)
        .single();

      const { data: group } = await supabaseAdmin
        .from("groups")
        .select("name")
        .eq("id", group_id)
        .single();

      const senderName = sender?.full_name ?? "Someone";
      const groupName = group?.name ?? "a group";
      const preview = content.length > 50
        ? content.substring(0, 50) + "..."
        : content;

      // Call push-send function
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

      await fetch(`${supabaseUrl}/functions/v1/push-send`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${serviceRoleKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          user_ids: memberIds,
          title: `${senderName} in ${groupName}`,
          body: preview,
          data: { route: `/groups/${group_id}/chat`, group_id },
        }),
      });
    }

    return new Response(JSON.stringify(message), {
      status: 201,
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
    console.error("send-message error:", e);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
