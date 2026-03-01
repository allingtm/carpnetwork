// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<Venue> _$VenueFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return Venue(
    id: data['id'] as String,
    name: data['name'] as String,
    locationLat: data['location_lat'] == null
        ? null
        : data['location_lat'] as double?,
    locationLng: data['location_lng'] == null
        ? null
        : data['location_lng'] as double?,
    county: data['county'] == null ? null : data['county'] as String?,
    country: data['country'] as String,
    venueType: data['venue_type'] == null
        ? null
        : data['venue_type'] as String?,
    createdAt: DateTime.parse(data['created_at'] as String),
  );
}

Future<Map<String, dynamic>> _$VenueToSupabase(
  Venue instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'name': instance.name,
    'location_lat': instance.locationLat,
    'location_lng': instance.locationLng,
    'county': instance.county,
    'country': instance.country,
    'venue_type': instance.venueType,
    'created_at': instance.createdAt.toIso8601String(),
  };
}

Future<Venue> _$VenueFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return Venue(
    id: data['id'] as String,
    name: data['name'] as String,
    locationLat: data['location_lat'] == null
        ? null
        : data['location_lat'] as double?,
    locationLng: data['location_lng'] == null
        ? null
        : data['location_lng'] as double?,
    county: data['county'] == null ? null : data['county'] as String?,
    country: data['country'] as String,
    venueType: data['venue_type'] == null
        ? null
        : data['venue_type'] as String?,
    createdAt: DateTime.parse(data['created_at'] as String),
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$VenueToSqlite(
  Venue instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'name': instance.name,
    'location_lat': instance.locationLat,
    'location_lng': instance.locationLng,
    'county': instance.county,
    'country': instance.country,
    'venue_type': instance.venueType,
    'created_at': instance.createdAt.toIso8601String(),
  };
}

/// Construct a [Venue]
class VenueAdapter extends OfflineFirstWithSupabaseAdapter<Venue> {
  VenueAdapter();

  @override
  final supabaseTableName = 'venues';
  @override
  final defaultToNull = true;
  @override
  final fieldsToSupabaseColumns = {
    'id': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'id',
    ),
    'name': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'name',
    ),
    'locationLat': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'location_lat',
    ),
    'locationLng': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'location_lng',
    ),
    'county': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'county',
    ),
    'country': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'country',
    ),
    'venueType': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'venue_type',
    ),
    'createdAt': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'created_at',
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
    'name': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'name',
      iterable: false,
      type: String,
    ),
    'locationLat': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'location_lat',
      iterable: false,
      type: double,
    ),
    'locationLng': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'location_lng',
      iterable: false,
      type: double,
    ),
    'county': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'county',
      iterable: false,
      type: String,
    ),
    'country': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'country',
      iterable: false,
      type: String,
    ),
    'venueType': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'venue_type',
      iterable: false,
      type: String,
    ),
    'createdAt': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'created_at',
      iterable: false,
      type: DateTime,
    ),
  };
  @override
  Future<int?> primaryKeyByUniqueColumns(
    Venue instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `Venue` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'Venue';

  @override
  Future<Venue> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$VenueFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    Venue input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$VenueToSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Venue> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$VenueFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    Venue input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async =>
      await _$VenueToSqlite(input, provider: provider, repository: repository);
}
