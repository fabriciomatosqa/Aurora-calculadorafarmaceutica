import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/calculator.dart';
import '../../domain/prescription.dart';
import 'prescription_capture.dart';
import 'prescription_ocr_parser.dart';

/// Fixed-schedule prescription quantity aid for pharmacists.
/// Not a clinical prescribing or drug-database application.
class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  PharmaceuticalForm _form = PharmaceuticalForm.tablet;
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _dose = TextEditingController();
  final _times = TextEditingController();
  final _days = TextEditingController();
  final _maximum = TextEditingController();
  final _reference = TextEditingController();
  final _package = TextEditingController();
  PrescriptionCalculation? _result;
  String? _error;
  String? _ocrReviewNote;
  bool _reviewedOcr = false;
  final _formKey = GlobalKey();

  @override
  void dispose() {
    for (final controller in [
      _name, _strength, _dose, _times, _days, _maximum, _reference, _package,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int _wholeNumber(String raw, String field) {
    final input = raw.trim();
    if (!RegExp(r'^\d+$').hasMatch(input)) {
      throw PrescriptionCalculationException(
        '$field deve ser um número inteiro positivo.',
      );
    }
    final value = int.tryParse(input);
    if (value == null) {
      throw PrescriptionCalculationException('Valor fora do limite em $field.');
    }
    return value;
  }

  void _applyRecognized(OcrPrescriptionCandidate item) {
    FocusScope.of(context).unfocus();
    setState(() {
      // Clear every prior field to avoid accidental cross-medication reuse.
      _name.text = item.name;
      _form = item.form ?? PharmaceuticalForm.tablet;
      _strength.text = item.strengthMgPerUnit?.toString() ?? '';
      _dose.text = item.doseMgPerAdministration?.toString() ?? '';
      _times.text = item.administrationsPerDay?.toString() ?? '';
      _days.text = item.durationDays?.toString() ?? '';
      _maximum.clear();
      _reference.clear();
      _package.clear();
      _reviewedOcr = false;
      _ocrReviewNote = item.warnings.isEmpty
          ? 'Dados importados do OCR. Confirme todos os valores com a imagem original.'
          : 'A leitura contém campos ausentes ou situações não suportadas: '
              + item.warnings.join(' ');
      _result = null;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _formKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeOutCubic, alignment: 0.04);
      }
    });
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    if (_ocrReviewNote != null && !_reviewedOcr) {
      setState(() {
        _error = 'Confira a prescrição original e confirme os dados '
            'extraídos antes de calcular.';
        _result = null;
      });
      return;
    }
    try {
      final result = calculatePrescription(
        form: _form,
        strengthMgPerUnit:
            parseDecimal(_strength.text, 'Concentração da apresentação'),
        prescribedMgPerAdministration:
            parseDecimal(_dose.text, 'Dose por administração'),
        administrationsPerDay: _wholeNumber(
          _times.text, 'Administrações por dia',
        ),
        durationDays: _wholeNumber(_days.text, 'Duração do tratamento'),
        maximumDailyMg: parseDecimal(
          _maximum.text, 'Dose máxima diária informada',
        ),
        maximumDoseReference: _reference.text,
        packageCapacity: _package.text.trim().isEmpty
            ? null
            : parseDecimal(_package.text, 'Capacidade da embalagem'),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _error = null;
      });
    } on CalculatorException catch (e) {
      setState(() {
        _error = e.message;
        _result = null;
      });
    } on PrescriptionCalculationException catch (e) {
      setState(() {
        _error = e.message;
        _result = null;
      });
    } catch (_) {
      setState(() {
        _error = 'Não foi possível calcular. Confira todos os campos.';
        _result = null;
      });
    }
  }

  void _example() {
    _name.text = 'Medicamento fictício (demonstração)';
    _form = PharmaceuticalForm.tablet;
    _strength.text = '500';
    _dose.text = '500';
    _times.text = '3';
    _days.text = '7';
    _maximum.text = '2000';
    _reference.text = 'LIMITE FICTÍCIO PARA DEMONSTRAÇÃO — não usar clinicamente';
    _package.text = '10';
    setState(() {
      _ocrReviewNote = null;
      _reviewedOcr = false;
      _result = null;
      _error = null;
    });
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    String helper,
  ) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
      ),
      onChanged: (_) {
        if (_result != null || _error != null) {
          setState(() {
            _result = null;
            _error = null;
            if (_ocrReviewNote != null) _reviewedOcr = false;
          });
        }
      },
    );
  }

  Widget _warning(String message, {bool critical = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: critical
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            critical ? Icons.error_outline : Icons.info_outline,
            color: critical ? scheme.onErrorContainer : scheme.onSurface,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: critical ? scheme.onErrorContainer : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultPanel(PrescriptionCalculation result) {
    final unit = result.form.unitName;
    final output =
        'Apresentação: ${result.form.label}\n'
        'Concentração: ${_strength.text} ${result.form.strengthUnit}\n'
        'Dose por administração: ${_dose.text} mg\n'
        'Unidades por administração: '
        '${formatValue(result.unitsPerAdministration)} $unit\n'
        'Frequência: ${result.administrationsPerDay} vezes/dia\n'
        'Duração: ${result.durationDays} dias\n'
        'Dose diária prescrita: ${formatValue(result.dailyDoseMg)} mg/dia\n'
        'Limite diário informado: ${formatValue(result.maximumDailyMg)} mg/dia\n'
        'Fonte declarada: ${result.maximumDoseReference}\n'
        'Quantidade matemática para o tratamento: '
        '${formatValue(result.totalUnits)} $unit\n'
        'Embalagens inteiras (se informadas): '
        '${result.packagesRequired?.toString() ?? 'não calculado'}\n'
        'ATENÇÃO: resultado matemático não substitui avaliação farmacêutica.';
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resultado matemático',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '${formatValue(result.totalUnits)} $unit',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatValue(result.unitsPerAdministration)} $unit por '
              'administração × ${result.administrationsPerDay} vezes/dia × '
              '${result.durationDays} dias',
            ),
            const SizedBox(height: 12),
            Text('Dose diária prescrita: '
                '${formatValue(result.dailyDoseMg)} mg/dia'),
            Text('Limite informado: '
                '${formatValue(result.maximumDailyMg)} mg/dia'),
            const SizedBox(height: 12),
            if (result.exceedsInformedMaximum)
              _warning(
                'ALERTA: a dose diária calculada é MAIOR do que o limite '
                'informado. Não utilize este cálculo para dispensar sem '
                'revisão e esclarecimento do profissional responsável.',
                critical: true,
              )
            else
              _warning(
                'A dose diária não ultrapassa o limite numérico informado. '
                'Isso NÃO comprova segurança, indicação correta nem '
                'adequação ao paciente. Exige revisão farmacêutica.',
              ),
            if (result.packagesRequired != null) ...[
              const SizedBox(height: 12),
              Text('Embalagens completas estimadas: '
                  '${result.packagesRequired}'),
              Text('Excedente nessas embalagens: '
                  '${formatValue(result.extraUnitsInWholePackages!)} $unit'),
              const Text(
                'É uma estimativa comercial, não autorização para fracionar '
                'ou dispensar embalagens extras.',
                style: TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Text('Referência informada: ${result.maximumDoseReference}'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: output));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cálculo copiado.')),
                );
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copiar memória do cálculo'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescrição e posologia'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text('Quantidade para a prescrição',
                style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              _warning(
                'Apoio matemático, não avaliação clínica automática. '
                'Não contempla doses se necessário (SOS), redução progressiva, '
                'ajuste por peso ou função renal, uso pediátrico, '
                'fracionamento de comprimidos e outras situações especiais.',
              ),
              const SizedBox(height: 17),
              PrescriptionCapture(onReviewCandidate: _applyRecognized),
              const SizedBox(height: 18),
              Card(
                key: _formKey,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Icon(Icons.fact_check_outlined, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Conferência dos dados',
                          style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800))),
                      ]),
                      const SizedBox(height: 7),
                      Text('Preencha manualmente ou revise o que a câmera identificou.',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      if (_ocrReviewNote != null) ...[
                        const SizedBox(height: 12),
                        _warning(_ocrReviewNote!, critical: true),
                      ],
                      const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Medicamento ou princípio ativo (opcional)',
                  helperText: 'Não informe dados identificáveis do paciente.',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<PharmaceuticalForm>(
                key: ValueKey(_form),
                initialValue: _form,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Forma farmacêutica',
                ),
                items: PharmaceuticalForm.values.map((form) =>
                  DropdownMenuItem<PharmaceuticalForm>(
                    value: form,
                    child: Text(form.label),
                  ),
                ).toList(),
                onChanged: (form) {
                  if (form == null) return;
                  setState(() {
                    _form = form;
                    if (_ocrReviewNote != null) _reviewedOcr = false;
                    _package.clear();
                    _result = null;
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 14),
              _numberField(
                _strength,
                'Concentração da apresentação (${_form.strengthUnit})',
                _form.isLiquid
                  ? 'Exemplo de conversão: 250 mg em 5 mL = 50 mg/mL. '
                    'Não informe "250" sem converter.'
                  : 'Conteúdo de princípio ativo por unidade inteira.',
              ),
              const SizedBox(height: 14),
              _numberField(_dose, 'Dose prescrita por administração (mg)',
                'Quantidade do princípio ativo em uma tomada.'),
              const SizedBox(height: 14),
              _numberField(_times, 'Administrações por dia',
                'Número inteiro para esquema fixo e regular.'),
              const SizedBox(height: 14),
              _numberField(_days, 'Duração do tratamento (dias)',
                'Número inteiro de dias completos do esquema.'),
              const SizedBox(height: 14),
              _numberField(_maximum, 'Dose máxima diária aplicável (mg/dia)',
                'Confira a bula profissional e o contexto clínico. '
                'Não use valor genérico de outro paciente ou indicação.'),
              const SizedBox(height: 14),
              TextField(
                controller: _reference,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Fonte e contexto da dose máxima',
                  helperText: 'Ex.: bula profissional, apresentação, '
                      'indicação e população. Campo obrigatório.',
                  helperMaxLines: 3,
                ),
                onChanged: (_) {
                  if (_result != null || _error != null) {
                    setState(() {
                      _result = null;
                      _error = null;
                      if (_ocrReviewNote != null) _reviewedOcr = false;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  launchUrl(
                    Uri.parse('https://consultas.anvisa.gov.br/#/bulario/'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Consultar Bulário oficial da ANVISA'),
              ),
              const SizedBox(height: 14),
              _numberField(
                _package,
                _form.isLiquid
                    ? 'Volume por frasco (mL) — opcional'
                    : 'Unidades por embalagem — opcional',
                'Embalagens completas são estimadas por arredondamento '
                'para cima, sem modificar a dose.',
              ),
              if (_ocrReviewNote != null) ...[
                const SizedBox(height: 14),
                CheckboxListTile(
                  value: _reviewedOcr,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Conferi a prescrição original e todos os dados usados'),
                  subtitle: const Text('A confirmação não equivale à validação clínica.'),
                  onChanged: (value) => setState(() {
                    _reviewedOcr = value ?? false;
                    _result = null;
                    _error = null;
                  }),
                ),
              ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_error != null) ...[
                _warning(_error!, critical: true),
                const SizedBox(height: 14),
              ],
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _calculate,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Calcular unidades necessárias'),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _example,
                child: const Text('Preencher exemplo inteiramente fictício'),
              ),
              if (_result != null) ...[
                const SizedBox(height: 18),
                _resultPanel(_result!),
              ],
              const SizedBox(height: 18),
              Text(
                'A apresentação disponível, a equivalência do ativo, '
                'as restrições de fracionamento, o ajuste individual e '
                'a adequação à legislação são conferidos pelo farmacêutico. '
                'Estar abaixo do limite numérico NÃO autoriza dispensação.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
