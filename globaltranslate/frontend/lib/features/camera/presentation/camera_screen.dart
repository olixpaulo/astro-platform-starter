import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ocr_repository.dart';

/// Tradução por câmara: captura/galeria → OCR → sobreposição da tradução.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  final _picker = ImagePicker();
  String _targetLang = 'pt';
  XFile? _image;
  OcrResult? _result;
  bool _processing = false;
  bool _showOverlay = true;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, maxWidth: 1920, imageQuality: 88);
    if (file == null) return;
    setState(() {
      _image = file;
      _result = null;
      _processing = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(ocrRepositoryProvider)
          .translateImage(filePath: file.path, targetLang: _targetLang);
      setState(() => _result = result);
    } catch (_) {
      setState(() => _error = 'Não foi possível ler texto na imagem.');
    } finally {
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tradução por câmara'),
        actions: [
          if (_result != null)
            IconButton(
              tooltip: _showOverlay ? 'Ver original' : 'Ver tradução',
              icon: Icon(_showOverlay ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _showOverlay = !_showOverlay),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _image == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 72, color: scheme.primary),
                          const SizedBox(height: 16),
                          const Text('Capture uma imagem com texto para traduzir'),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => Stack(
                        fit: StackFit.expand,
                        children: [
                          kIsWeb
                              ? Image.network(_image!.path, fit: BoxFit.contain)
                              : Image.file(File(_image!.path), fit: BoxFit.contain),
                          if (_processing)
                            Container(
                              color: Colors.black38,
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                          if (_result != null && _showOverlay)
                            for (final block in _result!.blocks)
                              Positioned(
                                left: block.x * constraints.maxWidth,
                                top: block.y * constraints.maxHeight,
                                width: block.width * constraints.maxWidth,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  color: scheme.primary.withOpacity(0.85),
                                  child: Text(
                                    block.translatedText ?? block.text,
                                    style: TextStyle(color: scheme.onPrimary, fontSize: 13),
                                  ),
                                ),
                              ),
                          if (_error != null)
                            Center(
                              child: Card(
                                color: scheme.errorContainer,
                                child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            if (_result?.translatedText != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(_result!.translatedText!),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _processing ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Câmara'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _processing ? null : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galeria'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
