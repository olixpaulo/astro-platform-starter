class Language {
  const Language({required this.code, required this.name, required this.nativeName});

  final String code;
  final String name;
  final String nativeName;

  factory Language.fromJson(Map<String, dynamic> json) => Language(
        code: json['code'] as String,
        name: json['name'] as String,
        nativeName: (json['native_name'] as String?) ?? '',
      );

  static const auto = Language(code: 'auto', name: 'Detetar idioma', nativeName: '');
}

class TranslationResult {
  const TranslationResult({
    this.id,
    required this.sourceText,
    required this.translatedText,
    this.detectedLang,
    this.alternatives = const [],
  });

  final String? id;
  final String sourceText;
  final String translatedText;
  final String? detectedLang;
  final List<String> alternatives;

  factory TranslationResult.fromJson(Map<String, dynamic> json) => TranslationResult(
        id: json['id'] as String?,
        sourceText: json['source_text'] as String,
        translatedText: json['translated_text'] as String,
        detectedLang: json['detected_lang'] as String?,
        alternatives: ((json['alternatives'] as List?) ?? []).cast<String>(),
      );
}

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.sourceLang,
    required this.targetLang,
    required this.sourceText,
    required this.translatedText,
    required this.isFavorite,
    required this.createdAt,
  });

  final String id;
  final String sourceLang;
  final String targetLang;
  final String sourceText;
  final String translatedText;
  final bool isFavorite;
  final DateTime createdAt;

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as String,
        sourceLang: json['source_lang'] as String,
        targetLang: json['target_lang'] as String,
        sourceText: json['source_text'] as String,
        translatedText: json['translated_text'] as String,
        isFavorite: (json['is_favorite'] as bool?) ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  HistoryItem copyWith({bool? isFavorite}) => HistoryItem(
        id: id,
        sourceLang: sourceLang,
        targetLang: targetLang,
        sourceText: sourceText,
        translatedText: translatedText,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt,
      );
}
