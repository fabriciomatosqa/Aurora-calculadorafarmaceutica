import '../../domain/prescription.dart';

/// OCR offers candidates, never an authenticated medical prescription.
/// Values MUST be compared visually against the original before calculation.
class OcrPrescriptionCandidate {
  const OcrPrescriptionCandidate({
    required this.name,
    required this.sourceText,
    required this.warnings,
    this.form,
    this.strengthMgPerUnit,
    this.doseMgPerAdministration,
    this.administrationsPerDay,
    this.durationDays,
  });

  final String name;
  final String sourceText;
  final PharmaceuticalForm? form;
  final double? strengthMgPerUnit;
  final double? doseMgPerAdministration;
  final int? administrationsPerDay;
  final int? durationDays;
  final List<String> warnings;

  bool get hasBasicSchedule =>
      form != null &&
      strengthMgPerUnit != null &&
      doseMgPerAdministration != null &&
      administrationsPerDay != null &&
      durationDays != null &&
      warnings.isEmpty;
}

double? _decimal(String? raw) =>
    raw == null ? null : double.tryParse(raw.replaceAll(',', '.'));

/// A deliberately conservative parser for simple, fixed-dose schedules.
/// It does not infer missing values or a clinical maximum from drug names.
List<OcrPrescriptionCandidate> extractPrescriptionCandidates(String raw) {
  if (raw.trim().isEmpty) return const [];

  final heading = RegExp(
    r'^(?:\d{1,2}[.)]\s*)?([a-zà-ÿ][a-zà-ÿ0-9+/-]*(?:\s+[a-zà-ÿ][a-zà-ÿ0-9+/-]*){0,7})\s+(\d+(?:[.,]\d+)?)\s*mg\b',
    caseSensitive: false,
  );
  final lines = raw.split(RegExp(r'\r?\n')).map((e) => e.trim())
      .where((e) => e.isNotEmpty).toList();
  final blocks = <List<String>>[];
  for (final line in lines) {
    final match = heading.firstMatch(line);
    final firstWord = line.toLowerCase().split(RegExp(r'\s+')).first;
    final isInstruction = <String>{
      'tomar', 'usar', 'ingerir', 'aplicar', 'administrar', 'uso',
      'receita', 'prescrição', 'paciente', 'dr.', 'dra.',
    }.contains(firstWord);
    if (match != null && !isInstruction) {
      blocks.add([line]);
    } else if (blocks.isNotEmpty && blocks.last.length < 6) {
      blocks.last.add(line);
    }
  }

  final results = <OcrPrescriptionCandidate>[];
  for (final block in blocks.take(30)) {
    final head = heading.firstMatch(block.first);
    if (head == null) continue;
    final name = head.group(1)!.trim();
    final text = block.join(' ');
    final normalized = text.toLowerCase();
    final warnings = <String>[];

    final liquid = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*mg\s*(?:/|em)\s*(\d+(?:[.,]\d+)?)\s*ml\b',
      caseSensitive: false,
    ).firstMatch(block.first);
    final perMl = RegExp(r'(\d+(?:[.,]\d+)?)\s*mg\s*/\s*ml\b',
        caseSensitive: false).firstMatch(block.first);

    PharmaceuticalForm? form;
    if (RegExp(r'suspens[aã]o', caseSensitive: false).hasMatch(text)) {
      form = PharmaceuticalForm.oralSuspension;
    } else if (RegExp(r'solu[çc][aã]o|xarope', caseSensitive: false)
        .hasMatch(text)) {
      form = PharmaceuticalForm.oralSolution;
    } else if (RegExp(r'comprimid', caseSensitive: false).hasMatch(text)) {
      form = PharmaceuticalForm.tablet;
    } else if (RegExp(r'c[aá]psul', caseSensitive: false).hasMatch(text)) {
      form = PharmaceuticalForm.capsule;
    } else if (RegExp(r'sach[eê]', caseSensitive: false).hasMatch(text)) {
      form = PharmaceuticalForm.sachet;
    } else if (liquid != null || perMl != null) {
      // Identify concentration units only; formulation still needs review.
      warnings.add('Forma líquida não identificada (solução/suspensão).');
    } else {
      warnings.add('Forma farmacêutica não identificada.');
    }

    double? strength;
    if (liquid != null) {
      final mg = _decimal(liquid.group(1));
      final ml = _decimal(liquid.group(2));
      if (mg != null && ml != null && ml > 0) strength = mg / ml;
    } else if (perMl != null) {
      strength = _decimal(perMl.group(1));
    } else if (form != null && !form.isLiquid) {
      strength = _decimal(head.group(2));
    }
    if (form?.isLiquid == true && liquid == null && perMl == null) {
      warnings.add('Concentração do líquido não está em mg/mL.');
    }

    double? dose;
    if (form != null && strength != null && strength > 0) {
      final units = form.isLiquid
          ? RegExp(r'(?:tomar|usar|administrar)\s*(\d+(?:[.,]\d+)?)\s*ml\b',
              caseSensitive: false).firstMatch(text)
          : RegExp(
              r'(?:tomar|ingerir|usar)\s*(\d+)\s*(?:comprimidos?|c[aá]psulas?|sach[eê]s?)\b',
              caseSensitive: false,
            ).firstMatch(text);
      final n = _decimal(units?.group(1));
      if (n != null && n > 0 && n <= 100) dose = n * strength;
    }

    int? frequency;
    final hourly = RegExp(
      r'(?:a cada|de)\s*(\d{1,2})\s*(?:em\s*\d{1,2}\s*)?(?:horas?|h)\b|(\d{1,2})\s*/\s*\2\s*h\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (hourly != null) {
      final hrs = int.tryParse(hourly.group(1) ?? hourly.group(2) ?? '');
      if (hrs != null && hrs > 0 && hrs <= 24 && 24 % hrs == 0) {
        frequency = 24 ~/ hrs;
      }
    }
    final daily = RegExp(
      r'(\d{1,2})\s*(?:x|vez(?:es)?)\s*(?:ao|por)\s*dia\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (daily != null) frequency = int.tryParse(daily.group(1)!);
    final once = RegExp(r'\buma vez (?:ao|por) dia\b', caseSensitive: false);
    if (frequency == null && once.hasMatch(text)) frequency = 1;
    if (frequency != null && (frequency < 1 || frequency > 24)) frequency = null;

    final duration = RegExp(r'(?:por|durante)\s*(\d{1,3})\s*dias?\b',
        caseSensitive: false).firstMatch(text);
    final days = duration == null ? null : int.tryParse(duration.group(1)!);
    final validDays = days != null && days >= 1 && days <= 365 ? days : null;

    if (RegExp(
      r'\bsos\b|se necess[aá]rio|conforme orienta|uso cont[ií]nuo|'
      r'mg\s*/\s*kg|ajuste|redu[çc][aã]o|aumentar|diminuir|'
      r'dias alternados|em dias alternados|se dor',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      warnings.add('Esquema variável/SOS ou dose individualizada: revisar sem cálculo automático.');
    }
    if (strength == null || !strength.isFinite || strength <= 0) {
      warnings.add('Concentração não identificada com segurança.');
    }
    if (dose == null) warnings.add('Dose por administração não identificada.');
    if (frequency == null) warnings.add('Frequência diária não identificada.');
    if (validDays == null) warnings.add('Duração em dias não identificada.');

    results.add(OcrPrescriptionCandidate(
      name: name,
      sourceText: text,
      form: form,
      strengthMgPerUnit: strength,
      doseMgPerAdministration: dose,
      administrationsPerDay: frequency,
      durationDays: validDays,
      warnings: warnings,
    ));
  }
  return results;
}
