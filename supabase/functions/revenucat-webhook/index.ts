import { corsHeaders } from "../_shared/cors.ts";
import { supabaseAdmin } from "../_shared/supabase-admin.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify webhook secret (no JWT — verify_jwt = false in config.toml)
    const authHeader = req.headers.get("Authorization");
    const expectedSecret = Deno.env.get("REVENUCAT_WEBHOOK_SECRET");
    if (!authHeader || authHeader !== `Bearer ${expectedSecret}`) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const payload = await req.json();
    const event = payload.event;
    if (!event) {
      return new Response(JSON.stringify({ error: "Invalid payload" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const eventId = event.id as string;
    const eventType = event.type as string;
    const appUserId = event.app_user_id as string;

    if (!eventId || !eventType || !appUserId) {
      return new Response(JSON.stringify({ error: "Missing event fields" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Idempotency check via stripe_events table
    const { data: existing } = await supabaseAdmin
      .from("stripe_events")
      .select("id")
      .eq("event_id", eventId)
      .maybeSingle();

    if (existing) {
      // Already processed — return 200 to prevent retries
      return new Response(JSON.stringify({ ok: true, duplicate: true }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Store event for idempotency
    const { error: insertError } = await supabaseAdmin
      .from("stripe_events")
      .insert({
        event_id: eventId,
        event_type: eventType,
        payload,
      });

    if (insertError) {
      console.error("Failed to insert stripe_event:", insertError);
    }

    // Map RevenueCat event to subscription state
    let subscriptionStatus: string;
    let subscriptionGraceUntil: string | null = null;
    const periodEndMs = event.expiration_at_ms as number | undefined;
    const periodEnd = periodEndMs
      ? new Date(periodEndMs).toISOString()
      : null;

    switch (eventType) {
      case "INITIAL_PURCHASE":
      case "RENEWAL":
        subscriptionStatus = "active";
        break;
      case "CANCELLATION":
        // Access continues until period end
        subscriptionStatus = "active";
        break;
      case "BILLING_ISSUE":
        subscriptionStatus = "past_due";
        if (periodEndMs) {
          // Grace period: period_end + 7 days
          subscriptionGraceUntil = new Date(
            periodEndMs + 7 * 24 * 60 * 60 * 1000,
          ).toISOString();
        }
        break;
      case "EXPIRATION":
        subscriptionStatus = "inactive";
        break;
      default:
        // Unhandled event type — acknowledge but don't update
        return new Response(
          JSON.stringify({ ok: true, skipped: eventType }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
    }

    // Update user subscription status
    const updateData: Record<string, unknown> = {
      subscription_status: subscriptionStatus,
    };
    if (periodEnd) {
      updateData.subscription_period_end = periodEnd;
    }
    if (subscriptionGraceUntil !== null) {
      updateData.subscription_grace_until = subscriptionGraceUntil;
    } else if (eventType !== "BILLING_ISSUE") {
      updateData.subscription_grace_until = null;
    }

    const { error: updateError } = await supabaseAdmin
      .from("users")
      .update(updateData)
      .eq("id", appUserId);

    if (updateError) {
      console.error("Failed to update user subscription:", updateError);
      return new Response(JSON.stringify({ error: "Failed to update user" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("revenucat-webhook error:", e);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
