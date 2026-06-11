import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../translation/data/translation_repository.dart';

/// Modo offline: download de pacotes de idiomas para traduções básicas sem internet.
class OfflineScreen extends ConsumerStatefulWidget {
  const OfflineScreen({super.key});

  @override
  ConsumerState<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends ConsumerState<OfflineScreen> {
  Set<String> _downloaded = {};

  @override
  void initState() {
    super.initState();
    _loadDownloaded();
  }

  Future<void> _loadDownloaded() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _downloaded = (prefs.getStringList('offline_packs') ?? []).toSet());
  }

  Future<void> _toggle(String code) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_downloaded.contains(code)) {
        _downloaded.remove(code);
      } else {
        _downloaded.add(code);
      }
    });
    await prefs.setStringList('offline_packs', _downloaded.toList());
  }

  @override
  Widget build(BuildContext context) {
    final languages = ref.watch(languagesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pacotes offline')),
      body: languages.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Não foi possível carregar os idiomas')),
        data: (langs) {
          final offline = langs.where((l) => l.code != 'auto').toList();
          return ListView.builder(
            itemCount: offline.length,
            itemBuilder: (context, index) {
              final lang = offline[index];
              final downloaded = _downloaded.contains(lang.code);
              return ListTile(
                title: Text(lang.name),
                subtitle: lang.nativeName.isEmpty ? null : Text(lang.nativeName),
                trailing: IconButton(
                  tooltip: downloaded ? 'Remover pacote' : 'Descarregar pacote',
                  icon: Icon(downloaded ? Icons.download_done : Icons.download_outlined),
                  color: downloaded ? Theme.of(context).colorScheme.primary : null,
                  onPressed: () => _toggle(lang.code),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
