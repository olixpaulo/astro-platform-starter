import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../../shared/widgets/language_bar.dart';
import '../../../shared/widgets/tts_button.dart';
import '../data/voice_repository.dart';

/// Tradução por voz: gravar → reconhecer → traduzir → ouvir.
class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen> {
  final _recorder = AudioRecorder();
  bool _recording = false;
  bool _processing = false;
  String _sourceLang = 'auto';
  String _targetLang = 'en';
  VoiceTranslation? _result;
  String? _error;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() {
        _recording = false;
        _processing = true;
        _error = null;
      });
      if (path != null) {
        try {
          final result = await ref.read(voiceRepositoryProvider).translateAudio(
                filePath: path,
                sourceLang: _sourceLang,
                targetLang: _targetLang,
              );
          setState(() => _result = result);
        } catch (_) {
          setState(() => _error = 'Não foi possível traduzir o áudio.');
        }
      }
      setState(() => _processing = false);
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await _tempPath();
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: dir);
        setState(() {
          _recording = true;
          _result = null;
          _error = null;
        });
      } else {
        setState(() => _error = 'Permissão de microfone negada.');
      }
    }
  }

  Future<String> _tempPath() async {
    return '${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tradução por voz')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              LanguageBar(
                sourceLang: _sourceLang,
                targetLang: _targetLang,
                onSourceChanged: (code) => setState(() => _sourceLang = code),
                onTargetChanged: (code) => setState(() => _targetLang = code),
                onSwap: () => setState(() {
                  final tmp = _sourceLang;
                  _sourceLang = _targetLang;
                  _targetLang = tmp;
                }),
              ),
              Expanded(
                child: _result == null
                    ? Center(
                        child: Text(
                          _error ??
                              (_processing
                                  ? 'A processar…'
                                  : _recording
                                      ? 'A ouvir… toque para parar'
                                      : 'Toque no microfone e fale'),
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView(
                        children: [
                          const SizedBox(height: 16),
                          Card(
                            child: ListTile(
                              title: Text(_result!.recognizedText),
                              subtitle: Text('Reconhecido (${_result!.detectedLang ?? _sourceLang})'),
                            ),
                          ),
                          Card(
                            color: scheme.primaryContainer,
                            child: ListTile(
                              title: Text(
                                _result!.translatedText,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              subtitle: Text('Tradução ($_targetLang)'),
                              trailing: TtsButton(text: _result!.translatedText, language: _targetLang),
                            ),
                          ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: FloatingActionButton.large(
                  onPressed: _processing ? null : _toggleRecording,
                  backgroundColor: _recording ? scheme.error : scheme.primary,
                  child: _processing
                      ? const CircularProgressIndicator()
                      : Icon(_recording ? Icons.stop : Icons.mic, color: scheme.onPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
