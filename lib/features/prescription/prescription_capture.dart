import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'prescription_ocr_parser.dart';

/// OCR data remains on device in temporary memory/cache, not persisted or sent.
class PrescriptionCapture extends StatefulWidget {
  const PrescriptionCapture({super.key, required this.onReviewCandidate});
  final ValueChanged<OcrPrescriptionCandidate> onReviewCandidate;

  @override
  State<PrescriptionCapture> createState() => _PrescriptionCaptureState();
}

class _PrescriptionCaptureState extends State<PrescriptionCapture> {
  final _picker = ImagePicker();
  final _transcription = TextEditingController();
  List<OcrPrescriptionCandidate> _candidates = const [];
  String? _imagePath;
  String? _error;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    _retrieveLostImage();
  }

  Future<void> _retrieveLostImage() async {
    try {
      final response = await _picker.retrieveLostData();
      if (!mounted || response.isEmpty) return;
      if (response.files?.isNotEmpty ?? false) {
        await _read(response.files!.first);
      } else if (response.exception != null) {
        setState(() => _error = 'Captura interrompida. Tente novamente.');
      }
    } catch (_) {
      // No interrupted photo to recover.
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_reading) return;
    try {
      final file = await _picker.pickImage(
        source: source, maxWidth: 2200, maxHeight: 2800,
        imageQuality: 92, requestFullMetadata: false,
      );
      if (file != null) await _read(file);
    } on PlatformException {
      if (mounted) setState(() => _error = 'Não foi possível acessar câmera ou galeria.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Falha ao selecionar imagem.');
    }
  }

  Future<void> _read(XFile file) async {
    if (!mounted) return;
    setState(() {
      _reading = true;
      _error = null;
      _imagePath = null;
      _transcription.clear();
      _candidates = const [];
    });
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final found = await recognizer.processImage(InputImage.fromFilePath(file.path));
      if (!mounted) return;
      setState(() {
        _imagePath = file.path;
        _transcription.text = found.text.trim();
        _candidates = extractPrescriptionCandidates(_transcription.text);
        if (_transcription.text.isEmpty) {
          _error = 'Nenhum texto identificado. Tente uma foto mais nítida ou digite os dados.';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Falha ao ler imagem. Use outra foto ou preencha manualmente.');
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _reading = false);
    }
  }

  void _reanalyze() {
    setState(() {
      _candidates = extractPrescriptionCandidates(_transcription.text);
      _error = _candidates.isEmpty
          ? 'Não foi encontrado medicamento com concentração em mg. Revise ou preencha manualmente.'
          : null;
    });
  }

  void _clear() {
    setState(() {
      _imagePath = null;
      _transcription.clear();
      _candidates = const [];
      _error = null;
    });
  }

  @override
  void dispose() {
    _transcription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.document_scanner_outlined, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ler prescrição por foto',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text('Reconhecimento local, sem enviar a imagem',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ])),
          ]),
          const SizedBox(height: 12),
          Text('Fotografe a prescrição inteira, com boa iluminação. '
            'O texto extraído pode conter erros: compare cada dose e unidade '
            'com o original antes de calcular.',
            style: TextStyle(height: 1.4, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 13),
          Row(children: [
            Expanded(child: FilledButton.icon(
              onPressed: _reading ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined), label: const Text('Tirar foto'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: _reading ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined), label: const Text('Galeria'))),
          ]),
          if (_reading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const Text('Reconhecendo texto…'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          if (_imagePath != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(_imagePath!), height: 76, width: 64,
                  fit: BoxFit.cover, cacheWidth: 160,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(
                '${_candidates.length} possível(is) medicamento(s) encontrado(s)',
                style: const TextStyle(fontWeight: FontWeight.w600))),
              IconButton(onPressed: _clear, tooltip: 'Limpar imagem e texto',
                icon: const Icon(Icons.delete_outline)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _transcription, minLines: 3, maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Texto extraído — editável',
                helperText: 'Corrija erros de leitura e toque em Reanalisar.',
                helperMaxLines: 2),
            ),
            Align(alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _reanalyze, icon: const Icon(Icons.refresh),
                label: const Text('Reanalisar texto'))),
            for (final item in _candidates) ...[
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                  color: scheme.surfaceContainerLow,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text([
                    if (item.form != null) item.form!.label,
                    if (item.strengthMgPerUnit != null)
                      '${item.strengthMgPerUnit} ${item.form?.strengthUnit ?? 'mg/mL ou mg/unidade'}',
                    if (item.doseMgPerAdministration != null)
                      '${item.doseMgPerAdministration} mg/tomada',
                    if (item.administrationsPerDay != null)
                      '${item.administrationsPerDay}x/dia',
                    if (item.durationDays != null)
                      '${item.durationDays} dias',
                  ].join(' • '), style: TextStyle(fontSize: 12,
                    color: scheme.onSurfaceVariant)),
                  if (item.warnings.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(item.warnings.join(' '),
                      style: TextStyle(color: scheme.error, fontSize: 12)),
                  ],
                  const SizedBox(height: 7),
                  Align(alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onReviewCandidate(item),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Revisar dados'))),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            Text('Não valida a prescrição, diagnóstico ou dose máxima. '
              'Selecione e revise cada medicamento separadamente.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }
}
