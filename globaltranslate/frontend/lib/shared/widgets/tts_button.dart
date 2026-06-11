import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_provider.dart';
import '../../features/translation/data/translation_repository.dart';

/// Botão de pronúncia: sintetiza e reproduz o texto com as preferências
/// de voz (género e velocidade) das definições.
class TtsButton extends ConsumerStatefulWidget {
  const TtsButton({super.key, required this.text, required this.language});

  final String text;
  final String language;

  @override
  ConsumerState<TtsButton> createState() => _TtsButtonState();
}

class _TtsButtonState extends ConsumerState<TtsButton> {
  final _player = AudioPlayer();
  bool _loading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (widget.text.trim().isEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      final settings = ref.read(settingsProvider);
      final bytes = await ref.read(translationRepositoryProvider).textToSpeech(
            text: widget.text,
            language: widget.language,
            voiceGender: settings.voiceGender,
            speed: settings.speechSpeed,
          );
      await _player.play(BytesSource(Uint8List.fromList(bytes)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível reproduzir o áudio')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ouvir',
      onPressed: _play,
      icon: _loading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.volume_up_outlined),
    );
  }
}
