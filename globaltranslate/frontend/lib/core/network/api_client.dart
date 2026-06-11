import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
  ));

  dio.interceptors.add(_AuthInterceptor(storage, dio));
  return dio;
});

/// Anexa o access token e renova-o automaticamente em respostas 401.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage, this._dio);

  final TokenStorage _storage;
  final Dio _dio;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthCall = err.requestOptions.path.contains('/auth/');
    if (err.response?.statusCode == 401 && !isAuthCall) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        try {
          final retried = await _dio.fetch(err.requestOptions);
          return handler.resolve(retried);
        } catch (_) {}
      }
    }
    handler.next(err);
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _storage.refreshToken;
    if (refresh == null) return false;
    try {
      final response = await Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl))
          .post('/auth/refresh', data: {'refresh_token': refresh});
      await _storage.saveTokens(
        access: response.data['access_token'] as String,
        refresh: response.data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      await _storage.clear();
      return false;
    }
  }
}
