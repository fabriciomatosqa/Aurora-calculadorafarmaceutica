# AURORA Calculadora Farmacêutica

Aplicativo Flutter multiplataforma, com interface em português, **21 calculadoras gerais** para soluções, controle de qualidade e produção farmacêutica. Os cálculos funcionam offline no Android e no iOS; interface clara/escura automática, busca, favoritos locais e cópia de entradas/resultados.

> **ATENÇÃO — Protótipo técnico v0.2.0.** Não validado para uso em ambiente regulado, decisão clínica, liberação/reprovação de lotes ou substituição de POPs e métodos aprovados. Toda fórmula, unidade, precisão, arredondamento, faixa, rastreabilidade e condição de aplicação deve ser avaliada pelo responsável técnico antes do uso operacional. Nenhum resultado determina conformidade.

## Calculadoras

**Soluções (9):** diluição C1V1, fator de diluição, concentração %m/v, %m/m, %v/v, molaridade, massa para molaridade, mistura de duas soluções, concentração mg/L.

**Controle de qualidade (7):** densidade, correção de teor/pureza, recuperação analítica, viés relativo, média/DP amostral/DPR, estimativa de LD e LQ por σ/S, perda por secagem.

**Produção (5):** rendimento de lote, perda de processo, escalonamento, massa teórica de comprimidos, vazão volumétrica.

Cada tela informa unidades fixas, fórmula e limitações. Valores monetários ou clínicos não fazem parte do escopo da versão 0.2.0. Em DPR, separar medições por ponto e vírgula ou linhas (vírgula pode ser separador decimal).

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

## Atualização pelo aplicativo (v0.2.0)

O app verifica automaticamente a existência de uma nova versão no GitHub **toda vez que a tela inicial abre**, sem travar cálculos offline. Também há um botão **Verificar atualizações** no topo.

Quando uma nova Release pública está disponível, ele pergunta se deseja atualizar. No Android, baixa o APK, verifica SHA-256, e abre o instalador do Android mediante autorização. O instalador não é silencioso. No iOS, abre apenas as novidades; a instalação real deve ocorrer pela App Store ou TestFlight.

**Atenção: este repositório está PRIVADO.** Releases privados não são acessíveis por um APK sem autenticação. Para ativar o verificador no celular, é necessário tornar público o repositório de distribuição (este ou outro) e disponibilizar nele as Releases. Tokens GitHub não devem ser incluídos no código.

**Assinatura:** a CI publica APK de teste, mas a atualização sobre uma instalação já existente exige a mesma chave de assinatura. Para gerar APK release assinável, é necessário configurar os quatro secrets de assinatura no GitHub; sem eles, a workflow **não publica Release**.

Leia **[Configuração do atualizador, assinatura e distribuição](docs/ATUALIZACOES.md)** antes de instalar a primeira versão.

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
- `lib/services/update_service.dart`: verificação de GitHub Releases, SHA-256 e instalador Android;
- `scripts/configure_android.py`: configuração do Android e assinatura via secrets;
- `test/`: casos unitários, limites e teste de interface;
- `docs/REFERENCIAS.md`: fontes, hipóteses e limites;
- `.github/workflows/`: CI Android e teste opcional iOS.

Os diretórios de plataformas Android/iOS são gerados em build pelo `flutter create` para evitar arquivos de template desatualizados; o CI gera uma plataforma limpa em cada execução.

## Próximos passos para versão regulada

Definir casos de uso e POPs da instituição, validar independentemente cada fórmula, implementar algoritmo de arredondamento conforme método, gestão de versões de cálculos, usuários e permissões, trilha de auditoria imutável, registros legíveis e íntegros, assinatura eletrônica quando exigida, backup, controles de mudança, IQ/OQ/PQ e avaliação de requisitos GxP (incluindo integridade dos dados). A aplicação não oferece essas garantias nesta versão.

**Licença:** não definida pelo proprietário. Não supor autorização para redistribuição comercial.