# AURORA Calculadora Farmacêutica

Aplicativo Flutter com foco exclusivo na versão **Android**, em português, com **22 calculadoras** para soluções, qualidade, produção e avaliação matemática de prescrições. Os cálculos funcionam offline; inclui interface clara/escura, pesquisa, favoritos locais e cópia de resultados. O iOS está fora das prioridades de desenvolvimento.

> **ATENÇÃO — Protótipo técnico v0.4.0.** Não validado para uso em ambiente regulado, decisão clínica, liberação/reprovação de lotes ou substituição de POPs e métodos aprovados. Toda fórmula, unidade, precisão, arredondamento, faixa, rastreabilidade e condição de aplicação deve ser avaliada pelo responsável técnico antes do uso operacional. Nenhum resultado determina conformidade.

## Calculadoras

**Soluções (9):** diluição C1V1, fator de diluição, concentração %m/v, %m/m, %v/v, molaridade, massa para molaridade, mistura de duas soluções, concentração mg/L.

**Controle de qualidade (7):** densidade, correção de teor/pureza, recuperação analítica, viés relativo, média/DP amostral/DPR, estimativa de LD e LQ por σ/S, perda por secagem.

**Produção (5):** rendimento de lote, perda de processo, escalonamento, massa teórica de comprimidos, vazão volumétrica.

**Prescrições (1):** quantidade de comprimidos/cápsulas/sachês inteiros ou volume de líquidos orais para tratamento de dose fixa; comparação da dose diária calculada com limite *informado* e estimativa opcional de embalagens. Veja [regras, validações, limitações e fontes](docs/PRESCRICOES.md).

Cada tela informa unidades fixas, fórmula e limitações. Valores monetários ou clínicos não fazem parte do escopo da versão 0.4.0. Em DPR, separar medições por ponto e vírgula ou linhas (vírgula pode ser separador decimal).

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

## Atualização diretamente pelo Android (v0.4.0)

O aplicativo verifica atualizações públicas ao abrir e ao voltar ao primeiro plano; também oferece os ícones **Verificar atualizações** e **Configurar atualizações**. Quando identifica uma versão mais recente, mostra notas, pergunta se deseja atualizar, baixa o APK com indicador de progresso, valida SHA-256 e abre o instalador Android com confirmação do usuário. Os cálculos continuam disponíveis offline, sem exigir login no GitHub.

**Distribuição ainda depende da configuração inicial pelo proprietário:** o código está em repositório privado e não pode ser consultado anonimamente. O AURORA consulta por padrão o canal PÚBLICO `fabriciomatosqa/aurora-calculadora-farmaceutica-updates`, que precisa ser criado. A CI publica lá apenas APKs assinados e arquivos SHA-256, após a configuração de uma chave persistente e de permissões de publicação restritas.

**Não existe instalação silenciosa.** Releases privados, APKs debug e Artifacts não são substitutos de uma Release pública assinada. Se o aparelho usa APK debug com outra chave, poderá ser necessário fazer backup e instalar a versão release limpa uma única vez.

Configuração detalhada: **[Atualizações Android — criação do canal público e assinatura](docs/ATUALIZACOES.md)**.

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