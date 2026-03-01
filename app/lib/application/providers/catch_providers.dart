import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brick/models/catch_report.model.dart';
import '../../data/catches/catch_repository.dart';

final catchRepositoryProvider = Provider<CatchRepository>((ref) {
  return CatchRepository();
});

/// Watches Brick for changes to a group's catches, returns live list.
final catchesProvider =
    StreamProvider.family<List<CatchReport>, String>((ref, groupId) {
  final repo = ref.watch(catchRepositoryProvider);
  return repo.watchCatchesForGroup(groupId);
});

/// Single catch detail by ID.
final catchDetailProvider =
    FutureProvider.family<CatchReport?, String>((ref, catchId) async {
  final repo = ref.watch(catchRepositoryProvider);
  return repo.getCatch(catchId);
});
