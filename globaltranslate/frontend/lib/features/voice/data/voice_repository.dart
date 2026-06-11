import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

final voiceRepositoryProvider = Provider<VoiceRepository>((ref) {
  return VoiceRepository(ref.watch(apiClientProvider));
});

class VoiceTranslation {
  const VoiceTranslation({
    required this.recognizedText,
    required this.translatedText,
    this.detectedLang,
  });

  final String recognizedText;
  final String translatedText;
  final String? detectedLang;

  factory VoiceTranslation.fromJson(Map<String, dynamic> json) => VoiceTranslation(
        recognizedText: json['recognized_text'] as String,
        translatedText: json['translated_text'] as String,
        detectedLang: json['detected_lang'] as String?,
      );
}

class VoiceRepository {
  VoiceRepository(this._dio);

  final Dio _dio;

  Future<VoiceTranslation> translateAudio({
    required String filePath,
    required String sourceLang,
    required String targetLang,
  }) async {
    final form = FormData.fromMap({
      'audio': await MultipartFile.fromFile(filePath, filename: 'recording.m4a'),
      'source_lang': sourceLang,
      'target_lang': targetLang,
    });
    final response = await _dio.post('/voice/translate', data: form);
    return VoiceTranslation.fromJson(response.data as Map<String, dynamic>);
  }
}
