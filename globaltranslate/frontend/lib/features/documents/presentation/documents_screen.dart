import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Tradução de documentos: PDF, DOCX, TXT, PPTX.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  List<dynamic> _documents = [];
  bool _loading = true;
  String _targetLang = 'pt';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ref.read(apiClientProvider).get('/documents');
      setState(() => _documents = response.data as List);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'pptx'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;

    final contentTypes = {
      'pdf': 'application/pdf',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt': 'text/plain',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    };

    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        file.bytes!,
        filename: file.name,
        contentType: DioMediaType.parse(contentTypes[file.extension] ?? 'application/octet-stream'),
      ),
      'source_lang': 'auto',
      'target_lang': _targetLang,
    });

    try {
      await ref.read(apiClientProvider).post('/documents', data: form);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento em processamento')),
        );
      }
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        final detail = (e.response?.data is Map ? e.response?.data['detail'] : null) as String?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail ?? 'Falha no envio do documento')),
        );
      }
    }
  }

  Future<void> _viewResult(String id, String filename) async {
    final response = await ref.read(apiClientProvider).get('/documents/$id');
    final text = response.data['translated_text'] as String?;
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(filename),
        content: SingleChildScrollView(child: SelectableText(text ?? 'Ainda em processamento…')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documentos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        icon: const Icon(Icons.upload_file),
        label: const Text('Traduzir documento'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(child: Text('Sem documentos.\nSuporta PDF, DOCX, TXT e PPTX.', textAlign: TextAlign.center))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index] as Map<String, dynamic>;
                      final status = doc['status'] as String;
                      return ListTile(
                        leading: Icon(switch (status) {
                          'completed' => Icons.check_circle_outline,
                          'failed' => Icons.error_outline,
                          _ => Icons.hourglass_top,
                        }),
                        title: Text(doc['filename'] as String),
                        subtitle: Text('${doc['source_lang']} → ${doc['target_lang']} · $status'),
                        onTap: status == 'completed'
                            ? () => _viewResult(doc['id'] as String, doc['filename'] as String)
                            : null,
                      );
                    },
                  ),
                ),
    );
  }
}
