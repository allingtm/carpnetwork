import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import '../../domain/models/pending_upload.dart';

part 'photo_database.g.dart';

@DriftDatabase(tables: [PendingUploads])
class PhotoDatabase extends _$PhotoDatabase {
  static PhotoDatabase? _instance;

  PhotoDatabase._() : super(_openConnection());

  factory PhotoDatabase() => _instance ??= PhotoDatabase._();

  @override
  int get schemaVersion => 1;

  /// Get all pending uploads (status = 'pending'), oldest first.
  Future<List<PendingUpload>> getPendingUploads() {
    return (select(pendingUploads)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Get a single pending upload by ID.
  Future<PendingUpload?> getUploadById(String id) {
    return (select(pendingUploads)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new pending upload.
  Future<void> insertUpload(PendingUploadsCompanion upload) {
    return into(pendingUploads).insert(upload);
  }

  /// Update upload status.
  Future<void> updateUploadStatus(String id, String status) {
    return (update(pendingUploads)..where((t) => t.id.equals(id)))
        .write(PendingUploadsCompanion(status: Value(status)));
  }

  /// Increment retry count and reset status to pending.
  Future<void> incrementRetry(String id, int currentRetryCount) {
    return (update(pendingUploads)..where((t) => t.id.equals(id))).write(
      PendingUploadsCompanion(
        retryCount: Value(currentRetryCount + 1),
        status: Value(currentRetryCount + 1 >= 5 ? 'failed' : 'pending'),
      ),
    );
  }

  /// Delete a completed upload record.
  Future<void> deleteUpload(String id) {
    return (delete(pendingUploads)..where((t) => t.id.equals(id))).go();
  }

  /// Count pending uploads for a catch report.
  Future<int> countPendingForCatch(String catchReportId) async {
    final count = pendingUploads.id.count();
    final query = selectOnly(pendingUploads)
      ..addColumns([count])
      ..where(pendingUploads.catchReportId.equals(catchReportId) &
          pendingUploads.status.equals('pending'));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pending_uploads.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
