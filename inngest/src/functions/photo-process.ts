import { inngest } from "../client";
import sharp from "sharp";
import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} from "@aws-sdk/client-s3";
import { createClient } from "@supabase/supabase-js";

const s3 = new S3Client({
  region: "auto",
  endpoint: process.env.CLOUDFLARE_R2_ENDPOINT!,
  credentials: {
    accessKeyId: process.env.CLOUDFLARE_R2_ACCESS_KEY_ID!,
    secretAccessKey: process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY!,
  },
});

export const photoProcess = inngest.createFunction(
  { id: "photo-process", retries: 3 },
  { event: "photo/process" },
  async ({ event }) => {
    const { r2_key, catch_report_id, group_id, user_id } = event.data;

    // 1. Download from R2 and capture ETag
    const getResponse = await s3.send(
      new GetObjectCommand({
        Bucket: process.env.CLOUDFLARE_R2_BUCKET_NAME!,
        Key: r2_key,
      })
    );

    const etag = getResponse.ETag;
    const bodyBytes = await getResponse.Body!.transformToByteArray();
    const buffer = Buffer.from(bodyBytes);

    // 2. Process with sharp: apply EXIF orientation, strip all metadata
    // .rotate() applies EXIF orientation physically, then stripping metadata
    // is done by NOT calling .withMetadata() (sharp strips by default)
    // .keepIccProfile() retains only the colour profile (no personal data)
    const processed = await sharp(buffer)
      .rotate()
      .keepIccProfile()
      .jpeg({ quality: 85 })
      .toBuffer();

    // 3. Verify metadata is stripped
    const metadata = await sharp(processed).metadata();
    if (metadata.exif || metadata.xmp || metadata.iptc) {
      throw new Error("EXIF stripping failed — metadata still present");
    }

    // 4. Re-upload processed image to R2
    await s3.send(
      new PutObjectCommand({
        Bucket: process.env.CLOUDFLARE_R2_BUCKET_NAME!,
        Key: r2_key,
        Body: processed,
        ContentType: "image/jpeg",
      })
    );

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

    // 6. Send Broadcast event so connected clients update photo placeholder
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
