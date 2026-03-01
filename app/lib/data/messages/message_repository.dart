import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageRepository {
  final SupabaseClient _client;

  MessageRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Send a message via the send-message Edge Function.
  Future<Map<String, dynamic>> sendMessage({
    required String groupId,
    required String content,
    String? replyToId,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final functionsUrl =
        '${_client.rest.url.replaceAll('/rest/v1', '')}/functions/v1';

    final body = <String, dynamic>{
      'group_id': groupId,
      'content': content,
    };
    if (replyToId != null) body['reply_to_id'] = replyToId;

    final response = await http.post(
      Uri.parse('$functionsUrl/send-message'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to send message');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Get messages from the local database (via Supabase for now, Brick for
  /// offline reads). Paginated, newest first.
  Future<List<Map<String, dynamic>>> getMessages(
    String groupId, {
    DateTime? before,
    int limit = 30,
  }) async {
    var query = _client
        .from('messages')
        .select('*, users:user_id(full_name, avatar_url)')
        .eq('group_id', groupId);

    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }

    return await query
        .order('created_at', ascending: false)
        .limit(limit);
  }

  /// Soft-delete a message.
  Future<void> softDeleteMessage(String messageId) async {
    await _client
        .from('messages')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', messageId);
  }
}
