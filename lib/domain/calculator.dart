import 'dart:math' as math;

/// Mathematics-only domain layer: no UI, networking or clinical decisions.
enum CalculatorCategory { solutions, quality, production, prescriptions }

extension CategoryLabel on CalculatorCategory {
  String get label => switch (this) {
        CalculatorCategory.solutions => 'Soluções',
        CalculatorCategory.quality => 'Controle de qualidade',
        CalculatorCategory.production => 'Produção',
        CalculatorCategory.prescriptions => 'Prescrições',
      };
}

class CalculatorField {
  final String key;
  final String label;
  final String unit;
  final String example;
  final bool series;
  const CalculatorField(this.key, this.label, this.unit, this.example,
      {this.series = false});
}

class CalculatorDefinition {
  final String id;
  final String name;
  final String summary;
  final CalculatorCategory category;
  final String formula;
  final List<CalculatorField> fields;
  final String note;

  const CalculatorDefinition({
    required this.id,
    required this.name,
    required this.summary,
    required this.category,
    required this.formula,
    required this.fields,
    required this.note,
  });
}

class CalculationResult {
  final String title;
  final double value;
  final String unit;
  final String explanation;
  final List<CalculationMetric> extras;
  const CalculationResult(this.title, this.value, this.unit, this.explanation,
      [this.extras = const []]);
}

class CalculationMetric {
  final String label;
  final double value;
  final String unit;
  const CalculationMetric(this.label, this.value, this.unit);
}

/// Equations are general dimensional identities, not release criteria.
/// All input units are fixed in the catalog and must be reviewed before use.
const calculators = <CalculatorDefinition>[
  CalculatorDefinition(
    id: 'dilution', name: 'Diluição (C₁V₁ = C₂V₂)',
    summary: 'Volume de estoque e diluente para uma solução final',
    category: CalculatorCategory.solutions,
    formula: 'V₁ = (C₂ × V₂) / C₁; Vdiluente = V₂ − V₁',
    fields: [
      CalculatorField('c1', 'Concentração do estoque', 'mg/mL', '100'),
      CalculatorField('c2', 'Concentração desejada', 'mg/mL', '10'),
      CalculatorField('v2', 'Volume final', 'mL', '100'),
    ],
    note: 'Pressupõe mesma substância, concentrações na mesma unidade e volumes aditivos. Confirme compatibilidade e estabilidade.'),
  CalculatorDefinition(
    id: 'dilution_factor', name: 'Fator de diluição',
    summary: 'Relação entre volume final e alíquota',
    category: CalculatorCategory.solutions,
    formula: 'FD = Vfinal / Valíquota',
    fields: [
      CalculatorField('aliquot', 'Volume da alíquota', 'mL', '5'),
      CalculatorField('final', 'Volume final', 'mL', '50'),
    ], note: 'Os dois volumes devem estar na mesma unidade. FD ≥ 1.'),
  CalculatorDefinition(
    id: 'mass_volume', name: 'Concentração % (m/v)',
    summary: 'Gramas de soluto por 100 mL de solução',
    category: CalculatorCategory.solutions,
    formula: '% (m/v) = (massa do soluto em g / volume final em mL) × 100',
    fields: [
      CalculatorField('mass', 'Massa do soluto', 'g', '5'),
      CalculatorField('volume', 'Volume final da solução', 'mL', '100'),
    ], note: 'Usar volume FINAL da solução, não apenas o volume de solvente.'),
  CalculatorDefinition(
    id: 'mass_mass', name: 'Concentração % (m/m)',
    summary: 'Massa de soluto dividida pela massa total',
    category: CalculatorCategory.solutions,
    formula: '% (m/m) = (massa do soluto / massa total da mistura) × 100',
    fields: [
      CalculatorField('solute', 'Massa do soluto', 'g', '15'),
      CalculatorField('total', 'Massa total da mistura', 'g', '300'),
    ], note: 'Massas na mesma unidade; massa do soluto não pode exceder a massa total.'),
  CalculatorDefinition(
    id: 'volume_volume', name: 'Concentração % (v/v)',
    summary: 'Volume do componente por 100 mL de mistura',
    category: CalculatorCategory.solutions,
    formula: '% (v/v) = (volume do componente / volume final) × 100',
    fields: [
      CalculatorField('solute', 'Volume do componente', 'mL', '20'),
      CalculatorField('total', 'Volume final da mistura', 'mL', '100'),
    ], note: 'Usar volume final medido; misturas podem contrair ou expandir.'),
  CalculatorDefinition(
    id: 'molarity', name: 'Molaridade',
    summary: 'Concentração em mol/L a partir de massa e massa molar',
    category: CalculatorCategory.solutions,
    formula: 'M = massa (g) / [massa molar (g/mol) × volume (L)]',
    fields: [
      CalculatorField('mass', 'Massa do soluto', 'g', '5.844'),
      CalculatorField('mw', 'Massa molar', 'g/mol', '58.44'),
      CalculatorField('volume', 'Volume final da solução', 'mL', '1000'),
    ], note: 'Considere a forma química correta (sal, hidrato etc.) e a pureza quando pertinente.'),
  CalculatorDefinition(
    id: 'molarity_mass', name: 'Massa para molaridade',
    summary: 'Massa necessária para preparar uma solução molar',
    category: CalculatorCategory.solutions,
    formula: 'm (g) = M (mol/L) × MM (g/mol) × V (mL) / 1000',
    fields: [
      CalculatorField('molarity', 'Molaridade desejada', 'mol/L', '0.1'),
      CalculatorField('mw', 'Massa molar', 'g/mol', '58.44'),
      CalculatorField('volume', 'Volume final', 'mL', '1000'),
    ], note: 'Resultado teórico, sem correção automática de pureza ou teor.'),
  CalculatorDefinition(
    id: 'blend', name: 'Mistura de duas soluções',
    summary: 'Concentração após misturar dois volumes',
    category: CalculatorCategory.solutions,
    formula: 'Cfinal = (C₁V₁ + C₂V₂) / (V₁ + V₂)',
    fields: [
      CalculatorField('c1', 'Concentração 1', 'mg/mL', '20'),
      CalculatorField('v1', 'Volume 1', 'mL', '50'),
      CalculatorField('c2', 'Concentração 2', 'mg/mL', '10'),
      CalculatorField('v2', 'Volume 2', 'mL', '50'),
    ], note: 'Mesma substância, unidades homogêneas, sem reação e com volumes aditivos.'),
  CalculatorDefinition(
    id: 'mg_per_l', name: 'Concentração em mg/L',
    summary: 'Massa em mg por litro de solução',
    category: CalculatorCategory.solutions,
    formula: 'C (mg/L) = massa (mg) / [volume (mL) / 1000]',
    fields: [
      CalculatorField('mass', 'Massa do analito', 'mg', '25'),
      CalculatorField('volume', 'Volume final', 'mL', '500'),
    ], note: 'mg/L não deve ser automaticamente tratado como ppm; isso depende da densidade.'),
  CalculatorDefinition(
    id: 'density', name: 'Densidade',
    summary: 'Massa por volume de uma amostra',
    category: CalculatorCategory.quality,
    formula: 'ρ = massa (g) / volume (mL)',
    fields: [
      CalculatorField('mass', 'Massa', 'g', '125'),
      CalculatorField('volume', 'Volume', 'mL', '100'),
    ], note: 'Temperatura influencia a densidade. Informe-a no registro técnico externo.'),
  CalculatorDefinition(
    id: 'purity_adjust', name: 'Correção de teor/pureza',
    summary: 'Ajusta a pesagem pela potência declarada',
    category: CalculatorCategory.quality,
    formula: 'Massa a pesar = massa ativa-alvo × 100 / teor (%)',
    fields: [
      CalculatorField('target', 'Massa ativa desejada', 'g', '100'),
      CalculatorField('purity', 'Teor certificado', '%', '98'),
    ], note: 'Pressupõe teor diretamente aplicável na mesma base do alvo. Não corrige umidade, sal/hidrato ou equivalência química.'),
  CalculatorDefinition(
    id: 'recovery', name: 'Recuperação analítica',
    summary: 'Recuperação de uma quantidade adicionada',
    category: CalculatorCategory.quality,
    formula: '% Recuperação = (encontrado − original) / adicionado × 100',
    fields: [
      CalculatorField('found', 'Quantidade após adição', 'mg', '119'),
      CalculatorField('original', 'Quantidade original', 'mg', '20'),
      CalculatorField('added', 'Quantidade adicionada', 'mg', '100'),
    ], note: 'Todas as quantidades na mesma unidade; exige desenho experimental compatível. Valor negativo sinaliza dados incoerentes.'),
  CalculatorDefinition(
    id: 'bias', name: 'Viés relativo',
    summary: 'Diferença relativa entre valor e referência',
    category: CalculatorCategory.quality,
    formula: 'Viés (%) = (medido − referência) / referência × 100',
    fields: [
      CalculatorField('measured', 'Valor medido', 'mg', '98'),
      CalculatorField('reference', 'Valor de referência', 'mg', '100'),
    ], note: 'O sinal indica viés positivo ou negativo; não estabelece conformidade.'),
  CalculatorDefinition(
    id: 'rsd', name: 'Média, DP e DPR (RSD)',
    summary: 'Precisão a partir de resultados replicados',
    category: CalculatorCategory.quality,
    formula: 'DP amostral = √[Σ(xᵢ − x̄)²/(n−1)]; DPR (%) = DP/x̄ × 100',
    fields: [
      CalculatorField('values', 'Resultados (separar por ponto e vírgula ou linha)', 'mesma unidade', '98; 99; 100; 101; 102', series: true),
    ], note: 'Usa desvio-padrão AMOSTRAL (n−1), pelo menos 2 medições e média positiva; mesmo método/unidade.'),
  CalculatorDefinition(
    id: 'lod_loq', name: 'LD e LQ por σ/inclinação',
    summary: 'Estimativa baseada em resposta analítica e curva',
    category: CalculatorCategory.quality,
    formula: 'LD = 3,3σ/|S|; LQ = 10σ/|S|',
    fields: [
      CalculatorField('sd', 'Desvio-padrão da resposta (σ)', 'resposta', '0.6'),
      CalculatorField('slope', 'Inclinação da curva (S)', 'resposta/(mg/L)', '2'),
    ], note: 'Estimativa ICH Q2(R2). Unidade do resultado é a da concentração no eixo X (exemplo: mg/L). A adequação deve ser demonstrada experimentalmente.'),
  CalculatorDefinition(
    id: 'drying', name: 'Perda por secagem',
    summary: 'Percentual de massa removida por secagem',
    category: CalculatorCategory.quality,
    formula: '% Perda = (massa antes − massa depois) / massa antes × 100',
    fields: [
      CalculatorField('before', 'Massa antes', 'g', '10'),
      CalculatorField('after', 'Massa depois', 'g', '9.6'),
    ], note: 'Perda por secagem pode incluir outros voláteis além da água. A metodologia é definida pelo procedimento aprovado.'),
  CalculatorDefinition(
    id: 'yield', name: 'Rendimento de lote',
    summary: 'Percentual obtido em relação ao previsto',
    category: CalculatorCategory.production,
    formula: 'Rendimento (%) = quantidade real / quantidade teórica × 100',
    fields: [
      CalculatorField('actual', 'Quantidade real', 'kg', '94'),
      CalculatorField('theoretical', 'Quantidade teórica', 'kg', '100'),
    ], note: 'Acima de 100% também é possível; investigar e comparar com os limites internos aprovados.'),
  CalculatorDefinition(
    id: 'loss', name: 'Perda de processo',
    summary: 'Massa perdida em relação à massa inicial',
    category: CalculatorCategory.production,
    formula: 'Perda (%) = (massa inicial − massa final) / massa inicial × 100',
    fields: [
      CalculatorField('initial', 'Massa inicial', 'kg', '100'),
      CalculatorField('final', 'Massa final', 'kg', '97'),
    ], note: 'Pressupõe que a diferença seja perda da mesma base de material, não transferência de água/insumos.'),
  CalculatorDefinition(
    id: 'batch_scale', name: 'Escalonamento de lote',
    summary: 'Recalcula massa de um componente para outro lote',
    category: CalculatorCategory.production,
    formula: 'Nova massa = massa base × (lote alvo / lote original)',
    fields: [
      CalculatorField('ingredient', 'Massa do componente no lote original', 'kg', '2'),
      CalculatorField('original', 'Tamanho original do lote', 'kg', '100'),
      CalculatorField('target', 'Tamanho do lote alvo', 'kg', '250'),
    ], note: 'Escalonamento linear teórico. Avaliar processo, rendimento, propriedades de mistura e validação antes da produção.'),
  CalculatorDefinition(
    id: 'tablet_batch', name: 'Massa de comprimidos',
    summary: 'Massa teórica total por quantidade e peso unitário',
    category: CalculatorCategory.production,
    formula: 'Massa total (kg) = número de unidades × massa por unidade (mg) / 1.000.000',
    fields: [
      CalculatorField('count', 'Quantidade de unidades', 'unidades', '100000'),
      CalculatorField('unitmass', 'Massa por unidade', 'mg', '500'),
    ], note: 'Massa teórica; não inclui perdas de processo ou sobredosagem.'),
  CalculatorDefinition(
    id: 'flow', name: 'Vazão volumétrica',
    summary: 'Volume de líquido por minuto',
    category: CalculatorCategory.production,
    formula: 'Vazão = volume (mL) / tempo (min)',
    fields: [
      CalculatorField('volume', 'Volume transferido', 'mL', '500'),
      CalculatorField('time', 'Tempo', 'min', '10'),
    ], note: 'Vazão média para o intervalo medido; não representa uma vazão instantânea.'),
  CalculatorDefinition(
    id: 'prescription_units',
    name: 'Quantidade da prescrição',
    summary: 'Posologia, apresentação e dose máxima informada',
    category: CalculatorCategory.prescriptions,
    formula: 'Quantidade = dose por tomada / teor por unidade × tomadas por dia × dias',
    fields: [],
    note: 'A tela dedicada exige a fonte e o contexto do limite diário. '
        'Não substitui avaliação clínica, checagem de bula nem autorização de dispensação.',
  ),
];

class CalculatorException implements Exception {
  final String message;
  const CalculatorException(this.message);
  @override
  String toString() => message;
}

/// Portuguese decimal comma or dot accepted, but ambiguous grouping is rejected.
double parseDecimal(String raw, String label) {
  final text = raw.trim().replaceAll(' ', '');
  if (text.isEmpty) throw CalculatorException('Preencha: $label.');
  if (text.contains(',') && text.contains('.')) {
    throw CalculatorException('Use vírgula OU ponto decimal em "$label", sem separador de milhar.');
  }
  final parsed = double.tryParse(text.replaceAll(',', '.'));
  if (parsed == null || !parsed.isFinite) {
    throw CalculatorException('Valor numérico inválido em "$label".');
  }
  return parsed;
}

String formatValue(double v) {
  if (!v.isFinite) return 'Inválido';
  if (v == 0) return '0';
  final str = v.toStringAsPrecision(7);
  return str.contains('e')
      ? str.replaceAll('.', ',')
      : (str.contains('.') ? str.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : str).replaceAll('.', ',');
}

CalculationResult calculate(CalculatorDefinition def, Map<String, String> entries) {
  final v = <String, double>{};
  for (final f in def.fields) {
    if (!f.series) v[f.key] = parseDecimal(entries[f.key] ?? '', f.label);
  }
  double get(String key, {bool zero = true}) {
    final n = v[key]!;
    if (n < 0 || (zero && n == 0)) {
      throw CalculatorException('"${def.fields.firstWhere((f) => f.key == key).label}" deve ser ${zero ? 'maior que zero' : 'zero ou positivo'}.');
    }
    return n;
  }
  CalculationResult result(String title, double number, String unit, String detail,
      [List<CalculationMetric> extras = const []]) {
    if (!number.isFinite || extras.any((e) => !e.value.isFinite)) {
      throw const CalculatorException('O resultado excede o intervalo numérico permitido.');
    }
    return CalculationResult(title, number, unit, detail, extras);
  }

  switch (def.id) {
    case 'dilution':
      final c1 = get('c1'), c2 = get('c2'), vf = get('v2');
      if (c2 > c1) throw const CalculatorException('Não é possível obter concentração maior por simples diluição.');
      final ve = c2 * vf / c1;
      return result('Volume de estoque', ve, 'mL', 'Transferir o estoque e completar até o volume final.',
          [CalculationMetric('Diluente aproximado', vf - ve, 'mL')]);
    case 'dilution_factor':
      final va = get('aliquot'), vf = get('final');
      if (vf < va) throw const CalculatorException('O volume final não pode ser menor que a alíquota.');
      return result('Fator de diluição', vf / va, '×', 'Razão adimensional entre os volumes.');
    case 'mass_volume':
      return result('Concentração', get('mass', zero: false) / get('volume') * 100, '% (m/v)', 'g de soluto por 100 mL de solução.');
    case 'mass_mass':
      final solute = get('solute', zero: false), total = get('total');
      if (solute > total) throw const CalculatorException('A massa do soluto não pode superar a massa total.');
      return result('Concentração', solute / total * 100, '% (m/m)', 'g de soluto por 100 g de mistura.');
    case 'volume_volume':
      final part = get('solute', zero: false), total = get('total');
      if (part > total) throw const CalculatorException('O volume do componente não pode superar o volume final.');
      return result('Concentração', part / total * 100, '% (v/v)', 'mL de componente por 100 mL da mistura final.');
    case 'molarity':
      return result('Molaridade', get('mass', zero: false) / (get('mw') * get('volume') / 1000), 'mol/L', 'Massa dividida pelo número de gramas por mol e pelo volume em litros.');
    case 'molarity_mass':
      return result('Massa necessária', get('molarity', zero: false) * get('mw') * get('volume') / 1000, 'g', 'Massa teórica da espécie química na solução final.');
    case 'blend':
      final c1 = get('c1', zero: false), c2 = get('c2', zero: false),
          a = get('v1'), b = get('v2');
      return result('Concentração da mistura', (c1 * a + c2 * b) / (a + b), 'mg/mL', 'Balanço de massa, assumindo volumes aditivos.',
          [CalculationMetric('Volume final estimado', a + b, 'mL')]);
    case 'mg_per_l':
      return result('Concentração', get('mass', zero: false) * 1000 / get('volume'), 'mg/L', 'Conversão de mL para L; não equivale necessariamente a ppm.');
    case 'density':
      return result('Densidade', get('mass', zero: false) / get('volume'), 'g/mL', 'Relação massa por volume na temperatura do ensaio.');
    case 'purity_adjust':
      final purity = get('purity');
      if (purity > 200) throw const CalculatorException('Confira o teor certificado: acima de 200% não é aceito.');
      return result('Massa a pesar', get('target', zero: false) * 100 / purity, 'g', 'Aplicável apenas se a base do teor coincidir com a base da massa desejada.');
    case 'recovery':
      final found = get('found', zero: false), original = get('original', zero: false), added = get('added');
      return result('Recuperação', (found - original) / added * 100, '%', 'Recuperação por adição conhecida de analito.');
    case 'bias':
      final measured = get('measured', zero: false), reference = get('reference');
      return result('Viés relativo', (measured - reference) / reference * 100, '%', 'Diferença percentual assinada em relação à referência.');
    case 'rsd':
      final input = entries['values']?.trim() ?? '';
      if (input.isEmpty) throw const CalculatorException('Informe ao menos duas medições.');
      final parts = input.split(RegExp(r'[;\n]+')).where((s) => s.trim().isNotEmpty).toList();
      if (parts.length < 2) throw const CalculatorException('Informe no mínimo duas medições separadas por ponto e vírgula.');
      if (parts.length > 10000) throw const CalculatorException('Limite de 10.000 medições por cálculo.');
      final values = parts.map((s) => parseDecimal(s, 'Resultado')).toList();
      if (values.any((n) => n < 0)) throw const CalculatorException('Este cálculo exige resultados não negativos.');
      final mean = values.reduce((a, b) => a + b) / values.length;
      if (mean <= 0) throw const CalculatorException('A média deve ser maior que zero.');
      final sd = math.sqrt(values.fold<double>(0, (s, n) => s + math.pow(n - mean, 2).toDouble()) / (values.length - 1));
      return result('Desvio-padrão relativo', sd / mean * 100, '%', 'DP amostral (n−1) em ${values.length} medições.',
          [CalculationMetric('Média', mean, 'unid.'), CalculationMetric('DP amostral', sd, 'unid.'), CalculationMetric('Número de medições', values.length.toDouble(), 'n')]);
    case 'lod_loq':
      final sigma = get('sd', zero: false), slope = v['slope']!.abs();
      if (slope == 0) throw const CalculatorException('A inclinação não pode ser zero.');
      return result('Limite de detecção (LD)', 3.3 * sigma / slope, 'unid. da curva', 'Estimativa pelo método σ/S da ICH Q2(R2).',
          [CalculationMetric('Limite de quantificação (LQ)', 10 * sigma / slope, 'unid. da curva')]);
    case 'drying':
      final before = get('before'), after = get('after', zero: false);
      if (after > before) throw const CalculatorException('A massa após secagem não pode superar a massa inicial neste modelo.');
      return result('Perda por secagem', (before - after) / before * 100, '%', 'Representa massa perdida, não necessariamente só água.');
    case 'yield':
      return result('Rendimento', get('actual', zero: false) / get('theoretical') * 100, '%', 'Quantidade real sobre quantidade teórica.');
    case 'loss':
      final initial = get('initial'), finalMass = get('final', zero: false);
      if (finalMass > initial) throw const CalculatorException('A massa final excede a massa inicial: revise os dados e a base de cálculo.');
      return result('Perda de processo', (initial - finalMass) / initial * 100, '%', 'Diferença de massa relativa à entrada.');
    case 'batch_scale':
      return result('Nova massa do componente', get('ingredient', zero: false) * get('target') / get('original'), 'kg', 'Escalonamento linear de lote.',
          [CalculationMetric('Fator de escala', v['target']! / v['original']!, '×')]);
    case 'tablet_batch':
      final count = get('count'), mass = get('unitmass');
      if (count != count.roundToDouble()) throw const CalculatorException('Quantidade de unidades deve ser um número inteiro.');
      return result('Massa teórica total', count * mass / 1000000, 'kg', 'Sem margem de perdas de processo.');
    case 'flow':
      return result('Vazão média', get('volume', zero: false) / get('time'), 'mL/min', 'Volume total dividido pelo tempo decorrido.');
    default:
      throw const CalculatorException('Calculadora não implementada.');
  }
}