# Atualização pelo próprio AURORA — Android v0.4.0

## Estado e limites

A versão 0.4.0 consulta um canal PÚBLICO de GitHub Releases quando o aplicativo abre e quando volta ao primeiro plano, além de permitir checagem manual pelo ícone de atualização. Ao detectar versão superior, pergunta se deseja baixar e instalar. O download do APK é conferido por SHA-256 e encaminhado ao instalador Android para confirmação **pelo usuário**. Nunca é silencioso.

**O código-fonte do AURORA permanece privado.** GitHub Releases em repositório privado não podem ser consultados de forma anônima por um APK. Não coloque tokens de GitHub no aplicativo.

Em 24/10/2026, o repositório público de distribuição abaixo AINDA NÃO EXISTIA. A funcionalidade somente poderá concluir a consulta e baixar um APK depois da configuração descrita a seguir. Nunca confundir código publicado na `main`, Artifacts de CI e um Release PÚBLICO instalável.

## 1. Criar o canal de distribuição

Na conta GitHub `fabriciomatosqa`, criar **um repositório PÚBLICO** exclusivo para os binários:

`fabriciomatosqa/aurora-calculadora-farmaceutica-updates`

Um repositório com README inicial basta. **Não copiar o código-fonte do aplicativo para ele.** Apenas versões APK Android assinadas e seu checksum serão publicados por CI. Se preferir outro nome, configure-o nas preferências do aplicativo.

## 2. Configurar autorização restrita no GitHub Actions do projeto privado

Na interface GitHub do repositório privado `Aurora-calculadorafarmaceutica`:

- `Settings > Secrets and variables > Actions > Variables`: definir `AURORA_PUBLIC_RELEASE_REPO` com o valor `fabriciomatosqa/aurora-calculadora-farmaceutica-updates`.
- Criar um **fine-grained personal access token** de curta duração com acesso **somente** ao repositório público de distribuição, permissão **Contents: Read and write**.
- `Settings > Secrets and variables > Actions > Secrets`: definir `AURORA_PUBLIC_RELEASE_TOKEN` com o token. Nunca incluir no aplicativo, código, README ou workflow em texto.

A workflow usa esse token APENAS na etapa final para criar o Release no repositório público. Sem ele, salva o APK assinado como **Artifact** e emite aviso, mas não disponibiliza atualização automática.

## 3. Assinatura Android estável (necessária para atualizar sobre instalação existente)

Gere no seu computador um keystore próprio e seguro, e guarde backup em local protegido:

```bash
keytool -genkeypair -v -keystore aurora-release.jks -keyalg RSA -keysize 3072 -validity 10000 -alias aurora -storetype PKCS12
```

No repositório de código, configure quatro **Actions Secrets**:

- `AURORA_KEYSTORE_BASE64`: conteúdo binário do keystore em Base64.
- `AURORA_KEYSTORE_PASSWORD`: senha do arquivo.
- `AURORA_KEY_ALIAS`: alias do certificado.
- `AURORA_KEY_PASSWORD`: senha da chave.

Em PowerShell Windows: `[Convert]::ToBase64String([IO.File]::ReadAllBytes('aurora-release.jks'))`.

**Nunca publique keystore ou senhas**. Guarde a chave de assinatura por toda a vida do produto. A mesma chave deve assinar todas as versões futuras. A equipe deve verificar assinatura real com `apksigner verify --print-certs` e testar uma atualização de ponta a ponta no aparelho.

A instalação **debug** inicial e a instalação **release** normalmente são assinadas com certificados diferentes. Android **não permite atualizar uma instalação debug para release usando assinatura diferente**. Neste caso, faça backup dos dados locais conforme suporte do app e instale a versão release limpa. Não prometa preservação de dados na migração debug→release.

## 4. Como publicar versões novas

Cada push à `main` executa testes e compila um APK de depuração como Actions Artifact. **Somente** se os quatro secrets de assinatura existirem, a CI faz `flutter build apk --release`, gera o arquivo:

`aurora-calculadora-farmaceutica-vX.Y.Z-android.apk`

Também gera `.apk.sha256`. Se token e variável do canal público estiverem configurados, a CI cria automaticamente o GitHub Release `vX.Y.Z` no repositório público. O código-fonte permanece privado.

Em versões futuras, atualize `version: X.Y.Z+N` no `pubspec.yaml`, com `N` crescente. Nunca reescreva arquivos de um Release existente.

Depois de configurar o repositório público e a assinatura, execute manualmente o workflow Android (ou faça novo push à main). A publicação automática só acontece se os testes, validações e build forem bem-sucedidos.

## 5. No aplicativo Android

- Abrir AURORA: verifica silenciosamente se há atualização; sem conectividade, os cálculos offline não são prejudicados.
- No ícone engrenagem **Configurar atualizações**, informar o repositório público, no formato `fabriciomatosqa/nome-do-repo`. Configuração permanece salva no aparelho.
- No ícone **Verificar atualizações**, fazer checagem manual. Caso canal esteja inacessível, app apresenta mensagem e opção de configurar.
- Se surgir uma versão maior, ler as notas, escolher **Atualizar**; o APK é baixado com indicador de progresso, o hash conferido e o instalador do Android aberto. O usuário deve consentir com a instalação e com eventual permissão do Android para arquivos desta origem.

A checagem automática não precisa de token nem de acesso ao GitHub privado. Não há instalação silenciosa, contorno de assinatura ou autoatualização em background.

## 6. Segurança, Play Store e teste real

Esta arquitetura destina-se à **distribuição direta fora da Play Store**. Ao publicar pela Play, seguir política de `REQUEST_INSTALL_PACKAGES` e adotar atualização da loja. Validar em Android físico instalação original, atualização entre duas versões release assinadas, hash inválido, ausência de rede, 404, falhas de download e falta de espaço.

Para uso farmacêutico regulamentado, continuam necessários revisão das fórmulas e validação profissional; o mecanismo de atualização não valida cálculos, prescrições ou registros.
