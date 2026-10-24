# Atualizações online — AURORA Calculadora Farmacêutica

## O que a v0.2.0 implementa

- Consulta assíncrona ao endpoint REST `/repos/{owner}/{repo}/releases/latest` ao abrir a tela inicial; falhas da consulta automática não impedem os cálculos offline.
- Ícone **Verificar atualizações** para consulta manual com mensagens de erro.
- Comparação numérica de versões (`0.10.0` é maior que `0.9.9`).
- Diálogo perguntando se deseja baixar a nova versão; a recusa não fecha o app.
- Android: download HTTPS do APK, checagem do SHA-256 e encaminhamento ao instalador do sistema; o Android exige consentimento para a instalação.
- iOS: apenas aviso e página de novidades; instalação iOS deve usar App Store ou TestFlight, não APK.

## LIMITAÇÃO CRÍTICA: repositório privado

Em 24/10/2026, `fabriciomatosqa/Aurora-calculadorafarmaceutica` estava **privado**. A API pública do GitHub responde 404 para Releases privados sem autenticação.

**Nunca embuta token pessoal GitHub no APK.** Para permitir verificação e downloads no celular, escolha um destes modelos:

1. Deixar este repositório público e publicar Releases assinados nele; OU
2. Manter código privado e criar um **repositório público exclusivo para distribuir APKs**, por exemplo `fabriciomatosqa/aurora-farmaceutica-releases`; nesse caso, configurar no build:
   `flutter build apk --release --dart-define=AURORA_UPDATE_REPO=fabriciomatosqa/aurora-farmaceutica-releases`.
   É necessário publicar naquele repositório público os Releases e seus arquivos; este workflow publica no repositório atual, não cria nem publica automaticamente em outro.

Sem essas providências, o botão é operacional, mas a API não revela as novas versões do repositório privado.

## Criar e armazenar assinatura persistente

Atualizações Android somente podem substituir o aplicativo instalado quando a **assinatura do APK é compatível** com a instalada. O APK `app-debug.apk` da CI usa chave de teste e **não deve servir como base para atualizações definitivas**.

Gere uma **única chave privada segura** no seu computador e faça backup fora do GitHub:

```bash
keytool -genkeypair -v -keystore aurora-release.jks -keyalg RSA -keysize 3072 -validity 10000 -alias aurora -storetype PKCS12
```

Acesse `Settings → Secrets and variables → Actions → New repository secret` e configure:

- `AURORA_KEYSTORE_BASE64`: arquivo inteiro da chave convertido em Base64;
- `AURORA_KEYSTORE_PASSWORD`: senha do arquivo da chave;
- `AURORA_KEY_ALIAS`: alias informado ao criar a chave (`aurora`);
- `AURORA_KEY_PASSWORD`: senha da chave.

Conversão de Base64:

- Linux/macOS: `base64 -w 0 aurora-release.jks` (no macOS: `base64 -i aurora-release.jks | tr -d '\n'`).
- PowerShell Windows: `[Convert]::ToBase64String([IO.File]::ReadAllBytes('aurora-release.jks'))`.

**Nunca envie o .jks nem senhas para commit, chat público ou release.** Guarde cópia segura com controle de acesso e backup. Se perder essa chave, não poderá substituir normalmente uma instalação assinada por ela.

Ao fazer push na `main`, a workflow compila e publica `app-debug.apk` como **Actions Artifact**. Se todas as quatro secrets estiverem presentes, ela também cria um APK release assinado, checksum `.sha256` e um **GitHub Release** com a tag `vX.Y.Z` correspondente a `pubspec.yaml`. A existência do release não torna downloads públicos quando o repositório é privado.

Para novos Releases, aumente `version:` no `pubspec.yaml` (o número à direita do sinal + deve subir também). Sem mudar a versão, a workflow não substitui uma Release existente.

## Antes de colocar em produção

- Executar e revisar `flutter analyze`, `flutter test` e `flutter build apk` em runners.
- Testar instalação inicial e atualização da versão anterior para a nova, confirmando dados locais e mesmo package ID.
- Validar assinatura com `apksigner verify --print-certs`; conferir a identidade das duas versões.
- Confirmar que o `.sha256` publicado corresponde ao arquivo e que uma adulteração cancela a instalação.
- Testar ausência de rede, 404, checksum incorreto, espaço insuficiente e permissão de instalação desconhecida.
- Google Play Store: checar política de `REQUEST_INSTALL_PACKAGES`; este fluxo foi pensado para **distribuição direta fora da Play Store**. Versão para Play deve usar mecanismo da loja e não contornar restrições.
- iOS: configurar App Store Connect/TestFlight para atualização instalável.

**Não utilizar cálculos do app para liberar lotes ou atividades GxP até validação própria documentada.**
