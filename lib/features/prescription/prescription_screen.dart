import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/calculator.dart';
import '../../domain/prescription.dart';
import 'prescription_document_reader.dart';
import 'prescription_text_hints.dart';

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
  final _prescriptionText = TextEditingController();
  final _documentReader = PrescriptionDocumentReader();
  String? _selectedFileName;
  String? _importMessage;
  bool _importBusy = false;
  PrescriptionCalculation? _result;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name, _strength, _dose, _times, _days, _maximum, _reference, _package,
      _prescriptionText,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _importPrescription(
    Future<PrescriptionDocument?> Function() pick,
  ) async {
    if (_importBusy) return;
    setState(() {
      _importBusy = true;
      _importMessage = null;
      _result = null;
    });
    try {
      final imported = await pick();
      if (!mounted || imported == null) return;
      setState(() {
        _selectedFileName = imported.name;
        _prescriptionText.text = imported.text;
        _importMessage = imported.fromOcr
            ? 'Leitura OCR concluída. Pode conter erros: revise cada palavra, '
              'dose e unidade antes de prosseguir.'
            : 'Texto do PDF extraído. Confira com o documento original.';
      });
    } on PrescriptionReadException catch (error) {
      if (mounted) setState(() => _importMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _importMessage =
            'Não foi possível abrir ou ler este arquivo. Tente outra imagem '
            'ou um PDF com texto selecionável.');
      }
    } finally {
      if (mounted) setState(() => _importBusy = false);
    }
  }

  Future<void> _reviewExtractedFields() async {
    final source = _prescriptionText.text.trim();
    if (source.isEmpty) {
      setState(() => _importMessage =
          'Envie uma imagem, arquivo PDF ou cole o texto da prescrição.');
      return;
    }
    final suggestions = suggestPrescriptionFields(source);
    if (suggestions.isEmpty) {
      setState(() => _importMessage =
          'Não foi possível identificar campos com segurança. '
          'Transcreva os valores manualmente abaixo.');
      return;
    }
    final details = <String>[
      if (suggestions.form != null)
        'Forma: ${suggestions.form!.label}',
      if (suggestions.strengthMg != null)
        'Apresentação: ${formatValue(suggestions.strengthMg!)} '
          '${suggestions.form?.strengthUnit ?? 'mg/unidade'}',
      if (suggestions.doseMg != null)
        'Dose por tomada: ${formatValue(suggestions.doseMg!)} mg',
      if (suggestions.administrationsPerDay != null)
        'Frequência: ${suggestions.administrationsPerDay} tomadas/dia',
      if (suggestions.durationDays != null)
        'Duração: ${suggestions.durationDays} dias',
    ];
    final approve = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar dados extraídos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esses dados são apenas sugestões. Compare com a prescrição '
                'original antes de transferir aos campos:',
              ),
              const SizedBox(height: 14),
              ...details.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $item'),
              )),
              const SizedBox(height: 12),
              const Text(
                'A dose máxima diária e sua referência NÃO serão preenchidas '
                'automaticamente. Somente o profissional pode verificá-las.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Revisar texto'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Aplicar sugestões'),
          ),
        ],
      ),
    );
    if (approve != true || !mounted) return;
    setState(() {
      if (suggestions.form != null) _form = suggestions.form!;
      if (suggestions.strengthMg != null) {
        _strength.text = formatValue(suggestions.strengthMg!);
      }
      if (suggestions.doseMg != null) {
        _dose.text = formatValue(suggestions.doseMg!);
      }
      if (suggestions.administrationsPerDay != null) {
        _times.text = '${suggestions.administrationsPerDay}';
      }
      if (suggestions.durationDays != null) {
        _days.text = '${suggestions.durationDays}';
      }
      _result = null;
      _error = null;
      _importMessage = 'Sugestões aplicadas. Confira TODOS os campos e '
          'preencha o limite diário com uma fonte oficial antes do cálculo.';
    });
  }

  Widget _documentImportPanel() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.document_scanner_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('1. IMPORTAR PRESCRIÇÃO',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ))),
            ]),
            const SizedBox(height: 8),
            const Text('Selecione uma imagem ou PDF para extrair o texto no '
              'próprio aparelho. Nenhum documento é enviado a um servidor.'),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: _importBusy ? null : () =>
                  _importPrescription(_documentReader.fromCamera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Tirar foto'),
              ),
              OutlinedButton.icon(
                onPressed: _importBusy ? null : () =>
                  _importPrescription(_documentReader.fromGallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeria'),
              ),
              OutlinedButton.icon(
                onPressed: _importBusy ? null : () =>
                  _importPrescription(_documentReader.fromFile),
                icon: const Icon(Icons.attach_file_outlined),
                label: const Text('Arquivo / PDF'),
              ),
            ]),
            if (_importBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 5),
              const Text('Lendo o documento no aparelho...'),
            ],
            if (_selectedFileName != null) ...[
              const SizedBox(height: 12),
              Text('Arquivo selecionado: $_selectedFileName',
                style: TextStyle(color: scheme.primary)),
            ],
            if (_importMessage != null) ...[
              const SizedBox(height: 12),
              _warning(_importMessage!),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _prescriptionText,
              maxLines: 7,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'Texto da prescrição (editável)',
                alignLabelWithHint: true,
                hintText: 'O texto extraído aparecerá aqui. '
                  'Também pode ser digitado ou colado manualmente.',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _importBusy ? null : _reviewExtractedFields,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Conferir e sugerir preenchimento'),
            ),
            const SizedBox(height: 10),
            Text(
              'OCR pode confundir 1/I, 0/O e mg/mL. Compare sempre '
              'com o documento original. Este app não aprova prescrições.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
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

  void _calculate() {
    FocusScope.of(context).unfocus();
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
              _documentImportPanel(),
              const SizedBox(height: 14),
              _warning(
                'Apoio matemático, não avaliação clínica automática. '
                'Não contempla doses se necessário (SOS), redução progressiva, '
                'ajuste por peso ou função renal, uso pediátrico, '
                'fracionamento de comprimidos e outras situações especiais.',
              ),
              const SizedBox(height: 18),
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
              const SizedBox(height: 18),
              if (_error != null) ...[
                _warning(_error!, critical: true),
                const SizedBox(height: 14),
              ],
              FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Calcular unidades necessárias'),
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
