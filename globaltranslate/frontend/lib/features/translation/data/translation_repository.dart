import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/models.dart';

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  return TranslationRepository(ref.watch(apiClientProvider));
});

final languagesProvider = FutureProvider<List<Language>>((ref) {
  return ref.watch(translationRepositoryProvider).languages();
});

class TranslationRepository {
  TranslationRepository(this._dio);

  final Dio _dio;

  Future<List<Language>> languages() async {
    final response = await _dio.get('/translations/languages');
    return (response.data as List).map((e) => Language.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TranslationResult> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
    bool saveHistory = true,
  }) async {
    final response = await _dio.post('/translations', data: {
      'text': text,
      'source_lang': sourceLang,
      'target_lang': targetLang,
      'save_history': saveHistory,
    });
    return TranslationResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<({List<HistoryItem> items, int total})> history({
    int page = 1,
    String? search,
    bool favoritesOnly = false,
  }) async {
    final response = await _dio.get('/translations/history', queryParameters: {
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
      'favorites_only': favoritesOnly,
    });
    final data = response.data as Map<String, dynamic>;
    return (
      items: (data['items'] as List).map((e) => HistoryItem.fromJson(e as Map<String, dynamic>)).toList(),
      total: data['total'] as int,
    );
  }

  Future<void> setFavorite(String translationId, bool favorite) async {
    if (favorite) {
      await _dio.post('/translations/$translationId/favorite');
    } else {
      await _dio.delete('/translations/$translationId/favorite');
    }
  }

  Future<List<int>> textToSpeech({
    required String text,
    required String language,
    required String voiceGender,
    required double speed,
  }) async {
    final response = await _dio.post(
      '/voice/tts',
      data: {'text': text, 'language': language, 'voice_gender': voiceGender, 'speed': speed},
      options: Options(responseType: ResponseType.bytes),
    );
    return (response.data as List<int>);
  }
}
