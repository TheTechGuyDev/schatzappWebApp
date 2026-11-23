import 'package:supabase_flutter/supabase_flutter.dart';

import '../demo_data.dart';

/// A group member for the info panel.
class InfoMember {
  const InfoMember({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.isAdmin = false,
    this.isMe = false,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final bool isAdmin;
  final bool isMe;
}

/// A group both people are in.
class InfoGroup {
  const InfoGroup(this.id, this.name, this.avatarUrl, this.memberCount);

  final String id;
  final String name;
  final String? avatarUrl;
  final int memberCount;
}

/// Everything the Contact / Group info panel shows, read from the same
/// tables as the phone (profiles, conversations, participants, contacts).
class ChatInfo {
  ChatInfo._();

  String name = '';
  String? avatarUrl;
  String phone = '';
  String username = '';
  String about = '';
  bool isOnline = false;
  DateTime? lastSeen;
  bool muted = false;

  /// 'i_blocked', 'they_blocked' or 'none'.
  String blockStatus = 'none';

  // Groups
  String description = '';
  bool isPrivateGroup = false;
  bool iAmAdmin = false;
  DateTime? createdAt;
  String? createdByName;
  List<InfoMember> members = [];

  // People
  List<InfoGroup> groupsInCommon = [];

  static SupabaseClient get _sb => Supabase.instance.client;

  static Future<ChatInfo> load(DemoChat chat) async {
    final me = _sb.auth.currentUser!.id;
    final i = ChatInfo._()
      ..name = chat.name
      ..avatarUrl = chat.avatarUrl
      ..phone = chat.phone
      ..username = chat.username
      ..muted = chat.isMuted
      ..isOnline = chat.isOnline;

    // Names this user saved for people.
    final saved = <String, String>{};
    try {
      final c = await _sb
          .from('contacts')
          .select('contact_user_id, saved_name')
          .eq('owner_id', me);
      for (final r in c) {
        final n = (r['saved_name'] as String?)?.trim() ?? '';
        if (r['contact_user_id'] != null && n.isNotEmpty) {
          saved['${r['contact_user_id']}'] = n;
        }
      }
    } catch (_) {}

    try {
      final p = await _sb
          .from('conversation_participants')
          .select('is_muted')
          .eq('conversation_id', chat.id)
          .eq('user_id', me)
          .maybeSingle();
      i.muted = p?['is_muted'] == true;
    } catch (_) {}

    if (chat.isGroup) {
      await _loadGroup(i, chat, me, saved);
    } else if (chat.otherUserId != null) {
      await _loadPerson(i, chat.otherUserId!, me, saved);
    }
    return i;
  }

  static Future<void> _loadPerson(
    ChatInfo i,
    String other,
    String me,
    Map<String, String> saved,
  ) async {
    try {
      final p = await _sb
          .from('profiles')
          .select()
          .eq('id', other)
          .maybeSingle();
      if (p != null) {
        final full = (p['full_name'] as String?)?.trim() ?? '';
        i.name = saved[other] ?? (full.isEmpty ? i.name : full);
        i.avatarUrl = (p['avatar_url'] as String?) ?? i.avatarUrl;
        i.username = (p['username'] as String?) ?? '';
        i.phone = (p['phone_number'] as String?) ?? i.phone;
        i.about = (p['about_text'] as String?)?.trim() ?? '';
        i.isOnline = p['is_online'] == true;
        i.lastSeen = DateTime.tryParse('${p['last_seen_at'] ?? ''}')?.toLocal();
      }
    } catch (_) {}

    try {
      final r = await _sb.rpc('block_status', params: {'p_other': other});
      i.blockStatus = '${r ?? 'none'}';
    } catch (_) {}

    // Groups in common (phone's getGroupsInCommon).
    try {
      final mine = await _sb
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', me)
          .isFilter('left_at', null);
      final myIds = mine.map((r) => '${r['conversation_id']}').toList();
      if (myIds.isEmpty) return;
      final theirs = await _sb
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', other)
          .isFilter('left_at', null)
          .inFilter('conversation_id', myIds);
      final shared = theirs.map((r) => '${r['conversation_id']}').toSet();
      if (shared.isEmpty) return;
      final groups = await _sb
          .from('conversations')
          .select('id, name, avatar_url')
          .eq('type', 'group')
          .inFilter('id', shared.toList());
      final ids = groups.map((g) => '${g['id']}').toList();
      final counts = <String, int>{};
      if (ids.isNotEmpty) {
        final m = await _sb
            .from('conversation_participants')
            .select('conversation_id')
            .isFilter('left_at', null)
            .inFilter('conversation_id', ids);
        for (final r in m) {
          final k = '${r['conversation_id']}';
          counts[k] = (counts[k] ?? 0) + 1;
        }
      }
      i.groupsInCommon = [
        for (final g in groups)
          InfoGroup(
            '${g['id']}',
            (g['name'] as String?) ?? 'Group',
            g['avatar_url'] as String?,
            counts['${g['id']}'] ?? 0,
          ),
      ]..sort((a, b) => a.name.compareTo(b.name));
    } catch (_) {}
  }

  static Future<void> _loadGroup(
    ChatInfo i,
    DemoChat chat,
    String me,
    Map<String, String> saved,
  ) async {
    String? createdBy;
    try {
      final g = await _sb
          .from('conversations')
          .select(
            'name, description, avatar_url, created_by, created_at, is_private_group',
          )
          .eq('id', chat.id)
          .maybeSingle();
      if (g != null) {
        i.name = (g['name'] as String?) ?? i.name;
        i.description = (g['description'] as String?)?.trim() ?? '';
        i.avatarUrl = (g['avatar_url'] as String?) ?? i.avatarUrl;
        i.isPrivateGroup = g['is_private_group'] == true;
        i.createdAt = DateTime.tryParse('${g['created_at'] ?? ''}')?.toLocal();
        createdBy = g['created_by'] as String?;
      }
    } catch (_) {}

    try {
      final rows = await _sb
          .from('conversation_participants_directory')
          .select('user_id, full_name, avatar_url, role')
          .eq('conversation_id', chat.id);
      final list = <InfoMember>[];
      for (final r in rows) {
        final id = '${r['user_id']}';
        final isMe = id == me;
        final admin = r['role'] == 'admin' || id == createdBy;
        if (isMe) i.iAmAdmin = admin;
        final full = (r['full_name'] as String?)?.trim() ?? '';
        list.add(
          InfoMember(
            userId: id,
            name: isMe
                ? 'You'
                : (saved[id] ?? (full.isEmpty ? 'Member' : full)),
            avatarUrl: r['avatar_url'] as String?,
            isAdmin: admin,
            isMe: isMe,
          ),
        );
        if (id == createdBy) {
          i.createdByName = isMe ? 'You' : (saved[id] ?? full);
        }
      }
      // You first, then admins, then by name.
      list.sort((a, b) {
        if (a.isMe != b.isMe) return a.isMe ? -1 : 1;
        if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      i.members = list;
    } catch (_) {}
  }
}
