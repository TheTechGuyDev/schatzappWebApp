import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../platform/call_bridge.dart';
import '../demo_data.dart';

enum CallPhase { idle, incoming, dialing, connecting, connected }

/// A person (Agora user) in the call.
class CallPeer {
  const CallPeer(this.uid, {this.hasVideo = false});

  final int uid;
  final bool hasVideo;
}

/// Voice and video calls with the same rows, RPCs and Agora channel rules as
/// the phone (start_call, accept_call, decline_call, end_call, heartbeat).
/// The phone and the web ring together; whichever answers takes the call.
class CallService extends ChangeNotifier {
  CallService._();
  static final CallService instance = CallService._();

  /// Same Agora project as the phone (an App ID is public; the certificate
  /// stays in the agora-token Edge Function).
  static const _appId = 'a7f7c3f7f8f6427a96f33e4808423324';
  static const _dialTimeout = Duration(seconds: 40);

  SupabaseClient get _sb => Supabase.instance.client;
  String? get _me => _sb.auth.currentUser?.id;

  CallPhase phase = CallPhase.idle;
  String? callId;
  String? conversationId;
  String? channel;
  bool isVideo = false;
  bool isGroup = false;
  String peerName = '';
  String? peerAvatar;

  /// The other phone confirmed it is ringing ("Calling" becomes "Ringing").
  bool ringing = false;
  DateTime? connectedAt;
  bool micOn = true;
  bool cameraOn = false;
  bool sharing = false;
  List<CallPeer> peers = [];

  /// Short messages for the call screen (errors, notices).
  final notice = ValueNotifier<String?>(null);

  Map<String, dynamic>? _incoming;
  StreamSubscription? _incomingSub;
  Timer? _poll;
  Timer? _beat;
  DateTime? _dialStart;
  int? _uid;
  bool _started = false;
  bool _ending = false;

  bool get active => phase != CallPhase.idle && phase != CallPhase.incoming;
  bool get hasIncoming => phase == CallPhase.incoming;

  // -------------------------------------------------------------------------
  // Listening for calls
  // -------------------------------------------------------------------------

  void start() {
    final me = _me;
    if (_started || me == null) return;
    _started = true;
    CallBridge.listen(_onBridge);
    _incomingSub = _sb
        .from('active_incoming_calls')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', me)
        .listen(_onIncomingRows, onError: (_) {});
  }

  Future<void> stop() async {
    if (active) await hangUp();
    _incomingSub?.cancel();
    _incomingSub = null;
    _started = false;
    _reset();
  }

  void _onIncomingRows(List<Map<String, dynamic>> rows) async {
    final c = rows.isNotEmpty ? rows.first : null;
    final ringingRow =
        c != null &&
        '${c['call_id'] ?? ''}'.isNotEmpty &&
        c['status'] == 'ringing' &&
        c['call_type'] != 'bimp';

    if (!ringingRow) {
      // Answered on the phone, declined, or the caller hung up.
      if (phase == CallPhase.incoming) {
        CallBridge.tone('stop');
        _reset();
      }
      return;
    }
    if (active) return; // already in a call: the phone keeps ringing
    if (phase == CallPhase.incoming && callId == '${c['call_id']}') return;

    _incoming = c;
    callId = '${c['call_id']}';
    conversationId = c['conversation_id'] as String?;
    channel = c['agora_channel_name'] as String?;
    isVideo = c['call_type'] == 'video';
    peerName = (c['caller_name'] as String?) ?? 'SchatzApp user';
    peerAvatar = c['caller_avatar'] as String?;
    phase = CallPhase.incoming;
    notifyListeners();
    CallBridge.tone('ring');

    // Show the name this user saved, like the phone does.
    final callerId = c['caller_id'] as String?;
    if (callerId != null) {
      try {
        final r = await _sb
            .from('contacts')
            .select('saved_name')
            .eq('owner_id', _me!)
            .eq('contact_user_id', callerId)
            .limit(1);
        final n = (r as List).isEmpty
            ? ''
            : '${r.first['saved_name'] ?? ''}'.trim();
        if (n.isNotEmpty && phase == CallPhase.incoming) {
          peerName = n;
          notifyListeners();
        }
      } catch (_) {}
    }
    try {
      await _sb.rpc('ack_call_ringing', params: {'p_call_id': callId});
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Outgoing
  // -------------------------------------------------------------------------

  /// Starts a call from a chat. Returns an error message, or null.
  Future<String?> call(DemoChat chat, {required bool video}) async {
    final me = _me;
    if (me == null) return 'Sign in to make calls.';
    if (active || phase == CallPhase.incoming) {
      return 'You are already in a call.';
    }
    final type = video ? 'video' : 'voice';
    try {
      final locked = await _sb
          .from('conversation_participants')
          .select('user_id')
          .eq('conversation_id', chat.id)
          .eq('private_lock', true)
          .isFilter('left_at', null)
          .limit(1);
      if ((locked as List).isNotEmpty) {
        return 'Calls are disabled in a Private Chat Lock chat';
      }

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final ch = 'call_${DateTime.now().millisecondsSinceEpoch}';
      final uid = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      final convo = await _sb
          .from('conversations')
          .select('type')
          .eq('id', chat.id)
          .maybeSingle();
      final group = '${convo?['type'] ?? ''}' == 'group';

      final parts = await _sb
          .from('conversation_participants')
          .select('user_id')
          .eq('conversation_id', chat.id)
          .neq('user_id', me);
      final callees = (parts as List)
          .map((r) => '${r['user_id']}')
          .toSet()
          .toList();
      if (callees.isEmpty) return 'There is no one to call in this chat.';

      final profile = await _sb
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', me)
          .single();

      final row = await _sb
          .from('calls')
          .insert({
            'conversation_id': chat.id,
            'caller_id': me,
            'callee_id': group ? null : callees.first,
            'is_group': group,
            'invited_user_ids': group ? callees : <String>[],
            'caller_name': profile['full_name'],
            'caller_avatar': profile['avatar_url'],
            'call_type': type,
            'status': 'ringing',
            'started_at': nowIso,
          })
          .select('id')
          .single();
      final id = '${row['id']}';

      await _sb.from('call_participants').insert({
        'call_id': id,
        'user_id': me,
        'joined_at': nowIso,
        'agora_uid': uid,
        'status': 'joined',
      });

      await _sb.from('active_incoming_calls').upsert([
        for (final u in callees)
          {
            'user_id': u,
            'call_id': id,
            'conversation_id': chat.id,
            'caller_id': me,
            'caller_name': profile['full_name'],
            'caller_avatar': profile['avatar_url'],
            'call_type': type,
            'status': 'ringing',
            'agora_channel_name': ch,
            'updated_at': nowIso,
          },
      ]);

      callId = id;
      conversationId = chat.id;
      channel = ch;
      isVideo = video;
      isGroup = group;
      peerName = chat.name;
      peerAvatar = chat.avatarUrl;
      ringing = false;
      _uid = uid;
      cameraOn = video;
      micOn = true;
      phase = CallPhase.dialing;
      _dialStart = DateTime.now();
      notifyListeners();
      CallBridge.tone('ringback');
      // Watch the call row from now on (answered, declined, ringing).
      _startTimers();

      final token = await _token(ch, uid);
      if (token == null) {
        await hangUp();
        return 'Could not start the call. Try again.';
      }
      final err = await CallBridge.join(
        appId: _appId,
        channel: ch,
        token: token,
        uid: uid,
        video: video,
      );
      if (err != null) {
        await hangUp();
        return err;
      }
      return null;
    } catch (_) {
      if (callId != null) await hangUp();
      _reset();
      return 'Could not start the call. Try again.';
    }
  }

  // -------------------------------------------------------------------------
  // Incoming
  // -------------------------------------------------------------------------

  Future<String?> accept() async {
    final c = _incoming;
    final me = _me;
    if (c == null || me == null || phase != CallPhase.incoming) return null;
    CallBridge.tone('stop');
    final id = callId!;
    final ch = channel;
    if (ch == null) {
      _reset();
      return "Couldn't accept the call, please try again";
    }
    phase = CallPhase.connecting;
    micOn = true;
    cameraOn = isVideo;
    notifyListeners();
    try {
      final existing = await _sb
          .from('call_participants')
          .select('id')
          .eq('call_id', id)
          .eq('user_id', me)
          .limit(1)
          .maybeSingle();
      if (existing == null) {
        await _sb.from('call_participants').insert({
          'call_id': id,
          'user_id': me,
          'joined_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      await _sb.from('calls').update({'status': 'answered'}).eq('id', id);
      _startTimers();

      final info = await _sb
          .from('calls')
          .select('is_group')
          .eq('id', id)
          .maybeSingle();
      isGroup = info?['is_group'] == true;

      final uid = DateTime.now().microsecondsSinceEpoch.remainder(1000000000);
      final token = await _token(ch, uid);
      if (token == null) throw Exception('token');
      _uid = uid;
      final err = await CallBridge.join(
        appId: _appId,
        channel: ch,
        token: token,
        uid: uid,
        video: isVideo,
      );
      await _sb.from('active_incoming_calls').delete().eq('call_id', id);
      if (err != null) {
        await hangUp();
        return err;
      }
      if (phase == CallPhase.connecting) {
        phase = CallPhase.connected;
        connectedAt = DateTime.now();
      }
      notifyListeners();
      return null;
    } catch (_) {
      _reset();
      return "Couldn't accept the call, please try again";
    }
  }

  Future<void> decline() async {
    final id = callId;
    final me = _me;
    CallBridge.tone('stop');
    _reset();
    if (id == null || me == null) return;
    try {
      final info = await _sb
          .from('calls')
          .select('is_group')
          .eq('id', id)
          .maybeSingle();
      if (info?['is_group'] == true) {
        // Group: only this person's ring goes away.
        await _sb
            .from('active_incoming_calls')
            .delete()
            .eq('call_id', id)
            .eq('user_id', me);
        return;
      }
      final rows = await _sb
          .from('calls')
          .update({'status': 'declined'})
          .eq('id', id)
          .select();
      if ((rows as List).isNotEmpty) {
        final r = rows.first;
        if (r['conversation_id'] != null && r['caller_id'] != null) {
          try {
            await _sb.from('messages').insert({
              'conversation_id': r['conversation_id'],
              'sender_id': r['caller_id'],
              'message_type': 'call',
              'content': '${r['call_type'] ?? 'voice'}:declined',
            });
          } catch (_) {}
        }
      }
      await _sb.from('active_incoming_calls').delete().eq('call_id', id);
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Ending
  // -------------------------------------------------------------------------

  /// Same as the phone's endCall: logs the call message once, leaves only
  /// when others are still in a group call.
  Future<void> hangUp() async {
    if (_ending) return;
    _ending = true;
    final id = callId;
    final me = _me;
    CallBridge.tone('stop');
    try {
      if (id != null && me != null) {
        final now = DateTime.now().toUtc();
        final row = await _sb
            .from('calls')
            .select(
              'started_at, status, conversation_id, caller_id, call_type, is_group',
            )
            .eq('id', id)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));

        var othersStay = false;
        if (row != null && row['is_group'] == true) {
          await _sb
              .from('call_participants')
              .update({'left_at': now.toIso8601String(), 'status': 'left'})
              .eq('call_id', id)
              .eq('user_id', me);
          final others = await _sb
              .from('call_participants')
              .select('user_id')
              .eq('call_id', id)
              .neq('user_id', me)
              .not('joined_at', 'is', null)
              .filter('left_at', 'is', null);
          othersStay = (others as List).isNotEmpty;
        }

        if (row != null && !othersStay) {
          final prior = '${row['status'] ?? ''}';
          if (prior != 'declined' && prior != 'ended' && prior != 'missed') {
            final answered = prior == 'answered';
            int? secs;
            if (answered && row['started_at'] != null) {
              secs = now
                  .difference(DateTime.parse('${row['started_at']}'))
                  .inSeconds;
              if (secs < 0) secs = 0;
            }
            await _sb
                .from('calls')
                .update({
                  'status': answered ? 'ended' : 'missed',
                  'ended_at': now.toIso8601String(),
                  'duration_seconds': ?secs,
                })
                .eq('id', id);
            if (row['conversation_id'] != null && row['caller_id'] != null) {
              try {
                await _sb.from('messages').insert({
                  'conversation_id': row['conversation_id'],
                  'sender_id': row['caller_id'],
                  'message_type': 'call',
                  'content':
                      '${row['call_type'] ?? 'voice'}:${answered ? 'answered' : 'missed'}',
                  'duration_seconds': ?secs,
                });
              } catch (_) {}
            }
          }
          try {
            await _sb.from('active_incoming_calls').delete().eq('call_id', id);
          } catch (_) {}
        }
      }
    } catch (_) {}
    await CallBridge.leave();
    _reset();
    _ending = false;
  }

  // -------------------------------------------------------------------------
  // Controls
  // -------------------------------------------------------------------------

  void toggleMic() {
    micOn = !micOn;
    CallBridge.setMic(micOn);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    final to = !cameraOn;
    final err = await CallBridge.setCamera(to);
    if (err != null) {
      notice.value = err;
      return;
    }
    cameraOn = to;
    notifyListeners();
  }

  Future<void> toggleScreen() async {
    if (sharing) {
      await CallBridge.stopScreen();
      sharing = false;
      notifyListeners();
      return;
    }
    final err = await CallBridge.startScreen();
    if (err == 'cancelled') return;
    if (err != null) {
      notice.value = err;
      return;
    }
    sharing = true;
    notifyListeners();
  }

  // -------------------------------------------------------------------------

  Future<String?> _token(String ch, int uid) async {
    try {
      final r = await _sb.functions.invoke(
        'agora-token',
        body: {'channelName': ch, 'uid': uid},
      );
      final data = r.data;
      if (data is Map && data['token'] is String) {
        return data['token'] as String;
      }
    } catch (_) {}
    return null;
  }

  void _startTimers() {
    _poll?.cancel();
    _beat?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _check());
    _beat = Timer.periodic(const Duration(seconds: 20), (_) => _heartbeat());
    _heartbeat();
  }

  int _tick = 0;

  Future<void> _check() async {
    final id = callId;
    if (id == null || _ending) return;
    // Connected calls are checked every 2 seconds, dialing every second.
    if (phase == CallPhase.connected && (_tick++ % 2 != 0)) return;
    try {
      final row = await _sb
          .from('calls')
          .select('status, ringing_at')
          .eq('id', id)
          .maybeSingle();
      if (callId != id) return;
      final s = '${row?['status'] ?? ''}';
      if (phase == CallPhase.dialing || phase == CallPhase.connecting) {
        if (row?['ringing_at'] != null && !ringing) {
          ringing = true;
          notifyListeners();
        }
        if (s == 'answered' && phase == CallPhase.dialing) {
          _markConnected();
        } else if (phase == CallPhase.dialing &&
            s == 'ringing' &&
            _dialStart != null &&
            DateTime.now().difference(_dialStart!) >= _dialTimeout) {
          notice.value = 'No answer';
          await hangUp();
          return;
        }
      }
      var removed = false;
      final me = _me;
      if (me != null && s != 'ended' && s != 'missed' && s != 'declined') {
        final part = await _sb
            .from('call_participants')
            .select('status')
            .eq('call_id', id)
            .eq('user_id', me)
            .maybeSingle();
        removed = '${part?['status'] ?? ''}' == 'removed';
      }
      if (removed || s == 'ended' || s == 'missed' || s == 'declined') {
        if (s == 'declined') notice.value = 'Call declined';
        if (removed) notice.value = 'You were removed from the call';
        CallBridge.tone('stop');
        await CallBridge.leave();
        _reset();
      }
    } catch (_) {}
  }

  Future<void> _heartbeat() async {
    final id = callId;
    if (id == null) return;
    try {
      if (_uid != null && channel != null) {
        await _sb.rpc(
          'call_report_agora',
          params: {'p_call_id': id, 'p_uid': _uid, 'p_channel': channel},
        );
      }
    } catch (_) {}
    try {
      final r = await _sb.rpc('call_heartbeat', params: {'p_call_id': id});
      final st = r is Map ? '${r['status']}' : '';
      if (st == 'ended' || st == 'missed' || st == 'declined') {
        await CallBridge.leave();
        _reset();
      }
    } catch (_) {}
  }

  void _onBridge(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'remotes':
        peers = [
          for (final p in (e['list'] as List? ?? const []))
            CallPeer(
              (p['uid'] as num).toInt(),
              hasVideo: p['hasVideo'] == true,
            ),
        ];
        // Someone is in the channel with us: the call is connected.
        if (peers.isNotEmpty && phase == CallPhase.dialing) {
          _markConnected();
        } else {
          notifyListeners();
        }
      case 'joined':
        cameraOn = e['camera'] == true;
        notifyListeners();
      case 'notice':
        notice.value = '${e['text']}';
      case 'screen-ended':
        sharing = false;
        notifyListeners();
      case 'connection':
        final s = '${e['state']}';
        if (s == 'RECONNECTING') notice.value = 'Reconnecting...';
    }
  }

  void _markConnected() {
    CallBridge.tone('stop');
    phase = CallPhase.connected;
    connectedAt ??= DateTime.now();
    notifyListeners();
  }

  void _reset() {
    _poll?.cancel();
    _beat?.cancel();
    _poll = null;
    _beat = null;
    phase = CallPhase.idle;
    callId = null;
    conversationId = null;
    channel = null;
    _incoming = null;
    _uid = null;
    _dialStart = null;
    ringing = false;
    connectedAt = null;
    sharing = false;
    cameraOn = false;
    micOn = true;
    peers = [];
    notifyListeners();
  }
}

/// The call log, built like the phone's Calls tab (calls the user made,
/// received, was invited to or joined).
Future<List<DemoCall>> loadCallLog() async {
  final sb = Supabase.instance.client;
  final me = sb.auth.currentUser!.id;

  final joined = <String>{};
  try {
    final rows = await sb
        .from('call_participants')
        .select('call_id')
        .eq('user_id', me)
        .not('joined_at', 'is', null)
        .order('joined_at', ascending: false)
        .limit(100);
    for (final r in rows) {
      joined.add('${r['call_id']}');
    }
  } catch (_) {}

  final calls = await sb
      .from('calls')
      .select()
      .or(
        [
          'caller_id.eq.$me',
          'callee_id.eq.$me',
          'invited_user_ids.cs.{$me}',
          if (joined.isNotEmpty) 'id.in.(${joined.join(',')})',
        ].join(','),
      )
      .order('started_at', ascending: false)
      .limit(50);

  final saved = <String, String>{};
  try {
    final c = await sb
        .from('contacts')
        .select('contact_user_id, saved_name')
        .eq('owner_id', me)
        .not('contact_user_id', 'is', null);
    for (final r in c) {
      final n = '${r['saved_name'] ?? ''}'.trim();
      if (n.isNotEmpty) saved['${r['contact_user_id']}'] = n;
    }
  } catch (_) {}

  final others = <String>{};
  final convIds = <String>{};
  final groupIds = <String>[];
  for (final r in calls) {
    final other = r['caller_id'] == me ? r['callee_id'] : r['caller_id'];
    if (other is String && other.isNotEmpty) others.add(other);
    if (r['is_group'] == true) {
      groupIds.add('${r['id']}');
      if (r['conversation_id'] is String) convIds.add(r['conversation_id']);
    }
  }

  final profiles = <String, Map<String, dynamic>>{};
  if (others.isNotEmpty) {
    try {
      final pr = await sb
          .from('profiles_public')
          .select('id, full_name, avatar_url')
          .inFilter('id', others.toList());
      for (final p in pr) {
        profiles['${p['id']}'] = Map<String, dynamic>.from(p);
      }
    } catch (_) {
      try {
        final pr = await sb
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', others.toList());
        for (final p in pr) {
          profiles['${p['id']}'] = Map<String, dynamic>.from(p);
        }
      } catch (_) {}
    }
  }

  final joinedCount = <String, int>{};
  final groups = <String, Map<String, dynamic>>{};
  try {
    if (groupIds.isNotEmpty) {
      final gp = await sb
          .from('call_participants')
          .select('call_id')
          .inFilter('call_id', groupIds)
          .not('joined_at', 'is', null);
      for (final p in gp) {
        final k = '${p['call_id']}';
        joinedCount[k] = (joinedCount[k] ?? 0) + 1;
      }
    }
    if (convIds.isNotEmpty) {
      final cr = await sb
          .from('conversations')
          .select('id, name, avatar_url')
          .inFilter('id', convIds.toList());
      for (final c in cr) {
        groups['${c['id']}'] = Map<String, dynamic>.from(c);
      }
    }
  } catch (_) {}

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final out = <DemoCall>[];
  for (final r in calls) {
    final id = '${r['id']}';
    final group = r['is_group'] == true;
    final outgoing = r['caller_id'] == me;
    final otherId = group
        ? ''
        : '${(outgoing ? r['callee_id'] : r['caller_id']) ?? ''}';
    final dur = r['duration_seconds'] as int?;
    final status = '${r['status'] ?? ''}';
    final answered = dur != null && dur > 0;
    final inProgress = status == 'ringing' || status == 'answered';
    CallDirection dir;
    if (status == 'declined') {
      dir = CallDirection.declined;
    } else if (answered || inProgress) {
      dir = outgoing ? CallDirection.outgoing : CallDirection.incoming;
    } else if (group && !outgoing && joined.contains(id)) {
      dir = CallDirection.incoming;
    } else {
      dir = outgoing ? CallDirection.cancelled : CallDirection.missed;
    }

    String name;
    String? avatar;
    if (group) {
      final g = groups['${r['conversation_id']}'];
      name = '${g?['name'] ?? ''}'.trim().isEmpty
          ? 'Group call'
          : '${g!['name']}'.trim();
      avatar = g?['avatar_url'] as String?;
    } else {
      final p = profiles[otherId];
      name =
          saved[otherId] ??
          ('${p?['full_name'] ?? ''}'.trim().isNotEmpty
              ? '${p!['full_name']}'.trim()
              : '${r['caller_name'] ?? 'SchatzApp user'}');
      avatar =
          (p?['avatar_url'] as String?) ??
          (outgoing ? null : r['caller_avatar'] as String?);
    }

    final at = DateTime.tryParse('${r['started_at'] ?? ''}')?.toLocal();
    String? durText;
    if (dur != null && dur > 0) {
      final m = dur ~/ 60;
      final s = dur % 60;
      durText = m > 0 ? '${m}m ${s}s' : '${s}s';
    }
    final h = at == null ? 0 : (at.hour % 12 == 0 ? 12 : at.hour % 12);
    out.add(
      DemoCall(
        id: id,
        name: name,
        direction: dir,
        date: at == null ? '' : '${at.day} ${months[at.month - 1]}',
        time: at == null
            ? ''
            : '$h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'}',
        duration: durText,
        isVideo: r['call_type'] == 'video',
        isOnline: false,
        avatarColor: null,
        avatarUrl: avatar,
        conversationId: r['conversation_id'] as String?,
        otherUserId: otherId.isEmpty ? null : otherId,
        isGroup: group,
        joinedCount: joinedCount[id] ?? 0,
        live: true,
      ),
    );
  }
  return out;
}
