import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain/calculator.dart';
import 'services/update_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AuroraApp());
}

const _aqua = Color(0xFF24E1CA);
const _violet = Color(0xFF8068F5);
const _navy = Color(0xFF0D1426);

class AuroraApp extends StatelessWidget {
  const AuroraApp({super.key, this.enableAutomaticUpdates = true});

  /// Disable external update checks in deterministic widget tests.
  final bool enableAutomaticUpdates;

  @override
  Widget build(BuildContext context) {
    ThemeData buildTheme(Brightness brightness) {
      final dark = brightness == Brightness.dark;
      final scheme = ColorScheme.fromSeed(
        seedColor: _aqua, brightness: brightness,
        primary: dark ? _aqua : const Color(0xFF007D76),
        secondary: _violet,
        surface: dark ? const Color(0xFF172238) : const Color(0xFFFFFFFF),
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: dark ? _navy : const Color(0xFFF3F7FA),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: dark ? _navy : const Color(0xFFF3F7FA),
          foregroundColor: scheme.onSurface,
        ),
        cardTheme: CardThemeData(
          color: scheme.surface, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: dark ? const Color(0xFF1C2A42) : const Color(0xFFEDF3F7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        ),
      );
    }

    return MaterialApp(
      title: 'AURORA Calculadora Farmacêutica',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: CalculatorHome(automaticUpdates: enableAutomaticUpdates),
    );
  }
}

IconData categoryIcon(CalculatorCategory category) => switch (category) {
      CalculatorCategory.solutions => Icons.science_outlined,
      CalculatorCategory.quality => Icons.verified_outlined,
      CalculatorCategory.production => Icons.precision_manufacturing_outlined,
    };

class CalculatorHome extends StatefulWidget {
  const CalculatorHome({super.key, this.automaticUpdates = true});

  final bool automaticUpdates;
  @override
  State<CalculatorHome> createState() => _CalculatorHomeState();
}

class _CalculatorHomeState extends State<CalculatorHome> with WidgetsBindingObserver {
  static const _favoritesKey = 'favorite_calculator_ids_v1';
  final _search = TextEditingController();
  final Set<String> _favorites = {};
  final UpdateService _updates = UpdateService();
  bool _checkingForUpdates = false;
  CalculatorCategory? _category;
  bool _onlyFavorites = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    if (widget.automaticUpdates) {
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_checkForUpdates(automatic: true));
      });
    }
    _search.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (widget.automaticUpdates && state == AppLifecycleState.resumed) {
      unawaited(_checkForUpdates(automatic: true));
    }
  }

  Future<void> _checkForUpdates({required bool automatic}) async {
    if (_checkingForUpdates) return;
    _checkingForUpdates = true;
    try {
      final release = await _updates.latestAvailable();
      if (!mounted) return;
      if (release == null) {
        if (!automatic) _message('Você já está na versão mais recente.');
        return;
      }
      final shouldUpdate = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Nova versão disponível'),
          content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AURORA ${release.version} já está disponível.'),
            const SizedBox(height: 8),
            const Text('Deseja atualizar agora?'),
            if (release.description.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(child: Text(release.description,
                  style: const TextStyle(fontSize: 12))),
              ),
            ],
            if (Platform.isIOS) ...[
              const SizedBox(height: 10),
              const Text('No iPhone, a instalação deve seguir o canal '
                  'de distribuição Apple. A página informa as novidades.',
                  style: TextStyle(fontSize: 12)),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Agora não')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(Platform.isAndroid ? 'Baixar e instalar' : 'Ver novidades')),
          ],
        ),
      );
      if (!mounted || shouldUpdate != true) return;
      if (Platform.isAndroid) {
        await _downloadAndInstall(release);
      } else {
        await launchUrl(release.pageUrl, mode: LaunchMode.externalApplication);
      }
    } on UpdateException catch (error) {
      if (!automatic && mounted) _message(error.message);
    } catch (_) {
      if (!automatic && mounted) {
        _message('Não foi possível verificar atualizações. Confira a internet.');
      }
    } finally {
      _checkingForUpdates = false;
    }
  }

  Future<void> _downloadAndInstall(AppRelease release) async {
    final progress = ValueNotifier<double?>(null);
    // Modal permanece visível até concluir a verificação SHA-256.
    bool dialogClosed = false;
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Baixando atualização'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, value, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value),
                const SizedBox(height: 14),
                Text(value == null ? 'Download e verificação de segurança…'
                    : '${(value * 100).toStringAsFixed(0)}% concluído'),
              ],
            ),
          ),
        ),
      ),
    );
    // Permite que o diálogo seja desenhado antes de iniciar a transferência.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    try {
      final apk = await _updates.downloadVerifiedApk(release,
        onProgress: (received, total) {
          if (total > 0 && received <= total) {
            progress.value = received / total;
          }
        },
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      dialogClosed = true;
      await _updates.requestInstallation(apk);
    } on UpdateException catch (error) {
      if (mounted) {
        if (!dialogClosed) {
          Navigator.of(context, rootNavigator: true).pop();
          dialogClosed = true;
        }
        _message(error.message);
      }
    } catch (_) {
      if (mounted) {
        if (!dialogClosed) {
          Navigator.of(context, rootNavigator: true).pop();
          dialogClosed = true;
        }
        _message('Falha ao baixar ou abrir o APK. Tente novamente.');
      }
    } finally {
      // Release resources only after the dialog's transition has completed.
      if (mounted && !dialogClosed) Navigator.of(context, rootNavigator: true).pop();
      await dialogFuture;
      progress.dispose();
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _favorites.addAll(prefs.getStringList(_favoritesKey) ?? []));
  }

  Future<void> _toggleFavorite(String id) async {
    setState(() {
      if (!_favorites.remove(id)) _favorites.add(id);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favorites.toList()..sort());
  }

  @override
  void dispose() {
    _search.dispose();
    if (widget.automaticUpdates) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _updates.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final visible = calculators.where((c) {
      if (_category != null && c.category != _category) return false;
      if (_onlyFavorites && !_favorites.contains(c.id)) return false;
      return c.name.toLowerCase().contains(query) ||
          c.summary.toLowerCase().contains(query) ||
          c.category.label.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_aqua, _violet]),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.auto_awesome, color: _navy, size: 20),
          ),
          const SizedBox(width: 10),
          const Flexible(child: Text('AURORA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.7))),
        ]),
        actions: [
          IconButton(
            tooltip: 'Verificar atualizações',
            icon: const Icon(Icons.system_update_alt_rounded),
            onPressed: () => _checkForUpdates(automatic: false),
          ),
          IconButton(
            tooltip: 'Sobre e segurança',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'AURORA Calculadora Farmacêutica',
              applicationVersion: '0.2.0',
              children: [
                const Text('Ferramenta educacional e de apoio técnico. Não validada para liberação de lotes, decisão clínica ou substituição de métodos e procedimentos aprovados.'),
                const SizedBox(height: 10),
                const Text('Confira as unidades, os pressupostos, os dados originais e os critérios de aceitação estabelecidos pela instituição.'),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                sliver: SliverToBoxAdapter(child: _hero(scheme)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar fórmula ou cálculo',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isNotEmpty ? IconButton(
                          tooltip: 'Limpar pesquisa',
                          icon: const Icon(Icons.close), onPressed: _search.clear,
                        ) : null,
                      ),
                    ),
                    const SizedBox(height: 13),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _filterChip('Todas', _category == null && !_onlyFavorites, () => setState(() {
                          _category = null; _onlyFavorites = false;
                        })),
                        ...CalculatorCategory.values.map((c) => _filterChip(c.label, _category == c && !_onlyFavorites,
                            () => setState(() { _category = c; _onlyFavorites = false; }))),
                        _filterChip('Favoritas', _onlyFavorites, () => setState(() { _onlyFavorites = true; _category = null; }), icon: Icons.star_outline),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Calculadoras', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text('${visible.length} disponíveis', style: TextStyle(color: scheme.onSurfaceVariant)),
                    ]),
                  ]),
                ),
              ),
              if (visible.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('Nenhuma calculadora encontrada. Experimente outra categoria ou pesquisa.', textAlign: TextAlign.center),
                  )),
                )
              else SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                sliver: SliverLayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.crossAxisExtent > 680;
                  if (wide) {
                    return SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 370, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 157,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _calculatorCard(visible[i], scheme),
                        childCount: visible.length,
                      ),
                    );
                  }
                  return SliverList.separated(
                    itemCount: visible.length,
                    itemBuilder: (context, i) => _calculatorCard(visible[i], scheme),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF104449), Color(0xFF24245D), Color(0xFF10213B)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.science_rounded, color: _aqua, size: 18),
          SizedBox(width: 8),
          Text('LABORATÓRIO • QUALIDADE • PRODUÇÃO',
              style: TextStyle(color: _aqua, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 16),
        const Text('Precisão em cada cálculo.',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        const Text('21 ferramentas, fórmulas explicadas e resultados instantâneos. Funciona offline.',
            style: TextStyle(color: Color(0xFFE2E7FA), fontSize: 14, height: 1.5)),
        const SizedBox(height: 14),
        const Row(children: [
          Icon(Icons.shield_outlined, color: Color(0xFFB3EAFF), size: 16),
          SizedBox(width: 8),
          Expanded(child: Text('Apoio técnico — exige conferência e validação para uso regulado.',
              style: TextStyle(color: Color(0xFFC6D5EE), fontSize: 12))),
        ]),
      ]),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onSelected, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label), selected: selected,
        avatar: icon == null ? null : Icon(icon, size: 18),
        onSelected: (_) => onSelected(),
        showCheckmark: false,
      ),
    );
  }

  Widget _calculatorCard(CalculatorDefinition calc, ColorScheme scheme) {
    final starred = _favorites.contains(calc.id);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => CalculatorDetail(
            calculator: calc,
            favorite: starred,
            onFavorite: () => _toggleFavorite(calc.id),
          ),
        )).then((_) { if (mounted) setState(() {}); }),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(categoryIcon(calc.category), color: scheme.primary, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(calc.category.label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: scheme.primary)),
              const SizedBox(height: 5),
              Text(calc.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(calc.summary, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ])),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: starred ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
              icon: Icon(starred ? Icons.star_rounded : Icons.star_border_rounded,
                  color: starred ? const Color(0xFFFFC857) : scheme.onSurfaceVariant),
              onPressed: () => _toggleFavorite(calc.id),
            ),
          ]),
        ),
      ),
    );
  }
}

class CalculatorDetail extends StatefulWidget {
  final CalculatorDefinition calculator;
  final bool favorite;
  final VoidCallback onFavorite;
  const CalculatorDetail({super.key, required this.calculator,
    required this.favorite, required this.onFavorite});
  @override
  State<CalculatorDetail> createState() => _CalculatorDetailState();
}

class _CalculatorDetailState extends State<CalculatorDetail> {
  late final Map<String, TextEditingController> _inputs;
  CalculationResult? _result;
  String? _error;
  late bool _favorite;

  @override
  void initState() {
    super.initState();
    _favorite = widget.favorite;
    _inputs = {for (final f in widget.calculator.fields) f.key: TextEditingController()};
  }

  @override
  void dispose() {
    for (final c in _inputs.values) { c.dispose(); }
    super.dispose();
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    try {
      final values = {for (final entry in _inputs.entries) entry.key: entry.value.text};
      final result = calculate(widget.calculator, values);
      setState(() { _result = result; _error = null; });
    } on CalculatorException catch (e) {
      setState(() { _result = null; _error = e.message; });
    } catch (_) {
      setState(() { _result = null; _error = 'Falha inesperada. Confira os dados e tente novamente.'; });
    }
  }

  void _example() {
    for (final f in widget.calculator.fields) {
      _inputs[f.key]!.text = f.example;
    }
    setState(() { _result = null; _error = null; });
  }

  @override
  Widget build(BuildContext context) {
    final calc = widget.calculator;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(calc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [IconButton(
          tooltip: _favorite ? 'Desfavoritar' : 'Favoritar',
          icon: Icon(_favorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _favorite ? const Color(0xFFFFC857) : null),
          onPressed: () { widget.onFavorite(); setState(() => _favorite = !_favorite); },
        )],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(categoryIcon(calc.category), color: scheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(calc.category.label, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            Text(calc.summary, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 19),
            Card(child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Valores de entrada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton.icon(onPressed: _example, icon: const Icon(Icons.auto_fix_high, size: 16), label: const Text('Exemplo')),
                ]),
                const SizedBox(height: 12),
                ...calc.fields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(bottom: 6),
                        child: Text(f.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                    TextField(
                      controller: _inputs[f.key],
                      minLines: 1, maxLines: f.series ? 4 : 1,
                      keyboardType: f.series ? TextInputType.multiline : const TextInputType.numberWithOptions(decimal: true, signed: true),
                      textInputAction: f.series ? TextInputAction.newline : TextInputAction.next,
                      onChanged: (_) { if (_result != null || _error != null) setState(() { _result = null; _error = null; }); },
                      decoration: InputDecoration(
                        hintText: f.series ? 'Ex.: ${f.example}' : 'Ex.: ${f.example.replaceAll('.', ',')}',
                        suffixText: f.series ? null : f.unit,
                      ),
                    ),
                  ]),
                )),
                SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
                  onPressed: _calculate,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Calcular', style: TextStyle(fontWeight: FontWeight.bold)),
                )),
              ]),
            )),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Card(color: scheme.errorContainer, child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.error_outline, color: scheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer))),
                ]),
              )),
            ],
            if (_result != null) ...[
              const SizedBox(height: 14),
              _resultCard(_result!, scheme),
            ],
            const SizedBox(height: 16),
            Card(child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(Icons.functions, color: scheme.primary), const SizedBox(width: 8),
                  const Text('Fórmula utilizada', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 12),
                SelectableText(calc.formula, style: const TextStyle(fontSize: 15, height: 1.55)),
                const SizedBox(height: 17),
                Row(children: [Icon(Icons.info_outline, size: 19, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 7), const Text('Premissas e cuidados', style: TextStyle(fontWeight: FontWeight.bold))]),
                const SizedBox(height: 7),
                Text(calc.note, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.55)),
              ]),
            )),
            const SizedBox(height: 12),
            Text('Uso técnico de apoio. Revise dados, unidades e procedimento aprovado antes de utilizar os resultados.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12), textAlign: TextAlign.center),
          ]),
        )),
      ),
    );
  }

  Widget _resultCard(CalculationResult result, ColorScheme scheme) {
    final export = StringBuffer()
      ..writeln('AURORA Calculadora Farmacêutica — ${widget.calculator.name}')
      ..writeln('Fórmula: ${widget.calculator.formula}');
    for (final field in widget.calculator.fields) {
      export.writeln('${field.label}: ${_inputs[field.key]!.text} ${field.series ? '' : field.unit}');
    }
    export.writeln('${result.title}: ${formatValue(result.value)} ${result.unit}');
    for (final metric in result.extras) {
      export.writeln('${metric.label}: ${formatValue(metric.value)} ${metric.unit}');
    }
    export.writeln('Apoio técnico não validado. Confirmar segundo POP/método aprovado.');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.45)),
        color: scheme.primary.withValues(alpha: 0.08),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.check_circle_outline, color: scheme.primary),
          const SizedBox(width: 9),
          const Text('Resultado calculado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 14),
        Text(result.title, style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 5),
        SelectableText('${formatValue(result.value)} ${result.unit}',
          style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: scheme.primary)),
        for (final extra in result.extras) ...[
          const Divider(height: 23),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(extra.label, style: TextStyle(color: scheme.onSurfaceVariant))),
            const SizedBox(width: 8),
            Flexible(child: Text('${formatValue(extra.value)} ${extra.unit}',
              textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
        ],
        const SizedBox(height: 12),
        Text(result.explanation, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy_outlined, size: 18),
          label: const Text('Copiar cálculo e dados'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: export.toString()));
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cálculo copiado para a área de transferência.')));
          },
        ),
      ]),
    );
  }
}
