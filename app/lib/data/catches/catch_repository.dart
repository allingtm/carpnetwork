import 'package:brick_core/query.dart';

import '../../brick/models/catch_report.model.dart';
import '../../brick/repository.dart';

class CatchRepository {
  final Repository _repository;

  CatchRepository({Repository? repository})
      : _repository = repository ?? Repository();

  /// Save a catch report to local SQLite immediately. Brick syncs to Supabase
  /// in the background when connectivity is available.
  Future<CatchReport> saveCatch(CatchReport report) async {
    return await _repository.upsert<CatchReport>(report);
  }

  /// Get paginated catches for a group from local SQLite (instant rendering).
  Future<List<CatchReport>> getCatchesForGroup(
    String groupId, {
    int offset = 0,
    int limit = 20,
  }) async {
    return await _repository.get<CatchReport>(
      query: Query(
        where: [
          Where('groupId').isExactly(groupId),
          const Where('deletedAt').isExactly(null),
        ],
        limit: limit,
        offset: offset,
        orderBy: [const OrderBy('caughtAt', ascending: false)],
      ),
    );
  }

  /// Get a single catch by ID from local DB.
  Future<CatchReport?> getCatch(String id) async {
    final results = await _repository.get<CatchReport>(
      query: Query(where: [Where('id').isExactly(id)]),
    );
    return results.isEmpty ? null : results.first;
  }

  /// Optimistic update to local DB. Brick syncs the change.
  Future<CatchReport> updateCatch(CatchReport report) async {
    return await _repository.upsert<CatchReport>(report);
  }

  /// Soft delete — sets deletedAt locally, syncs to Supabase.
  Future<void> softDeleteCatch(String id) async {
    final report = await getCatch(id);
    if (report == null) return;

    final deleted = CatchReport(
      id: report.id,
      groupId: report.groupId,
      userId: report.userId,
      venueId: report.venueId,
      fishSpecies: report.fishSpecies,
      fishWeightLb: report.fishWeightLb,
      fishWeightOz: report.fishWeightOz,
      fishName: report.fishName,
      swim: report.swim,
      castingDistanceWraps: report.castingDistanceWraps,
      baitType: report.baitType,
      baitBrand: report.baitBrand,
      baitProduct: report.baitProduct,
      baitSizeMm: report.baitSizeMm,
      baitColour: report.baitColour,
      rigName: report.rigName,
      hookSize: report.hookSize,
      hooklinkMaterial: report.hooklinkMaterial,
      hooklinkLengthInches: report.hooklinkLengthInches,
      leadArrangement: report.leadArrangement,
      airPressureMb: report.airPressureMb,
      windDirection: report.windDirection,
      windSpeedMph: report.windSpeedMph,
      airTempC: report.airTempC,
      waterTempC: report.waterTempC,
      cloudCover: report.cloudCover,
      rain: report.rain,
      moonPhase: report.moonPhase,
      caughtAt: report.caughtAt,
      notes: report.notes,
      deletedAt: DateTime.now(),
      createdAt: report.createdAt,
      updatedAt: DateTime.now(),
    );

    await _repository.upsert<CatchReport>(deleted);
  }

  /// Search catches locally with filters.
  Future<List<CatchReport>> searchCatches(
    String groupId, {
    String? species,
    String? venueId,
    String? baitType,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final conditions = <Where>[
      Where('groupId').isExactly(groupId),
      const Where('deletedAt').isExactly(null),
    ];

    if (species != null) {
      conditions.add(Where('fishSpecies').isExactly(species));
    }
    if (venueId != null) {
      conditions.add(Where('venueId').isExactly(venueId));
    }
    if (baitType != null) {
      conditions.add(Where('baitType').isExactly(baitType));
    }

    return await _repository.get<CatchReport>(
      query: Query(
        where: conditions,
        orderBy: [const OrderBy('caughtAt', ascending: false)],
      ),
    );
  }

  /// Subscribe to live changes for a group's catches.
  Stream<List<CatchReport>> watchCatchesForGroup(String groupId) {
    return _repository.subscribe<CatchReport>(
      query: Query(
        where: [
          Where('groupId').isExactly(groupId),
          const Where('deletedAt').isExactly(null),
        ],
        orderBy: [const OrderBy('caughtAt', ascending: false)],
      ),
    );
  }
}
