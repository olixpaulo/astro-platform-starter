import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/translation/data/translation_repository.dart';
import '../../features/translation/domain/models.dart';

/// Barra de seleção de idiomas (origem ⇄ destino) reutilizada em vários ecrãs.
class LanguageBar extends ConsumerWidget {
  const LanguageBar({
    super.key,
    required this.sourceLang,
    required this.targetLang,
    required this.onSourceChanged,
    required this.onTargetChanged,
    this.onSwap,
    this.allowAutoDetect = true,
  });

  final String sourceLang;
  final String targetLang;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onTargetChanged;
  final VoidCallback? onSwap;
  final bool allowAutoDetect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languages = ref.watch(languagesProvider);

    return languages.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
      data: (langs) {
        final source = allowAutoDetect ? [Language.auto, ...langs] : langs;
        return Row(
          children: [
            Expanded(
              child: _LanguageButton(
                languages: source,
                selected: sourceLang,
                onChanged: onSourceChanged,
              ),
            ),
            IconButton(
              tooltip: 'Trocar idiomas',
              onPressed: sourceLang == 'auto' ? null : onSwap,
              icon: const Icon(Icons.swap_horiz),
            ),
            Expanded(
              child: _LanguageButton(
                languages: langs,
                selected: targetLang,
                onChanged: onTargetChanged,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.languages, required this.selected, required this.onChanged});

  final List<Language> languages;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = languages.where((l) => l.code == selected).firstOrNull;
    return OutlinedButton(
      onPressed: () async {
        final picked = await showModalBottomSheet<Language>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _LanguagePicker(languages: languages),
        );
        if (picked != null) onChanged(picked.code);
      },
      child: Text(current?.name ?? selected, overflow: TextOverflow.ellipsis),
    );
  }
}

class _LanguagePicker extends StatefulWidget {
  const _LanguagePicker({required this.languages});

  final List<Language> languages;

  @override
  State<_LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<_LanguagePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.languages
        .where((l) =>
            l.name.toLowerCase().contains(_query.toLowerCase()) ||
            l.nativeName.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Pesquisar idioma',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final lang = filtered[index];
                return ListTile(
                  title: Text(lang.name),
                  subtitle: lang.nativeName.isEmpty ? null : Text(lang.nativeName),
                  onTap: () => Navigator.of(context).pop(lang),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
