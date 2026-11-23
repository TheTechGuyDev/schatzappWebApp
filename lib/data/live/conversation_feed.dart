import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../platform/web_files.dart';
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
  final Map<String, String> _myReactions = {};
  Set<String> _stars = {};
  StreamSubscription? _starSub;
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

    _starSub = _sb
        .from('message_stars')
        .stream(primaryKey: ['user_id', 'message_id'])
        .eq('user_id', _me)
        .listen((rows) {
          _stars = rows.map((r) => '${r['message_id']}').toSet();
          _emit();
        }, onError: (_) {});

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
          .select('message_id, emoji, user_id')
          .inFilter(
            'message_id',
            ids.length > 300 ? ids.sublist(ids.length - 300) : ids,
          );
      _reactions.clear();
      _myReactions.clear();
      for (final r in rows) {
        (_reactions[r['message_id'] as String] ??= []).add('${r['emoji']}');
        if (r['user_id'] == _me) {
          _myReactions[r['message_id'] as String] = '${r['emoji']}';
        }
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
          senderId: r['sender_id'] as String?,
          isStarred: _stars.contains('${r['id']}'),
          isPinned: r['is_pinned'] == true,
          myReaction: _myReactions['${r['id']}'],
          replyToId: r['reply_to_message_id'] as String?,
          replyLabel: r['reply_to_content'] == null ? null : _replyLabel(r),
          raw: r,
        ),
      );
    }
    out.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    messages = out;
    loaded = true;
    _notify();
  }

  String _replyLabel(Map<String, dynamic> r) {
    final own = r['reply_to_is_own'] == true;
    final mine = r['sender_id'] == _me;
    // reply_to_is_own: the quoted message belongs to the person replying.
    if (own == mine) return 'You';
    if (!isGroup) return _otherName ?? 'Them';
    final quotedId = _raw
        .where((m) => m['id'] == r['reply_to_message_id'])
        .map((m) => m['sender_id'] as String?)
        .firstOrNull;
    if (quotedId == _me) return 'You';
    return _names[quotedId] ?? 'Member';
  }

  /// Name of the other person in a direct chat (for reply labels).
  String? _otherName;
  set otherName(String? v) => _otherName = v;

  /// Sends a text message (same row shape as the mobile app).
  Future<void> sendText(String text, {DemoMessage? replyTo}) async {
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
      if (replyTo != null && replyTo.id.isNotEmpty) ...{
        'reply_to_message_id': replyTo.id,
        'reply_to_content': replyPreview(replyTo),
        'reply_to_is_own': replyTo.isMine,
      },
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

  // ---------------------------------------------------------------------
  // Message actions (same rules and rows as the phone)
  // ---------------------------------------------------------------------

  /// React, change the reaction, or remove it when the same emoji is tapped.
  Future<void> react(DemoMessage m, String emoji) async {
    if (m.id.isEmpty || m.pending) return;
    if (m.myReaction == emoji) {
      await _sb
          .from('message_reactions')
          .delete()
          .eq('message_id', m.id)
          .eq('user_id', _me);
    } else {
      await _sb.from('message_reactions').upsert({
        'message_id': m.id,
        'user_id': _me,
        'emoji': emoji,
      }, onConflict: 'message_id,user_id');
    }
    await _loadReactions();
    _emit();
  }

  Future<void> toggleStar(DemoMessage m) async {
    if (m.isStarred) {
      await _sb
          .from('message_stars')
          .delete()
          .eq('user_id', _me)
          .eq('message_id', m.id);
      _stars.remove(m.id);
    } else {
      await _sb.from('message_stars').upsert({
        'user_id': _me,
        'message_id': m.id,
      });
      _stars.add(m.id);
    }
    _emit();
  }

  static const maxPins = 4;

  /// Returns an error message, or null when done.
  Future<String?> setPinned(DemoMessage m, bool pin) async {
    if (pin) {
      final pinned = _raw.where((r) => r['is_pinned'] == true).length;
      if (pinned >= maxPins) return 'You can only pin up to $maxPins messages';
    }
    await _sb.rpc(
      'set_messages_pinned',
      params: {
        'p_ids': [m.id],
        'p_pin': pin,
      },
    );
    return null;
  }

  /// Same edit window as the phone: 30 minutes, or 8 once someone replied.
  bool canEdit(DemoMessage m) {
    if (!m.isMine || m.kind != MessageKind.text || m.createdAt == null) {
      return false;
    }
    final created = m.createdAt!;
    final replied = _raw.any(
      (r) =>
          r['sender_id'] != _me &&
          (DateTime.tryParse('${r['created_at']}')?.isAfter(created.toUtc()) ??
              false),
    );
    final limit = Duration(minutes: replied ? 8 : 30);
    return DateTime.now().difference(created) <= limit;
  }

  Future<void> edit(DemoMessage m, String text) async {
    final content = text.trim();
    if (content.isEmpty || content == m.text) return;
    await _sb
        .from('messages')
        .update({'content': content, 'is_edited': true})
        .eq('id', m.id);
  }

  /// Why "Delete for everyone" is not allowed, or null when it is.
  /// The database enforces the same rules.
  String? deleteBlockReason(DemoMessage m) {
    if (!m.isMine) return 'Only your own messages can be deleted for everyone.';
    final seen = DateTime.tryParse('${m.raw['seen_at'] ?? ''}');
    if (seen == null) return null;
    if (DateTime.now().toUtc().difference(seen.toUtc()) >
        const Duration(minutes: 5)) {
      return 'Seen more than 5 minutes ago, so it can only be deleted for you.';
    }
    final created = m.createdAt!.toUtc();
    final window = _raw.where((r) {
      final at = DateTime.tryParse('${r['created_at']}')?.toUtc();
      return at != null &&
          at.isAfter(created.subtract(const Duration(minutes: 5))) &&
          !at.isAfter(created);
    }).toList();
    final senders = window.map((r) => r['sender_id']).toSet();
    if (window.length > 7 && senders.length > 1) {
      return 'Too many messages exchanged in 5 minutes, so it can only be '
          'deleted for you.';
    }
    return null;
  }

  Future<void> deleteForEveryone(DemoMessage m) async {
    await _sb.from('messages').update({'is_deleted': true}).eq('id', m.id);
  }

  Future<void> deleteForMe(DemoMessage m) async {
    final current = List<String>.from(
      ((m.raw['deleted_for_user_ids'] as List?) ?? const []).map((e) => '$e'),
    );
    if (current.contains(_me)) return;
    current.add(_me);
    await _sb
        .from('messages')
        .update({'deleted_for_user_ids': current})
        .eq('id', m.id);
  }

  /// Forwards messages unchanged (media included) to chats and people.
  static Future<void> forward(
    List<DemoMessage> messages, {
    List<String> conversationIds = const [],
    List<String> userIds = const [],
  }) async {
    final sb = Supabase.instance.client;
    final me = sb.auth.currentUser!.id;
    final targets = [...conversationIds];
    for (final u in userIds) {
      targets.add(await ChatRepo.instance.directConversationWith(u));
    }
    const keep = [
      'message_type',
      'content',
      'media_url',
      'media_urls',
      'thumbnail_url',
      'media_size_bytes',
      'media_duration_seconds',
      'duration_seconds',
      'media_pages',
    ];
    for (final c in targets.toSet()) {
      for (final m in messages) {
        final row = <String, dynamic>{
          'conversation_id': c,
          'sender_id': me,
          'is_forwarded': true,
        };
        for (final k in keep) {
          final v = m.raw[k];
          if (v != null && !(v is String && v.isEmpty)) row[k] = v;
        }
        row['message_type'] ??= 'text';
        await sb.from('messages').insert(row);
      }
    }
  }

  // ---------------------------------------------------------------------
  // Media (same storage paths and message rows as the phone)
  // ---------------------------------------------------------------------

  /// Uploads still in progress, shown as "Sending..." bubbles.
  final List<String> uploading = [];

  StorageFileApi get _bucket => _sb.storage.from('chat-media');

  Future<String> _put(String path, Uint8List bytes, String mime) async {
    await _bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(upsert: true, contentType: mime),
    );
    return _bucket.getPublicUrl(path);
  }

  Future<T> _withUpload<T>(String label, Future<T> Function() job) async {
    uploading.add(label);
    _notify();
    try {
      return await job();
    } finally {
      uploading.remove(label);
      _notify();
    }
  }

  /// Photos and videos. Several photos become one image_group message,
  /// each video its own message (like the phone). Caption on the first.
  Future<void> sendMedia(List<PickedFile> files, String caption) async {
    final photos = files.where((f) => f.isImage).toList();
    final videos = files.where((f) => f.isVideo).toList();
    final label = files.length == 1
        ? (videos.isEmpty ? 'Sending photo...' : 'Sending video...')
        : 'Sending ${files.length} files...';
    await _withUpload(label, () async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      var captionUsed = false;
      String? takeCaption() {
        if (captionUsed || caption.trim().isEmpty) return null;
        captionUsed = true;
        return caption.trim();
      }

      for (var i = 0; i < videos.length; i++) {
        final v = videos[i];
        final ext = v.mime.contains('quicktime')
            ? 'mov'
            : (v.mime.contains('webm') ? 'webm' : 'mp4');
        final url = await _put('chat_media/${stamp}_v$i.$ext', v.bytes, v.mime);
        String? thumb;
        final t = await videoThumbnail(v.bytes, v.mime);
        if (t != null) {
          thumb = await _put(
            'chat_media/${stamp}_v${i}_thumb.jpg',
            t,
            'image/jpeg',
          );
        }
        await _sb.from('messages').insert({
          'conversation_id': conversationId,
          'sender_id': _me,
          'message_type': 'video',
          'media_url': url,
          'thumbnail_url': thumb,
          'media_size_bytes': v.bytes.length,
          'duration_seconds': await mediaDuration(v.bytes, v.mime),
          'content': takeCaption(),
        });
      }

      final urls = <String>[];
      final thumbs = <String?>[];
      for (var i = 0; i < photos.length; i++) {
        final p = photos[i];
        final small = await resizeImage(p.bytes, p.mime);
        final isGif = p.mime == 'image/gif';
        final base = 'chat_media/${stamp}_$i';
        final url = await _put(
          isGif ? '$base.gif' : '$base.jpg',
          small,
          isGif ? 'image/gif' : 'image/jpeg',
        );
        urls.add(url);
        String? thumb;
        if (!isGif) {
          try {
            final t = await resizeImage(
              small,
              'image/jpeg',
              maxDim: 480,
              quality: 0.7,
            );
            thumb = await _put('${base}_thumb.jpg', t, 'image/jpeg');
          } catch (_) {}
        }
        thumbs.add(thumb);
      }
      if (urls.length == 1) {
        await _sb.from('messages').insert({
          'conversation_id': conversationId,
          'sender_id': _me,
          'message_type': 'image',
          'media_url': urls.first,
          'thumbnail_url': thumbs.first,
          'content': takeCaption(),
        });
      } else if (urls.length > 1) {
        await _sb.from('messages').insert({
          'conversation_id': conversationId,
          'sender_id': _me,
          'message_type': 'image_group',
          'media_url': urls.first,
          'media_urls': urls,
          'content': takeCaption(),
        });
      }
    });
  }

  /// Any file sent as a document (stored under documents/ like the phone).
  Future<void> sendDocument(PickedFile f) async {
    await _withUpload('Sending ${f.name}...', () async {
      final safe = f.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final url = await _put(
        'documents/${DateTime.now().millisecondsSinceEpoch}_$safe',
        f.bytes,
        f.mime,
      );
      await _sb.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': _me,
        'message_type': 'document',
        'content': f.name,
        'media_url': url,
        'media_size_bytes': f.bytes.length,
      });
    });
  }

  /// Voice note (recorded or an audio file), stored under voice_notes/.
  Future<void> sendVoice(
    Uint8List bytes,
    String mime,
    String ext,
    int? seconds,
  ) async {
    await _withUpload('Sending voice note...', () async {
      final url = await _put(
        'voice_notes/${DateTime.now().millisecondsSinceEpoch}.$ext',
        bytes,
        mime,
      );
      await _sb.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': _me,
        'message_type': 'voice_note',
        'media_url': url,
        'duration_seconds': seconds ?? await mediaDuration(bytes, mime),
      });
    });
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
    _starSub?.cancel();
    _typingChannel?.unsubscribe();
    _metaChannel?.unsubscribe();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _typingOff?.cancel();
    super.dispose();
  }
}

/// Short text used when quoting a message in a reply.
String replyPreview(DemoMessage m) {
  final t = m.text.trim();
  return switch (m.kind) {
    MessageKind.image => t.isEmpty ? 'Photo' : 'Photo: $t',
    MessageKind.video => t.isEmpty ? 'Video' : 'Video: $t',
    MessageKind.voice => 'Voice message',
    MessageKind.document => t.isEmpty ? 'Document' : t,
    MessageKind.gift => 'Gift card',
    _ => t,
  };
}
