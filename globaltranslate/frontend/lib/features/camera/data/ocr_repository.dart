import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

final ocrRepositoryProvider = Provider<OcrRepository>((ref) {
  return OcrRepository(ref.watch(apiClientProvider));
});

class OcrBlock {
  const OcrBlock({
    required this.text,
    this.translatedText,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String text;
  final String? translatedText;
  final double x, y, width, height;

  factory OcrBlock.fromJson(Map<String, dynamic> json) => OcrBlock(
        text: json['text'] as String,
        translatedText: json['translated_text'] as String?,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );
}

class OcrResult {
  const OcrResult({this.detectedLang, required this.fullText, this.translatedText, required this.blocks});

  final String? detectedLang;
  final String fullText;
  final String? translatedText;
  final List<OcrBlock> blocks;

  factory OcrResult.fromJson(Map<String, dynamic> json) => OcrResult(
        detectedLang: json['detected_lang'] as String?,
        fullText: json['full_text'] as String,
        translatedText: json['translated_text'] as String?,
        blocks: ((json['blocks'] as List?) ?? [])
            .map((e) => OcrBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class OcrRepository {
  OcrRepository(this._dio);

  final Dio _dio;

  Future<OcrResult> translateImage({required String filePath, required String targetLang}) async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
      'target_lang': targetLang,
    });
    final response = await _dio.post('/ocr/translate', data: form);
    return OcrResult.fromJson(response.data as Map<String, dynamic>);
  }
}
