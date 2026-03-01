import 'package:workmanager/workmanager.dart';

import 'photo_upload_service.dart';

const uploadTaskName = 'photo-upload-task';

/// Workmanager callback dispatcher. Must be a top-level function.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == uploadTaskName || taskName == Workmanager.iOSBackgroundTask) {
      try {
        final service = PhotoUploadService();
        // Process exactly one photo per invocation (small and idempotent)
        await service.processNext();
      } catch (_) {
        // Don't crash the background task
      }
    }
    return true;
  });
}

/// Register the background upload task.
/// Call once from main.dart after initialization.
Future<void> registerBackgroundUploadTask() async {
  // Android: periodic task with network constraint (min 15 minutes)
  await Workmanager().registerPeriodicTask(
    'photo-upload',
    uploadTaskName,
    constraints: Constraints(networkType: NetworkType.connected),
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}

/// Trigger an immediate one-off upload task (e.g. on connectivity change or
/// iOS silent push).
Future<void> triggerImmediateUpload() async {
  await Workmanager().registerOneOffTask(
    'photo-upload-immediate',
    uploadTaskName,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
