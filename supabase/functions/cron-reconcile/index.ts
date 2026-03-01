import { corsHeaders } from "../_shared/cors.ts";
import { supabaseAdmin } from "../_shared/supabase-admin.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Authenticate via CRON_SECRET header
  const cronSecret = Deno.env.get("CRON_SECRET");
  const authHeader = req.headers.get("x-cron-secret");

  if (!cronSecret || authHeader !== cronSecret) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const results: Record<string, unknown> = {};

  try {
    // 1. Reconcile groups.member_count against actual group_memberships count
    const { data: groups, error: groupsError } = await supabaseAdmin
      .from("groups")
      .select("id");

    if (groupsError) throw groupsError;

    let reconciled = 0;
    for (const group of groups ?? []) {
      const { count, error: countError } = await supabaseAdmin
        .from("group_memberships")
        .select("*", { count: "exact", head: true })
        .eq("group_id", group.id);

      if (countError) {
        console.error(`Error counting members for group ${group.id}:`, countError);
        continue;
      }

      const { error: updateError } = await supabaseAdmin
        .from("groups")
        .update({ member_count: count ?? 0 })
        .eq("id", group.id);

      if (!updateError) reconciled++;
    }
    results.member_count_reconciled = reconciled;

    // 2. Prune stripe_events older than 90 days
    const ninetyDaysAgo = new Date();
    ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);

    const { count: prunedEvents, error: eventsError } = await supabaseAdmin
      .from("stripe_events")
      .delete({ count: "exact" })
      .lt("created_at", ninetyDaysAgo.toISOString());

    if (eventsError) {
      // Table may not exist yet — log but don't fail
      console.warn("stripe_events prune skipped:", eventsError.message);
      results.stripe_events_pruned = "skipped";
    } else {
      results.stripe_events_pruned = prunedEvents ?? 0;
    }

    // 3. Prune user_devices where last_active_at < 60 days ago (stale FCM tokens)
    const sixtyDaysAgo = new Date();
    sixtyDaysAgo.setDate(sixtyDaysAgo.getDate() - 60);

    const { count: prunedDevices, error: devicesError } = await supabaseAdmin
      .from("user_devices")
      .delete({ count: "exact" })
      .lt("last_active_at", sixtyDaysAgo.toISOString());

    if (devicesError) {
      console.warn("user_devices prune skipped:", devicesError.message);
      results.stale_devices_pruned = "skipped";
    } else {
      results.stale_devices_pruned = prunedDevices ?? 0;
    }

    return new Response(JSON.stringify({ ok: true, results }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("cron-reconcile error:", e);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(e) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
