import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/user.dart';

/// Estado de sessão: null = não autenticado.
final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() => ref.read(authRepositoryProvider).currentUser();

  Future<void> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.login(email: email, password: password);
    state = AsyncData(await repo.currentUser());
  }

  Future<void> register(String email, String password, String fullName) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.register(email: email, password: password, fullName: fullName);
    await login(email, password);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}
