import 'dart:math' as math;

/// Mathematical assistance only. Never substitute for a pharmacist's
/// prescription review, approved product information or dispensing rules.
enum PharmaceuticalForm {
  tablet,
  capsule,
  sachet,
  oralSolution,
  oralSuspension,
}

extension PharmaceuticalFormLabel on PharmaceuticalForm {
  bool get isLiquid =>
      this == PharmaceuticalForm.oralSolution ||
      this == PharmaceuticalForm.oralSuspension;

  String get label => switch (this) {
        PharmaceuticalForm.tablet => 'Comprimido',
        PharmaceuticalForm.capsule => 'Cápsula',
        PharmaceuticalForm.sachet => 'Sachê',
        PharmaceuticalForm.oralSolution => 'Solução oral',
        PharmaceuticalForm.oralSuspension => 'Suspensão oral',
      };

  String get unitName => switch (this) {
        PharmaceuticalForm.tablet => 'comprimidos',
        PharmaceuticalForm.capsule => 'cápsulas',
        PharmaceuticalForm.sachet => 'sachês',
        PharmaceuticalForm.oralSolution ||
        PharmaceuticalForm.oralSuspension => 'mL',
      };

  String get strengthUnit => isLiquid ? 'mg/mL' : 'mg/unidade';
}

class PrescriptionCalculationException implements Exception {
  const PrescriptionCalculationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PrescriptionCalculation {
  const PrescriptionCalculation({
    required this.form,
    required this.unitsPerAdministration,
    required this.totalUnits,
    required this.dailyDoseMg,
    required this.totalDoseMg,
    required this.maximumDailyMg,
    required this.maximumDoseReference,
    required this.exceedsInformedMaximum,
    required this.administrationsPerDay,
    required this.durationDays,
    this.packagesRequired,
    this.packageCapacity,
    this.extraUnitsInWholePackages,
  });

  final PharmaceuticalForm form;
  /// Integer units for solids; millilitres for oral liquid forms.
  final double unitsPerAdministration;
  final double totalUnits;
  final double dailyDoseMg;
  final double totalDoseMg;
  /// Supplied externally; never looked up, inferred or validated clinically.
  final double maximumDailyMg;
  final String maximumDoseReference;
  final bool exceedsInformedMaximum;
  final int administrationsPerDay;
  final int durationDays;
  final int? packagesRequired;
  final double? packageCapacity;
  final double? extraUnitsInWholePackages;
}

/// Calculates mathematical units to cover a FIXED regular treatment schedule.
/// This calculation does not handle PRN, tapering schedules, titration,
/// weight-based dosing, split tablets, injectable drugs, or controlled-drug
/// dispensing restrictions. These require a separate professional review.
PrescriptionCalculation calculatePrescription({
  required PharmaceuticalForm form,
  required double strengthMgPerUnit,
  required double prescribedMgPerAdministration,
  required int administrationsPerDay,
  required int durationDays,
  required double maximumDailyMg,
  required String maximumDoseReference,
  double? packageCapacity,
}) {
  void positiveFinite(double value, String label) {
    if (!value.isFinite || value <= 0) {
      throw PrescriptionCalculationException(
        '$label deve ser um número positivo e finito.',
      );
    }
  }

  positiveFinite(strengthMgPerUnit, 'A concentração da apresentação');
  positiveFinite(prescribedMgPerAdministration, 'A dose prescrita');
  positiveFinite(maximumDailyMg, 'A dose máxima diária informada');
  if (maximumDoseReference.trim().isEmpty) {
    throw const PrescriptionCalculationException(
      'Informe a fonte e o contexto do limite diário (bula/POP e indicação).',
    );
  }
  if (administrationsPerDay < 1 || administrationsPerDay > 24) {
    throw const PrescriptionCalculationException(
      'Informe de 1 a 24 administrações por dia, para esquema regular.',
    );
  }
  if (durationDays < 1 || durationDays > 365) {
    throw const PrescriptionCalculationException(
      'Informe a duração de 1 a 365 dias. Para outro esquema, revise manualmente.',
    );
  }

  var unitsPerAdministration =
      prescribedMgPerAdministration / strengthMgPerUnit;
  if (!unitsPerAdministration.isFinite ||
      unitsPerAdministration <= 0 ||
      unitsPerAdministration > 1000000) {
    throw const PrescriptionCalculationException(
      'Incompatibilidade ou quantidade excessiva para a apresentação informada.',
    );
  }

  if (!form.isLiquid) {
    final nearestInteger = unitsPerAdministration.roundToDouble();
    if ((unitsPerAdministration - nearestInteger).abs() > 1e-8) {
      throw const PrescriptionCalculationException(
        'A dose não corresponde a unidades inteiras desta apresentação. '
        'O app não divide, tritura ou arredonda unidades: confirme a apresentação '
        'e a prescrição com o profissional responsável.',
      );
    }
    // Normalize floating-point noise only after checking whole-unit equivalence.
    unitsPerAdministration = nearestInteger;
  }

  final totalUnits =
      unitsPerAdministration * administrationsPerDay * durationDays;
  final dailyDoseMg =
      prescribedMgPerAdministration * administrationsPerDay;
  final totalDoseMg = dailyDoseMg * durationDays;
  if (!totalUnits.isFinite ||
      !dailyDoseMg.isFinite ||
      !totalDoseMg.isFinite ||
      totalUnits <= 0 ||
      totalUnits > 100000000) {
    throw const PrescriptionCalculationException(
      'Resultado muito grande ou inválido. Confira os dados informados.',
    );
  }

  int? packageCount;
  double? leftover;
  if (packageCapacity != null) {
    positiveFinite(packageCapacity, 'A capacidade da embalagem');
    if (!form.isLiquid &&
        (packageCapacity - packageCapacity.roundToDouble()).abs() > 1e-8) {
      throw const PrescriptionCalculationException(
        'Quantidade de unidades por caixa deve ser inteira.',
      );
    }
    final estimated = totalUnits / packageCapacity;
    if (!estimated.isFinite || estimated <= 0 || estimated > 1000000) {
      throw const PrescriptionCalculationException(
        'Número de embalagens excede o limite desta ferramenta.',
      );
    }
    final count = estimated.ceil();
    packageCount = count;
    leftover = math.max(0.0, count * packageCapacity - totalUnits);
  }

  return PrescriptionCalculation(
    form: form,
    unitsPerAdministration: unitsPerAdministration,
    totalUnits: totalUnits,
    dailyDoseMg: dailyDoseMg,
    totalDoseMg: totalDoseMg,
    maximumDailyMg: maximumDailyMg,
    maximumDoseReference: maximumDoseReference.trim(),
    // Comparing the user's declared number does not verify clinical safety.
    exceedsInformedMaximum: dailyDoseMg > maximumDailyMg,
    administrationsPerDay: administrationsPerDay,
    durationDays: durationDays,
    packagesRequired: packageCount,
    packageCapacity: packageCapacity,
    extraUnitsInWholePackages: leftover,
  );
}
