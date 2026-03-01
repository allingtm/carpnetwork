# Carp.Network — Step 05: Photo Upload Pipeline — Edge Functions + Inngest Job

**Read the spec file first:** `Carp-Network-Design-Specification-v1.5-Final.md` — Sections 4.2, 4.2.1, 7.1, 17.4  
**Depends on:** Step 04 (shared Edge Function utilities), Step 00 (Inngest project)  
**Commit after completion:** `git commit -m "Step 05: Photo pipeline — photos-presign, photos-confirm, photo-process Inngest job"`

---

## Context

The photo pipeline is split across three components because of a platform constraint: the sharp library (used for EXIF stripping) has native C bindings that are incompatible with Deno. So the flow is:

1. **photos-presign** (Edge Function, Deno) — generates a presigned R2 upload URL
2. **photos-confirm** (Edge Function, Deno) — validates the upload and dispatches processing
3. **photo-process** (Inngest job, Node.js) — downloads, strips EXIF with sharp, re-uploads

---

## Task 1: photos-presign Edge Function

Create `supabase/functions/photos-presign/index.ts`.

**Auth:** JWT required  
**Rate limit:** 30 per user per 15 minutes

**Input (Zod strict):**
```typescript
{
  catch_report_id: string,  // UUID
  group_id: string,         // UUID
  file_type: string,        // Must be "image/jpeg"
  file_size: number         // Must be < 4MB (4_194_304 bytes)
}
```

**Logic:**
1. Verify JWT, extract user_id
2. Verify user is member of the group
3. Validate file_type is exactly "image/jpeg"
4. Validate file_size < 4MB
5. Generate R2 object key: `groups/{group_id}/catches/{catch_report_id}/{uuid_v4}.jpg`
6. Create presigned PutObject URL using AWS S3 SDK (R2 is S3-compatible):
   ```typescript
   import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
   import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
   
   const s3 = new S3Client({
     region: "auto",
     endpoint: Deno.env.get("CLOUDFLARE_R2_ENDPOINT"),
     credentials: {
       accessKeyId: Deno.env.get("CLOUDFLARE_R2_ACCESS_KEY_ID"),
       secretAccessKey: Deno.env.get("CLOUDFLARE_R2_SECRET_ACCESS_KEY"),
     },
   });
   
   const url = await getSignedUrl(s3, new PutObjectCommand({
     Bucket: Deno.env.get("CLOUDFLARE_R2_BUCKET_NAME"),
     Key: r2Key,
     ContentType: "image/jpeg",
     ContentLength: file_size,
   }), { expiresIn: 600 }); // 10 minutes
   ```
7. Store the R2 key in Upstash Redis with 10-minute TTL (for validation in photos-confirm):
   ```typescript
   await redis.set(`presign:${r2Key}`, JSON.stringify({ user_id, catch_report_id, group_id }), { ex: 600 });
   ```
8. Return `{ presigned_url, r2_key }`

**Reference:** Spec Section 4.2 (steps 4–6), 17.10

---

## Task 2: photos-confirm Edge Function

Create `supabase/functions/photos-confirm/index.ts`.

**Auth:** JWT required  
**Rate limit:** 30 per user per 15 minutes

**Input (Zod strict):**
```typescript
{
  r2_key: string
}
```

**Logic:**
1. Verify JWT, extract user_id
2. Look up the R2 key in Redis: `await redis.get(`presign:${r2_key}`)`
3. If no Redis record exists → 400 "Invalid or expired upload"
4. Verify the user_id in the Redis record matches the JWT user_id
5. Dispatch an Inngest event to trigger the `photo-process` job:
   ```typescript
   await inngest.send({
     name: "photo/process",
     data: {
       r2_key,
       catch_report_id: redisData.catch_report_id,
       group_id: redisData.group_id,
       user_id: redisData.user_id,
     },
   });
   ```
   Use Inngest's REST API to send the event (POST to `https://inn.gs/e/{INNGEST_SIGNING_KEY}` or use the Inngest SDK's HTTP send method).
6. Delete the Redis presign record
7. Return 202 Accepted: `{ status: "processing" }`

**Important:** This function does NOT do EXIF stripping. Sharp cannot run in Deno.

**Reference:** Spec Section 4.2 (steps 7–9)

---

## Task 3: photo-process Inngest Job

Create `inngest/src/functions/photo-process.ts`.

This is a **Node.js** function, not a Deno Edge Function.

```typescript
import { inngest } from "../client";
import sharp from "sharp";
import { S3Client, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import { createClient } from "@supabase/supabase-js";

export const photoProcess = inngest.createFunction(
  { id: "photo-process", retries: 3 },
  { event: "photo/process" },
  async ({ event }) => {
    const { r2_key, catch_report_id, group_id, user_id } = event.data;
    
    // 1. Download from R2, capture ETag
    const getResponse = await s3.send(new GetObjectCommand({
      Bucket: process.env.CLOUDFLARE_R2_BUCKET_NAME,
      Key: r2_key,
    }));
    const etag = getResponse.ETag;
    const buffer = Buffer.from(await getResponse.Body.transformToByteArray());
    
    // 2. Process with sharp
    const processed = await sharp(buffer)
      .rotate()                    // Apply EXIF orientation FIRST
      .keepIccProfile()            // ICC profile has no personal data
      .withMetadata({              // Strip everything else
        exif: undefined,
        xmp: undefined,
        iptc: undefined,
      })
      .jpeg({ quality: 85 })
      .toBuffer();
    
    // 3. Verify metadata is stripped
    const metadata = await sharp(processed).metadata();
    if (metadata.exif || metadata.xmp || metadata.iptc) {
      throw new Error("EXIF stripping failed — metadata still present");
    }
    
    // 4. Re-upload to R2 (verify ETag hasn't changed)
    await s3.send(new PutObjectCommand({
      Bucket: process.env.CLOUDFLARE_R2_BUCKET_NAME,
      Key: r2_key,
      Body: processed,
      ContentType: "image/jpeg",
      // Note: R2 doesn't support conditional PutObject with If-Match,
      // so verify ETag separately if needed
    }));
    
    // 5. Create database record
    const supabase = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );
    
    const publicUrl = `${process.env.CLOUDFLARE_R2_PUBLIC_URL}/${r2_key}`;
    
    await supabase.from("catch_report_photos").insert({
      catch_report_id,
      group_id,
      r2_key,
      url: publicUrl,
      uploaded_by: user_id,
    });
    
    // 6. Send Broadcast event so connected clients update the photo placeholder
    const channel = supabase.channel(`group:${group_id}`);
    await channel.send({
      type: "broadcast",
      event: "photo_ready",
      payload: { catch_report_id, r2_key, url: publicUrl },
    });
    await supabase.removeChannel(channel);
    
    return { success: true, r2_key };
  }
);
```

**Update `inngest/src/client.ts`** to export the Inngest client:
```typescript
import { Inngest } from "inngest";
export const inngest = new Inngest({ id: "carp-network" });
```

**Update or create `inngest/src/index.ts`** to register all functions with Inngest serve.

**Reference:** Spec Section 4.2 (steps 10–16)

---

## Task 4: Send Message Edge Function

Create `supabase/functions/send-message/index.ts`.

**Auth:** JWT required  
**Rate limit:** 30 per user per minute

**Input (Zod strict):**
```typescript
{
  group_id: string,
  content: string,        // max 2000 chars
  reply_to_id?: string    // optional UUID
}
```

**Logic:**
1. Verify JWT, extract user_id
2. Verify user is member of the group
3. If reply_to_id provided, verify it exists in the same group
4. Insert message into `messages` table (service role)
5. Send Broadcast event to `group:{groupId}` channel:
   ```typescript
   channel.send({
     type: "broadcast",
     event: "new_message",
     payload: { id, group_id, user_id, content, reply_to_id, created_at }
   });
   ```
6. Query group members (excluding sender) from `group_memberships`
7. Call `push-send` function for all other members with notification data
8. Return the created message object

**Reference:** Spec Sections 7.1, 9.1

---

## Task 5: Weather Backfill Edge Function

Create `supabase/functions/weather-backfill/index.ts`.

**Auth:** Service role / database webhook (not called by clients)

This function is triggered by a database webhook when a catch_report is inserted with null weather fields. It backfills weather data from the weather API.

**Logic:**
1. Receive the inserted catch_report record
2. If `air_pressure_mb IS NOT NULL`, return (already has weather data — was logged online)
3. Look up the venue's coordinates from the `venues` table using `venue_id`
4. Call the weather API with coordinates and `caught_at` timestamp
5. Update the catch_report with: `air_pressure_mb`, `temperature_c`, `wind_mph`, `wind_direction`, `weather_conditions`
6. If the weather API cannot provide historical data (too far in the past), leave fields null

**Reference:** Spec Sections 8.3, 7.1

---

## Validation

1. `supabase functions serve photos-presign` — starts without error
2. `supabase functions serve photos-confirm` — starts without error
3. `supabase functions serve send-message` — starts without error
4. `supabase functions serve weather-backfill` — starts without error
5. `cd inngest && npx tsc --noEmit` — compiles without error
6. The photo-process function is registered with the Inngest client
