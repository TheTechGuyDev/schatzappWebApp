import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/web_auth.dart';
import '../../data/demo_data.dart';
import '../../data/live/call_service.dart';
import '../../data/live/chat_repo.dart';
import '../../shell/app_shell.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/resizable_width.dart';
import '../chats/chat_dialogs.dart';
import 'call_screen.dart';

/// Calls tab (UI image 3). Uses placeholder data until the backend phase.
class CallsPage extends StatefulWidget {
  const CallsPage({super.key});

  static const routePath = '/calls';

  @override
  State<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends State<CallsPage> {
  CallFilter _filter = CallFilter.all;
  String _query = '';
  String? _selectedId = WebAuth.instance.isLive ? null : 'c1';
  final _listWidth = PanelWidth('calls_list_width', 480);

  bool get _live => WebAuth.instance.isLive;
  List<DemoCall> _log = [];
  bool _loading = true;
  String? _error;
  CallPhase _lastPhase = CallPhase.idle;

  List<DemoCall> get _source => _live ? _log : demoCalls;

  @override
  void initState() {
    super.initState();
    if (_live) {
      _load();
      CallService.instance.addListener(_onCallChange);
    }
  }

  @override
  void dispose() {
    CallService.instance.removeListener(_onCallChange);
    super.dispose();
  }

  /// Reload the log when a call ends.
  void _onCallChange() {
    final p = CallService.instance.phase;
    if (p == CallPhase.idle && _lastPhase != CallPhase.idle) {
      Future.delayed(const Duration(seconds: 2), _load);
    }
    _lastPhase = p;
  }

  Future<void> _load() async {
    try {
      final log = await loadCallLog();
      if (!mounted) return;
      setState(() {
        _log = log;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load calls. Check your connection.';
      });
    }
  }

  void _toast(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));

  /// Calls the person or group of a log entry.
  Future<void> _callBack(DemoCall c, bool video) async {
    if (!_live) {
      showCallScreen(context, name: c.name, color: c.avatarColor, video: video);
      return;
    }
    try {
      var conv = c.conversationId;
      if ((conv == null || conv.isEmpty) && c.otherUserId != null) {
        conv = await ChatRepo.instance.directConversationWith(c.otherUserId!);
      }
      if (conv == null) return;
      final err = await CallService.instance.call(
        DemoChat(
          id: conv,
          name: c.name,
          preview: '',
          time: '',
          isGroup: c.isGroup,
          avatarUrl: c.avatarUrl,
          otherUserId: c.otherUserId,
        ),
        video: video,
      );
      if (err != null) _toast(err);
    } catch (_) {
      _toast('Could not start the call, please try again');
    }
  }

  Future<void> _newCall() async {
    final picked = await showDialog<List<DemoContact>>(
      context: context,
      builder: (_) => ContactPickerDialog(
        title: 'New call',
        load: _live ? ChatRepo.instance.normalContacts : null,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final p = picked.first;
    await _callBack(
      DemoCall(
        id: '',
        name: p.name,
        direction: CallDirection.outgoing,
        date: '',
        time: '',
        avatarColor: p.color,
        avatarUrl: p.avatarUrl,
        otherUserId: p.userId,
      ),
      false,
    );
  }

  List<DemoCall> get _visible {
    final q = _query.trim().toLowerCase();
    return _source.where((c) {
      final pass = switch (_filter) {
        CallFilter.all => true,
        CallFilter.missed => c.direction == CallDirection.missed,
        CallFilter.incoming =>
          c.direction == CallDirection.incoming ||
              c.direction == CallDirection.declined ||
              c.direction == CallDirection.missed,
        CallFilter.outgoing =>
          c.direction == CallDirection.outgoing ||
              c.direction == CallDirection.cancelled,
      };
      return pass && (q.isEmpty || c.name.toLowerCase().contains(q));
    }).toList();
  }

  DemoCall? get _selected {
    for (final c in _source) {
      if (c.id == _selectedId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    final list = _CallList(
      calls: _visible,
      filter: _filter,
      selectedId: size == ScreenSize.phone ? null : _selectedId,
      onFilter: (f) => setState(() => _filter = f),
      onSearch: (q) => setState(() => _query = q),
      onOpen: (c) => setState(() => _selectedId = c.id),
      live: _live,
      loading: _live && _loading,
      error: _error,
      onNewCall: _newCall,
    );
    final call = _selected;
    final details = call == null
        ? const Center(
            child: Text(
              'Select a call to see details',
              style: TextStyle(color: AppColors.meta),
            ),
          )
        : _CallDetails(
            call: call,
            onCall: (video) => _callBack(call, video),
            onBack: size == ScreenSize.phone
                ? () => setState(() => _selectedId = null)
                : null,
          );

    if (size == ScreenSize.phone) {
      return Container(
        color: Colors.white,
        child: call == null ? list : details,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
      child: LayoutBuilder(
        builder: (context, c) {
          // Calls list width is dragged by the user; details keep 380px.
          final maxList = (c.maxWidth - 16 - 380).clamp(320.0, 900.0);
          final w = _listWidth.value.clamp(320.0, maxList);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: w,
                child: ShellPanel(color: AppColors.panelBg, child: list),
              ),
              ResizeHandle(
                width: 16,
                onDrag: (dx) => setState(
                  () => _listWidth.set((w + dx).clamp(320.0, maxList)),
                ),
                onDoubleTap: () =>
                    setState(() => _listWidth.set(_listWidth.initial)),
              ),
              Expanded(
                child: ShellPanel(
                  color: const Color(0xFFFAF7FE),
                  child: details,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

class _CallList extends StatelessWidget {
  const _CallList({
    required this.calls,
    required this.filter,
    required this.selectedId,
    required this.onFilter,
    required this.onSearch,
    required this.onOpen,
    required this.onNewCall,
    this.live = false,
    this.loading = false,
    this.error,
  });

  final VoidCallback onNewCall;
  final bool live;
  final bool loading;
  final String? error;
  final List<DemoCall> calls;
  final CallFilter filter;
  final String? selectedId;
  final ValueChanged<CallFilter> onFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<DemoCall> onOpen;

  @override
  Widget build(BuildContext context) {
    void soon(String what) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what is coming soon.')));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 22, 14, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Calls',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading,
                  ),
                ),
              ),
              if (!live)
                PopupMenuButton<int>(
                  tooltip: 'More',
                  position: PopupMenuPosition.under,
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 28,
                    color: AppColors.heading,
                  ),
                  onSelected: (v) {
                    if (v == 0) {
                      showIncomingCall(
                        context,
                        name: 'Mr Kesta Wealth',
                        color: const Color(0xFF8A6A55),
                        video: true,
                      );
                    } else {
                      soon('Clear call log');
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 0,
                      child: Text('Preview incoming call (demo)'),
                    ),
                    PopupMenuItem(value: 1, child: Text('Clear call log')),
                  ],
                ),
              IconButton(
                tooltip: 'New call',
                onPressed: onNewCall,
                icon: const Icon(Icons.add_call, size: 26),
                color: AppColors.heading,
              ),
              if (!live)
                IconButton(
                  tooltip: 'Scheduled calls',
                  onPressed: () => soon('Scheduled calls'),
                  icon: const Icon(Icons.calendar_month_outlined, size: 27),
                  color: AppColors.heading,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          child: SearchField(hint: 'Search recent calls', onChanged: onSearch),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 14, 8),
          child: FilterChips<CallFilter>(
            values: CallFilter.values,
            labels: const ['All', 'Missed', 'Incoming', 'Outgoing'],
            selected: filter,
            onSelected: onFilter,
            filledInactive: true,
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(26, 14, 26, 8),
          child: Text(
            'Recent',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.heading,
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : calls.isEmpty
              ? Center(
                  child: Text(
                    error ?? 'No calls here yet',
                    style: const TextStyle(color: AppColors.meta),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: calls.length,
                  itemBuilder: (_, i) => _CallTile(
                    call: calls[i],
                    selected: calls[i].id == selectedId,
                    onTap: () => onOpen(calls[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

IconData _directionIcon(CallDirection d) => switch (d) {
  CallDirection.incoming => Icons.south_west,
  CallDirection.outgoing => Icons.north_east,
  CallDirection.cancelled => Icons.north_east,
  CallDirection.declined => Icons.call_missed,
  CallDirection.missed => Icons.call_missed,
};

class _CallTile extends StatelessWidget {
  const _CallTile({
    required this.call,
    required this.selected,
    required this.onTap,
  });

  final DemoCall call;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missed = call.direction == CallDirection.missed;
    final metaColor = missed ? AppColors.missed : AppColors.meta;
    final parts = [
      call.label,
      '${call.date}, ${call.time}',
      if (call.duration != null) call.duration!,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? const Color(0xFFEFE2FE) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Avatar(
                  name: call.name,
                  color: call.avatarColor,
                  photoUrl: call.avatarUrl,
                  isGroup: call.isGroup,
                  size: 58,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        call.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: missed ? AppColors.missed : AppColors.heading,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            _directionIcon(call.direction),
                            size: 16,
                            color: metaColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              parts.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, color: metaColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  missed
                      ? Icons.notifications_active_outlined
                      : (call.isVideo
                            ? Icons.videocam_outlined
                            : Icons.call_outlined),
                  color: AppColors.accent,
                  size: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Details
// ---------------------------------------------------------------------------

class _CallDetails extends StatelessWidget {
  const _CallDetails({required this.call, required this.onCall, this.onBack});

  final DemoCall call;
  final ValueChanged<bool> onCall;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    void soon(String what) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what is coming soon.')));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: AppColors.heading),
                ),
              const Spacer(),
              if (!call.live) ...[
                IconButton(
                  tooltip: 'Favourite',
                  onPressed: () => soon('Favourites'),
                  icon: const Icon(Icons.star_border_rounded, size: 30),
                  color: AppColors.heading,
                ),
                IconButton(
                  tooltip: 'More',
                  onPressed: () => soon('Call options'),
                  icon: const Icon(Icons.more_horiz, size: 28),
                  color: AppColors.heading,
                ),
              ] else
                const SizedBox(height: 48),
            ],
          ),
          Avatar(
            name: call.name,
            color: call.avatarColor,
            photoUrl: call.avatarUrl,
            isGroup: call.isGroup,
            size: 128,
            isOnline: call.isOnline,
            onlineDotSize: 26,
          ),
          const SizedBox(height: 22),
          Text(
            call.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.heading,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            call.live
                ? (call.isGroup
                      ? 'Group call · ${call.joinedCount} joined'
                      : (call.isVideo ? 'Video call' : 'Voice call'))
                : (call.isOnline ? 'Online' : 'Last seen recently'),
            style: const TextStyle(fontSize: 18, color: AppColors.body),
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, c) {
              final w = ((c.maxWidth - 28) / 3).clamp(90.0, 122.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    width: w,
                    icon: Icons.videocam_outlined,
                    label: 'Video Call',
                    filled: true,
                    onTap: () => onCall(true),
                  ),
                  const SizedBox(width: 14),
                  _ActionButton(
                    width: w,
                    icon: Icons.call_outlined,
                    label: 'Voice Call',
                    onTap: () => onCall(false),
                  ),
                  const SizedBox(width: 14),
                  _ActionButton(
                    width: w,
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Message',
                    onTap: () => context.go('/chats'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 46),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _CallInfoCard(call: call),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final double width;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : AppColors.accent;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: width,
        height: 92,
        decoration: BoxDecoration(
          color: filled ? null : const Color(0xFFF3ECFE),
          gradient: filled
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFA54BF0), Color(0xFF8A33E6)],
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          border: filled ? null : Border.all(color: const Color(0xFFE6DAFA)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: filled ? 0.28 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: width < 110 ? 15 : 17,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallInfoCard extends StatelessWidget {
  const _CallInfoCard({required this.call});

  final DemoCall call;

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String v, {bool last = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(k, style: const TextStyle(fontSize: 17, color: AppColors.body)),
          const Spacer(),
          Text(
            v,
            style: const TextStyle(fontSize: 17, color: AppColors.heading),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDeep.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF1EEFC),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: const Row(
              children: [
                Icon(Icons.call, color: AppColors.accent, size: 26),
                SizedBox(width: 16),
                Text(
                  'Call Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading,
                  ),
                ),
              ],
            ),
          ),
          row('Type', call.typeLabel),
          row('Date', '${call.date}, ${call.time}'),
          row('Duration', call.duration ?? '-', last: true),
        ],
      ),
    );
  }
}
