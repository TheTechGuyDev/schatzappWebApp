import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/demo_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/flag_image.dart';

/// "Log in with Phone Number" fallback, shown inside the sign-in card.
/// Mirrors the mobile phone_login (country picker + number, Get OTP) and
/// verify_mobile_number (6-digit OTP, resend countdown) pages.
/// Placeholder: any number gets an OTP screen and any 6 digits sign in.
class PhoneLoginContent extends StatefulWidget {
  const PhoneLoginContent({
    super.key,
    required this.compact,
    required this.keepSignedIn,
    required this.onKeepSignedIn,
    required this.onBackToQr,
    required this.onSignedIn,
    required this.onHelp,
  });

  final bool compact;
  final bool keepSignedIn;
  final ValueChanged<bool> onKeepSignedIn;
  final VoidCallback onBackToQr;
  final VoidCallback onSignedIn;
  final VoidCallback onHelp;

  @override
  State<PhoneLoginContent> createState() => _PhoneLoginContentState();
}

class _PhoneLoginContentState extends State<PhoneLoginContent> {
  DemoCountry _country = demoCountries.first;
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();
  bool _otpStep = false;
  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _otp.addListener(() {
      setState(() => _error = null);
      if (_otp.text.length == 6) _verify();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _otp.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');
  String get _fullNumber => '${_country.dial} ${_phone.text.trim()}';

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendIn = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _getOtp() async {
    if (_digits.length < 7) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _otpStep = true;
    });
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _otpFocus.requestFocus(),
    );
  }

  Future<void> _verify() async {
    if (_otp.text.length != 6 || _busy) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onSignedIn();
  }

  Future<void> _pickCountry() async {
    final c = await showDialog<DemoCountry>(
      context: context,
      builder: (_) => _CountryDialog(selected: _country),
    );
    if (c != null) setState(() => _country = c);
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.compact ? 22.0 : 64.0;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: widget.compact ? 0 : 640),
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, 22, pad, 26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _otpStep
                      ? () => setState(() {
                          _otpStep = false;
                          _otp.clear();
                        })
                      : widget.onBackToQr,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text(_otpStep ? 'Change number' : 'Back to QR code'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandDeep,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            BrandLogo(
              markSize: widget.compact ? 44 : 54,
              fontSize: widget.compact ? 28 : 33,
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _otpStep ? _otpView() : _phoneView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: widget.compact ? 26 : 34,
            fontWeight: FontWeight.w800,
            color: AppColors.heading,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            height: 1.45,
            color: AppColors.body,
          ),
        ),
      ],
    );
  }

  Widget _phoneView() {
    return Column(
      children: [
        _title(
          'Log in to SchatzApp',
          'Continue to experience powerful features\nfor seamless communication.',
        ),
        const SizedBox(height: 26),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Enter your number to continue',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.heading,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickCountry,
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F5FB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDCD7E6)),
                ),
                child: Row(
                  children: [
                    FlagImage(code: _country.code),
                    const SizedBox(width: 8),
                    Text(
                      _country.dial,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.heading,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.body,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 54,
                child: TextField(
                  controller: _phone,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                    LengthLimitingTextInputFormatter(15),
                  ],
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _getOtp(),
                  style: const TextStyle(fontSize: 17, letterSpacing: 0.5),
                  decoration: InputDecoration(
                    hintText: '---  ---- -----',
                    hintStyle: const TextStyle(color: AppColors.meta),
                    filled: true,
                    fillColor: const Color(0xFFF7F5FB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFDCD7E6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.brandDeep,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        _ErrorLine(_error),
        const SizedBox(height: 14),
        _KeepRow(value: widget.keepSignedIn, onChanged: widget.onKeepSignedIn),
        const SizedBox(height: 18),
        _BigButton(label: 'Get OTP', busy: _busy, onTap: _getOtp),
        const SizedBox(height: 14),
        TextButton(
          onPressed: widget.onHelp,
          child: const Text(
            'Need help logging in?',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.brandDeep,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _FeatureChips(),
      ],
    );
  }

  Widget _otpView() {
    final n = _otp.text.length;
    return Column(
      children: [
        _title('Verify Mobile', 'Enter OTP sent to $_fullNumber'),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () => _otpFocus.requestFocus(),
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 6; i++)
                    Container(
                      width: 52,
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F5FB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _error != null
                              ? AppColors.missed
                              : (i == n
                                    ? AppColors.brandDeep
                                    : const Color(0xFFDCD7E6)),
                          width: i == n ? 1.6 : 1,
                        ),
                      ),
                      child: Text(
                        i < n ? _otp.text[i] : '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading,
                        ),
                      ),
                    ),
                ],
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _otp,
                    focusNode: _otpFocus,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _ErrorLine(_error),
        const SizedBox(height: 22),
        _BigButton(
          label: 'Verify',
          busy: _busy,
          onTap: () {
            if (_otp.text.length != 6) {
              setState(
                () => _error = 'Invalid or expired code, please try again.',
              );
              return;
            }
            _verify();
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Didn't receive OTP? ",
              style: TextStyle(color: AppColors.body),
            ),
            if (_resendIn > 0)
              Text(
                'Resend code in ${_resendIn}s',
                style: const TextStyle(
                  color: AppColors.meta,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              InkWell(
                onTap: () {
                  _otp.clear();
                  _startCountdown();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('New code sent to $_fullNumber')),
                  );
                },
                child: const Text(
                  'Resend code',
                  style: TextStyle(
                    color: AppColors.brandDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.error);

  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.missed),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              error!,
              style: const TextStyle(fontSize: 13, color: AppColors.missed),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeepRow extends StatelessWidget {
  const _KeepRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            activeColor: AppColors.brandDeep,
            onChanged: (v) => onChanged(v ?? false),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: () => onChanged(!value),
          child: const Text(
            'Keep me signed in',
            style: TextStyle(color: AppColors.heading),
          ),
        ),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: busy ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandDeep,
          disabledBackgroundColor: AppColors.brandDeep.withValues(alpha: 0.6),
          shape: const StadiumBorder(),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _FeatureChips extends StatelessWidget {
  const _FeatureChips();

  @override
  Widget build(BuildContext context) {
    // Mobile shows "End-to-End Encrypted"; messages are not end-to-end
    // encrypted, so the web says "Secure" instead.
    const items = [
      (Icons.verified_user_outlined, 'Secure'),
      (Icons.bolt_outlined, 'Lightning Fast'),
      (Icons.devices_outlined, 'Works Everywhere'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final i in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.lavenderSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(i.$1, size: 16, color: AppColors.brandDeep),
                const SizedBox(width: 6),
                Text(
                  i.$2,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.heading,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Country list (the mobile app's ListOfCountries dialog). Real data comes
/// from the supported_countries table in the backend phase.
class _CountryDialog extends StatefulWidget {
  const _CountryDialog({required this.selected});

  final DemoCountry selected;

  @override
  State<_CountryDialog> createState() => _CountryDialogState();
}

class _CountryDialogState extends State<_CountryDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = demoCountries
        .where(
          (c) =>
              _q.isEmpty ||
              c.name.toLowerCase().contains(_q) ||
              c.dial.contains(_q),
        )
        .toList();
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 10, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select your country',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search country or code',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF7F5FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  final on =
                      c.code == widget.selected.code &&
                      c.dial == widget.selected.dial;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    selected: on,
                    selectedTileColor: AppColors.lavenderSoft,
                    leading: FlagImage(code: c.code),
                    title: Text(c.name),
                    trailing: Text(
                      c.dial,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.body,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
