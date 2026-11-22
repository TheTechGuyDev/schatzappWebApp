import 'package:go_router/go_router.dart';

import 'auth/web_auth.dart';
import 'features/auth/sign_in_page.dart';
import 'features/calls/calls_page.dart';
import 'features/chats/chats_page.dart';
import 'features/get_app/get_app_page.dart';
import 'features/profile/profile_page.dart';
import 'features/stories/stories_page.dart';
import 'features/wallet/wallet_page.dart';
import 'platform/device_check.dart';
import 'shell/app_shell.dart';

/// App routes. Phones always land on the "Get the app" page: SchatzApp Web
/// is for computers and tablets only. Signed-out visitors only see /login.
final appRouter = GoRouter(
  initialLocation: isPhoneDevice ? GetAppPage.routePath : '/chats',
  refreshListenable: WebAuth.instance,
  redirect: (_, state) {
    final path = state.uri.path;
    final onGetApp = path == GetAppPage.routePath;
    if (isPhoneDevice) return onGetApp ? null : GetAppPage.routePath;
    if (onGetApp) return SignInPage.routePath;
    final onLogin = path == SignInPage.routePath;
    final signedIn = WebAuth.instance.signedIn;
    if (!signedIn && !onLogin) return SignInPage.routePath;
    if (signedIn && (onLogin || path == '/')) return '/chats';
    return null;
  },
  routes: [
    GoRoute(path: GetAppPage.routePath, builder: (_, _) => const GetAppPage()),
    GoRoute(path: '/', redirect: (_, _) => SignInPage.routePath),
    GoRoute(path: SignInPage.routePath, builder: (_, _) => const SignInPage()),
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
          path: WalletPage.routePath,
          pageBuilder: (_, _) => const NoTransitionPage(child: WalletPage()),
        ),
        GoRoute(
          path: StoriesPage.routePath,
          pageBuilder: (_, _) => const NoTransitionPage(child: StoriesPage()),
        ),
        GoRoute(
          path: ProfilePage.routePath,
          pageBuilder: (_, _) => const NoTransitionPage(child: ProfilePage()),
        ),
      ],
    ),
  ],
);
