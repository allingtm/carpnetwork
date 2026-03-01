// GENERATED CODE DO NOT EDIT
// This file should be version controlled
import 'package:brick_sqlite/db.dart';
part '20260301151958.migration.dart';

/// All intelligently-generated migrations from all `@Migratable` classes on disk
final migrations = <Migration>{
  const Migration20260301151958(),};

/// A consumable database structure including the latest generated migration.
final schema = Schema(
  0,
  generatorVersion: 1,
  tables: <SchemaTable>{
    SchemaTable(
      'CatchReport',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('id', Column.varchar, unique: true),
        SchemaColumn('group_id', Column.varchar),
        SchemaColumn('user_id', Column.varchar),
        SchemaColumn('venue_id', Column.varchar),
        SchemaColumn('fish_species', Column.varchar),
        SchemaColumn('fish_weight_lb', Column.integer),
        SchemaColumn('fish_weight_oz', Column.integer),
        SchemaColumn('fish_name', Column.varchar),
        SchemaColumn('swim', Column.varchar),
        SchemaColumn('casting_distance_wraps', Column.integer),
        SchemaColumn('bait_type', Column.varchar),
        SchemaColumn('bait_brand', Column.varchar),
        SchemaColumn('bait_product', Column.varchar),
        SchemaColumn('bait_size_mm', Column.integer),
        SchemaColumn('bait_colour', Column.varchar),
        SchemaColumn('rig_name', Column.varchar),
        SchemaColumn('hook_size', Column.integer),
        SchemaColumn('hooklink_material', Column.varchar),
        SchemaColumn('hooklink_length_inches', Column.integer),
        SchemaColumn('lead_arrangement', Column.varchar),
        SchemaColumn('air_pressure_mb', Column.Double),
        SchemaColumn('wind_direction', Column.varchar),
        SchemaColumn('wind_speed_mph', Column.integer),
        SchemaColumn('air_temp_c', Column.Double),
        SchemaColumn('water_temp_c', Column.Double),
        SchemaColumn('cloud_cover', Column.varchar),
        SchemaColumn('rain', Column.varchar),
        SchemaColumn('moon_phase', Column.varchar),
        SchemaColumn('caught_at', Column.datetime),
        SchemaColumn('notes', Column.varchar),
        SchemaColumn('deleted_at', Column.datetime),
        SchemaColumn('created_at', Column.datetime),
        SchemaColumn('updated_at', Column.datetime),
      },
      indices: <SchemaIndex>{},
    ),
    SchemaTable(
      'Message',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('id', Column.varchar, unique: true),
        SchemaColumn('group_id', Column.varchar),
        SchemaColumn('user_id', Column.varchar),
        SchemaColumn('content', Column.varchar),
        SchemaColumn('reply_to_id', Column.varchar),
        SchemaColumn('deleted_at', Column.datetime),
        SchemaColumn('created_at', Column.datetime),
      },
      indices: <SchemaIndex>{},
    ),
    SchemaTable(
      'Venue',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('id', Column.varchar, unique: true),
        SchemaColumn('name', Column.varchar),
        SchemaColumn('location_lat', Column.Double),
        SchemaColumn('location_lng', Column.Double),
        SchemaColumn('county', Column.varchar),
        SchemaColumn('country', Column.varchar),
        SchemaColumn('venue_type', Column.varchar),
        SchemaColumn('created_at', Column.datetime),
      },
      indices: <SchemaIndex>{},
    ),
  },
);
