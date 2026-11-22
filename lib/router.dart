import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'features/auth/sign_in_page.dart';
import 'features/calls/calls_page.dart';
import 'features/chats/chats_page.dart';
import 'features/placeholder/coming_soon_page.dart';
import 'shell/app_shell.dart';

/// App routes. The session redirect (signed out -> /login) is added when the
/// QR sign-in backend is wired. Until then every route is reachable so the
/// UI can be reviewed on the preview link.
final appRouter = GoRouter(
  initialLocation: SignInPage.routePath,
  routes: [
    GoRoute(path: '/', redirect: (_, _) => SignInPage.routePath),
    GoRoute(
      path: SignInPage.routePath,
      builder: (_, _) => const SignInPage(),
    ),
    ShellRoute(
      builder: (_, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: ChatsPage.routePath,
          pageBuilder: (_, _) => const NoTransitionPage(child: ChatsPage()),
        ),
        GoRoute(
          path: CallsPage.routePath,
          pageBuilder: (_, _) => const NoTransitionPage(child: CallsPage()),
        ),
        GoRoute(
          path: '/wallets',
          pageBuilder: (_, _) => const NoTransitionPage(
            child: ComingSoonPage(
              title: 'Wallets',
              icon: Icons.account_balance_wallet_outlined,
              message: 'The Wallets screen will be built from your next UI.',
            ),
          ),
        ),
        GoRoute(
          path: '/stories',
          pageBuilder: (_, _) => const NoTransitionPage(
            child: ComingSoonPage(
              title: 'Stories',
              icon: Icons.motion_photos_on_outlined,
              message: 'The Stories screen will be built from your next UI.',
            ),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (_, _) => const NoTransitionPage(
            child: ComingSoonPage(
              title: 'Profile',
              icon: Icons.account_circle_outlined,
              message: 'The Profile screen will be built from your next UI.',
            ),
          ),
        ),
      ],
    ),
  ],
);
