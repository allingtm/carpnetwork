import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'catch_reports'),
)
class CatchReport extends OfflineFirstWithSupabaseModel {
  @Supabase(unique: true)
  @Sqlite(unique: true)
  final String id;

  final String groupId;
  final String userId;
  final String venueId;

  /// One of: common, mirror, leather, ghost, fully_scaled, grass
  final String fishSpecies;

  final int fishWeightLb;

  /// 0–15 (CHECK constraint on DB)
  final int fishWeightOz;

  final String? fishName;
  final String? swim;
  final int? castingDistanceWraps;

  // Bait fields
  final String? baitType;
  final String? baitBrand;
  final String? baitProduct;
  final int? baitSizeMm;
  final String? baitColour;

  // Rig fields
  final String? rigName;
  final int? hookSize;
  final String? hooklinkMaterial;
  final int? hooklinkLengthInches;
  final String? leadArrangement;

  // Weather fields (auto-populated or backfilled)
  final double? airPressureMb;
  final String? windDirection;
  final int? windSpeedMph;
  final double? airTempC;
  final double? waterTempC;
  final String? cloudCover;
  final String? rain;
  final String? moonPhase;

  final DateTime caughtAt;
  final String? notes;

  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  CatchReport({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.venueId,
    required this.fishSpecies,
    required this.fishWeightLb,
    required this.fishWeightOz,
    this.fishName,
    this.swim,
    this.castingDistanceWraps,
    this.baitType,
    this.baitBrand,
    this.baitProduct,
    this.baitSizeMm,
    this.baitColour,
    this.rigName,
    this.hookSize,
    this.hooklinkMaterial,
    this.hooklinkLengthInches,
    this.leadArrangement,
    this.airPressureMb,
    this.windDirection,
    this.windSpeedMph,
    this.airTempC,
    this.waterTempC,
    this.cloudCover,
    this.rain,
    this.moonPhase,
    required this.caughtAt,
    this.notes,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });
}
