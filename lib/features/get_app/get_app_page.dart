import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../../theme/app_theme.dart';
import '../../widgets/brand_logo.dart';

/// Store links. Fill these in once the apps are published.
class StoreLinks {
  static const appStore = '';
  static const googlePlay = '';
}

/// Shown to phone visitors. SchatzApp Web only runs on computers and
/// tablets, so phones are asked to download the mobile app instead.
class GetAppPage extends StatelessWidget {
  const GetAppPage({super.key});

  static const routePath = '/get-app';

  void _openStore(BuildContext context, String store, String url) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('SchatzApp is coming soon to $store.')),
        );
      return;
    }
    web.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final jakarta = GoogleFonts.plusJakartaSans;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.panelTop,
                    Color(0xFF7A30DA),
                    AppColors.panelBottom,
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const BrandLogo(markSize: 28, fontSize: 20),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                      child: Text(
                        'SchatzApp is made\nfor your phone',
                        style: jakarta(
                          fontSize: 34,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                      child: Text(
                        'Download the app to connect, chat, call and send '
                        'value on the go.',
                        style: jakarta(
                          fontSize: 17,
                          height: 1.45,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (r) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                        stops: [0.06, 0.4],
                      ).createShader(r),
                      child: Image.asset(
                        'assets/images/signin_phones.png',
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Download
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    Text(
                      'Get the SchatzApp app',
                      textAlign: TextAlign.center,
                      style: jakarta(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _StoreButton(
                      icon: Icons.apple,
                      small: 'Download on the',
                      big: 'App Store',
                      onTap: () =>
                          _openStore(context, 'the App Store', StoreLinks.appStore),
                    ),
                    const SizedBox(height: 12),
                    _StoreButton(
                      icon: Icons.shop_rounded,
                      small: 'Get it on',
                      big: 'Google Play',
                      onTap: () => _openStore(
                        context,
                        'Google Play',
                        StoreLinks.googlePlay,
                      ),
                    ),
                    const SizedBox(height: 26),
                    const _InfoCard(),
                    const SizedBox(height: 26),
                    Text(
                      '© ${DateTime.now().year} SchatzApp. '
                      'All rights reserved.',
                      textAlign: TextAlign.center,
                      style: jakarta(fontSize: 13, color: AppColors.meta),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  const _StoreButton({
    required this.icon,
    required this.small,
    required this.big,
    required this.onTap,
  });

  final IconData icon;
  final String small;
  final String big;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: Material(
        color: AppColors.heading,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    small,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    big,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lavenderSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6DAFA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.laptop_mac_rounded, color: AppColors.brandDeep, size: 30),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'SchatzApp Web works on computers, laptops and tablets. '
              'Open this page on a bigger screen and scan the QR code '
              'with the app to sign in.',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: AppColors.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
