import 'package:aurora_calculadora_farmaceutica/domain/calculator.dart';
import 'package:flutter_test/flutter_test.dart';

CalculatorDefinition d(String id) => calculators.firstWhere((c) => c.id == id);
CalculationResult run(String id, Map<String, String> values) => calculate(d(id), values);

void main() {
  test('Catálogo possui 22 IDs distintos com fórmulas e aviso', () {
    expect(calculators.length, 22);
    expect(calculators.map((c) => c.id).toSet().length, 22);
    expect(calculators.every((c) => c.formula.isNotEmpty && c.note.isNotEmpty), true);
  });

  test('Aceita vírgula decimal e ponto decimal', () {
    expect(parseDecimal('1,25', 'teste'), 1.25);
    expect(parseDecimal('1.25', 'teste'), 1.25);
    expect(() => parseDecimal('1.234,5', 'teste'), throwsA(isA<CalculatorException>()));
    expect(() => parseDecimal('Infinity', 'teste'), throwsA(isA<CalculatorException>()));
  });

  test('Formatação não perde zeros de números inteiros', () {
    expect(formatValue(100), '100');
    expect(formatValue(1.50), '1,5');
    expect(formatValue(0), '0');
    expect(formatValue(1000), '1000');
  });

  test('Diluição fornece volume estoque e diluente', () {
    final r = run('dilution', {'c1': '100', 'c2': '10', 'v2': '100'});
    expect(r.value, closeTo(10, 1e-10));
    expect(r.extras.single.value, closeTo(90, 1e-10));
  });

  test('Diluição rejeita concentração maior que estoque', () {
    expect(() => run('dilution', {'c1': '10', 'c2': '20', 'v2': '100'}), throwsA(isA<CalculatorException>()));
  });

  test('Fator diluição é adimensional e não inferior a 1', () {
    expect(run('dilution_factor', {'aliquot': '5', 'final': '50'}).value, 10);
    expect(() => run('dilution_factor', {'aliquot': '50', 'final': '5'}), throwsA(isA<CalculatorException>()));
  });

  test('% m/v: 5 gramas em 100 mL equivale a 5%', () {
    expect(run('mass_volume', {'mass': '5', 'volume': '100'}).value, 5);
  });

  test('% m/m: 15g em 300g equivale a 5%', () {
    expect(run('mass_mass', {'solute': '15', 'total': '300'}).value, 5);
    expect(() => run('mass_mass', {'solute': '310', 'total': '300'}), throwsA(isA<CalculatorException>()));
  });

  test('% v/v: 20 mL de 100mL é 20%', () {
    expect(run('volume_volume', {'solute': '20', 'total': '100'}).value, 20);
  });

  test('Molaridade NaCl 5.844 g / 58.44 g/mol em 1L é 0,1M', () {
    expect(run('molarity', {'mass': '5.844', 'mw': '58.44', 'volume': '1000'}).value, closeTo(0.1, 1e-12));
  });

  test('Massa molaridade: 0,1 M NaCl 1L são 5,844g', () {
    expect(run('molarity_mass', {'molarity': '0,1', 'mw': '58,44', 'volume': '1000'}).value, closeTo(5.844, 1e-12));
  });

  test('Mistura de soluções balanceia massa', () {
    final r = run('blend', {'c1': '20', 'v1': '50', 'c2': '10', 'v2': '50'});
    expect(r.value, 15);
    expect(r.extras.single.value, 100);
  });

  test('mg/L não presume equivalência a ppm', () {
    expect(run('mg_per_l', {'mass': '25', 'volume': '500'}).value, 50);
  });

  test('Densidade 125g / 100mL é 1,25g/mL', () {
    expect(run('density', {'mass': '125', 'volume': '100'}).value, 1.25);
  });

  test('Correção do teor 98% para massa ativa 100g', () {
    expect(run('purity_adjust', {'target': '100', 'purity': '98'}).value, closeTo(102.040816, 1e-5));
    expect(() => run('purity_adjust', {'target': '100', 'purity': '0'}), throwsA(isA<CalculatorException>()));
  });

  test('Recuperação por adição', () {
    expect(run('recovery', {'found': '119', 'original': '20', 'added': '100'}).value, 99);
  });

  test('Viés relativo mantém sinal', () {
    expect(run('bias', {'measured': '98', 'reference': '100'}).value, -2);
  });

  test('RSD com DP amostral, 5 medições', () {
    final r = run('rsd', {'values': '98; 99; 100; 101; 102'});
    expect(r.value, closeTo(1.58113883, 1e-6));
    expect(r.extras[0].value, 100);
    expect(r.extras[1].value, closeTo(1.58113883, 1e-6));
    expect(r.extras[2].value, 5);
  });

  test('RSD com vírgula decimal separados por ponto e vírgula', () {
    final r = run('rsd', {'values': '1,0; 1,1; 1,2'});
    expect(r.extras[0].value, closeTo(1.1, 1e-10));
  });

  test('RSD rejeita uma só medição ou média nula', () {
    expect(() => run('rsd', {'values': '10'}), throwsA(isA<CalculatorException>()));
    expect(() => run('rsd', {'values': '0; 0'}), throwsA(isA<CalculatorException>()));
  });

  test('LD e LQ ICH Q2 sigma e inclinação', () {
    final r = run('lod_loq', {'sd': '0.6', 'slope': '2'});
    expect(r.value, closeTo(0.99, 1e-10));
    expect(r.extras.single.value, closeTo(3, 1e-10));
  });

  test('Perda secagem 10g para 9.6g é 4%', () {
    expect(run('drying', {'before': '10', 'after': '9.6'}).value, closeTo(4, 1e-10));
  });

  test('Rendimento 94kg / 100kg é 94%', () {
    expect(run('yield', {'actual': '94', 'theoretical': '100'}).value, 94);
  });

  test('Perda processo 100kg para 97kg é 3%', () {
    expect(run('loss', {'initial': '100', 'final': '97'}).value, 3);
  });

  test('Escala de 100kg para 250kg de componente 2kg', () {
    final r = run('batch_scale', {'ingredient': '2', 'original': '100', 'target': '250'});
    expect(r.value, 5);
    expect(r.extras.single.value, 2.5);
  });

  test('100000 comprimidos de 500mg são 50kg', () {
    expect(run('tablet_batch', {'count': '100000', 'unitmass': '500'}).value, 50);
    expect(() => run('tablet_batch', {'count': '1.5', 'unitmass': '500'}), throwsA(isA<CalculatorException>()));
  });

  test('Vazão: 500mL em 10min equivale a 50mL/min', () {
    expect(run('flow', {'volume': '500', 'time': '10'}).value, 50);
  });

  test('Evita divisão por zero e dados faltantes', () {
    expect(() => run('flow', {'volume': '500', 'time': '0'}), throwsA(isA<CalculatorException>()));
    expect(() => run('flow', {'volume': '', 'time': '1'}), throwsA(isA<CalculatorException>()));
  });
}
