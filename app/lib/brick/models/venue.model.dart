import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'venues'),
)
class Venue extends OfflineFirstWithSupabaseModel {
  @Supabase(unique: true)
  @Sqlite(unique: true)
  final String id;

  final String name;
  final double? locationLat;
  final double? locationLng;
  final String? county;
  final String country;
  final String? venueType;
  final DateTime createdAt;

  Venue({
    required this.id,
    required this.name,
    this.locationLat,
    this.locationLng,
    this.county,
    this.country = 'UK',
    this.venueType,
    required this.createdAt,
  });
}
