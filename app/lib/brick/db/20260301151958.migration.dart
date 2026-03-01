// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20260301151958_up = [
  InsertTable('CatchReport'),
  InsertTable('Message'),
  InsertTable('Venue'),
  InsertColumn('id', Column.varchar, onTable: 'CatchReport', unique: true),
  InsertColumn('group_id', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('user_id', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('venue_id', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('fish_species', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('fish_weight_lb', Column.integer, onTable: 'CatchReport'),
  InsertColumn('fish_weight_oz', Column.integer, onTable: 'CatchReport'),
  InsertColumn('fish_name', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('swim', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('casting_distance_wraps', Column.integer, onTable: 'CatchReport'),
  InsertColumn('bait_type', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('bait_brand', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('bait_product', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('bait_size_mm', Column.integer, onTable: 'CatchReport'),
  InsertColumn('bait_colour', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('rig_name', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('hook_size', Column.integer, onTable: 'CatchReport'),
  InsertColumn('hooklink_material', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('hooklink_length_inches', Column.integer, onTable: 'CatchReport'),
  InsertColumn('lead_arrangement', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('air_pressure_mb', Column.Double, onTable: 'CatchReport'),
  InsertColumn('wind_direction', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('wind_speed_mph', Column.integer, onTable: 'CatchReport'),
  InsertColumn('air_temp_c', Column.Double, onTable: 'CatchReport'),
  InsertColumn('water_temp_c', Column.Double, onTable: 'CatchReport'),
  InsertColumn('cloud_cover', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('rain', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('moon_phase', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('caught_at', Column.datetime, onTable: 'CatchReport'),
  InsertColumn('notes', Column.varchar, onTable: 'CatchReport'),
  InsertColumn('deleted_at', Column.datetime, onTable: 'CatchReport'),
  InsertColumn('created_at', Column.datetime, onTable: 'CatchReport'),
  InsertColumn('updated_at', Column.datetime, onTable: 'CatchReport'),
  InsertColumn('id', Column.varchar, onTable: 'Message', unique: true),
  InsertColumn('group_id', Column.varchar, onTable: 'Message'),
  InsertColumn('user_id', Column.varchar, onTable: 'Message'),
  InsertColumn('content', Column.varchar, onTable: 'Message'),
  InsertColumn('reply_to_id', Column.varchar, onTable: 'Message'),
  InsertColumn('deleted_at', Column.datetime, onTable: 'Message'),
  InsertColumn('created_at', Column.datetime, onTable: 'Message'),
  InsertColumn('id', Column.varchar, onTable: 'Venue', unique: true),
  InsertColumn('name', Column.varchar, onTable: 'Venue'),
  InsertColumn('location_lat', Column.Double, onTable: 'Venue'),
  InsertColumn('location_lng', Column.Double, onTable: 'Venue'),
  InsertColumn('county', Column.varchar, onTable: 'Venue'),
  InsertColumn('country', Column.varchar, onTable: 'Venue'),
  InsertColumn('venue_type', Column.varchar, onTable: 'Venue'),
  InsertColumn('created_at', Column.datetime, onTable: 'Venue')
];

const List<MigrationCommand> _migration_20260301151958_down = [
  DropTable('CatchReport'),
  DropTable('Message'),
  DropTable('Venue'),
  DropColumn('id', onTable: 'CatchReport'),
  DropColumn('group_id', onTable: 'CatchReport'),
  DropColumn('user_id', onTable: 'CatchReport'),
  DropColumn('venue_id', onTable: 'CatchReport'),
  DropColumn('fish_species', onTable: 'CatchReport'),
  DropColumn('fish_weight_lb', onTable: 'CatchReport'),
  DropColumn('fish_weight_oz', onTable: 'CatchReport'),
  DropColumn('fish_name', onTable: 'CatchReport'),
  DropColumn('swim', onTable: 'CatchReport'),
  DropColumn('casting_distance_wraps', onTable: 'CatchReport'),
  DropColumn('bait_type', onTable: 'CatchReport'),
  DropColumn('bait_brand', onTable: 'CatchReport'),
  DropColumn('bait_product', onTable: 'CatchReport'),
  DropColumn('bait_size_mm', onTable: 'CatchReport'),
  DropColumn('bait_colour', onTable: 'CatchReport'),
  DropColumn('rig_name', onTable: 'CatchReport'),
  DropColumn('hook_size', onTable: 'CatchReport'),
  DropColumn('hooklink_material', onTable: 'CatchReport'),
  DropColumn('hooklink_length_inches', onTable: 'CatchReport'),
  DropColumn('lead_arrangement', onTable: 'CatchReport'),
  DropColumn('air_pressure_mb', onTable: 'CatchReport'),
  DropColumn('wind_direction', onTable: 'CatchReport'),
  DropColumn('wind_speed_mph', onTable: 'CatchReport'),
  DropColumn('air_temp_c', onTable: 'CatchReport'),
  DropColumn('water_temp_c', onTable: 'CatchReport'),
  DropColumn('cloud_cover', onTable: 'CatchReport'),
  DropColumn('rain', onTable: 'CatchReport'),
  DropColumn('moon_phase', onTable: 'CatchReport'),
  DropColumn('caught_at', onTable: 'CatchReport'),
  DropColumn('notes', onTable: 'CatchReport'),
  DropColumn('deleted_at', onTable: 'CatchReport'),
  DropColumn('created_at', onTable: 'CatchReport'),
  DropColumn('updated_at', onTable: 'CatchReport'),
  DropColumn('id', onTable: 'Message'),
  DropColumn('group_id', onTable: 'Message'),
  DropColumn('user_id', onTable: 'Message'),
  DropColumn('content', onTable: 'Message'),
  DropColumn('reply_to_id', onTable: 'Message'),
  DropColumn('deleted_at', onTable: 'Message'),
  DropColumn('created_at', onTable: 'Message'),
  DropColumn('id', onTable: 'Venue'),
  DropColumn('name', onTable: 'Venue'),
  DropColumn('location_lat', onTable: 'Venue'),
  DropColumn('location_lng', onTable: 'Venue'),
  DropColumn('county', onTable: 'Venue'),
  DropColumn('country', onTable: 'Venue'),
  DropColumn('venue_type', onTable: 'Venue'),
  DropColumn('created_at', onTable: 'Venue')
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260301151958',
  up: _migration_20260301151958_up,
  down: _migration_20260301151958_down,
)
class Migration20260301151958 extends Migration {
  const Migration20260301151958()
    : super(
        version: 20260301151958,
        up: _migration_20260301151958_up,
        down: _migration_20260301151958_down,
      );
}
