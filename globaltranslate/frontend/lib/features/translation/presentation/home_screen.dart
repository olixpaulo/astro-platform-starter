import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/language_bar.dart';
import '../../../shared/widgets/tts_button.dart';
import '../data/translation_repository.dart';
import '../providers/translation_provider.dart';

/// Ecrã principal: tradução de texto em tempo real.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(translationProvider);
    final notifier = ref.read(translationProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GlobalTranslate'),
        actions: [
          IconButton(
            tooltip: 'Documentos',
            icon: const Icon(Icons.description_outlined),
            onPressed: () => context.push('/documents'),
          ),
          IconButton(
            tooltip: 'Definições',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LanguageBar(
              sourceLang: state.sourceLang,
              targetLang: state.targetLang,
              onSourceChanged: notifier.setSourceLang,
              onTargetChanged: notifier.setTargetLang,
              onSwap: notifier.swapLanguages,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _controller,
                      onChanged: notifier.onTextChanged,
                      maxLines: 6,
                      minLines: 3,
                      maxLength: 10000,
                      decoration: const InputDecoration(
                        hintText: 'Escreva para traduzir…',
                        border: InputBorder.none,
                        fillColor: Colors.transparent,
                        counterText: '',
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TtsButton(text: _controller.text, language: state.sourceLang),
                        IconButton(
                          tooltip: 'Limpar',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            notifier.onTextChanged('');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (state.isTranslating) const LinearProgressIndicator(),
            if (state.error != null)
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(state.error!, style: TextStyle(color: scheme.onErrorContainer)),
                ),
              ),
            if (state.result != null) ...[
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (state.result!.detectedLang != null && state.sourceLang == 'auto')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Idioma detetado: ${state.result!.detectedLang}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      SelectableText(
                        state.result!.translatedText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TtsButton(text: state.result!.translatedText, language: state.targetLang),
                          IconButton(
                            tooltip: 'Copiar',
                            icon: const Icon(Icons.copy_outlined),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: state.result!.translatedText));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tradução copiada')),
                              );
                            },
                          ),
                          if (state.result!.id != null)
                            IconButton(
                              tooltip: 'Adicionar aos favoritos',
                              icon: const Icon(Icons.star_border),
                              onPressed: () async {
                                await ref
                                    .read(translationRepositoryProvider)
                                    .setFavorite(state.result!.id!, true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Adicionado aos favoritos')),
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (state.result!.alternatives.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Alternativas', style: Theme.of(context).textTheme.labelLarge),
                for (final alt in state.result!.alternatives)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.alt_route, size: 18),
                    title: Text(alt),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
