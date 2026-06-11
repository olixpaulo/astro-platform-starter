import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/tts_button.dart';
import '../../translation/data/translation_repository.dart';
import '../../translation/domain/models.dart';

/// Histórico de traduções com pesquisa e favoritos.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _search = '';
  bool _favoritesOnly = false;
  List<HistoryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(translationRepositoryProvider)
          .history(search: _search, favoritesOnly: _favoritesOnly);
      setState(() => _items = result.items);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível carregar o histórico')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite(HistoryItem item) async {
    await ref.read(translationRepositoryProvider).setFavorite(item.id, !item.isFavorite);
    setState(() {
      final index = _items.indexOf(item);
      _items[index] = item.copyWith(isFavorite: !item.isFavorite);
      if (_favoritesOnly && !_items[index].isFavorite) _items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        actions: [
          IconButton(
            tooltip: _favoritesOnly ? 'Mostrar tudo' : 'Só favoritos',
            icon: Icon(_favoritesOnly ? Icons.star : Icons.star_border),
            onPressed: () {
              setState(() => _favoritesOnly = !_favoritesOnly);
              _load();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Pesquisar no histórico',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (value) {
                  _search = value;
                  _load();
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('Sem traduções'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: ListTile(
                                  title: Text(item.sourceText, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      item.translatedText,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Theme.of(context).colorScheme.primary),
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TtsButton(text: item.translatedText, language: item.targetLang),
                                      IconButton(
                                        icon: Icon(
                                          item.isFavorite ? Icons.star : Icons.star_border,
                                          color: item.isFavorite ? Colors.amber : null,
                                        ),
                                        onPressed: () => _toggleFavorite(item),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
