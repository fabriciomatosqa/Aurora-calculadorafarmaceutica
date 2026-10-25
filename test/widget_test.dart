import 'package:aurora_calculadora_farmaceutica/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Tela inicial carrega identidade e pesquisa', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AuroraApp(enableAutomaticUpdates: false));
    await tester.pumpAndSettle();
    expect(find.text('AURORA'), findsOneWidget);
    expect(find.text('Calculadoras'), findsOneWidget);
    expect(find.text('Buscar fórmula ou cálculo'), findsOneWidget);
    expect(find.byTooltip('Configurar atualizações'), findsNothing);
    expect(find.byTooltip('Verificar atualizações'), findsOneWidget);
  });
}
