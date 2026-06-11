import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider));
});

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;

  Future<void> register({required String email, required String password, String fullName = ''}) async {
    await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'full_name': fullName,
    });
  }

  Future<void> login({required String email, required String password}) async {
    final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    await _storage.saveTokens(
      access: response.data['access_token'] as String,
      refresh: response.data['refresh_token'] as String,
    );
  }

  Future<void> logout() async {
    final refresh = await _storage.refreshToken;
    if (refresh != null) {
      try {
        await _dio.post('/auth/logout', data: {'refresh_token': refresh});
      } catch (_) {}
    }
    await _storage.clear();
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({required String token, required String newPassword}) async {
    await _dio.post('/auth/reset-password', data: {'token': token, 'new_password': newPassword});
  }

  Future<User?> currentUser() async {
    final token = await _storage.accessToken;
    if (token == null) return null;
    try {
      final response = await _dio.get('/users/me');
      return User.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
