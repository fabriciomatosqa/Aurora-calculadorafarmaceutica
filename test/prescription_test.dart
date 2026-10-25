import 'package:aurora_calculadora_farmaceutica/domain/prescription.dart';
import 'package:flutter_test/flutter_test.dart';

const _source = 'Fonte fictícia declarada para teste técnico';

PrescriptionCalculation solid({
  PharmaceuticalForm form = PharmaceuticalForm.tablet,
  double strength = 500,
  double dose = 500,
  int times = 3,
  int days = 7,
  double maximum = 2000,
  double? packageCapacity,
  String source = _source,
}) => calculatePrescription(
  form: form,
  strengthMgPerUnit: strength,
  prescribedMgPerAdministration: dose,
  administrationsPerDay: times,
  durationDays: days,
  maximumDailyMg: maximum,
  maximumDoseReference: source,
  packageCapacity: packageCapacity,
);

void main() {
  group('Prescrição matemática de sólidos', () {
    test('500 mg por tomada, 3x/dia, 7 dias = 21 comprimidos', () {
      final result = solid();
      expect(result.unitsPerAdministration, 1);
      expect(result.totalUnits, 21);
      expect(result.dailyDoseMg, 1500);
      expect(result.totalDoseMg, 10500);
      expect(result.exceedsInformedMaximum, isFalse);
      expect(result.packagesRequired, isNull);
    });

    test('Caixas inteiras: 21 comprimidos com caixas de 10 = 3', () {
      final result = solid(packageCapacity: 10);
      expect(result.packagesRequired, 3);
      expect(result.extraUnitsInWholePackages, 9);
      expect(result.totalUnits, 21);
    });

    test('Dois comprimidos por dose, 2 vezes/dia por 5 dias', () {
      final result = solid(dose: 1000, times: 2, days: 5);
      expect(result.unitsPerAdministration, 2);
      expect(result.totalUnits, 20);
      expect(result.dailyDoseMg, 2000);
      expect(result.exceedsInformedMaximum, isFalse);
    });

    test('Cápsula fracionária é bloqueada, não arredondada', () {
      expect(
        () => solid(form: PharmaceuticalForm.capsule, dose: 750),
        throwsA(isA<PrescriptionCalculationException>()),
      );
    });

    test('Comprimido fracionário exige revisão profissional', () {
      expect(
        () => solid(form: PharmaceuticalForm.tablet, dose: 250),
        throwsA(isA<PrescriptionCalculationException>()),
      );
    });

    test('Sachês inteiros podem ser contados como unidades', () {
      final result = solid(form: PharmaceuticalForm.sachet, times: 1, days: 3);
      expect(result.totalUnits, 3);
      expect(result.form.unitName, 'sachês');
    });
  });

  group('Soluções e suspensões orais', () {
    test('50 mg/mL, 250 mg, 2x/dia, 7 dias = 70 mL', () {
      final result = solid(
        form: PharmaceuticalForm.oralSolution,
        strength: 50,
        dose: 250,
        times: 2,
        days: 7,
        maximum: 600,
      );
      expect(result.unitsPerAdministration, 5);
      expect(result.totalUnits, 70);
      expect(result.dailyDoseMg, 500);
    });

    test('Estima 2 frascos de 40 mL para 70 mL de suspensão', () {
      final result = solid(
        form: PharmaceuticalForm.oralSuspension,
        strength: 50,
        dose: 250,
        times: 2,
        days: 7,
        maximum: 600,
        packageCapacity: 40,
      );
      expect(result.packagesRequired, 2);
      expect(result.extraUnitsInWholePackages, 10);
    });

    test('Permite mL fracionário sem arredondar o volume', () {
      final result = solid(
        form: PharmaceuticalForm.oralSolution,
        strength: 40,
        dose: 50,
        times: 1,
        days: 2,
      );
      expect(result.unitsPerAdministration, 1.25);
      expect(result.totalUnits, 2.5);
    });
  });

  group('Verificações e limites', () {
    test('Dose acima do máximo informado gera alerta sem alterar dose', () {
      final result = solid(maximum: 1200);
      expect(result.dailyDoseMg, 1500);
      expect(result.exceedsInformedMaximum, isTrue);
      expect(result.totalUnits, 21);
    });

    test('Exatamente no máximo não ativa excesso numérico', () {
      final result = solid(maximum: 1500);
      expect(result.exceedsInformedMaximum, isFalse);
    });

    test('Fonte de dose máxima é obrigatória', () {
      expect(
        () => solid(source: '  '),
        throwsA(isA<PrescriptionCalculationException>()),
      );
    });

    test('Não aceita concentração, dose ou máximo zero ou negativos', () {
      for (final action in [
        () => solid(strength: 0),
        () => solid(strength: -1),
        () => solid(dose: 0),
        () => solid(maximum: 0),
        () => solid(maximum: -100),
        () => solid(strength: double.infinity),
      ]) {
        expect(action, throwsA(isA<PrescriptionCalculationException>()));
      }
    });

    test('Frequência e duração devem estar em limites explícitos', () {
      expect(() => solid(times: 0),
          throwsA(isA<PrescriptionCalculationException>()));
      expect(() => solid(times: 25),
          throwsA(isA<PrescriptionCalculationException>()));
      expect(() => solid(days: 0),
          throwsA(isA<PrescriptionCalculationException>()));
      expect(() => solid(days: 366),
          throwsA(isA<PrescriptionCalculationException>()));
    });

    test('Capacidade de caixa deve ser inteira para sólidos', () {
      expect(() => solid(packageCapacity: 2.5),
          throwsA(isA<PrescriptionCalculationException>()));
    });

    test('Embalagem nula não altera número de unidades prescritas', () {
      final a = solid();
      final b = solid(packageCapacity: 30);
      expect(a.totalUnits, b.totalUnits);
      expect(b.packagesRequired, 1);
      expect(b.extraUnitsInWholePackages, 9);
    });
  });
}
