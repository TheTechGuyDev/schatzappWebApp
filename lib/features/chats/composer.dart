import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/live/conversation_feed.dart';
import '../../platform/camera_dialog.dart';
import '../../platform/voice_recorder.dart';
import '../../platform/web_files.dart';
import '../../theme/app_theme.dart';
import 'message_bubble.dart' show bubbleShadow;

const _gradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFAE5CF2), Color(0xFF8A3BE6)],
);

/// WhatsApp Web style composer in SchatzApp colours:
/// [+] [emoji] [ message field ] [mic | send]
/// The send button only appears when the field holds real text.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    this.onTyping,
    this.feed,
  });

  final ValueChanged<String> onSend;
  final VoidCallback? onTyping;

  /// Live conversation. Null in preview mode (attachments show a notice).
  final ConversationFeed? feed;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);
  final _attachMenu = MenuController();
  final _emojiMenu = MenuController();
  final _recorder = VoiceRecorder();
  Timer? _ticker;
  bool _hasText = false;
  bool _recording = false;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_recording) _recorder.stop(cancel: true);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyDownEvent &&
        (e.logicalKey == LogicalKeyboardKey.enter ||
            e.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _submit() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text.trim());
    _controller.clear();
    _focus.requestFocus();
  }

  void _insertEmoji(String emoji) {
    final v = _controller.value;
    final sel = v.selection.isValid
        ? v.selection
        : TextSelection.collapsed(offset: v.text.length);
    final text = v.text.replaceRange(sel.start, sel.end, emoji);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: sel.start + emoji.length),
    );
    _focus.requestFocus();
  }

  /// Runs an upload and reports failures in plain words.
  void _run(Future<void> Function(ConversationFeed feed) job) {
    final feed = widget.feed;
    if (feed == null) {
      _toast('Sign in with your phone to send attachments.');
      return;
    }
    job(feed).catchError((Object _) {
      if (mounted) {
        _toast('Could not send. Check your connection and try again.');
      }
    });
  }

  // ------------------------------------------------------------------
  // Attach actions
  // ------------------------------------------------------------------

  Future<void> _pickDocument() async {
    if (widget.feed == null) return _run((_) async {});
    final files = await pickFiles(accept: '*/*');
    if (files.isEmpty) return;
    final f = files.first;
    if (f.bytes.length > 100 * 1024 * 1024) {
      return _toast('Documents must be under 100 MB.');
    }
    _run((feed) => feed.sendDocument(f));
  }

  Future<void> _pickMedia() async {
    if (widget.feed == null) return _run((_) async {});
    var files = await pickFiles(accept: 'image/*,video/*', multiple: true);
    files = files.where((f) => f.isImage || f.isVideo).toList();
    if (files.isEmpty || !mounted) return;
    if (files.length > 10) {
      _toast('You can send up to 10 at a time. The first 10 were kept.');
      files = files.take(10).toList();
    }
    if (files.any((f) => f.isVideo && f.bytes.length > 64 * 1024 * 1024)) {
      return _toast('Videos must be under 64 MB.');
    }
    final caption = await showDialog<String>(
      context: context,
      builder: (_) => _MediaPreviewDialog(files: files),
    );
    if (caption == null) return;
    _run((feed) => feed.sendMedia(files, caption));
  }

  Future<void> _openCamera() async {
    if (widget.feed == null) return _run((_) async {});
    final bytes = await takeCameraPhoto(context);
    if (bytes == null) return;
    final file = PickedFile(
      name: 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg',
      bytes: bytes,
      mime: 'image/jpeg',
    );
    _run((feed) => feed.sendMedia([file], ''));
  }

  Future<void> _pickAudio() async {
    if (widget.feed == null) return _run((_) async {});
    final files = await pickFiles(accept: 'audio/*');
    if (files.isEmpty) return;
    final f = files.first;
    if (f.bytes.length > 32 * 1024 * 1024) {
      return _toast('Audio files must be under 32 MB.');
    }
    final dot = f.name.lastIndexOf('.');
    final ext = dot > 0 ? f.name.substring(dot + 1).toLowerCase() : 'm4a';
    final seconds = await mediaDuration(f.bytes, f.mime);
    _run((feed) => feed.sendVoice(f.bytes, f.mime, ext, seconds));
  }

  // ------------------------------------------------------------------
  // Voice notes
  // ------------------------------------------------------------------

  Future<void> _startRecording() async {
    if (widget.feed == null) return _run((_) async {});
    try {
      await _recorder.start();
    } catch (e) {
      return _toast(e.toString().replaceFirst('Exception: ', ''));
    }
    if (!mounted) return;
    setState(() => _recording = true);
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    if (_stopping) return;
    _stopping = true;
    _ticker?.cancel();
    final result = await _recorder.stop(cancel: !send);
    _stopping = false;
    if (!mounted) return;
    setState(() => _recording = false);
    if (!send) return;
    if (result == null) return _toast('Hold on a little longer to record.');
    _run(
      (feed) =>
          feed.sendVoice(result.bytes, result.mime, result.ext, result.seconds),
    );
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final uploads = widget.feed?.uploading ?? const <String>[];
    return Container(
      color: const Color(0xFFF7F3FD),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (uploads.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [for (final u in uploads) _UploadChip(label: u)],
              ),
            ),
          _recording ? _recordingBar() : _inputBar(),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
              boxShadow: bubbleShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: _attachButton(),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: _emojiButton(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      onChanged: (v) {
                        if (v.trim().isNotEmpty) widget.onTyping?.call();
                      },
                      style: const TextStyle(fontSize: 16, height: 1.35),
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        hintStyle: TextStyle(
                          color: AppColors.meta,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          transitionBuilder: (child, a) =>
              ScaleTransition(scale: a, child: child),
          child: _hasText
              ? _RoundButton(
                  key: const ValueKey('send'),
                  tooltip: 'Send',
                  icon: Icons.send_rounded,
                  onTap: _submit,
                )
              : _RoundButton(
                  key: const ValueKey('mic'),
                  tooltip: 'Record voice note',
                  icon: Icons.mic_rounded,
                  onTap: _startRecording,
                ),
        ),
      ],
    );
  }

  Widget _attachButton() {
    return MenuAnchor(
      controller: _attachMenu,
      alignmentOffset: const Offset(0, -8),
      style: _menuStyle,
      menuChildren: [
        _AttachItem(
          icon: Icons.description_rounded,
          color: const Color(0xFF7B2FE0),
          label: 'Document',
          onTap: _pickDocument,
        ),
        _AttachItem(
          icon: Icons.photo_library_rounded,
          color: const Color(0xFF1FB5A3),
          label: 'Photos & videos',
          onTap: _pickMedia,
        ),
        _AttachItem(
          icon: Icons.photo_camera_rounded,
          color: const Color(0xFFE0487F),
          label: 'Camera',
          onTap: _openCamera,
        ),
        _AttachItem(
          icon: Icons.headphones_rounded,
          color: const Color(0xFFF08A24),
          label: 'Audio',
          onTap: _pickAudio,
        ),
      ],
      builder: (context, c, _) => _CircleIcon(
        tooltip: 'Attach',
        icon: c.isOpen ? Icons.close_rounded : Icons.add_rounded,
        active: c.isOpen,
        onTap: () => c.isOpen ? c.close() : c.open(),
      ),
    );
  }

  Widget _emojiButton() {
    return MenuAnchor(
      controller: _emojiMenu,
      alignmentOffset: const Offset(0, -8),
      style: _menuStyle,
      menuChildren: [
        _EmojiGrid(
          onPick: (e) {
            _insertEmoji(e);
          },
        ),
      ],
      builder: (context, c, _) => _CircleIcon(
        tooltip: 'Emoji',
        icon: Icons.sentiment_satisfied_alt_outlined,
        active: c.isOpen,
        onTap: () => c.isOpen ? c.close() : c.open(),
      ),
    );
  }

  Widget _recordingBar() {
    final s = _recorder.elapsed.inSeconds;
    final time = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
              boxShadow: bubbleShadow,
            ),
            child: Row(
              children: [
                _CircleIcon(
                  tooltip: 'Cancel',
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.missed,
                  onTap: () => _stopRecording(send: false),
                ),
                const SizedBox(width: 6),
                _PulseDot(),
                const SizedBox(width: 10),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Recording voice note...',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.meta, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _RoundButton(
          tooltip: 'Send voice note',
          icon: Icons.send_rounded,
          onTap: () => _stopRecording(send: true),
        ),
      ],
    );
  }
}

final _menuStyle = MenuStyle(
  backgroundColor: const WidgetStatePropertyAll(Colors.white),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.white),
  elevation: const WidgetStatePropertyAll(10),
  shadowColor: WidgetStatePropertyAll(
    const Color(0xFF5B1CD3).withValues(alpha: 0.25),
  ),
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.border),
    ),
  ),
);

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.accentSoft : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 26,
            color: color ?? (active ? AppColors.accent : AppColors.body),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _gradient,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8A3BE6).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _AttachItem extends StatelessWidget {
  const _AttachItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: onTap,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(230, 52)),
        overlayColor: WidgetStatePropertyAll(
          AppColors.accentSoft.withValues(alpha: 0.7),
        ),
      ),
      leadingIcon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 21),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.heading,
          ),
        ),
      ),
    );
  }
}

class _UploadChip extends StatelessWidget {
  const _UploadChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.body),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: AppColors.missed,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Emoji picker
// ----------------------------------------------------------------------

const _emojiSets = <(String, IconData, String)>[
  (
    'Smileys',
    Icons.sentiment_satisfied_alt_outlined,
    '😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🤭 🤫 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪 😵 🤐 🥴 🤢 🤮 🤧 😷 🤒 🤕',
  ),
  (
    'Gestures',
    Icons.waving_hand_outlined,
    '👍 👎 👌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ ✋ 🤚 🖐️ 🖖 👋 🤝 🙏 👏 🙌 👐 🤲 💪 🫶 ✍️ 💅 👀 🧠 🫡 🤷 🤦 🙋 🙇 💃 🕺 🏃 🚶',
  ),
  (
    'Hearts',
    Icons.favorite_border_rounded,
    '❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟 ✨ 🔥 💯 ⭐ 🌟 💫 🎉 🎊 🎁 🎈 🏆 🥇 👑 💎 💰 💵 💳',
  ),
  (
    'Things',
    Icons.emoji_food_beverage_outlined,
    '🍕 🍔 🍟 🌭 🍿 🍗 🍖 🍝 🍜 🍲 🍛 🍣 🍱 🍩 🍪 🎂 🍰 🍫 🍬 🍭 ☕ 🍵 🥤 🍺 🍷 🥂 ⚽ 🏀 🎮 🎧 🎵 📱 💻 📷 🚗 ✈️ 🏠 ⏰ 📌 ✅ ❌',
  ),
];

class _EmojiGrid extends StatefulWidget {
  const _EmojiGrid({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  State<_EmojiGrid> createState() => _EmojiGridState();
}

class _EmojiGridState extends State<_EmojiGrid> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final emojis = _emojiSets[_tab].$3.split(' ');
    return SizedBox(
      width: 340,
      height: 300,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                for (var i = 0; i < _emojiSets.length; i++)
                  Expanded(
                    child: Tooltip(
                      message: _emojiSets[i].$1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _tab = i),
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                width: 2.5,
                                color: i == _tab
                                    ? AppColors.accent
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          child: Icon(
                            _emojiSets[i].$2,
                            size: 21,
                            color: i == _tab
                                ? AppColors.accent
                                : AppColors.meta,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: GridView.count(
              crossAxisCount: 8,
              padding: const EdgeInsets.all(8),
              children: [
                for (final e in emojis)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => widget.onPick(e),
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Photos & videos preview before sending
// ----------------------------------------------------------------------

class _MediaPreviewDialog extends StatefulWidget {
  const _MediaPreviewDialog({required this.files});

  final List<PickedFile> files;

  @override
  State<_MediaPreviewDialog> createState() => _MediaPreviewDialogState();
}

class _MediaPreviewDialogState extends State<_MediaPreviewDialog> {
  final _caption = TextEditingController();
  int _index = 0;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _send() => Navigator.of(context).pop(_caption.text.trim());

  Widget _tile(PickedFile f, {BoxFit fit = BoxFit.cover}) {
    if (f.isImage) {
      return Image.memory(f.bytes, fit: fit, gaplessPlayback: true);
    }
    return Container(
      color: const Color(0xFF1E1530),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 46,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              f.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.files;
    final current = files[_index];
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    files.length == 1
                        ? (current.isVideo ? 'Send video' : 'Send photo')
                        : 'Send ${files.length} items',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.body,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 320,
                  color: AppColors.lavenderSoft,
                  child: _tile(current, fit: BoxFit.contain),
                ),
              ),
              if (files.length > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: files.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => InkWell(
                      onTap: () => setState(() => _index = i),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            width: 2.5,
                            color: i == _index
                                ? AppColors.accent
                                : Colors.transparent,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _tile(files[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caption,
                      autofocus: true,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Add a caption',
                        filled: true,
                        fillColor: AppColors.lavenderSoft,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RoundButton(
                    tooltip: 'Send',
                    icon: Icons.send_rounded,
                    onTap: _send,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
