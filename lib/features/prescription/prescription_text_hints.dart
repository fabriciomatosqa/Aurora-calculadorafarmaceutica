import '../../domain/prescription.dart';

/// Conservative, opt-in, *unverified* hints from OCR/PDF text.
/// The user must confirm all fields and supply an independently verified
/// maximum daily dose. No automated clinical decision is made.
class PrescriptionTextHints {
  const PrescriptionTextHints({
    this.form,
    this.strengthMg,
    this.doseMg,
    this.administrationsPerDay,
    this.durationDays,
  });

  final PharmaceuticalForm? form;
  final double? strengthMg;
  final double? doseMg;
  final int? administrationsPerDay;
  final int? durationDays;

  bool get isEmpty => form == null && strengthMg == null &&
      doseMg == null && administrationsPerDay == null && durationDays == null;
}

PrescriptionTextHints suggestPrescriptionFields(String rawText) {
  final text = rawText.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final form = switch (text) {
    _ when RegExp(r'\bcomprimidos?\b').hasMatch(text) =>
      PharmaceuticalForm.tablet,
    _ when RegExp(r'\bc[aá]psulas?\b').hasMatch(text) =>
      PharmaceuticalForm.capsule,
    _ when RegExp(r'\bsach[eê]s?\b').hasMatch(text) =>
      PharmaceuticalForm.sachet,
    _ when RegExp(r'\bsuspens[aã]o\b').hasMatch(text) =>
      PharmaceuticalForm.oralSuspension,
    _ when RegExp(r'\bsolu[cç][aã]o\b').hasMatch(text) =>
      PharmaceuticalForm.oralSolution,
    _ => null,
  };
  // Only single, labelled concentration in mg per solid unit.
  double? strength;
  if (form != null && !form.isLiquid) {
    final strengths = RegExp(r'\b(\d+(?:[,.]\d+)?)\s*mg\b')
        .allMatches(text)
        .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '.')))
        .whereType<double>()
        .where((x) => x > 0 && x.isFinite)
        .toSet();
    if (strengths.length == 1) strength = strengths.single;
  } else if (form != null && form.isLiquid) {
    // Only explicit mg/mL, never treat "250 mg/5 mL" as 250 mg/mL.
    final concentration = RegExp(r'\b(\d+(?:[,.]\d+)?)\s*mg\s*/\s*ml\b')
        .firstMatch(text);
    if (concentration != null) {
      strength = double.tryParse(
        concentration.group(1)!.replaceAll(',', '.'),
      );
    }
  }

  int? administrations;
  final frequency = RegExp(
    r'\b([1-9]|1\d|2[0-4])\s*(?:vezes|tomadas?)\s*(?:ao|por)\s*dia\b',
  ).firstMatch(text);
  if (frequency != null) {
    administrations = int.tryParse(frequency.group(1)!);
  } else {
    final interval = RegExp(r'\ba cada\s*(4|6|8|12|24)\s*horas?\b')
        .firstMatch(text);
    if (interval != null) {
      administrations = 24 ~/ int.parse(interval.group(1)!);
    }
  }

  int? days;
  final duration = RegExp(r'\b(?:por|durante)\s*(\d{1,3})\s*dias?\b')
      .firstMatch(text);
  if (duration != null) {
    days = int.tryParse(duration.group(1)!);
    if (days == 0 || (days != null && days > 365)) days = null;
  }

  double? dose;
  // Derive dose only when a whole, clearly specified number of identical
  // solids appears with a unique concentration. Otherwise keep it blank.
  if (strength != null && form != null && !form.isLiquid) {
    final match = RegExp(
      r'\btomar\s*(\d{1,2})\s*(?:comprimidos?|c[aá]psulas?|sach[eê]s?)\b',
    ).firstMatch(text);
    if (match != null) {
      final units = int.tryParse(match.group(1)!);
      if (units != null && units >= 1 && units <= 20) {
        dose = units * strength;
      }
    }
  }
  return PrescriptionTextHints(
    form: form,
    strengthMg: strength,
    doseMg: dose,
    administrationsPerDay: administrations,
    durationDays: days,
  );
}
