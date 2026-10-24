# AURORA Calculadora Farmacêutica

Aplicativo Flutter multiplataforma, com interface em português, **21 calculadoras gerais** para soluções, controle de qualidade e produção farmacêutica. Os cálculos funcionam offline no Android e no iOS; interface clara/escura automática, busca, favoritos locais e cópia de entradas/resultados.

> **ATENÇÃO — Protótipo técnico v0.1.0.** Não validado para uso em ambiente regulado, decisão clínica, liberação/reprovação de lotes ou substituição de POPs e métodos aprovados. Toda fórmula, unidade, precisão, arredondamento, faixa, rastreabilidade e condição de aplicação deve ser avaliada pelo responsável técnico antes do uso operacional. Nenhum resultado determina conformidade.

## Calculadoras

**Soluções (9):** diluição C1V1, fator de diluição, concentração %m/v, %m/m, %v/v, molaridade, massa para molaridade, mistura de duas soluções, concentração mg/L.

**Controle de qualidade (7):** densidade, correção de teor/pureza, recuperação analítica, viés relativo, média/DP amostral/DPR, estimativa de LD e LQ por σ/S, perda por secagem.

**Produção (5):** rendimento de lote, perda de processo, escalonamento, massa teórica de comprimidos, vazão volumétrica.

Cada tela informa unidades fixas, fórmula e limitações. Valores monetários ou clínicos não fazem parte do escopo da versão 0.1.0. Em DPR, separar medições por ponto e vírgula ou linhas (vírgula pode ser separador decimal).

## Android — construir e obter APK

A workflow [`Android APK - testes e compilação`](.github/workflows/android.yml) executa automaticamente em cada push à `main` e pode ser iniciada manualmente em **Actions → Android APK - testes e compilação → Run workflow**.

Na execução bem-sucedida, abrir o job e baixar o artefato `aurora-calculadora-farmaceutica-android-v0.1.0-debug` (ZIP contendo `app-debug.apk`). Trata-se de um **APK de desenvolvimento** instalável em Android, não de uma versão de produção assinada para Play Store. Instalação manual exige permitir instalação da origem escolhida, conforme políticas do aparelho.

Para compilar localmente com Flutter e Android SDK:

```bash
flutter create --project-name aurora_calculadora_farmaceutica --org br.com.aurora --platforms android .
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Saída típica: `build/app/outputs/flutter-apk/app-debug.apk`.

## iOS — projeto, simulador e distribuição

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
- `test/`: casos unitários, limites e teste de interface;
- `docs/REFERENCIAS.md`: fontes, hipóteses e limites;
- `.github/workflows/`: CI Android e teste opcional iOS.

Os diretórios de plataformas Android/iOS são gerados em build pelo `flutter create` para evitar arquivos de template desatualizados; o CI gera uma plataforma limpa em cada execução.

## Próximos passos para versão regulada

Definir casos de uso e POPs da instituição, validar independentemente cada fórmula, implementar algoritmo de arredondamento conforme método, gestão de versões de cálculos, usuários e permissões, trilha de auditoria imutável, registros legíveis e íntegros, assinatura eletrônica quando exigida, backup, controles de mudança, IQ/OQ/PQ e avaliação de requisitos GxP (incluindo integridade dos dados). A aplicação não oferece essas garantias nesta versão.

**Licença:** não definida pelo proprietário. Não supor autorização para redistribuição comercial.