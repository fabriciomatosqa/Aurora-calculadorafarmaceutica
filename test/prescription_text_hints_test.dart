import 'package:aurora_calculadora_farmaceutica/domain/prescription.dart';
import 'package:aurora_calculadora_farmaceutica/features/prescription/prescription_text_hints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Extrai sugestões explícitas de comprimidos sem dose máxima inventada', () {
    final r = suggestPrescriptionFields(
      'Medicamento fictício 500 mg comprimido. '
      'Tomar 1 comprimido a cada 8 horas por 7 dias.',
    );
    expect(r.form, PharmaceuticalForm.tablet);
    expect(r.strengthMg, 500);
    expect(r.doseMg, 500);
    expect(r.administrationsPerDay, 3);
    expect(r.durationDays, 7);
  });

  test('Comprimidos com múltiplas concentrações não são inferidos', () {
    final r = suggestPrescriptionFields(
      'Comprimido 250 mg ou 500 mg. Tomar 1 comprimido por 5 dias.',
    );
    expect(r.strengthMg, isNull);
    expect(r.doseMg, isNull);
    expect(r.durationDays, 5);
  });

  test('Líquido lê apenas concentração explicitamente em mg/mL', () {
    final r = suggestPrescriptionFields(
      'Solução oral 50 mg/mL, tomar a cada 12 horas por 10 dias',
    );
    expect(r.form, PharmaceuticalForm.oralSolution);
    expect(r.strengthMg, 50);
    expect(r.doseMg, isNull);
    expect(r.administrationsPerDay, 2);
    expect(r.durationDays, 10);
  });

  test('Não inventa mg/mL de apresentação expressa em mg/5 mL', () {
    final r = suggestPrescriptionFields('Suspensão 250 mg/5 mL por 5 dias');
    expect(r.form, PharmaceuticalForm.oralSuspension);
    expect(r.strengthMg, isNull);
    expect(r.durationDays, 5);
  });

  test('Não supõe dados quando OCR está vazio ou sem posologia', () {
    expect(suggestPrescriptionFields('').isEmpty, true);
    final r = suggestPrescriptionFields('Paciente: texto incompleto');
    expect(r.isEmpty, true);
  });
}
