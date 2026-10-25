import 'package:aurora_calculadora_farmaceutica/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:aurora_calculadora_farmaceutica/features/prescription/prescription_screen.dart';

void main() {
  testWidgets('Tela inicial carrega identidade e pesquisa', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AuroraApp(enableAutomaticUpdates: false));
    await tester.pumpAndSettle();
    expect(find.text('AURORA'), findsOneWidget);
    expect(find.text('Calculadoras'), findsOneWidget);
    expect(find.text('Buscar fórmula ou cálculo'), findsOneWidget);
    final favoritos = tester.getTopLeft(find.text('Favoritos')).dx;
    final todas = tester.getTopLeft(find.text('Todas')).dx;
    expect(favoritos, lessThan(todas));
  });
  testWidgets('Prescrições mostra botões de importar antes dos campos', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrescriptionScreen()));
    expect(find.text('1. IMPORTAR PRESCRIÇÃO'), findsOneWidget);
    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Galeria'), findsOneWidget);
    expect(find.text('Arquivo / PDF'), findsOneWidget);
    expect(find.text('Texto da prescrição (editável)'), findsOneWidget);
  });
}
