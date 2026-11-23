import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/web_auth.dart';

import '../../data/demo_data.dart';
import '../../shell/app_shell.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/flag_image.dart';

/// Profile tab (Profile UI image): Account and Language.
/// Account shows the same fields as the mobile Personal Information page.
/// Placeholder data until the backend phase.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  static const routePath = '/profile';

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

enum _Section { account, language }

class _Language {
  const _Language(this.code, this.flag, this.name);

  /// Same codes as the mobile app (FFLocalizations.languages()).
  final String code;
  final String flag;
  final String name;
}

const _languages = [
  _Language('zh_Hant', 'cn', '中文 (繁體)'),
  _Language('en', 'gb', 'English'),
  _Language('fr', 'fr', 'Français'),
  _Language('de', 'de', 'Deutsch'),
  _Language('it', 'it', 'Italiano'),
  _Language('es', 'es', 'Español'),
  _Language('ja', 'jp', '日本語 (にほんご)'),
  _Language('ko', 'kr', '한국어'),
  _Language('pl', 'pl', 'Polski'),
  _Language('ro', 'ro', 'Română'),
];

class _ProfilePageState extends State<ProfilePage> {
  _Section? _section = _Section.account;
  String _lang = 'en';
  static const _langKey = 'web_language';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final l = p.getString(_langKey);
      if (l != null && mounted && _languages.any((x) => x.code == l)) {
        setState(() => _lang = l);
      }
    });
  }

  String get _langName => _languages.firstWhere((l) => l.code == _lang).name;

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    final menu = _Menu(
      selected: size == ScreenSize.phone ? null : _section,
      languageName: _langName,
      onSelect: (s) => setState(() => _section = s),
    );
    final Widget detail = switch (_section) {
      _Section.account => const _AccountPanel(),
      _Section.language => _LanguagePanel(
        selected: _lang,
        onSelect: (c) {
          setState(() => _lang = c);
          SharedPreferences.getInstance().then((p) => p.setString(_langKey, c));
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('Language set to $_langName')),
            );
        },
      ),
      null => const SizedBox.shrink(),
    };

    if (size == ScreenSize.phone) {
      if (_section == null) return Container(color: Colors.white, child: menu);
      return Container(
        color: Colors.white,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => setState(() => _section = null),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            Expanded(child: detail),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: size == ScreenSize.desktop ? 340 : 300,
            child: ShellPanel(child: menu),
          ),
          const SizedBox(width: 12),
          Expanded(child: ShellPanel(child: detail)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu
// ---------------------------------------------------------------------------

class _Menu extends StatelessWidget {
  const _Menu({
    required this.selected,
    required this.languageName,
    required this.onSelect,
  });

  final _Section? selected;
  final String languageName;
  final ValueChanged<_Section> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(10, 0, 10, 14),
          child: Text(
            'Profile',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.heading,
            ),
          ),
        ),
        _MenuTile(
          icon: Icons.person_outline_rounded,
          title: 'Account',
          subtitle: 'Personal Information',
          active: selected == _Section.account,
          onTap: () => onSelect(_Section.account),
        ),
        const SizedBox(height: 6),
        _MenuTile(
          icon: Icons.public,
          title: 'Language',
          subtitle: languageName,
          active: selected == _Section.language,
          onTap: () => onSelect(_Section.language),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFFF1E6FE) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.heading, size: 28),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: AppColors.meta,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: active ? AppColors.accent : AppColors.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language
// ---------------------------------------------------------------------------

class _LanguagePanel extends StatelessWidget {
  const _LanguagePanel({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 46, 24, 28),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFEDF4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.public, color: AppColors.heading),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Text(
                  "We'll use your device language or location to set the app "
                  'language automatically. You can always change it here.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: AppColors.heading,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandDeep.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < _languages.length; i++)
                _LanguageRow(
                  lang: _languages[i],
                  selected: _languages[i].code == selected,
                  divider:
                      i < _languages.length - 1 &&
                      _languages[i].code != selected &&
                      _languages[i + 1].code != selected,
                  onTap: () => onSelect(_languages[i].code),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.lang,
    required this.selected,
    required this.divider,
    required this.onTap,
  });

  final _Language lang;
  final bool selected;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF1E6FE) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            border: divider
                ? const Border(bottom: BorderSide(color: AppColors.border))
                : null,
          ),
          child: Row(
            children: [
              FlagImage(code: lang.flag, width: 38, height: 26),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  lang.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: AppColors.heading,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.accent : AppColors.meta,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account (Personal Information)
// ---------------------------------------------------------------------------

/// Account details, read from the same rows the phone's Personal
/// Information page uses (profiles, kyc_submissions, wallets).
class _Account {
  String fullName = '';
  String displayName = '';
  String email = '';
  String phone = '';
  String country = '';
  String accountNumber = '';
  String kycStatus = '';
  String joined = '';
  String? photo;

  static Future<_Account> load() async {
    final sb = Supabase.instance.client;
    final me = sb.auth.currentUser!;
    final a = _Account();
    try {
      final p = await sb
          .from('profiles')
          .select('full_name, username, phone_number, avatar_url, created_at')
          .eq('id', me.id)
          .maybeSingle();
      a.displayName = '${p?['username'] ?? ''}'.trim();
      a.fullName = '${p?['full_name'] ?? ''}'.trim();
      a.phone = '${p?['phone_number'] ?? ''}';
      a.photo = p?['avatar_url'] as String?;
      final j = DateTime.tryParse('${p?['created_at'] ?? ''}')?.toLocal();
      if (j != null) {
        const m = [
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
        a.joined = '${j.day} ${m[j.month - 1]} ${j.year}';
      }
    } catch (_) {}
    try {
      final k = await sb
          .from('kyc_submissions')
          .select('first_name, last_name, country, status')
          .eq('user_id', me.id)
          .order('submitted_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final legal = '${k?['first_name'] ?? ''} ${k?['last_name'] ?? ''}'.trim();
      if (legal.isNotEmpty) a.fullName = legal;
      a.country = '${k?['country'] ?? ''}';
      a.kycStatus = '${k?['status'] ?? ''}';
    } catch (_) {}
    try {
      final w = await sb
          .from('wallets')
          .select('schatz_account_number, email, kyc_status')
          .eq('user_id', me.id)
          .maybeSingle();
      a.accountNumber = '${w?['schatz_account_number'] ?? ''}';
      a.email = '${w?['email'] ?? ''}';
      if (a.kycStatus.isEmpty) a.kycStatus = '${w?['kyc_status'] ?? ''}';
    } catch (_) {}
    final authEmail = me.email ?? '';
    if (a.email.isEmpty && !authEmail.endsWith('.invalid')) a.email = authEmail;
    return a;
  }
}

class _AccountPanel extends StatefulWidget {
  const _AccountPanel();

  @override
  State<_AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<_AccountPanel> {
  _Account? _a;

  bool get _live => WebAuth.instance.isLive;

  @override
  void initState() {
    super.initState();
    if (_live) {
      _Account.load().then((a) {
        if (mounted) setState(() => _a = a);
      });
    }
  }

  String _v(String live, String demo) =>
      !_live ? demo : (live.isEmpty ? 'Not set' : live);

  @override
  Widget build(BuildContext context) {
    if (_live && _a == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    final a = _a ?? _Account();
    final verified =
        !_live ||
        [
          'approved',
          'verified',
          'completed',
        ].contains(a.kycStatus.toLowerCase());
    final statusText = !_live
        ? 'Verified'
        : (verified
              ? 'Verified'
              : (a.kycStatus.isEmpty
                    ? 'Not verified'
                    : '${a.kycStatus[0].toUpperCase()}${a.kycStatus.substring(1)}'));
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 28),
      children: [
        Row(
          children: [
            Avatar(
              name: _live
                  ? (a.fullName.isEmpty ? 'Me' : a.fullName)
                  : demoCurrentUserName,
              photoUrl: a.photo,
              size: 72,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your personal details associated with your '
                    'SchatzWallet account.',
                    style: TextStyle(fontSize: 14.5, color: AppColors.meta),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        _InfoCard(
          title: 'Personal Details',
          rows: [
            ('Full legal name', _v(a.fullName, 'Chloe Bites')),
            ('Display name', _v(a.displayName, 'Chloe Bites')),
            (
              'Email address',
              _live
                  ? (a.email.isEmpty ? 'Not set' : maskEmail(a.email))
                  : maskEmail('kestawealth@gmail.com'),
            ),
            ('Phone number', _v(a.phone, '+234 701 000 1234')),
            ('Country of residence', _v(a.country, 'Nigeria')),
          ],
        ),
        const SizedBox(height: 18),
        _InfoCard(
          title: 'Account Information',
          rows: [
            ('Account number', _v(a.accountNumber, 'SFZ70100017391')),
            ('Account status', ''),
            ('Date joined', _v(a.joined, '28 Aug 2026')),
          ],
          trailingFor: (label, value) {
            if (label == 'Account status') {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: verified
                      ? const Color(0xFFD9F7DD)
                      : const Color(0xFFFFF1D6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      verified ? Icons.verified : Icons.pending_outlined,
                      size: 15,
                      color: verified
                          ? const Color(0xFF14A23A)
                          : const Color(0xFFB7791F),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: verified
                            ? const Color(0xFF14A23A)
                            : const Color(0xFFB7791F),
                      ),
                    ),
                  ],
                ),
              );
            }
            if (label == 'Account number' && value != 'Not set') {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.heading,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Account number copied'),
                          ),
                        );
                    },
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              );
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        const Text(
          'To change these details, update them in the SchatzApp mobile app.',
          style: TextStyle(fontSize: 13, color: AppColors.meta),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows, this.trailingFor});

  final String title;
  final List<(String, String)> rows;
  final Widget? Function(String label, String value)? trailingFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFF6F2FD),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.heading,
              ),
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Text(
                    rows[i].$1,
                    style: const TextStyle(fontSize: 15, color: AppColors.body),
                  ),
                  const Spacer(),
                  trailingFor?.call(rows[i].$1, rows[i].$2) ??
                      Text(
                        rows[i].$2,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.heading,
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

/// Hides most of an email on the web, e.g. kes********alth@gmail.com.
/// Short names keep only the first letter: a****@gmail.com.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  final name = email.substring(0, at);
  final domain = email.substring(at);
  if (name.length <= 4) return '${name[0]}${'*' * 4}$domain';
  if (name.length <= 7) {
    return '${name.substring(0, 2)}${'*' * 4}${name.substring(name.length - 1)}$domain';
  }
  return '${name.substring(0, 3)}${'*' * 8}${name.substring(name.length - 4)}$domain';
}
