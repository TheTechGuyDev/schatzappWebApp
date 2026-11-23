import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../demo_data.dart';

/// Live chat data from the same Supabase tables as the mobile app, kept in
/// sync with Realtime. Mirrors the mobile ChatListPanel and ChatThread logic.
class ChatRepo extends ChangeNotifier {
  ChatRepo._();
  static final ChatRepo instance = ChatRepo._();

  SupabaseClient get _sb => Supabase.instance.client;
  String? get uid => _sb.auth.currentUser?.id;

  bool loading = true;
  String? error;
  List<DemoChat> chats = [];
  List<DemoChat> lockedChats = [];

  /// Signed-in user's profile (for the left menu and Profile tab).
  Map<String, dynamic>? me;

  RealtimeChannel? _channel;
  Timer? _debounce;
  bool _started = false;

  Future<void> start() async {
    if (_started || uid == null) return;
    _started = true;
    await Future.wait([refresh(), _loadMe()]);
    _channel = _sb
        .channel('web-chatlist-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) => _schedule(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_participants',
          callback: (_) => _schedule(),
        )
        .subscribe();
  }

  Future<void> stop() async {
    _started = false;
    _debounce?.cancel();
    await _channel?.unsubscribe();
    _channel = null;
    chats = [];
    lockedChats = [];
    me = null;
    loading = true;
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  Future<void> _loadMe() async {
    try {
      me = await _sb
          .from('profiles')
          .select('id, full_name, username, avatar_url, phone_number')
          .eq('id', uid!)
          .maybeSingle();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refresh() async {
    final me = uid;
    if (me == null) return;
    try {
      final rows = List<Map<String, dynamic>>.from(
        await _sb
            .from('chat_list_view')
            .select()
            .order('is_pinned', ascending: false)
            .order('last_message_at', ascending: false),
      );

      final otherIds = rows
          .where((r) => r['type'] != 'group')
          .map((r) => r['other_user_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      // Names the user saved for their contacts win over profile names.
      final saved = <String, String>{};
      final phones = <String, String>{};
      final abouts = <String, String>{};
      final usernames = <String, String>{};
      if (otherIds.isNotEmpty) {
        final c = await _sb
            .from('contacts')
            .select('contact_user_id, saved_name')
            .eq('owner_id', me)
            .inFilter('contact_user_id', otherIds);
        for (final r in c) {
          final id = r['contact_user_id'] as String?;
          final n = (r['saved_name'] as String?)?.trim();
          if (id != null && n != null && n.isNotEmpty) {
            saved[id] = n.replaceAll('\n', ' ');
          }
        }
        try {
          final p = await _sb
              .from('profiles')
              .select('id, username, phone_number')
              .inFilter('id', otherIds);
          for (final r in p) {
            final id = r['id'] as String;
            if ((r['phone_number'] ?? '') != '') phones[id] = r['phone_number'];
            if ((r['username'] ?? '') != '') usernames[id] = r['username'];
          }
        } catch (_) {}
      }

      // Read receipts for chats where I sent the last message.
      final sent = rows.where(
        (r) => r['type'] != 'group' && r['last_message_sender_id'] == me,
      );
      final sentConv = sent.map((r) => r['conversation_id'] as String).toList();
      final otherReadAt = <String, DateTime>{};
      final noReceipt = <String>{};
      if (sentConv.isNotEmpty) {
        try {
          final pr = await _sb
              .from('conversation_participants')
              .select('conversation_id, user_id, last_read_at')
              .inFilter('conversation_id', sentConv)
              .neq('user_id', me);
          for (final r in pr) {
            final at = DateTime.tryParse('${r['last_read_at'] ?? ''}');
            if (at != null) otherReadAt[r['conversation_id']] = at;
          }
          final ids = sent
              .map((r) => r['other_user_id'] as String?)
              .whereType<String>()
              .toList();
          final ps = await _sb
              .from('privacy_settings')
              .select('user_id, read_receipts_enabled')
              .inFilter('user_id', ids);
          for (final r in ps) {
            if (r['read_receipts_enabled'] == false) {
              noReceipt.add(r['user_id']);
            }
          }
        } catch (_) {}
      }

      Set<String> requestPeers = {};
      try {
        final q = await _sb.rpc('pending_request_peers');
        requestPeers = {for (final x in (q as List)) x.toString()};
      } catch (_) {}

      final normal = <DemoChat>[];
      final locked = <DemoChat>[];
      for (final r in rows) {
        if (r['type'] == 'direct' &&
            requestPeers.contains('${r['other_user_id']}')) {
          continue; // message requests are handled on the phone
        }
        final c = _toChat(
          r,
          me: me,
          saved: saved,
          phones: phones,
          abouts: abouts,
          usernames: usernames,
          otherReadAt: otherReadAt,
          noReceipt: noReceipt,
        );
        (c.isLocked ? locked : normal).add(c);
      }
      chats = normal;
      lockedChats = locked;
      loading = false;
      error = null;
      notifyListeners();
    } catch (e) {
      loading = false;
      error = 'Could not load chats. Check your connection.';
      notifyListeners();
    }
  }

  DemoChat _toChat(
    Map<String, dynamic> r, {
    required String me,
    required Map<String, String> saved,
    required Map<String, String> phones,
    required Map<String, String> abouts,
    required Map<String, String> usernames,
    required Map<String, DateTime> otherReadAt,
    required Set<String> noReceipt,
  }) {
    final group = r['type'] == 'group';
    final other = r['other_user_id'] as String?;
    final name = (!group && other != null && saved[other] != null)
        ? saved[other]!
        : ((r['display_name'] as String?)?.trim().isNotEmpty == true
              ? r['display_name'] as String
              : (group ? 'Group' : 'SchatzApp user'));
    final type = (r['last_message_type'] as String?) ?? '';
    final lastAt = DateTime.tryParse('${r['last_message_at'] ?? ''}')
        ?.toLocal();
    final fromMe = r['last_message_sender_id'] == me;
    var marker = ChatMarker.none;
    if (fromMe && !group && type.isNotEmpty && lastAt != null) {
      final read = otherReadAt[r['conversation_id']];
      final seen =
          other != null &&
          !noReceipt.contains(other) &&
          read != null &&
          !read.isBefore(lastAt);
      marker = seen ? ChatMarker.activeStatus : ChatMarker.seenStatus;
    }
    final preview = previewFor(type, r['last_message_content'] as String?);
    return DemoChat(
      id: r['conversation_id'] as String,
      name: name,
      preview: preview.isEmpty
          ? ''
          : (fromMe && group ? 'You: $preview' : preview),
      time: lastAt == null ? '' : formatListTime(lastAt),
      unread: (r['unread_count'] as int?) ?? 0,
      isGroup: group,
      isOnline: r['is_online'] == true,
      isArchived: r['is_archived'] == true,
      previewIsPhoto: type == 'image' || type == 'image_group',
      marker: marker,
      avatarUrl: r['display_avatar'] as String?,
      otherUserId: other,
      isLocked: r['is_locked'] == true,
      isPinned: r['is_pinned'] == true,
      isMuted: r['is_muted'] == true,
      lastAt: lastAt,
      phone: other == null ? '' : (phones[other] ?? ''),
      about: other == null ? '' : (abouts[other] ?? ''),
      username: other == null ? '' : (usernames[other] ?? ''),
    );
  }

  /// Marks a chat read (same as the mobile markConversationAsRead).
  Future<void> markRead(String conversationId) async {
    final me = uid;
    if (me == null) return;
    for (final list in [chats, lockedChats]) {
      final i = list.indexWhere((c) => c.id == conversationId);
      if (i >= 0 && list[i].unread > 0) {
        list[i] = _copyUnread(list[i], 0);
        notifyListeners();
      }
    }
    try {
      await _sb
          .from('conversation_participants')
          .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('user_id', me);
    } catch (_) {}
  }

  DemoChat _copyUnread(DemoChat c, int unread) => DemoChat(
    id: c.id,
    name: c.name,
    preview: c.preview,
    time: c.time,
    unread: unread,
    isGroup: c.isGroup,
    isOnline: c.isOnline,
    isArchived: c.isArchived,
    previewIsPhoto: c.previewIsPhoto,
    marker: c.marker,
    avatarUrl: c.avatarUrl,
    otherUserId: c.otherUserId,
    isLocked: c.isLocked,
    isPinned: c.isPinned,
    isMuted: c.isMuted,
    lastAt: c.lastAt,
    phone: c.phone,
    about: c.about,
    username: c.username,
  );

  /// Checks the app password (same RPC as the mobile app).
  Future<bool> verifyAppPassword(String password) async {
    try {
      final r = await _sb.rpc(
        'verify_app_password',
        params: {'p_password': password},
      );
      return r is Map && r['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// This user's theme and wallpaper for a chat (conversation_participants).
  Future<(String?, String?)> chatAppearance(String conversationId) async {
    try {
      final r = await _sb
          .from('conversation_participants')
          .select('chat_theme, chat_wallpaper_url')
          .eq('conversation_id', conversationId)
          .eq('user_id', uid!)
          .maybeSingle();
      return (r?['chat_theme'] as String?, r?['chat_wallpaper_url'] as String?);
    } catch (_) {
      return (null, null);
    }
  }

  Future<void> setChatTheme(String conversationId, String? theme) async {
    await _sb
        .from('conversation_participants')
        .update({'chat_theme': theme, 'chat_wallpaper_url': null})
        .eq('conversation_id', conversationId)
        .eq('user_id', uid!);
  }

  // ---------------------------------------------------------------------
  // Contacts, new chats and groups (same tables and RPCs as the phone)
  // ---------------------------------------------------------------------

  List<DemoContact>? _contacts;

  /// The user's saved SchatzApp contacts, by saved name.
  Future<List<DemoContact>> contacts({bool force = false}) async {
    if (_contacts != null && !force) return _contacts!;
    final rows = await _sb
        .from('contacts')
        .select(
          'contact_user_id, saved_name, phone_number, '
          'profiles!contacts_contact_user_id_fkey(full_name, avatar_url, phone_number)',
        )
        .eq('owner_id', uid!)
        .not('contact_user_id', 'is', null);
    final out = <DemoContact>[];
    final seen = <String>{};
    for (final r in rows) {
      final id = r['contact_user_id'] as String?;
      if (id == null || id == uid || !seen.add(id)) continue;
      final p = r['profiles'] as Map<String, dynamic>?;
      final saved = (r['saved_name'] as String?)?.trim() ?? '';
      final name = saved.isNotEmpty
          ? saved
          : ((p?['full_name'] as String?)?.trim().isNotEmpty == true
                ? p!['full_name'] as String
                : 'SchatzApp user');
      out.add(
        DemoContact(
          name,
          (r['phone_number'] as String?) ??
              (p?['phone_number'] as String?) ??
              '',
          null,
          id,
          p?['avatar_url'] as String?,
        ),
      );
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return _contacts = out;
  }

  /// Opens the existing direct chat with someone, or creates it.
  Future<String> directConversationWith(String otherUserId) async {
    final r = await _sb.rpc(
      'find_or_create_direct_conversation',
      params: {'p_current_user_id': uid, 'p_other_user_id': otherUserId},
    );
    return r as String;
  }

  /// Creates a group like the phone: creator is admin, others are members.
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
    required bool isPrivate,
    String? avatarUrl,
  }) async {
    final conv = await _sb
        .from('conversations')
        .insert({
          'type': 'group',
          'name': name.trim(),
          'avatar_url': avatarUrl,
          'created_by': uid,
          'is_private_group': isPrivate,
        })
        .select('id')
        .single();
    final id = conv['id'] as String;
    await _sb.from('conversation_participants').insert([
      {'conversation_id': id, 'user_id': uid, 'role': 'admin'},
      for (final m in memberIds)
        {'conversation_id': id, 'user_id': m, 'role': 'member'},
    ]);
    await refresh();
    return id;
  }

  /// Group photo, stored where the phone stores it.
  Future<String> uploadGroupAvatar(List<int> jpegBytes) async {
    final path = 'avatars/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bucket = _sb.storage.from('group-avatars');
    await bucket.uploadBinary(
      path,
      Uint8List.fromList(jpegBytes),
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    return bucket.getPublicUrl(path);
  }

  Future<void> addMembers(String conversationId, List<String> userIds) async {
    if (userIds.isEmpty) return;
    await _sb.from('conversation_participants').insert([
      for (final u in userIds)
        {'conversation_id': conversationId, 'user_id': u, 'role': 'member'},
    ]);
  }

  Future<void> setMuted(String conversationId, bool muted) async {
    await _sb
        .from('conversation_participants')
        .update({'is_muted': muted})
        .eq('conversation_id', conversationId)
        .eq('user_id', uid!);
    await refresh();
  }

  /// 'i_blocked', 'they_blocked', 'none' (phone's block_status RPC).
  Future<String> blockStatus(String otherUserId) async {
    try {
      final r = await _sb.rpc('block_status', params: {'p_other': otherUserId});
      return '${r ?? 'none'}';
    } catch (_) {
      return 'none';
    }
  }

  Future<void> block(String otherUserId) async {
    final existing = await _sb
        .from('blocked_users')
        .select('id')
        .eq('blocker_id', uid!)
        .eq('blocked_id', otherUserId)
        .limit(1);
    if ((existing as List).isEmpty) {
      await _sb.from('blocked_users').insert({
        'blocker_id': uid,
        'blocked_id': otherUserId,
      });
    }
  }

  Future<void> unblock(String otherUserId) async {
    await _sb
        .from('blocked_users')
        .delete()
        .eq('blocker_id', uid!)
        .eq('blocked_id', otherUserId);
  }

  Future<void> leaveGroup(String conversationId) async {
    await _sb.rpc(
      'leave_group',
      params: {'p_conversation_id': conversationId, 'p_user_id': uid},
    );
    await refresh();
  }

  /// Deletes every message in a chat for this user only (phone's Clear chat).
  Future<void> clearChat(String conversationId) async {
    final rows = await _sb
        .from('messages')
        .select('id, deleted_for_user_ids')
        .eq('conversation_id', conversationId);
    for (final r in rows) {
      final ids = List<String>.from(
        ((r['deleted_for_user_ids'] as List?) ?? const []).map((e) => '$e'),
      );
      if (ids.contains(uid)) continue;
      ids.add(uid!);
      await _sb
          .from('messages')
          .update({'deleted_for_user_ids': ids})
          .eq('id', r['id']);
    }
    await refresh();
  }

  /// Removes the chat from this user's list (phone's Delete chat).
  Future<void> deleteChat(String conversationId) async {
    try {
      final msgs = await _sb
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId);
      final ids = msgs.map((r) => '${r['id']}').toList();
      for (var i = 0; i < ids.length; i += 200) {
        await _sb
            .from('message_stars')
            .delete()
            .eq('user_id', uid!)
            .inFilter(
              'message_id',
              ids.sublist(i, (i + 200).clamp(0, ids.length)),
            );
      }
    } catch (_) {}
    await _sb.rpc(
      'delete_conversations_for_user',
      params: {
        'p_conversation_ids': [conversationId],
        'p_user_id': uid,
      },
    );
    await refresh();
  }
}

/// Short preview text for a message type (chat list).
String previewFor(String type, String? content) {
  switch (type) {
    case 'image':
      return 'Photo';
    case 'image_group':
      return 'Photos';
    case 'video':
      return 'Video';
    case 'voice_note':
      return 'Voice message';
    case 'document':
      return (content?.trim().isNotEmpty ?? false)
          ? content!.trim()
          : 'Document';
    case 'call':
      return (content ?? '').toLowerCase().startsWith('video')
          ? 'Video call'
          : 'Voice call';
    case 'gift_card':
      return 'Gift card';
    case '':
      return '';
    default:
      return (content ?? '').replaceAll('\n', ' ').trim();
  }
}

/// WhatsApp-style time for the chat list.
String formatListTime(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return formatClock(t);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) {
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][t.weekday - 1];
  }
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.month)}/${two(t.day)}/${two(t.year % 100)}';
}

String formatClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}
