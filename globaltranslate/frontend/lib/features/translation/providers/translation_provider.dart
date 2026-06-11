import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../data/translation_repository.dart';
import '../domain/models.dart';

class TranslationState {
  const TranslationState({
    this.sourceLang = 'auto',
    this.targetLang = 'en',
    this.result,
    this.isTranslating = false,
    this.error,
  });

  final String sourceLang;
  final String targetLang;
  final TranslationResult? result;
  final bool isTranslating;
  final String? error;

  TranslationState copyWith({
    String? sourceLang,
    String? targetLang,
    TranslationResult? result,
    bool? isTranslating,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return TranslationState(
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      result: clearResult ? null : (result ?? this.result),
      isTranslating: isTranslating ?? this.isTranslating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final translationProvider =
    NotifierProvider<TranslationNotifier, TranslationState>(TranslationNotifier.new);

class TranslationNotifier extends Notifier<TranslationState> {
  Timer? _debounce;
  String _pendingText = '';

  @override
  TranslationState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const TranslationState();
  }

  void setSourceLang(String code) => state = state.copyWith(sourceLang: code);

  void setTargetLang(String code) {
    state = state.copyWith(targetLang: code);
    if (_pendingText.isNotEmpty) _translateNow(_pendingText);
  }

  void swapLanguages() {
    if (state.sourceLang == 'auto') return;
    state = state.copyWith(sourceLang: state.targetLang, targetLang: state.sourceLang);
    if (_pendingText.isNotEmpty) _translateNow(_pendingText);
  }

  /// Tradução em tempo real: chamada a cada alteração do texto, com debounce.
  void onTextChanged(String text) {
    _pendingText = text;
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      state = state.copyWith(clearResult: true, clearError: true, isTranslating: false);
      return;
    }
    _debounce = Timer(AppConstants.translateDebounce, () => _translateNow(text));
  }

  Future<void> _translateNow(String text) async {
    state = state.copyWith(isTranslating: true, clearError: true);
    try {
      final result = await ref.read(translationRepositoryProvider).translate(
            text: text,
            sourceLang: state.sourceLang,
            targetLang: state.targetLang,
          );
      // Ignora respostas obsoletas (o utilizador continuou a escrever)
      if (text == _pendingText) {
        state = state.copyWith(result: result, isTranslating: false);
      }
    } catch (_) {
      if (text == _pendingText) {
        state = state.copyWith(isTranslating: false, error: 'Falha na tradução. Verifique a ligação.');
      }
    }
  }
}
