// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<CatchReport> _$CatchReportFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return CatchReport(
    id: data['id'] as String,
    groupId: data['group_id'] as String,
    userId: data['user_id'] as String,
    venueId: data['venue_id'] as String,
    fishSpecies: data['fish_species'] as String,
    fishWeightLb: data['fish_weight_lb'] as int,
    fishWeightOz: data['fish_weight_oz'] as int,
    fishName: data['fish_name'] == null ? null : data['fish_name'] as String?,
    swim: data['swim'] == null ? null : data['swim'] as String?,
    castingDistanceWraps: data['casting_distance_wraps'] == null
        ? null
        : data['casting_distance_wraps'] as int?,
    baitType: data['bait_type'] == null ? null : data['bait_type'] as String?,
    baitBrand: data['bait_brand'] == null
        ? null
        : data['bait_brand'] as String?,
    baitProduct: data['bait_product'] == null
        ? null
        : data['bait_product'] as String?,
    baitSizeMm: data['bait_size_mm'] == null
        ? null
        : data['bait_size_mm'] as int?,
    baitColour: data['bait_colour'] == null
        ? null
        : data['bait_colour'] as String?,
    rigName: data['rig_name'] == null ? null : data['rig_name'] as String?,
    hookSize: data['hook_size'] == null ? null : data['hook_size'] as int?,
    hooklinkMaterial: data['hooklink_material'] == null
        ? null
        : data['hooklink_material'] as String?,
    hooklinkLengthInches: data['hooklink_length_inches'] == null
        ? null
        : data['hooklink_length_inches'] as int?,
    leadArrangement: data['lead_arrangement'] == null
        ? null
        : data['lead_arrangement'] as String?,
    airPressureMb: data['air_pressure_mb'] == null
        ? null
        : data['air_pressure_mb'] as double?,
    windDirection: data['wind_direction'] == null
        ? null
        : data['wind_direction'] as String?,
    windSpeedMph: data['wind_speed_mph'] == null
        ? null
        : data['wind_speed_mph'] as int?,
    airTempC: data['air_temp_c'] == null ? null : data['air_temp_c'] as double?,
    waterTempC: data['water_temp_c'] == null
        ? null
        : data['water_temp_c'] as double?,
    cloudCover: data['cloud_cover'] == null
        ? null
        : data['cloud_cover'] as String?,
    rain: data['rain'] == null ? null : data['rain'] as String?,
    moonPhase: data['moon_phase'] == null
        ? null
        : data['moon_phase'] as String?,
    caughtAt: DateTime.parse(data['caught_at'] as String),
    notes: data['notes'] == null ? null : data['notes'] as String?,
    deletedAt: data['deleted_at'] == null
        ? null
        : data['deleted_at'] == null
        ? null
        : DateTime.tryParse(data['deleted_at'] as String),
    createdAt: DateTime.parse(data['created_at'] as String),
    updatedAt: DateTime.parse(data['updated_at'] as String),
  );
}

Future<Map<String, dynamic>> _$CatchReportToSupabase(
  CatchReport instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'group_id': instance.groupId,
    'user_id': instance.userId,
    'venue_id': instance.venueId,
    'fish_species': instance.fishSpecies,
    'fish_weight_lb': instance.fishWeightLb,
    'fish_weight_oz': instance.fishWeightOz,
    'fish_name': instance.fishName,
    'swim': instance.swim,
    'casting_distance_wraps': instance.castingDistanceWraps,
    'bait_type': instance.baitType,
    'bait_brand': instance.baitBrand,
    'bait_product': instance.baitProduct,
    'bait_size_mm': instance.baitSizeMm,
    'bait_colour': instance.baitColour,
    'rig_name': instance.rigName,
    'hook_size': instance.hookSize,
    'hooklink_material': instance.hooklinkMaterial,
    'hooklink_length_inches': instance.hooklinkLengthInches,
    'lead_arrangement': instance.leadArrangement,
    'air_pressure_mb': instance.airPressureMb,
    'wind_direction': instance.windDirection,
    'wind_speed_mph': instance.windSpeedMph,
    'air_temp_c': instance.airTempC,
    'water_temp_c': instance.waterTempC,
    'cloud_cover': instance.cloudCover,
    'rain': instance.rain,
    'moon_phase': instance.moonPhase,
    'caught_at': instance.caughtAt.toIso8601String(),
    'notes': instance.notes,
    'deleted_at': instance.deletedAt?.toIso8601String(),
    'created_at': instance.createdAt.toIso8601String(),
    'updated_at': instance.updatedAt.toIso8601String(),
  };
}

Future<CatchReport> _$CatchReportFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return CatchReport(
    id: data['id'] as String,
    groupId: data['group_id'] as String,
    userId: data['user_id'] as String,
    venueId: data['venue_id'] as String,
    fishSpecies: data['fish_species'] as String,
    fishWeightLb: data['fish_weight_lb'] as int,
    fishWeightOz: data['fish_weight_oz'] as int,
    fishName: data['fish_name'] == null ? null : data['fish_name'] as String?,
    swim: data['swim'] == null ? null : data['swim'] as String?,
    castingDistanceWraps: data['casting_distance_wraps'] == null
        ? null
        : data['casting_distance_wraps'] as int?,
    baitType: data['bait_type'] == null ? null : data['bait_type'] as String?,
    baitBrand: data['bait_brand'] == null
        ? null
        : data['bait_brand'] as String?,
    baitProduct: data['bait_product'] == null
        ? null
        : data['bait_product'] as String?,
    baitSizeMm: data['bait_size_mm'] == null
        ? null
        : data['bait_size_mm'] as int?,
    baitColour: data['bait_colour'] == null
        ? null
        : data['bait_colour'] as String?,
    rigName: data['rig_name'] == null ? null : data['rig_name'] as String?,
    hookSize: data['hook_size'] == null ? null : data['hook_size'] as int?,
    hooklinkMaterial: data['hooklink_material'] == null
        ? null
        : data['hooklink_material'] as String?,
    hooklinkLengthInches: data['hooklink_length_inches'] == null
        ? null
        : data['hooklink_length_inches'] as int?,
    leadArrangement: data['lead_arrangement'] == null
        ? null
        : data['lead_arrangement'] as String?,
    airPressureMb: data['air_pressure_mb'] == null
        ? null
        : data['air_pressure_mb'] as double?,
    windDirection: data['wind_direction'] == null
        ? null
        : data['wind_direction'] as String?,
    windSpeedMph: data['wind_speed_mph'] == null
        ? null
        : data['wind_speed_mph'] as int?,
    airTempC: data['air_temp_c'] == null ? null : data['air_temp_c'] as double?,
    waterTempC: data['water_temp_c'] == null
        ? null
        : data['water_temp_c'] as double?,
    cloudCover: data['cloud_cover'] == null
        ? null
        : data['cloud_cover'] as String?,
    rain: data['rain'] == null ? null : data['rain'] as String?,
    moonPhase: data['moon_phase'] == null
        ? null
        : data['moon_phase'] as String?,
    caughtAt: DateTime.parse(data['caught_at'] as String),
    notes: data['notes'] == null ? null : data['notes'] as String?,
    deletedAt: data['deleted_at'] == null
        ? null
        : data['deleted_at'] == null
        ? null
        : DateTime.tryParse(data['deleted_at'] as String),
    createdAt: DateTime.parse(data['created_at'] as String),
    updatedAt: DateTime.parse(data['updated_at'] as String),
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$CatchReportToSqlite(
  CatchReport instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'group_id': instance.groupId,
    'user_id': instance.userId,
    'venue_id': instance.venueId,
    'fish_species': instance.fishSpecies,
    'fish_weight_lb': instance.fishWeightLb,
    'fish_weight_oz': instance.fishWeightOz,
    'fish_name': instance.fishName,
    'swim': instance.swim,
    'casting_distance_wraps': instance.castingDistanceWraps,
    'bait_type': instance.baitType,
    'bait_brand': instance.baitBrand,
    'bait_product': instance.baitProduct,
    'bait_size_mm': instance.baitSizeMm,
    'bait_colour': instance.baitColour,
    'rig_name': instance.rigName,
    'hook_size': instance.hookSize,
    'hooklink_material': instance.hooklinkMaterial,
    'hooklink_length_inches': instance.hooklinkLengthInches,
    'lead_arrangement': instance.leadArrangement,
    'air_pressure_mb': instance.airPressureMb,
    'wind_direction': instance.windDirection,
    'wind_speed_mph': instance.windSpeedMph,
    'air_temp_c': instance.airTempC,
    'water_temp_c': instance.waterTempC,
    'cloud_cover': instance.cloudCover,
    'rain': instance.rain,
    'moon_phase': instance.moonPhase,
    'caught_at': instance.caughtAt.toIso8601String(),
    'notes': instance.notes,
    'deleted_at': instance.deletedAt?.toIso8601String(),
    'created_at': instance.createdAt.toIso8601String(),
    'updated_at': instance.updatedAt.toIso8601String(),
  };
}

/// Construct a [CatchReport]
class CatchReportAdapter extends OfflineFirstWithSupabaseAdapter<CatchReport> {
  CatchReportAdapter();

  @override
  final supabaseTableName = 'catch_reports';
  @override
  final defaultToNull = true;
  @override
  final fieldsToSupabaseColumns = {
    'id': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'id',
    ),
    'groupId': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'group_id',
    ),
    'userId': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'user_id',
    ),
    'venueId': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'venue_id',
    ),
    'fishSpecies': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'fish_species',
    ),
    'fishWeightLb': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'fish_weight_lb',
    ),
    'fishWeightOz': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'fish_weight_oz',
    ),
    'fishName': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'fish_name',
    ),
    'swim': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'swim',
    ),
    'castingDistanceWraps': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'casting_distance_wraps',
    ),
    'baitType': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'bait_type',
    ),
    'baitBrand': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'bait_brand',
    ),
    'baitProduct': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'bait_product',
    ),
    'baitSizeMm': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'bait_size_mm',
    ),
    'baitColour': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'bait_colour',
    ),
    'rigName': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'rig_name',
    ),
    'hookSize': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'hook_size',
    ),
    'hooklinkMaterial': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'hooklink_material',
    ),
    'hooklinkLengthInches': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'hooklink_length_inches',
    ),
    'leadArrangement': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'lead_arrangement',
    ),
    'airPressureMb': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'air_pressure_mb',
    ),
    'windDirection': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'wind_direction',
    ),
    'windSpeedMph': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'wind_speed_mph',
    ),
    'airTempC': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'air_temp_c',
    ),
    'waterTempC': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'water_temp_c',
    ),
    'cloudCover': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'cloud_cover',
    ),
    'rain': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'rain',
    ),
    'moonPhase': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'moon_phase',
    ),
    'caughtAt': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'caught_at',
    ),
    'notes': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'notes',
    ),
    'deletedAt': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'deleted_at',
    ),
    'createdAt': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'created_at',
    ),
    'updatedAt': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'updated_at',
    ),
  };
  @override
  final ignoreDuplicates = false;
  @override
  final uniqueFields = {'id'};
  @override
  final Map<String, RuntimeSqliteColumnDefinition> fieldsToSqliteColumns = {
    'primaryKey': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: '_brick_id',
      iterable: false,
      type: int,
    ),
    'id': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'id',
      iterable: false,
      type: String,
    ),
    'groupId': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'group_id',
      iterable: false,
      type: String,
    ),
    'userId': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'user_id',
      iterable: false,
      type: String,
    ),
    'venueId': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'venue_id',
      iterable: false,
      type: String,
    ),
    'fishSpecies': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'fish_species',
      iterable: false,
      type: String,
    ),
    'fishWeightLb': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'fish_weight_lb',
      iterable: false,
      type: int,
    ),
    'fishWeightOz': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'fish_weight_oz',
      iterable: false,
      type: int,
    ),
    'fishName': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'fish_name',
      iterable: false,
      type: String,
    ),
    'swim': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'swim',
      iterable: false,
      type: String,
    ),
    'castingDistanceWraps': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'casting_distance_wraps',
      iterable: false,
      type: int,
    ),
    'baitType': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'bait_type',
      iterable: false,
      type: String,
    ),
    'baitBrand': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'bait_brand',
      iterable: false,
      type: String,
    ),
    'baitProduct': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'bait_product',
      iterable: false,
      type: String,
    ),
    'baitSizeMm': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'bait_size_mm',
      iterable: false,
      type: int,
    ),
    'baitColour': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'bait_colour',
      iterable: false,
      type: String,
    ),
    'rigName': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'rig_name',
      iterable: false,
      type: String,
    ),
    'hookSize': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'hook_size',
      iterable: false,
      type: int,
    ),
    'hooklinkMaterial': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'hooklink_material',
      iterable: false,
      type: String,
    ),
    'hooklinkLengthInches': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'hooklink_length_inches',
      iterable: false,
      type: int,
    ),
    'leadArrangement': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'lead_arrangement',
      iterable: false,
      type: String,
    ),
    'airPressureMb': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'air_pressure_mb',
      iterable: false,
      type: double,
    ),
    'windDirection': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'wind_direction',
      iterable: false,
      type: String,
    ),
    'windSpeedMph': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'wind_speed_mph',
      iterable: false,
      type: int,
    ),
    'airTempC': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'air_temp_c',
      iterable: false,
      type: double,
    ),
    'waterTempC': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'water_temp_c',
      iterable: false,
      type: double,
    ),
    'cloudCover': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'cloud_cover',
      iterable: false,
      type: String,
    ),
    'rain': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'rain',
      iterable: false,
      type: String,
    ),
    'moonPhase': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'moon_phase',
      iterable: false,
      type: String,
    ),
    'caughtAt': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'caught_at',
      iterable: false,
      type: DateTime,
    ),
    'notes': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'notes',
      iterable: false,
      type: String,
    ),
    'deletedAt': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'deleted_at',
      iterable: false,
      type: DateTime,
    ),
    'createdAt': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'created_at',
      iterable: false,
      type: DateTime,
    ),
    'updatedAt': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'updated_at',
      iterable: false,
      type: DateTime,
    ),
  };
  @override
  Future<int?> primaryKeyByUniqueColumns(
    CatchReport instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `CatchReport` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'CatchReport';

  @override
  Future<CatchReport> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$CatchReportFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    CatchReport input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$CatchReportToSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<CatchReport> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$CatchReportFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    CatchReport input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$CatchReportToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
