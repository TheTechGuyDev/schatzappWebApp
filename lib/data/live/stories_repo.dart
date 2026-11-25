import 'dart:math';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../platform/web_files.dart';
import '../demo_data.dart';
import 'chat_repo.dart';

/// Story settings (story_settings table, same defaults as the phone).
class StorySettings {
  StorySettings({
    this.durationHours = 24,
    this.sortOrder = 'time',
    this.viewVisibility = 'everyone',
    this.allowDownload = true,
    this.allowReplies = true,
    this.showLocation = true,
  });

  int durationHours;
  String sortOrder;
  String viewVisibility;
  bool allowDownload;
  bool allowReplies;
  bool showLocation;
}

/// Someone who viewed one of my stories.
class StoryViewer {
  const StoryViewer(
    this.name,
    this.avatarUrl,
    this.at, {
    this.userId = '',
    this.reactions = const [],
    this.requestId,
  });

  final String name;
  final String? avatarUrl;
  final DateTime? at;
  final String userId;

  /// Their reactions on this story (max 2), in the app's order.
  final List<String> reactions;

  /// A request they sent me that I haven't answered (they can't message me
  /// yet), or null.
  final String? requestId;
}

/// Reactions on a story: counts and mine (favorite, peace, laugh, sad,
/// angry). Old 'thumbs' rows count as laugh.
class StoryReactions {
  StoryReactions(this.counts, this.mine);

  final Map<String, int> counts;
  final Set<String> mine;
}

/// Live stories with the same tables, visibility rules and storage paths as
/// the phone (statuses, status_views, status_reactions, story_settings...).
class StoriesRepo {
  StoriesRepo._();
  static final StoriesRepo instance = StoriesRepo._();

  SupabaseClient get _sb => Supabase.instance.client;
  String get _me => _sb.auth.currentUser!.id;

  static const reactionTypes = ['favorite', 'peace', 'laugh', 'sad', 'angry'];

  /// Emoji for each reaction type, in display order.
  static const reactionEmoji = {
    'favorite': '❤️',
    'peace': '✌️',
    'laugh': '😂',
    'sad': '😢',
    'angry': '😠',
  };

  /// Each user can pick at most this many reactions per post (also enforced
  /// by a database trigger).
  static const maxReactionsPerUser = 2;

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static String timeAgo(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return 'Yesterday';
  }

  static List<Color>? gradientOf(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    Color one(String h) {
      var v = h.trim().replaceAll('#', '');
      if (v.length == 6) v = 'FF$v';
      return Color(int.tryParse(v, radix: 16) ?? 0xFF7A2BE8);
    }

    final parts = hex.split(',');
    final a = one(parts[0]);
    return [a, parts.length > 1 ? one(parts[1]) : a];
  }

  static String hexOf(List<Color> g) {
    String h(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return '${h(g.first)},${h(g.last)}';
  }

  StoryItem _item(Map<String, dynamic> r, {int views = 0}) {
    final type = '${r['media_type'] ?? 'image'}';
    final text = type == 'text';
    final g = gradientOf(r['background_color'] as String?);
    return StoryItem.live(
      id: '${r['id']}',
      kind: text ? StoryKind.text : StoryKind.photo,
      text: text ? '${r['caption'] ?? ''}' : '',
      caption: text ? '' : '${r['caption'] ?? ''}',
      mediaUrl: r['media_url'] as String?,
      isVideo: type == 'video',
      createdAt: DateTime.tryParse('${r['created_at'] ?? ''}')?.toLocal(),
      viewCount: views,
      commentsEnabled: r['comments_enabled'] != false,
      fontIndex: (r['text_font_index'] as int?) ?? 0,
      gradient: g,
      background: g?.first ?? const Color(0xFF7A2BE8),
    );
  }

  /// The phone's visibility rules: privacy "nobody"/"contacts", hidden
  /// from me, and story_settings "phone_number"/"custom".
  Future<Set<String>> _allowedPosters(List<String> posterIds) async {
    final me = _me;
    if (posterIds.isEmpty) return {};
    final privacy = await _sb
        .from('privacy_settings')
        .select('user_id, status_visibility')
        .inFilter('user_id', posterIds);
    final nobody = <String>{};
    final contactsOnly = <String>{};
    for (final r in privacy) {
      final v = r['status_visibility'];
      if (v == 'nobody') nobody.add('${r['user_id']}');
      if (v == 'contacts') contactsOnly.add('${r['user_id']}');
    }

    final contactsAllowed = <String>{};
    if (contactsOnly.isNotEmpty) {
      final c = await _sb
          .from('contacts')
          .select('owner_id')
          .inFilter('owner_id', contactsOnly.toList())
          .eq('contact_user_id', me);
      contactsAllowed.addAll(c.map((r) => '${r['owner_id']}'));
      final conv = await _sb
          .from('conversations')
          .select('user_a_id, user_b_id')
          .or('user_a_id.eq.$me,user_b_id.eq.$me');
      for (final r in conv) {
        final other = r['user_a_id'] == me ? r['user_b_id'] : r['user_a_id'];
        if (other is String && contactsOnly.contains(other)) {
          contactsAllowed.add(other);
        }
      }
    }

    final hidden =
        (await _sb
                .from('status_hidden_from')
                .select('owner_id')
                .eq('hidden_user_id', me)
                .inFilter('owner_id', posterIds))
            .map((r) => '${r['owner_id']}')
            .toSet();

    final settings = await _sb
        .from('story_settings')
        .select('user_id, view_visibility')
        .inFilter('user_id', posterIds);
    final phoneOnly = <String>{};
    final custom = <String>{};
    for (final r in settings) {
      final v = r['view_visibility'] ?? 'everyone';
      if (v == 'phone_number') phoneOnly.add('${r['user_id']}');
      if (v == 'custom') custom.add('${r['user_id']}');
    }
    final mutual = <String>{};
    if (phoneOnly.isNotEmpty) {
      final m = await _sb
          .from('contacts')
          .select('owner_id')
          .inFilter('owner_id', phoneOnly.toList())
          .eq('contact_user_id', me);
      mutual.addAll(m.map((r) => '${r['owner_id']}'));
    }
    final customAllowed = <String>{};
    if (custom.isNotEmpty) {
      final a = await _sb
          .from('story_custom_viewers')
          .select('owner_id')
          .inFilter('owner_id', custom.toList())
          .eq('viewer_id', me);
      customAllowed.addAll(a.map((r) => '${r['owner_id']}'));
    }

    return {
      for (final id in posterIds)
        if (!nobody.contains(id) &&
            !hidden.contains(id) &&
            (!contactsOnly.contains(id) || contactsAllowed.contains(id)) &&
            (!phoneOnly.contains(id) || mutual.contains(id)) &&
            (!custom.contains(id) || customAllowed.contains(id)))
          id,
    };
  }

  /// Saved name, then username, then full name (same as the phone).
  Future<Map<String, (String, String?)>> _people(List<String> ids) async {
    final out = <String, (String, String?)>{};
    if (ids.isEmpty) return out;
    final saved = <String, String>{};
    final c = await _sb
        .from('contacts')
        .select('contact_user_id, saved_name')
        .eq('owner_id', _me)
        .inFilter('contact_user_id', ids);
    for (final r in c) {
      final n = '${r['saved_name'] ?? ''}'.trim();
      if (n.isNotEmpty) saved['${r['contact_user_id']}'] = n;
    }
    final p = await _sb
        .from('profiles')
        .select('id, full_name, username, avatar_url')
        .inFilter('id', ids);
    for (final r in p) {
      final id = '${r['id']}';
      final u = '${r['username'] ?? ''}'.trim();
      final f = '${r['full_name'] ?? ''}'.trim();
      out[id] = (
        saved[id] ?? (u.isNotEmpty ? u : (f.isNotEmpty ? f : 'SchatzApp user')),
        r['avatar_url'] as String?,
      );
    }
    return out;
  }

  String get _nowIso => DateTime.now().toUtc().toIso8601String();

  // -------------------------------------------------------------------------
  // Loading
  // -------------------------------------------------------------------------

  /// Friends' stories (people I saved or who saved me), unviewed first.
  Future<List<DemoStory>> friends() async {
    final me = _me;
    final mine = await _sb
        .from('contacts')
        .select('contact_user_id')
        .eq('owner_id', me)
        .not('contact_user_id', 'is', null);
    final theirs = await _sb
        .from('contacts')
        .select('owner_id')
        .eq('contact_user_id', me)
        .not('owner_id', 'is', null);
    final friendIds = {
      ...mine.map((r) => '${r['contact_user_id']}'),
      ...theirs.map((r) => '${r['owner_id']}'),
    }..remove(me);

    // People in Private Chats stay hidden unless the user allows it.
    try {
      final locked =
          (await _sb
                  .from('chat_list_view')
                  .select('other_user_id')
                  .eq('is_locked', true)
                  .neq('type', 'group'))
              .map((r) => '${r['other_user_id']}')
              .toSet();
      final p = await _sb
          .from('profiles')
          .select('show_locked_stories_in_normal')
          .eq('id', me)
          .maybeSingle();
      if (p?['show_locked_stories_in_normal'] != true) {
        friendIds.removeWhere(locked.contains);
      }
    } catch (_) {}
    if (friendIds.isEmpty) return [];

    final rows = await _sb
        .from('statuses')
        .select()
        .inFilter('user_id', friendIds.toList())
        .gt('expires_at', _nowIso)
        .order('created_at', ascending: true);
    if (rows.isEmpty) return [];

    final posters = rows.map((r) => '${r['user_id']}').toSet().toList();
    final allowed = await _allowedPosters(posters);
    final people = await _people(allowed.toList());
    final viewed =
        (await _sb
                .from('status_views')
                .select('status_id')
                .eq('viewer_id', me)
                .inFilter('status_id', rows.map((r) => '${r['id']}').toList()))
            .map((r) => '${r['status_id']}')
            .toSet();

    final byUser = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final u = '${r['user_id']}';
      if (allowed.contains(u)) (byUser[u] ??= []).add(r);
    }
    final list = [
      for (final e in byUser.entries)
        DemoStory(
          userId: e.key,
          name: people[e.key]?.$1 ?? 'SchatzApp user',
          avatarUrl: people[e.key]?.$2,
          time: timeAgo(
            DateTime.tryParse('${e.value.last['created_at']}')?.toLocal(),
          ),
          viewed: e.value.every((r) => viewed.contains('${r['id']}')),
          items: [for (final r in e.value) _item(r)],
        ),
    ];
    // Newest first, like the phone.
    list.sort((a, b) {
      final at = a.items.last.createdAt ?? DateTime(0);
      final bt = b.items.last.createdAt ?? DateTime(0);
      return bt.compareTo(at);
    });
    return list;
  }

  /// My active stories with view counts.
  Future<DemoStory> mine() async {
    final me = _me;
    final rows = await _sb
        .from('statuses')
        .select()
        .eq('user_id', me)
        .gt('expires_at', _nowIso)
        .order('created_at', ascending: true);
    final ids = rows.map((r) => '${r['id']}').toList();
    final views = <String, int>{};
    if (ids.isNotEmpty) {
      final v = await _sb
          .from('status_views')
          .select('status_id')
          .inFilter('status_id', ids);
      for (final r in v) {
        final k = '${r['status_id']}';
        views[k] = (views[k] ?? 0) + 1;
      }
    }
    final p = ChatRepo.instance.me;
    return DemoStory(
      userId: me,
      name: '${p?['full_name'] ?? 'Me'}',
      avatarUrl: p?['avatar_url'] as String?,
      time: rows.isEmpty
          ? ''
          : timeAgo(DateTime.tryParse('${rows.last['created_at']}')?.toLocal()),
      items: [for (final r in rows) _item(r, views: views['${r['id']}'] ?? 0)],
    );
  }

  /// For You: everyone's visible stories, one card per batch, shuffled with
  /// more weight for people I watch often (same as the phone).
  Future<List<DemoPost>> forYou() async {
    final me = _me;
    final rows = await _sb
        .from('statuses')
        .select()
        .neq('user_id', me)
        .gt('expires_at', _nowIso)
        .order('created_at', ascending: true)
        .limit(300);
    if (rows.isEmpty) return [];
    final posters = rows.map((r) => '${r['user_id']}').toSet().toList();
    final allowed = await _allowedPosters(posters);
    final people = await _people(allowed.toList());

    final groups = <String, List<Map<String, dynamic>>>{};
    final owner = <String, String>{};
    for (final r in rows) {
      final u = '${r['user_id']}';
      if (!allowed.contains(u)) continue;
      final batch = '${r['batch_id'] ?? ''}';
      final key = batch.isNotEmpty ? 'b:$u:$batch' : 's:${r['id']}';
      (groups[key] ??= []).add(r);
      owner[key] = u;
    }

    final affinity = <String, int>{};
    try {
      final h = await _sb
          .from('status_views')
          .select('status_id, statuses!inner(user_id)')
          .eq('viewer_id', me)
          .inFilter('statuses.user_id', allowed.toList());
      for (final r in h) {
        final s = r['statuses'];
        final u = s is Map ? '${s['user_id']}' : null;
        if (u != null) affinity[u] = (affinity[u] ?? 0) + 1;
      }
    } catch (_) {}

    DemoPost toPost(String key) {
      final rs = groups[key]!;
      final u = owner[key]!;
      final author = DemoStory(
        userId: u,
        name: people[u]?.$1 ?? 'SchatzApp user',
        avatarUrl: people[u]?.$2,
        time: timeAgo(
          DateTime.tryParse('${rs.first['created_at']}')?.toLocal(),
        ),
        items: const [],
      );
      final ids = [for (final r in rs) '${r['id']}'];
      final first = rs.first;
      if (first['media_type'] == 'text') {
        final g = gradientOf(first['background_color'] as String?);
        return DemoPost.text(
          author,
          '${first['caption'] ?? ''}',
          g?.first ?? const Color(0xFF7A2BE8),
          statusIds: ids,
          gradient: g,
          fontIndex: (first['text_font_index'] as int?) ?? 0,
        );
      }
      return DemoPost.media(
        author,
        [
          for (final r in rs)
            if ((r['media_url'] ?? '') != '')
              r['media_type'] == 'video'
                  ? FeedMedia.video(
                      '${r['media_url']}',
                      thumb: _thumbFor('${r['media_url']}'),
                    )
                  : FeedMedia.image('${r['media_url']}'),
        ],
        statusIds: ids,
        caption: '${first['caption'] ?? ''}',
      );
    }

    // Weighted shuffle, weight = views of that person + 1.
    final rnd = Random();
    final pool = groups.keys.toList();
    final out = <DemoPost>[];
    while (pool.isNotEmpty) {
      final w = [for (final k in pool) (affinity[owner[k]] ?? 0) + 1];
      var roll = rnd.nextInt(w.fold(0, (a, b) => a + b));
      var pick = 0;
      for (var i = 0; i < pool.length; i++) {
        roll -= w[i];
        if (roll < 0) {
          pick = i;
          break;
        }
      }
      out.add(toPost(pool.removeAt(pick)));
    }
    return out.where((p) => p.text != null || p.media.isNotEmpty).toList();
  }

  /// Videos keep a first-frame image next to them: name_thumb.jpg.
  static String _thumbFor(String url) {
    final q = url.indexOf('?');
    final base = q < 0 ? url : url.substring(0, q);
    final dot = base.lastIndexOf('.');
    return dot < 0 ? base : '${base.substring(0, dot)}_thumb.jpg';
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> markViewed(String statusId) async {
    if (statusId.isEmpty) return;
    try {
      await _sb
          .from('status_views')
          .upsert(
            {'status_id': statusId, 'viewer_id': _me},
            onConflict: 'status_id,viewer_id',
            ignoreDuplicates: true,
          );
    } catch (_) {}
  }

  Future<StoryReactions> reactions(String statusId) async {
    final rows = await _sb
        .from('status_reactions')
        .select('user_id, reaction_type')
        .eq('status_id', statusId);
    final counts = {for (final t in reactionTypes) t: 0};
    final mine = <String>{};
    for (final r in rows) {
      var t = '${r['reaction_type']}';
      if (t == 'thumbs') t = 'laugh';
      if (!counts.containsKey(t)) continue;
      counts[t] = counts[t]! + 1;
      if (r['user_id'] == _me) mine.add(t);
    }
    return StoryReactions(counts, mine);
  }

  /// A reaction can't be removed or changed after this long (also enforced
  /// by a database trigger).
  static const reactionLockAfter = Duration(seconds: 3);

  /// Adds or removes my reaction. Throws [ReactionLockedException] when the
  /// reaction is older than 3 seconds, [ReactionLimitException] at 2.
  Future<void> toggleReaction(String statusId, String type) async {
    // 'laugh' replaced the old 'thumbs', so both are treated as one.
    final same = type == 'laugh' ? ['laugh', 'thumbs'] : [type];
    final existing = List<Map<String, dynamic>>.from(
      await _sb
          .from('status_reactions')
          .select('id, created_at')
          .eq('status_id', statusId)
          .eq('user_id', _me)
          .inFilter('reaction_type', same),
    );
    try {
      if (existing.isNotEmpty) {
        final now = DateTime.now().toUtc();
        for (final r in existing) {
          final at = DateTime.tryParse('${r['created_at'] ?? ''}')?.toUtc();
          if (at == null || now.difference(at) > reactionLockAfter) {
            throw const ReactionLockedException();
          }
        }
        await _sb
            .from('status_reactions')
            .delete()
            .eq('status_id', statusId)
            .eq('user_id', _me)
            .inFilter('reaction_type', same);
      } else {
        await _sb.from('status_reactions').insert({
          'status_id': statusId,
          'user_id': _me,
          'reaction_type': type,
        });
      }
    } on PostgrestException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('3 seconds')) throw const ReactionLockedException();
      if (m.contains('up to 2')) throw const ReactionLimitException();
      rethrow;
    }
  }

  /// A reply goes to the poster's chat with the story attached (phone's
  /// sendStoryInteraction).
  Future<void> reply(String ownerId, StoryItem item, String text) async {
    final conv = await ChatRepo.instance.directConversationWith(ownerId);
    await _sb.from('messages').insert({
      'conversation_id': conv,
      'sender_id': _me,
      'message_type': 'text',
      'content': text,
      'reply_to_status_id': item.id,
      'reply_to_status_media_url': item.mediaUrl,
      'reply_to_status_media_type': item.kind == StoryKind.text
          ? 'text'
          : (item.isVideo ? 'video' : 'image'),
    });
  }

  /// People who viewed my story, with their reactions and any pending
  /// request (same as the phone's viewers list).
  Future<List<StoryViewer>> viewers(String statusId) async {
    final rows = await _sb
        .from('status_views')
        .select('viewer_id, viewed_at, profiles(full_name, avatar_url)')
        .eq('status_id', statusId)
        .order('viewed_at', ascending: false);
    final ids = [
      for (final r in rows)
        if (r['viewer_id'] != null) '${r['viewer_id']}',
    ];

    final reacts = <String, Set<String>>{};
    final requests = <String, String>{};
    if (ids.isNotEmpty) {
      try {
        final rr = await _sb
            .from('status_reactions')
            .select('user_id, reaction_type')
            .eq('status_id', statusId)
            .inFilter('user_id', ids);
        for (final r in rr) {
          var t = '${r['reaction_type']}';
          if (t == 'thumbs') t = 'laugh';
          reacts.putIfAbsent('${r['user_id']}', () => {}).add(t);
        }
      } catch (_) {}
      try {
        final nr = await _sb
            .from('notifications')
            .select('id, from_user_id')
            .eq('user_id', _me)
            .eq('status', 'pending')
            .inFilter('type', ['friend_request', 'message_request'])
            .inFilter('from_user_id', ids)
            .order('created_at', ascending: false);
        for (final r in nr) {
          requests.putIfAbsent('${r['from_user_id']}', () => '${r['id']}');
        }
      } catch (_) {}
    }

    return [
      for (final r in rows)
        StoryViewer(
          '${(r['profiles'] as Map?)?['full_name'] ?? 'SchatzApp user'}',
          (r['profiles'] as Map?)?['avatar_url'] as String?,
          DateTime.tryParse('${r['viewed_at'] ?? ''}')?.toLocal(),
          userId: '${r['viewer_id'] ?? ''}',
          reactions: [
            for (final t in reactionTypes)
              if (reacts['${r['viewer_id']}']?.contains(t) ?? false) t,
          ],
          requestId: requests['${r['viewer_id']}'],
        ),
    ];
  }

  /// Accept or decline a pending request (phone's respond_notification).
  Future<void> respondRequest(String notificationId, bool accept) async {
    await _sb.rpc(
      'respond_notification',
      params: {'p_id': notificationId, 'p_accept': accept},
    );
  }

  Future<void> delete(String statusId) async {
    await _sb.from('status_views').delete().eq('status_id', statusId);
    await _sb.from('statuses').delete().eq('id', statusId);
  }

  // -------------------------------------------------------------------------
  // Posting
  // -------------------------------------------------------------------------

  Future<String> _post({
    required String mediaType,
    String? mediaUrl,
    String caption = '',
    String background = '',
    int fontIndex = 0,
    bool comments = true,
  }) async {
    final s = await settings();
    final now = DateTime.now().toUtc();
    final row = await _sb
        .from('statuses')
        .insert({
          'user_id': _me,
          'media_url': mediaUrl,
          'media_type': mediaType,
          'caption': caption.isEmpty ? null : caption,
          'background_color': background.isEmpty ? null : background,
          'text_font_index': fontIndex,
          'created_at': now.toIso8601String(),
          'expires_at': now
              .add(Duration(hours: s.durationHours > 0 ? s.durationHours : 24))
              .toIso8601String(),
        })
        .select('id')
        .single();
    final id = '${row['id']}';
    if (!comments) {
      try {
        await _sb
            .from('statuses')
            .update({'comments_enabled': false})
            .eq('id', id);
      } catch (_) {}
    }
    return id;
  }

  Future<void> postText(
    String text,
    List<Color> gradient, {
    int fontIndex = 0,
    bool comments = true,
  }) => _post(
    mediaType: 'text',
    caption: text,
    background: hexOf(gradient),
    fontIndex: fontIndex,
    comments: comments,
  );

  /// Photo or video, stored under status_media/ like the phone.
  Future<void> postMedia(
    PickedFile f, {
    String caption = '',
    bool comments = true,
  }) async {
    final bucket = _sb.storage.from('chat-media');
    final base = 'status_media/${DateTime.now().millisecondsSinceEpoch}_0';
    String url;
    if (f.isVideo) {
      final ext = f.mime.contains('webm')
          ? 'webm'
          : (f.mime.contains('quicktime') ? 'mov' : 'mp4');
      await bucket.uploadBinary(
        '$base.$ext',
        f.bytes,
        fileOptions: FileOptions(upsert: true, contentType: f.mime),
      );
      url = bucket.getPublicUrl('$base.$ext');
      final thumb = await videoThumbnail(f.bytes, f.mime);
      if (thumb != null) {
        try {
          await bucket.uploadBinary(
            '${base}_thumb.jpg',
            thumb,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
        } catch (_) {}
      }
    } else {
      final Uint8List small = await resizeImage(f.bytes, f.mime);
      await bucket.uploadBinary(
        '$base.jpg',
        small,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      url = bucket.getPublicUrl('$base.jpg');
    }
    await _post(
      mediaType: f.isVideo ? 'video' : 'image',
      mediaUrl: url,
      caption: caption,
      comments: comments,
    );
  }

  // -------------------------------------------------------------------------
  // Settings
  // -------------------------------------------------------------------------

  Future<StorySettings> settings() async {
    final r = await _sb
        .from('story_settings')
        .select()
        .eq('user_id', _me)
        .maybeSingle();
    if (r == null) {
      final s = StorySettings();
      try {
        await _sb.from('story_settings').insert({
          'user_id': _me,
          'duration_hours': s.durationHours,
          'sort_order': s.sortOrder,
          'view_visibility': s.viewVisibility,
          'allow_download': s.allowDownload,
          'allow_replies': s.allowReplies,
          'show_location': s.showLocation,
        });
      } catch (_) {}
      return s;
    }
    return StorySettings(
      durationHours: (r['duration_hours'] as int?) ?? 24,
      sortOrder: '${r['sort_order'] ?? 'time'}',
      viewVisibility: '${r['view_visibility'] ?? 'everyone'}',
      allowDownload: r['allow_download'] != false,
      allowReplies: r['allow_replies'] != false,
      showLocation: r['show_location'] != false,
    );
  }

  Future<void> saveSettings(StorySettings s) async {
    await settings(); // makes sure the row exists
    await _sb
        .from('story_settings')
        .update({
          'duration_hours': s.durationHours,
          'sort_order': s.sortOrder,
          'view_visibility': s.viewVisibility,
          'allow_download': s.allowDownload,
          'allow_replies': s.allowReplies,
          'show_location': s.showLocation,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', _me);
  }

  Future<Set<String>> customViewers() async {
    final r = await _sb
        .from('story_custom_viewers')
        .select('viewer_id')
        .eq('owner_id', _me);
    return r.map((x) => '${x['viewer_id']}').toSet();
  }

  Future<void> setCustomViewers(Set<String> ids) async {
    await _sb.from('story_custom_viewers').delete().eq('owner_id', _me);
    if (ids.isEmpty) return;
    await _sb.from('story_custom_viewers').insert([
      for (final id in ids) {'owner_id': _me, 'viewer_id': id},
    ]);
  }
}

/// The reaction is older than 3 seconds, so it can't be removed.
class ReactionLockedException implements Exception {
  const ReactionLockedException();
  static const message = "Reactions can't be changed after 3 seconds";
  @override
  String toString() => message;
}

/// The user already has 2 reactions on this post.
class ReactionLimitException implements Exception {
  const ReactionLimitException();
  static const message = 'You can pick up to 2 reactions on a post';
  @override
  String toString() => message;
}
