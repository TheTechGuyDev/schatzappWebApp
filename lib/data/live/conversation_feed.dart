import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../demo_data.dart';
import 'chat_repo.dart';

/// Live messages for one conversation (mobile ChatThread / GroupChatThread):
/// Realtime stream, sender names for groups, reactions, read receipts,
/// typing (same `typing-<id>` broadcast channel as the phone) and sending.
class ConversationFeed extends ChangeNotifier {
  ConversationFeed(this.conversationId, {required this.isGroup}) {
    _start();
  }

  final String conversationId;
  final bool isGroup;

  SupabaseClient get _sb => Supabase.instance.client;
  String get _me => _sb.auth.currentUser!.id;

  List<DemoMessage> messages = [];
  bool loaded = false;

  /// Names of people typing right now.
  final Map<String, String> typing = {};

  List<Map<String, dynamic>> _raw = [];
  final Map<String, String> _names = {};
  final Map<String, List<String>> _reactions = {};
  DateTime? _othersReadAt;
  bool _receiptsOn = true;
  final List<Map<String, dynamic>> _pending = [];

  StreamSubscription? _sub;
  RealtimeChannel? _typingChannel;
  RealtimeChannel? _metaChannel;
  final Map<String, Timer> _typingTimers = {};
  Timer? _typingOff;
  DateTime? _lastTypingSent;
  bool _disposed = false;

  void _start() {
    _sub = _sb
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .listen((rows) async {
          _raw = List<Map<String, dynamic>>.from(rows);
          await _loadNames();
          await _loadReactions();
          _emit();
          ChatRepo.instance.markRead(conversationId);
        }, onError: (_) {});

    _loadReadState();

    _metaChannel = _sb
        .channel('web-conv-meta-$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversation_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (_) => _loadReadState(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          callback: (_) async {
            await _loadReactions();
            _emit();
          },
        )
        .subscribe();

    _typingChannel = _sb
        .channel('typing-$conversationId')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final id = payload['userId']?.toString();
            if (id == null || id == _me) return;
            final on = payload['isTyping'] == true;
            _typingTimers.remove(id)?.cancel();
            if (on) {
              typing[id] = _names[id] ?? 'Someone';
              // Safety: clear if the "stopped" event never arrives.
              _typingTimers[id] = Timer(const Duration(seconds: 6), () {
                typing.remove(id);
                _notify();
              });
            } else {
              typing.remove(id);
            }
            _notify();
          },
        )
        .subscribe();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadNames() async {
    final ids = _raw
        .map((r) => r['sender_id'] as String?)
        .whereType<String>()
        .where((id) => id != _me && !_names.containsKey(id))
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    try {
      final saved = await _sb
          .from('contacts')
          .select('contact_user_id, saved_name')
          .eq('owner_id', _me)
          .inFilter('contact_user_id', ids);
      for (final r in saved) {
        final n = (r['saved_name'] as String?)?.trim();
        if (n != null && n.isNotEmpty) _names[r['contact_user_id']] = n;
      }
      final missing = ids.where((i) => !_names.containsKey(i)).toList();
      if (missing.isNotEmpty) {
        final p = await _sb
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', missing);
        for (final r in p) {
          _names[r['id']] = (r['full_name'] as String?) ?? 'Member';
        }
      }
    } catch (_) {}
  }

  Future<void> _loadReactions() async {
    final ids = _raw.map((r) => r['id'] as String).toList();
    if (ids.isEmpty) return;
    try {
      final rows = await _sb
          .from('message_reactions')
          .select('message_id, emoji')
          .inFilter(
            'message_id',
            ids.length > 300 ? ids.sublist(ids.length - 300) : ids,
          );
      _reactions.clear();
      for (final r in rows) {
        (_reactions[r['message_id'] as String] ??= []).add('${r['emoji']}');
      }
    } catch (_) {}
  }

  Future<void> _loadReadState() async {
    try {
      final rows = await _sb
          .from('conversation_participants')
          .select('user_id, last_read_at')
          .eq('conversation_id', conversationId)
          .neq('user_id', _me);
      DateTime? minRead;
      final others = <String>[];
      for (final r in rows) {
        others.add(r['user_id'] as String);
        final at = DateTime.tryParse('${r['last_read_at'] ?? ''}');
        // In groups a message is "read" once everyone has read it.
        if (at == null) {
          minRead = DateTime.fromMillisecondsSinceEpoch(0);
        } else if (minRead == null || at.isBefore(minRead)) {
          minRead = at;
        }
      }
      _othersReadAt = minRead;
      if (!isGroup && others.isNotEmpty) {
        final ps = await _sb
            .from('privacy_settings')
            .select('read_receipts_enabled')
            .eq('user_id', others.first)
            .maybeSingle();
        _receiptsOn = ps?['read_receipts_enabled'] != false;
      }
      _emit();
    } catch (_) {}
  }

  MessageKind _kind(String t) => switch (t) {
    'text' => MessageKind.text,
    'image' || 'image_group' => MessageKind.image,
    'video' => MessageKind.video,
    'voice_note' || 'audio' => MessageKind.voice,
    'document' => MessageKind.document,
    'call' => MessageKind.call,
    'gift_card' => MessageKind.gift,
    _ => MessageKind.other,
  };

  void _emit() {
    final serverClientIds = _raw
        .map((r) => r['client_id']?.toString())
        .whereType<String>()
        .toSet();
    _pending.removeWhere((p) => serverClientIds.contains(p['client_id']));
    final out = <DemoMessage>[];
    for (final r in [..._raw, ..._pending]) {
      if (r['is_deleted'] == true) continue;
      final deletedFor = (r['deleted_for_user_ids'] as List?) ?? const [];
      if (deletedFor.contains(_me)) continue;
      final created =
          DateTime.tryParse('${r['created_at'] ?? ''}')?.toLocal() ??
          DateTime.now();
      final mine = r['sender_id'] == _me;
      final type = (r['message_type'] as String?) ?? 'text';
      final read =
          _receiptsOn &&
          _othersReadAt != null &&
          !_othersReadAt!.isBefore(created.toUtc());
      final urls = ((r['media_urls'] as List?) ?? const [])
          .map((e) => '$e')
          .where((e) => e.isNotEmpty)
          .toList();
      out.add(
        DemoMessage(
          id: '${r['id']}',
          text: (r['content'] as String?) ?? '',
          time: formatClock(created),
          createdAt: created,
          isMine: mine,
          kind: _kind(type),
          isRead: read,
          pending: r['_pending'] == true,
          mediaUrl: r['media_url'] as String?,
          mediaUrls: urls,
          thumbUrl: r['thumbnail_url'] as String?,
          durationSeconds:
              (r['duration_seconds'] ?? r['media_duration_seconds']) as int?,
          senderName: (isGroup && !mine) ? _names[r['sender_id']] : null,
          reactions: _reactions['${r['id']}'] ?? const [],
          replyTo: r['reply_to_content'] as String?,
          isEdited: r['is_edited'] == true,
          isForwarded: r['is_forwarded'] == true,
        ),
      );
    }
    out.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    messages = out;
    loaded = true;
    _notify();
  }

  /// Sends a text message (same row shape as the mobile app).
  Future<void> sendText(String text) async {
    final content = text.trim();
    if (content.isEmpty) return;
    setTyping(false);
    final clientId = 'c_${DateTime.now().microsecondsSinceEpoch}';
    final row = {
      'conversation_id': conversationId,
      'sender_id': _me,
      'message_type': 'text',
      'content': content,
      'client_id': clientId,
    };
    _pending.add({
      ...row,
      'id': clientId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      '_pending': true,
    });
    _emit();
    try {
      await _sb.from('messages').insert(row);
    } catch (e) {
      _pending.removeWhere((p) => p['client_id'] == clientId);
      _emit();
      rethrow;
    }
  }

  /// Tells the other side we are typing (throttled), then stops after 3s.
  void setTyping(bool on) {
    final now = DateTime.now();
    if (on) {
      if (_lastTypingSent == null ||
          now.difference(_lastTypingSent!) > const Duration(seconds: 2)) {
        _lastTypingSent = now;
        _sendTyping(true);
      }
      _typingOff?.cancel();
      _typingOff = Timer(const Duration(seconds: 3), () => setTyping(false));
    } else if (_lastTypingSent != null) {
      _lastTypingSent = null;
      _typingOff?.cancel();
      _sendTyping(false);
    }
  }

  void _sendTyping(bool on) {
    _typingChannel?.sendBroadcastMessage(
      event: 'typing',
      payload: {'userId': _me, 'isTyping': on},
    );
  }

  @override
  void dispose() {
    _disposed = true;
    setTyping(false);
    _sub?.cancel();
    _typingChannel?.unsubscribe();
    _metaChannel?.unsubscribe();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _typingOff?.cancel();
    super.dispose();
  }
}
