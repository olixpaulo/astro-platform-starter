import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../../shared/widgets/tts_button.dart';
import '../../voice/data/voice_repository.dart';

/// Modo conversação: duas pessoas falando idiomas diferentes,
/// com interface dividida (metade superior invertida para o interlocutor).
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _Message {
  const _Message({required this.original, required this.translated, required this.fromTop});

  final String original;
  final String translated;
  final bool fromTop;
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _recorder = AudioRecorder();
  String _topLang = 'en';
  String _bottomLang = 'pt';
  bool? _recordingTop; // null = ninguém a gravar
  bool _processing = false;
  final List<_Message> _messages = [];

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool isTop) async {
    if (_recordingTop != null) {
      if (_recordingTop != isTop) return; // o outro lado está a gravar
      final path = await _recorder.stop();
      setState(() {
        _recordingTop = null;
        _processing = true;
      });
      if (path != null) {
        final sourceLang = isTop ? _topLang : _bottomLang;
        final targetLang = isTop ? _bottomLang : _topLang;
        try {
          final result = await ref.read(voiceRepositoryProvider).translateAudio(
                filePath: path,
                sourceLang: sourceLang,
                targetLang: targetLang,
              );
          setState(() => _messages.add(_Message(
                original: result.recognizedText,
                translated: result.translatedText,
                fromTop: isTop,
              )));
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Falha ao traduzir. Tente novamente.')),
            );
          }
        }
      }
      setState(() => _processing = false);
    } else {
      if (await _recorder.hasPermission()) {
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: '${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        setState(() => _recordingTop = isTop);
      }
    }
  }

  Widget _half({required bool isTop}) {
    final lang = isTop ? _topLang : _bottomLang;
    final recording = _recordingTop == isTop;
    final scheme = Theme.of(context).colorScheme;
    final relevant = _messages.where((m) => m.fromTop != isTop).toList();
    final lastIncoming = relevant.isEmpty ? null : relevant.last;

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Chip(label: Text(lang.toUpperCase())),
        ),
        Expanded(
          child: Center(
            child: lastIncoming == null
                ? Text('Toque no microfone para falar',
                    style: TextStyle(color: scheme.onSurfaceVariant))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lastIncoming.translated,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        TtsButton(text: lastIncoming.translated, language: lang),
                      ],
                    ),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FloatingActionButton(
            heroTag: isTop ? 'mic-top' : 'mic-bottom',
            backgroundColor: recording ? scheme.error : scheme.primary,
            onPressed: _processing ? null : () => _toggle(isTop),
            child: Icon(recording ? Icons.stop : Icons.mic, color: scheme.onPrimary),
          ),
        ),
      ],
    );

    // O lado de cima fica rodado 180° para o interlocutor à frente
    return Expanded(
      child: isTop ? RotatedBox(quarterTurns: 2, child: content) : content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversação')),
      body: SafeArea(
        child: Column(
          children: [
            _half(isTop: true),
            Divider(height: 2, thickness: 2, color: Theme.of(context).colorScheme.outlineVariant),
            if (_processing) const LinearProgressIndicator(),
            _half(isTop: false),
          ],
        ),
      ),
    );
  }
}
