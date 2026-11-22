import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/brand_logo.dart';

/// Web sign-in screen (UI image 1).
///
/// UI stage: the QR value is a placeholder and "Log in with Phone Number"
/// opens the app with demo data until the sign-in backend is wired.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  static const routePath = '/login';

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool _keepSignedIn = true;

  void _comingSoon(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what is not available yet.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _WaveBackground()),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final compact = w < 760;
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Column(
                    children: [
                      _TopBar(
                        compact: w < 1000,
                        tiny: w < 560,
                        onSignIn: () {},
                        onGetStarted: () => _comingSoon('Sign up on web'),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 16 : 40,
                          compact ? 20 : 48,
                          compact ? 16 : 40,
                          0,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1316),
                          child: _Card(
                            showWelcomePanel: w >= 1150,
                            stackQr: w < 900,
                            keepSignedIn: _keepSignedIn,
                            onKeepSignedIn: (v) =>
                                setState(() => _keepSignedIn = v),
                            onHelp: () => _comingSoon('Help'),
                            onPhoneLogin: () => context.go('/chats'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const _Footer(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.compact,
    required this.tiny,
    required this.onSignIn,
    required this.onGetStarted,
  });

  final bool compact;
  final bool tiny;
  final VoidCallback onSignIn;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final linkStyle = GoogleFonts.plusJakartaSans(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      color: AppColors.heading,
    );
    return Container(
      height: 76,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: Row(
            children: [
              BrandLogo(
                markSize: compact ? 36 : 46,
                fontSize: compact ? 24 : 31,
              ),
              const Spacer(),
              if (!compact)
                for (final l in const [
                  'Features',
                  'How It Works',
                  'Security',
                  'Pricing',
                  'Help',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Text(l, style: linkStyle),
                  ),
              if (!compact) const Spacer(),
              if (!tiny) ...[
                _PillButton(
                  label: 'Sign In',
                  outlined: true,
                  onTap: onSignIn,
                  width: compact ? 96 : 124,
                ),
                const SizedBox(width: 14),
              ],
              _PillButton(
                label: 'Get Started',
                onTap: onGetStarted,
                width: compact ? 120 : 154,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    required this.width,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onTap;
  final double width;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 46,
      child: Material(
        color: outlined ? Colors.white : AppColors.brandDeep,
        shape: StadiumBorder(
          side: outlined
              ? const BorderSide(color: AppColors.brandDeep, width: 1.4)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: outlined ? AppColors.brandDeep : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main card
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({
    required this.showWelcomePanel,
    required this.stackQr,
    required this.keepSignedIn,
    required this.onKeepSignedIn,
    required this.onHelp,
    required this.onPhoneLogin,
  });

  final bool showWelcomePanel;
  final bool stackQr;
  final bool keepSignedIn;
  final ValueChanged<bool> onKeepSignedIn;
  final VoidCallback onHelp;
  final VoidCallback onPhoneLogin;

  @override
  Widget build(BuildContext context) {
    final content = _SignInContent(
      stackQr: stackQr,
      keepSignedIn: keepSignedIn,
      onKeepSignedIn: onKeepSignedIn,
      onHelp: onHelp,
      onPhoneLogin: onPhoneLogin,
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDeep.withValues(alpha: 0.10),
            blurRadius: 50,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: showWelcomePanel
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(width: 450, child: _WelcomePanel()),
                  Expanded(child: content),
                ],
              ),
            )
          : content,
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.panelTop, Color(0xFF7A30DA), AppColors.panelBottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            // Fade the illustration's top edge into the panel gradient.
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black],
                stops: [0.06, 0.4],
              ).createShader(r),
              child: Image.asset(
                'assets/images/signin_phones.png',
                fit: BoxFit.fitWidth,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(62, 88, 40, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to\nSchatzApp',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 50,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'A secure and simple way to\nconnect, chat, and send value.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.95),
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

class _SignInContent extends StatelessWidget {
  const _SignInContent({
    required this.stackQr,
    required this.keepSignedIn,
    required this.onKeepSignedIn,
    required this.onHelp,
    required this.onPhoneLogin,
  });

  final bool stackQr;
  final bool keepSignedIn;
  final ValueChanged<bool> onKeepSignedIn;
  final VoidCallback onHelp;
  final VoidCallback onPhoneLogin;

  @override
  Widget build(BuildContext context) {
    final qrColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _QrBox(data: 'schatzapp://link-device?session=preview'),
        const SizedBox(height: 22),
        _KeepSignedIn(value: keepSignedIn, onChanged: onKeepSignedIn),
        const SizedBox(height: 14),
        _LinkText('Need help signing in?', onTap: onHelp),
      ],
    );

    const stepsColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Steps(),
        SizedBox(height: 26),
        _FeatureRow(),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        stackQr ? 20 : 64,
        stackQr ? 28 : 16,
        stackQr ? 20 : 64,
        stackQr ? 28 : 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandLogo(markSize: stackQr ? 44 : 54, fontSize: stackQr ? 28 : 33),
          const SizedBox(height: 20),
          Text(
            'Sign in to SchatzApp',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: stackQr ? 28 : 37,
              fontWeight: FontWeight.w800,
              color: AppColors.heading,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use the QR code to sign in on your computer.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: stackQr ? 16 : 20,
              color: AppColors.body,
            ),
          ),
          SizedBox(height: stackQr ? 24 : 32),
          if (stackQr) ...[
            qrColumn,
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: stepsColumn,
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                qrColumn,
                const SizedBox(width: 68),
                const Expanded(child: stepsColumn),
              ],
            ),
          const SizedBox(height: 22),
          const _OrDivider(),
          const SizedBox(height: 18),
          _PhoneButton(onTap: onPhoneLogin),
        ],
      ),
    );
  }
}

class _QrBox extends StatelessWidget {
  const _QrBox({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 292,
      height: 270,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9E0FA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDeep.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        padding: EdgeInsets.zero,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF0E0B1A),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF0E0B1A),
        ),
        embeddedImage: const AssetImage('assets/images/s_logo.png'),
        embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(52, 58)),
      ),
    );
  }
}

class _KeepSignedIn extends StatelessWidget {
  const _KeepSignedIn({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.brandDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: () => onChanged(!value),
          child: Text(
            'Keep me signed in',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              color: AppColors.heading,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Tooltip(
          message:
              'Stay signed in on this browser until you log out or remove it '
              'from Linked Devices on your phone.',
          child: Icon(Icons.info_outline, size: 22, color: AppColors.body),
        ),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText(this.text, {required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.brandDeep,
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    final normal = GoogleFonts.plusJakartaSans(
      fontSize: 17,
      height: 1.4,
      color: AppColors.heading,
    );
    final bold = normal.copyWith(fontWeight: FontWeight.w700);
    final steps = <InlineSpan>[
      TextSpan(text: 'Open SchatzApp on your phone.', style: normal),
      TextSpan(
        style: normal,
        children: [
          const TextSpan(text: 'Tap Menu '),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(Icons.menu, size: 18, color: AppColors.heading),
          ),
          const TextSpan(text: ' and select\n'),
          TextSpan(text: 'Linked Devices.', style: bold),
        ],
      ),
      TextSpan(
        style: normal,
        children: [
          const TextSpan(text: 'Tap '),
          TextSpan(text: 'Link a Device.', style: bold),
        ],
      ),
      TextSpan(
        text: 'Scan the QR code on this screen\nto sign in.',
        style: normal,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.lavender,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandDeep,
                    ),
                  ),
                ),
                const SizedBox(width: 21),
                Expanded(child: Text.rich(steps[i])),
              ],
            ),
          ),
          if (i < steps.length - 1)
            const Padding(
              padding: EdgeInsets.only(left: 61),
              child: Divider(height: 1, color: AppColors.divider),
            ),
        ],
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.verified_user_outlined, 'Secure'),
      (Icons.bolt_outlined, 'Fast'),
      (Icons.devices_outlined, 'Multi-Device'),
      (Icons.lock_outline, 'Private'),
    ];
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Icon(items[i].$1, size: 30, color: AppColors.brandDeep),
                  const SizedBox(height: 8),
                  Text(
                    items[i].$2,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: AppColors.heading,
                    ),
                  ),
                ],
              ),
            ),
            if (i < items.length - 1)
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.divider,
              ),
          ],
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Or sign in with phone number',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.brandDeep,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.divider)),
      ],
    );
  }
}

class _PhoneButton extends StatelessWidget {
  const _PhoneButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 390),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.phone, size: 24, color: AppColors.brandDeep),
          label: Text(
            'Log in with Phone Number',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.brandDeep,
            ),
          ),
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            side: const BorderSide(color: AppColors.brandDeep, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: 16,
      color: AppColors.body,
    );
    return Column(
      children: [
        Text(
          'Ensure your phone is connected to the internet.',
          textAlign: TextAlign.center,
          style: style,
        ),
        const SizedBox(height: 18),
        Text(
          '© ${DateTime.now().year} SchatzApp. All rights reserved.',
          textAlign: TextAlign.center,
          style: style,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Background
// ---------------------------------------------------------------------------

class _WaveBackground extends StatelessWidget {
  const _WaveBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WavePainter());
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F6FD), Color(0xFFF2ECFD)],
        ).createShader(rect),
    );

    final w = size.width;
    final h = size.height;

    // Left swoosh.
    final left = Path()
      ..moveTo(0, h * 0.42)
      ..cubicTo(w * 0.06, h * 0.55, w * 0.02, h * 0.80, w * 0.09, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      left,
      Paint()..color = const Color(0xFFE6D8FC).withValues(alpha: 0.75),
    );

    // Right swooshes.
    final right1 = Path()
      ..moveTo(w, h * 0.08)
      ..cubicTo(w * 0.93, h * 0.20, w * 0.95, h * 0.40, w * 0.91, h * 0.62)
      ..cubicTo(w * 0.89, h * 0.75, w * 0.93, h * 0.90, w, h * 0.95)
      ..close();
    canvas.drawPath(
      right1,
      Paint()..color = const Color(0xFFE9DDFD).withValues(alpha: 0.8),
    );
    final right2 = Path()
      ..moveTo(w, h * 0.22)
      ..cubicTo(w * 0.96, h * 0.35, w * 0.97, h * 0.55, w, h * 0.68)
      ..close();
    canvas.drawPath(
      right2,
      Paint()..color = const Color(0xFFC9AEF9).withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
