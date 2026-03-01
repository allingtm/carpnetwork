import 'package:drift/drift.dart';

/// Local Drift table for tracking photo uploads that need to happen
/// in the background. Each row = one photo to upload.
class PendingUploads extends Table {
  TextColumn get id => text()();
  TextColumn get catchReportId => text()();
  TextColumn get groupId => text()();
  TextColumn get localFilePath => text()();
  /// pending, uploading, complete, failed
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
