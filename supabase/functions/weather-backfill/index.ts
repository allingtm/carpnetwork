import { corsHeaders } from "../_shared/cors.ts";
import { supabaseAdmin } from "../_shared/supabase-admin.ts";

interface WebhookPayload {
  type: "INSERT";
  table: string;
  schema: string;
  record: Record<string, unknown>;
  old_record: null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify service role authorization (database webhook)
    const authHeader = req.headers.get("Authorization");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!authHeader || authHeader !== `Bearer ${serviceRoleKey}`) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const payload: WebhookPayload = await req.json();
    const record = payload.record;

    // If weather data already present, skip
    if (record.air_pressure_mb != null) {
      return new Response(
        JSON.stringify({ ok: true, skipped: "weather already present" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const catchReportId = record.id as string;
    const venueId = record.venue_id as string | null;
    const caughtAt = record.caught_at as string | null;

    if (!venueId || !caughtAt) {
      return new Response(
        JSON.stringify({ ok: true, skipped: "missing venue or caught_at" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Look up venue coordinates
    const { data: venue, error: venueError } = await supabaseAdmin
      .from("venues")
      .select("latitude, longitude")
      .eq("id", venueId)
      .single();

    if (venueError || !venue || !venue.latitude || !venue.longitude) {
      return new Response(
        JSON.stringify({ ok: true, skipped: "venue has no coordinates" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Call weather API (OpenWeatherMap history/timemachine)
    const openWeatherKey = Deno.env.get("OPENWEATHER_API_KEY");
    if (!openWeatherKey) {
      console.error("OPENWEATHER_API_KEY not configured");
      return new Response(
        JSON.stringify({ ok: true, skipped: "weather API not configured" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const caughtAtUnix = Math.floor(new Date(caughtAt).getTime() / 1000);
    const weatherUrl =
      `https://api.openweathermap.org/data/3.0/onecall/timemachine?lat=${venue.latitude}&lon=${venue.longitude}&dt=${caughtAtUnix}&appid=${openWeatherKey}&units=metric`;

    const weatherResponse = await fetch(weatherUrl);
    if (!weatherResponse.ok) {
      console.error(
        "Weather API error:",
        weatherResponse.status,
        await weatherResponse.text(),
      );
      return new Response(
        JSON.stringify({ ok: true, skipped: "weather API unavailable" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const weatherData = await weatherResponse.json();
    const current = weatherData.data?.[0] ?? weatherData.current;

    if (!current) {
      return new Response(
        JSON.stringify({ ok: true, skipped: "no weather data available" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Extract weather fields
    const updateData: Record<string, unknown> = {};

    if (current.pressure != null) {
      updateData.air_pressure_mb = current.pressure;
    }
    if (current.temp != null) {
      updateData.temperature_c = current.temp;
    }
    if (current.wind_speed != null) {
      // OpenWeatherMap returns m/s, convert to mph
      updateData.wind_mph = Math.round(current.wind_speed * 2.237 * 10) / 10;
    }
    if (current.wind_deg != null) {
      updateData.wind_direction = degreeToCompass(current.wind_deg);
    }
    if (current.weather?.[0]?.description) {
      updateData.weather_conditions = current.weather[0].description;
    }

    if (Object.keys(updateData).length === 0) {
      return new Response(
        JSON.stringify({ ok: true, skipped: "no usable weather fields" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Update catch report
    const { error: updateError } = await supabaseAdmin
      .from("catch_reports")
      .update(updateData)
      .eq("id", catchReportId);

    if (updateError) {
      console.error("Failed to update catch report weather:", updateError);
      throw updateError;
    }

    return new Response(
      JSON.stringify({ ok: true, updated: Object.keys(updateData) }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (e) {
    console.error("weather-backfill error:", e);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

function degreeToCompass(deg: number): string {
  const directions = [
    "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
    "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW",
  ];
  const index = Math.round(deg / 22.5) % 16;
  return directions[index];
}
