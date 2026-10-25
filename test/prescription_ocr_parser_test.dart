import 'package:aurora_calculadora_farmaceutica/features/prescription/prescription_ocr_parser.dart';
import 'package:aurora_calculadora_farmaceutica/domain/prescription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OCR conservador', () {
    test('não inventa medicamentos em texto sem concentração', () {
      expect(extractPrescriptionCandidates('Paciente Fulano\nUso oral\nTomar com água'),
          isEmpty);
    });

    test('extrai um item simples, com dose fixa e duração explícita', () {
      final items = extractPrescriptionCandidates(
        'MedicamentoFicticio 500 mg comprimidos\n'
        'Tomar 1 comprimido a cada 8 horas por 7 dias.',
      );
      expect(items, hasLength(1));
      final item = items.single;
      expect(item.name, 'MedicamentoFicticio');
      expect(item.form, PharmaceuticalForm.tablet);
      expect(item.strengthMgPerUnit, 500);
      expect(item.doseMgPerAdministration, 500);
      expect(item.administrationsPerDay, 3);
      expect(item.durationDays, 7);
      expect(item.hasBasicSchedule, isTrue);
    });

    test('lista mais de um medicamento sem misturar seus esquemas', () {
      final items = extractPrescriptionCandidates(
        'Medicamento A 100 mg cápsulas\n'
        'Tomar 2 cápsulas 2 vezes ao dia durante 5 dias\n'
        'Medicamento B 250 mg comprimidos\n'
        'Tomar 1 comprimido 1 vez ao dia por 10 dias',
      );
      expect(items, hasLength(2));
      expect(items[0].doseMgPerAdministration, 200);
      expect(items[0].durationDays, 5);
      expect(items[1].doseMgPerAdministration, 250);
      expect(items[1].durationDays, 10);
    });

    test('converte apenas concentração explícita de líquido mg/5mL', () {
      final items = extractPrescriptionCandidates(
        'SuspensaoFicticia 250 mg / 5 mL suspensão oral\n'
        'Tomar 5 mL a cada 12 horas durante 7 dias',
      );
      expect(items, hasLength(1));
      final item = items.single;
      expect(item.form, PharmaceuticalForm.oralSuspension);
      expect(item.strengthMgPerUnit, 50);
      expect(item.doseMgPerAdministration, 250);
      expect(item.administrationsPerDay, 2);
    });

    test('horário ou duração ausentes não são adivinhados', () {
      final item = extractPrescriptionCandidates(
        'Medicamento 500 mg comprimidos\nTomar 1 comprimido',
      ).single;
      expect(item.administrationsPerDay, isNull);
      expect(item.durationDays, isNull);
      expect(item.hasBasicSchedule, isFalse);
      expect(item.warnings, isNotEmpty);
    });

    test('SOS não produz candidato pronto para cálculo automático', () {
      final item = extractPrescriptionCandidates(
        'Medicamento 500 mg comprimidos\n'
        'Tomar 1 comprimido 3 vezes ao dia por 7 dias se necessário',
      ).single;
      expect(item.warnings.join(' '), contains('variável/SOS'));
      expect(item.hasBasicSchedule, isFalse);
    });

    test('não extrai máximos clínicos a partir de medicamento', () {
      final item = extractPrescriptionCandidates(
        'Medicamento 300 mg comprimidos\n'
        'Tomar 1 comprimido 2x ao dia por 5 dias',
      ).single;
      expect(item.hasBasicSchedule, isTrue);
      // Candidate purposely has no field for a maximum daily dose.
      expect(item.strengthMgPerUnit, 300);
    });

    test('texto vazio não quebra o analisador', () {
      expect(extractPrescriptionCandidates('  \n \n'), isEmpty);
    });
  });
}
