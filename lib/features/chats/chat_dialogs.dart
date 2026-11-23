import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../data/demo_data.dart';
import '../../platform/web_files.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';

/// Popups used by the Chats tab. Content mirrors the mobile app screens:
/// addfriends (New user), createagroup, add_members_to_group,
/// app_password_gate (Private Chat) and the theme selector.

// ---------------------------------------------------------------------------
// Shared shell
// ---------------------------------------------------------------------------

class DialogShell extends StatelessWidget {
  const DialogShell({
    super.key,
    required this.title,
    required this.child,
    this.width = 440,
    this.action,
    this.onBack,
  });

  final String title;
  final Widget child;
  final double width;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.86;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 14, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: onBack != null ? 'Back' : 'Close',
                    onPressed: onBack ?? () => Navigator.of(context).pop(),
                    icon: Icon(
                      onBack != null ? Icons.arrow_back : Icons.close,
                      color: AppColors.heading,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading,
                      ),
                    ),
                  ),
                  ?action,
                ],
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint, {IconData? icon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.meta),
    prefixIcon: icon == null ? null : Icon(icon, color: AppColors.body),
    filled: true,
    fillColor: const Color(0xFFF7F5FB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDCD7E6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
    ),
  );
}

// ---------------------------------------------------------------------------
// Contact picker (New user / Add members)
// ---------------------------------------------------------------------------

/// Single select returns one contact as soon as it is tapped.
/// Multi select shows checkboxes and an action button.
class ContactPickerDialog extends StatefulWidget {
  const ContactPickerDialog({
    super.key,
    required this.title,
    this.multiSelect = false,
    this.actionLabel = 'Add',
    this.exclude = const {},
    this.load,
  });

  final String title;
  final bool multiSelect;
  final String actionLabel;

  /// Contact keys (user ids when live) to leave out.
  final Set<String> exclude;

  /// Loads the user's real contacts. Null uses the preview contacts.
  final Future<List<DemoContact>> Function()? load;

  @override
  State<ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<ContactPickerDialog> {
  String _q = '';
  final Set<String> _picked = {};
  late List<DemoContact>? _all = widget.load == null ? demoContacts : null;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.load
        ?.call()
        .then((c) {
          if (mounted) setState(() => _all = c);
        })
        .catchError((Object _) {
          if (mounted) setState(() => _error = 'Could not load your contacts.');
        });
  }

  @override
  Widget build(BuildContext context) {
    final all = _all ?? const <DemoContact>[];
    final list = all
        .where((c) => c.name != demoCurrentUserName || widget.load != null)
        .where((c) => !widget.exclude.contains(c.key))
        .where(
          (c) =>
              _q.isEmpty ||
              c.name.toLowerCase().contains(_q) ||
              c.phone.replaceAll(' ', '').contains(_q.replaceAll(' ', '')),
        )
        .toList();
    return DialogShell(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              decoration: _fieldDecoration(
                widget.multiSelect
                    ? "Enter Member's name..."
                    : 'Search friends',
                icon: Icons.search,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'All Contacts',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.meta,
                ),
              ),
            ),
          ),
          Flexible(
            child: _all == null && _error == null
                ? const Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(30),
                    child: Text(
                      _error ??
                          (all.isEmpty
                              ? 'No contacts yet. Add contacts on your phone.'
                              : 'No contacts found'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.meta),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      final picked = _picked.contains(c.key);
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Avatar(
                          name: c.name,
                          color: c.color,
                          photoUrl: c.avatarUrl,
                          size: 44,
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.heading,
                          ),
                        ),
                        subtitle: Text(
                          c.phone,
                          style: const TextStyle(color: AppColors.meta),
                        ),
                        trailing: widget.multiSelect
                            ? Checkbox(
                                value: picked,
                                activeColor: AppColors.accent,
                                onChanged: (_) => _toggle(c),
                              )
                            : null,
                        onTap: () {
                          if (widget.multiSelect) {
                            _toggle(c);
                          } else {
                            Navigator.of(context).pop([c]);
                          }
                        },
                      );
                    },
                  ),
          ),
          if (widget.multiSelect)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: _PrimaryButton(
                label: _picked.isEmpty
                    ? widget.actionLabel
                    : '${widget.actionLabel} (${_picked.length})',
                onTap: () {
                  if (_picked.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Select at least one member to add'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context)
                      .pop(all.where((c) => _picked.contains(c.key)).toList());
                },
              ),
            ),
        ],
      ),
    );
  }

  void _toggle(DemoContact c) => setState(() {
    _picked.contains(c.key) ? _picked.remove(c.key) : _picked.add(c.key);
  });
}

// ---------------------------------------------------------------------------
// Create group
// ---------------------------------------------------------------------------

typedef NewGroup = ({
  String name,
  List<DemoContact> members,
  bool isPrivate,
  Uint8List? photo,
});

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key, this.privateGroup = false, this.load});

  /// True when started from inside Private Chats (private by default).
  final bool privateGroup;

  /// Loads the user's real contacts. Null uses the preview contacts.
  final Future<List<DemoContact>> Function()? load;

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _name = TextEditingController();
  String _q = '';
  final Set<String> _picked = {};
  late bool _private = widget.privateGroup;
  late List<DemoContact>? _all = widget.load == null ? demoContacts : null;
  Uint8List? _photo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.load
        ?.call()
        .then((c) {
          if (mounted) setState(() => _all = c);
        })
        .catchError((Object _) {
          if (mounted) setState(() => _all = const []);
        });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final files = await pickFiles(accept: 'image/*');
    if (files.isEmpty) return;
    final f = files.first;
    if (f.bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group photos must be under 5 MB.')),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final small = await resizeImage(
        f.bytes,
        'image/jpeg',
        maxDim: 500,
        quality: 0.8,
      );
      if (mounted) setState(() => _photo = small);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _create() {
    if (_name.text.trim().isEmpty || _picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a group name and select at least one member'),
        ),
      );
      return;
    }
    Navigator.of(context).pop<NewGroup>((
      name: _name.text.trim(),
      members: (_all ?? const <DemoContact>[])
          .where((c) => _picked.contains(c.key))
          .toList(),
      isPrivate: _private,
      photo: _photo,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final list = (_all ?? const <DemoContact>[])
        .where((c) => c.name != demoCurrentUserName || widget.load != null)
        .where((c) => _q.isEmpty || c.name.toLowerCase().contains(_q))
        .toList();
    return DialogShell(
      title: widget.privateGroup ? 'New private group' : 'Create New Group',
      width: 480,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Group photo
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _busy ? null : _pickPhoto,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lavenderSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6DAFA)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.accentSoft,
                      backgroundImage: _photo == null
                          ? null
                          : MemoryImage(_photo!),
                      child: _photo != null
                          ? null
                          : const Icon(
                              Icons.add_a_photo_outlined,
                              color: AppColors.accent,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _photo == null
                              ? 'Add Group Photo'
                              : 'Change Group Photo',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.heading,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'JPG, PNG or GIF, Max 5MB',
                          style: TextStyle(fontSize: 13, color: AppColors.meta),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Group Name',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.heading,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: _fieldDecoration('Enter Group name...'),
            ),
            const SizedBox(height: 14),
            // Private group switch
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.accent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Private group',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.heading,
                          ),
                        ),
                      ),
                      Switch(
                        value: _private,
                        activeThumbColor: AppColors.accent,
                        onChanged: widget.privateGroup
                            ? null
                            : (v) => setState(() => _private = v),
                      ),
                    ],
                  ),
                  const Text(
                    'Calls, files and location are disabled. Only the creator '
                    'or an admin can remove it, and removing it deletes the '
                    'group.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.meta),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _picked.isEmpty
                  ? 'Add Members'
                  : 'Add Members (${_picked.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.heading,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              decoration: _fieldDecoration(
                "Enter Member's name...",
                icon: Icons.search,
              ),
            ),
            const SizedBox(height: 6),
            if (_all == null)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              )
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No contacts found',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.meta),
                ),
              ),
            for (final c in list)
              CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _picked.contains(c.key),
                activeColor: AppColors.accent,
                controlAffinity: ListTileControlAffinity.trailing,
                secondary: Avatar(
                  name: c.name,
                  color: c.color,
                  photoUrl: c.avatarUrl,
                  size: 40,
                ),
                title: Text(
                  c.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading,
                  ),
                ),
                onChanged: (_) => setState(() {
                  _picked.contains(c.key)
                      ? _picked.remove(c.key)
                      : _picked.add(c.key);
                }),
              ),
            const SizedBox(height: 14),
            _PrimaryButton(label: 'Create', onTap: _busy ? null : _create),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App password gate (Private Chats)
// ---------------------------------------------------------------------------

class PasswordGateDialog extends StatefulWidget {
  const PasswordGateDialog({super.key, this.verify});

  /// Real check (verify_app_password RPC). Null in the UI preview.
  final Future<bool> Function(String password)? verify;

  @override
  State<PasswordGateDialog> createState() => _PasswordGateDialogState();
}

class _PasswordGateDialogState extends State<PasswordGateDialog> {
  final _pw = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  bool _checking = false;

  Future<void> _unlock() async {
    if (_checking) return;
    final verify = widget.verify;
    if (verify == null) {
      // UI preview only.
      if (_pw.text.length < 4) {
        setState(() => _error = 'Incorrect password');
        return;
      }
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _checking = true);
    final ok = await verify(_pw.text);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = 'Incorrect password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: AppColors.accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Private Chat',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter your app password to continue',
                style: TextStyle(fontSize: 14, color: AppColors.meta),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pw,
                autofocus: true,
                obscureText: _obscure,
                onSubmitted: (_) => _unlock(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: _fieldDecoration('App password').copyWith(
                  errorText: _error,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.meta,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _PrimaryButton(label: 'Unlock', onTap: _unlock),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.meta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat theme
// ---------------------------------------------------------------------------

/// Returns the chosen theme key, '' for default, or null when cancelled.
class ChatThemeDialog extends StatefulWidget {
  const ChatThemeDialog({super.key, this.selected});

  final String? selected;

  @override
  State<ChatThemeDialog> createState() => _ChatThemeDialogState();
}

class _ChatThemeDialogState extends State<ChatThemeDialog> {
  late String _selected = widget.selected ?? '';

  @override
  Widget build(BuildContext context) {
    Widget tile({
      required String key,
      required Widget preview,
      required String label,
    }) {
      final on = _selected == key;
      return GestureDetector(
        onTap: () => setState(() => _selected = key),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 96,
              height: 170,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: on ? AppColors.accent : AppColors.border,
                  width: on ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    preview,
                    if (on)
                      const Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: EdgeInsets.all(5),
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: AppColors.accent,
                            child: Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                color: on ? AppColors.accent : AppColors.body,
              ),
            ),
          ],
        ),
      );
    }

    return DialogShell(
      title: 'Select Themes',
      width: 720,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Background photo upload is coming soon.'),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.image_outlined, color: AppColors.heading),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Choose from Photo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.heading,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.meta),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 14,
              children: [
                tile(
                  key: '',
                  label: 'Default',
                  preview: Container(
                    color: AppColors.conversationBg,
                    child: const Icon(
                      Icons.format_paint_outlined,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                for (var i = 0; i < chatThemes.length; i++)
                  tile(
                    key: chatThemes[i].key,
                    label: 'Theme ${i + 1}',
                    preview: Image.asset(
                      chatThemes[i].preview,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Each theme sets your bubble colors and background together. '
              'Choose a photo to use your own background instead.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.meta),
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
              label: 'Apply',
              onTap: () => Navigator.of(context).pop(_selected),
            ),
          ],
        ),
      ),
    );
  }
}
