import 'package:go_router/go_router.dart';

import 'features/auth/sign_in_page.dart';

/// App routes. The signed-in shell (/chats, /calls, ...) is added in a later
/// phase together with the session redirect.
final appRouter = GoRouter(
  initialLocation: SignInPage.routePath,
  routes: [
    GoRoute(
      path: '/',
      redirect: (_, _) => SignInPage.routePath,
    ),
    GoRoute(
      path: SignInPage.routePath,
      builder: (_, _) => const SignInPage(),
    ),
  ],
);
