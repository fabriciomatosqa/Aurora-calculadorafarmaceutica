# AURORA Calculadora Farmacêutica

Aplicativo Flutter com foco exclusivo na versão **Android**, em português, com **22 calculadoras** para soluções, qualidade, produção e avaliação matemática de prescrições. Os cálculos funcionam offline; inclui interface clara/escura, pesquisa, favoritos locais e cópia de resultados. O iOS está fora das prioridades de desenvolvimento.

> **ATENÇÃO — Protótipo técnico v0.6.0.** Não validado para uso em ambiente regulado, decisão clínica, liberação/reprovação de lotes ou substituição de POPs e métodos aprovados. Toda fórmula, unidade, precisão, arredondamento, faixa, rastreabilidade e condição de aplicação deve ser avaliada pelo responsável técnico antes do uso operacional. Nenhum resultado determina conformidade.

## Calculadoras

**Soluções (9):** diluição C1V1, fator de diluição, concentração %m/v, %m/m, %v/v, molaridade, massa para molaridade, mistura de duas soluções, concentração mg/L.

**Controle de qualidade (7):** densidade, correção de teor/pureza, recuperação analítica, viés relativo, média/DP amostral/DPR, estimativa de LD e LQ por σ/S, perda por secagem.

**Produção (5):** rendimento de lote, perda de processo, escalonamento, massa teórica de comprimidos, vazão volumétrica.

**Prescrições (1):** quantidade de comprimidos/cápsulas/sachês inteiros ou volume de líquidos orais para tratamento de dose fixa; comparação da dose diária calculada com limite *informado* e estimativa opcional de embalagens. Veja [regras, validações, limitações e fontes](docs/PRESCRICOES.md).

Cada tela informa unidades fixas, fórmula e limitações. Valores monetários ou clínicos não fazem parte do escopo da versão 0.6.0. Em DPR, separar medições por ponto e vírgula ou linhas (vírgula pode ser separador decimal).

## Android — construir e obter APK

A workflow [`Android - testes, APK e Release`](.github/workflows/android.yml) executa automaticamente em cada push à `main` e pode ser iniciada manualmente em **Actions → Android APK - testes e compilação → Run workflow**.

Na execução bem-sucedida, abrir o job e baixar o artefato `aurora-farmaceutica-debug-<número da execução>` (ZIP contendo `app-debug.apk`). Trata-se de um **APK de desenvolvimento** instalável em Android, não de uma versão definitiva com assinatura persistente. Instalação manual exige permitir instalação da origem escolhida, conforme políticas do aparelho.

Para compilar localmente com Flutter e Android SDK:

```bash
flutter create --project-name aurora_calculadora_farmaceutica --org br.com.aurora --platforms android .
python3 scripts/configure_android.py  # configura permissões e, se houver secrets, assinatura
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Saída típica: `build/app/outputs/flutter-apk/app-debug.apk`.

## Importar prescrições por câmera, foto ou PDF (Android v0.6.0)

Na categoria **Prescrições**, abra **Quantidade da prescrição**. O cartão **1. IMPORTAR PRESCRIÇÃO** aparece em destaque no topo com três opções: **Tirar foto**, **Galeria** e **Arquivo / PDF**.

- Fotos e imagens JPG/PNG recebem OCR **no próprio celular**, sem envio ao servidor.
- PDFs digitais com texto selecionável têm texto extraído localmente; PDFs escaneados exigem imagem/foto para OCR.
- O texto aparece em campo editável. A opção **Conferir e sugerir preenchimento** oferece somente sugestões limitadas de posologia, sempre com confirmação humana.
- **A dose máxima diária não é inferida**: exige valor e referência conferidos pelo profissional. Extração de texto não equivale a validação de prescrição.
- **Favoritos** agora é a primeira aba do catálogo, à frente de Todas.
- Consulte [detalhes e limitações de importação](docs/PRESCRICOES.md).

## Atualização online pelo próprio app Android (v0.6.0)

O repositório oficial agora é **PÚBLICO**. O aplicativo consulta os [Releases do próprio repositório](https://github.com/fabriciomatosqa/Aurora-calculadorafarmaceutica/releases) ao iniciar e ao retornar ao primeiro plano, além do botão de verificação no topo. Nenhuma configuração de outro repositório, credencial ou download manual pelo GitHub é necessária **para versões release assinadas compatíveis**.

Se houver uma atualização, o app mostra a versão e as notas, pergunta se deseja instalar, baixa o APK internamente, verifica seu SHA-256 e abre o instalador do Android. A confirmação do usuário continua obrigatória: não é uma instalação silenciosa.

**Para o primeiro Release funcionar**, o proprietário ainda precisa configurar a **assinatura Android permanente** (quatro Actions Secrets). O workflow `.github/workflows/android.yml` publica um APK release no próprio repositório, somente depois de validação e compilação bem-sucedidas. Sem esses secrets, apenas APK debug estará disponível como Actions Artifact — não como Release de atualização. Um APK release pode exigir reinstalação inicial se a versão atual usa assinatura debug diferente.

Veja [configuração da assinatura, publicação e testes de atualização](docs/ATUALIZACOES.md).

## iOS — fora de escopo no momento

O trabalho atual é exclusivamente Android. O workflow iOS legado permanece no repositório, mas não participa da compilação Android e não integra as prioridades presentes.

## Registro anterior: iOS — instruções mantidas para uso futuro

**iOS não usa APK.** O código Flutter é compartilhado; para testar no iPhone ou gerar IPA é necessário ambiente **macOS com Xcode**, provisionamento e assinatura Apple adequados.

A workflow `iOS - compilação de simulador` é manual, usa runner macOS e produz app de simulador, **não um IPA instalável em iPhone físico**.

No Mac:

```bash
flutter create --project-name aurora_calculadora_farmaceutica --org br.com.aurora --platforms ios .
flutter pub get
flutter test
flutter build ios --simulator --debug
```

Para distribuição real, configurar equipe Apple, Bundle ID, certificados/profiles e executar `flutter build ipa` segundo documentação Apple/Flutter. O aplicativo ainda não tem assinatura iOS.

## Estrutura

- `lib/main.dart`: interface e experiência mobile;
- `lib/domain/calculator.dart`: catálogo e matemática desacoplada;
- `lib/domain/prescription.dart`: domínio isolado para unidades de prescrições;
- `lib/features/prescription/prescription_screen.dart`: formulário e avisos da prescrição;
- `test/prescription_test.dart`: testes matemáticos e alertas;
- `lib/services/update_service.dart`: verificação de GitHub Releases, SHA-256 e instalador Android;
- `scripts/configure_android.py`: configuração do Android e assinatura via secrets;
- `test/`: casos unitários, limites e teste de interface;
- `docs/REFERENCIAS.md`: fontes, hipóteses e limites;
- `.github/workflows/`: CI Android e teste opcional iOS.

Os diretórios de plataformas Android/iOS são gerados em build pelo `flutter create` para evitar arquivos de template desatualizados; o CI gera uma plataforma limpa em cada execução.

## Próximos passos para versão regulada

Definir casos de uso e POPs da instituição, validar independentemente cada fórmula, implementar algoritmo de arredondamento conforme método, gestão de versões de cálculos, usuários e permissões, trilha de auditoria imutável, registros legíveis e íntegros, assinatura eletrônica quando exigida, backup, controles de mudança, IQ/OQ/PQ e avaliação de requisitos GxP (incluindo integridade dos dados). A aplicação não oferece essas garantias nesta versão.

**Licença:** não definida pelo proprietário. Não supor autorização para redistribuição comercial.