import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'photo_database.dart';

/// Processes ONE PendingUpload at a time (small and idempotent).
///
/// Flow: query pending → check connectivity → presign → upload to R2
/// → confirm → mark complete → delete temp file.
class PhotoUploadService {
  final PhotoDatabase _db;

  PhotoUploadService({PhotoDatabase? db}) : _db = db ?? PhotoDatabase();

  /// Process the next pending upload. Returns true if a photo was processed.
  Future<bool> processNext() async {
    final pending = await _db.getPendingUploads();
    if (pending.isEmpty) return false;

    final upload = pending.first;

    // Mark as uploading
    await _db.updateUploadStatus(upload.id, 'uploading');

    try {
      final file = File(upload.localFilePath);
      if (!file.existsSync()) {
        await _db.updateUploadStatus(upload.id, 'failed');
        return true;
      }

      final fileBytes = await file.readAsBytes();
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) {
        await _db.updateUploadStatus(upload.id, 'pending');
        return false;
      }

      final functionsUrl =
          '${supabase.rest.url.replaceAll('/rest/v1', '')}/functions/v1';

      // Step 1: Get presigned URL
      final presignResponse = await http.post(
        Uri.parse('$functionsUrl/photos-presign'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'catch_report_id': upload.catchReportId,
          'group_id': upload.groupId,
          'file_type': 'image/jpeg',
          'file_size': fileBytes.length,
        }),
      );

      if (presignResponse.statusCode != 200) {
        throw Exception('Presign failed: ${presignResponse.statusCode}');
      }

      final presignData =
          jsonDecode(presignResponse.body) as Map<String, dynamic>;
      final presignedUrl = presignData['presigned_url'] as String;
      final r2Key = presignData['r2_key'] as String;

      // Step 2: Upload to R2 via presigned URL
      final uploadResponse = await http.put(
        Uri.parse(presignedUrl),
        headers: {'Content-Type': 'image/jpeg'},
        body: fileBytes,
      );

      if (uploadResponse.statusCode != 200) {
        throw Exception('R2 upload failed: ${uploadResponse.statusCode}');
      }

      // Step 3: Confirm upload
      final confirmResponse = await http.post(
        Uri.parse('$functionsUrl/photos-confirm'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'r2_key': r2Key}),
      );

      if (confirmResponse.statusCode != 202) {
        throw Exception('Confirm failed: ${confirmResponse.statusCode}');
      }

      // Step 4: Mark complete and clean up
      await _db.updateUploadStatus(upload.id, 'complete');
      try { await file.delete(); } catch (_) {}
      return true;
    } catch (e) {
      // On failure: increment retry, set back to pending (or failed after 5)
      await _db.incrementRetry(upload.id, upload.retryCount);
      return true;
    }
  }
}
