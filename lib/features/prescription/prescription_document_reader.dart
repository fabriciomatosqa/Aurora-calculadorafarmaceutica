import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';

/// Processes documents strictly on the device. It makes no network calls and
/// never infers a drug's maximum dose or whether a prescription is valid.
class PrescriptionDocumentReader {
  PrescriptionDocumentReader({ImagePicker? imagePicker})
      : _images = imagePicker ?? ImagePicker();

  final ImagePicker _images;
  static const int maxSizeBytes = 15 * 1024 * 1024;
  static const int maxPdfPages = 8;

  Future<PrescriptionDocument?> fromCamera() async {
    final photo = await _images.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 2400,
      maxHeight: 3000,
    );
    if (photo == null) return null;
    return _recognizeImage(photo.path, photo.name);
  }

  Future<PrescriptionDocument?> fromGallery() async {
    final photo = await _images.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 3000,
    );
    if (photo == null) return null;
    return _recognizeImage(photo.path, photo.name);
  }

  Future<PrescriptionDocument?> fromFile() async {
    // Android Storage Access Framework, without blanket storage permissions.
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: false,
    );
    if (selection == null || selection.files.isEmpty) return null;
    final document = selection.files.single;
    final path = document.path;
    if (path == null) {
      throw const PrescriptionReadException(
        'O arquivo selecionado não está disponível neste aparelho.',
      );
    }
    final extension = document.name.split('.').last.toLowerCase();
    if (extension == 'pdf') return _readPdf(path, document.name);
    if (['jpg', 'jpeg', 'png'].contains(extension)) {
      return _recognizeImage(path, document.name);
    }
    throw const PrescriptionReadException('Formato não suportado.');
  }

  Future<PrescriptionDocument> _recognizeImage(
      String path, String name) async {
    await _validateSize(path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final image = InputImage.fromFilePath(path);
      final recognized = await recognizer.processImage(image);
      final content = recognized.text.trim();
      if (content.isEmpty) {
        throw const PrescriptionReadException(
          'Não consegui ler o texto da imagem. Use uma foto nítida '
          'ou preencha os dados manualmente.',
        );
      }
      return PrescriptionDocument(name: name, text: content, fromOcr: true);
    } finally {
      await recognizer.close();
    }
  }

  Future<PrescriptionDocument> _readPdf(String path, String name) async {
    await _validateSize(path);
    final pdf = await PdfDocument.openFile(path);
    try {
      if (pdf.pages.length > maxPdfPages) {
        throw const PrescriptionReadException(
          'O PDF deve ter no máximo 8 páginas.',
        );
      }
      final buffer = StringBuffer();
      for (final page in pdf.pages) {
        final pageText = await page.loadText();
        final text = pageText?.fullText.trim() ?? '';
        if (text.isNotEmpty) {
          buffer.writeln(text);
          buffer.writeln();
        }
      }
      final content = buffer.toString().trim();
      if (content.isEmpty) {
        throw const PrescriptionReadException(
          'Este PDF não contém texto selecionável (pode ser digitalizado). '
          'Use a opção Foto/Imagem para OCR ou transcreva manualmente.',
        );
      }
      return PrescriptionDocument(name: name, text: content, fromOcr: false);
    } finally {
      await pdf.dispose();
    }
  }

  Future<void> _validateSize(String path) async {
    final size = await File(path).length();
    if (size == 0 || size > maxSizeBytes) {
      throw const PrescriptionReadException(
        'O arquivo precisa ter até 15 MB e não pode estar vazio.',
      );
    }
  }
}

class PrescriptionDocument {
  const PrescriptionDocument({
    required this.name,
    required this.text,
    required this.fromOcr,
  });

  final String name;
  final String text;
  final bool fromOcr;
}

class PrescriptionReadException implements Exception {
  const PrescriptionReadException(this.message);

  final String message;
  @override
  String toString() => message;
}
