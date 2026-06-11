import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/camera/presentation/camera_screen.dart';
import '../../features/conversation/presentation/conversation_screen.dart';
import '../../features/documents/presentation/documents_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/offline/presentation/offline_screen.dart';
import '../../features/premium/presentation/premium_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/translation/presentation/home_screen.dart';
import '../../features/voice/presentation/voice_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (auth.isLoading) return null;
      final loggedIn = auth.valueOrNull != null;
      final onAuthPage = {'/login', '/register', '/forgot-password'}.contains(state.matchedLocation);
      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/voice', builder: (_, __) => const VoiceScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/conversation', builder: (_, __) => const ConversationScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/camera', builder: (_, __) => const CameraScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          ]),
        ],
      ),
      GoRoute(path: '/documents', builder: (_, __) => const DocumentsScreen()),
      GoRoute(path: '/offline', builder: (_, __) => const OfflineScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/premium', builder: (_, __) => const PremiumScreen()),
    ],
  );
});

class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.translate), label: 'Texto'),
          NavigationDestination(icon: Icon(Icons.mic), label: 'Voz'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), label: 'Conversa'),
          NavigationDestination(icon: Icon(Icons.camera_alt_outlined), label: 'Câmara'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'),
        ],
      ),
    );
  }
}
