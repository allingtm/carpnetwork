import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'messages'),
)
class Message extends OfflineFirstWithSupabaseModel {
  @Supabase(unique: true)
  @Sqlite(unique: true)
  final String id;

  final String groupId;
  final String userId;
  final String content;
  final String? replyToId;
  final DateTime? deletedAt;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.content,
    this.replyToId,
    this.deletedAt,
    required this.createdAt,
  });
}
