# Atualização automática do AURORA — Android v0.4.1

## Experiência de quem usa o aplicativo

Não há campo de repositório, token, URL ou canal. O AURORA conhece previamente
seu endereço oficial de distribuição e **verifica atualizações automaticamente**
na abertura e quando retorna ao primeiro plano (intervalo mínimo de 30 minutos
dentro da mesma sessão). Sem versão nova, segue funcionando offline normalmente.

Quando encontra versão mais recente:
1. Baixa o APK automaticamente, com progresso discreto, sem bloquear a interface.
2. Confere a integridade do arquivo por SHA-256 fornecido pelo GitHub.
3. Abre o instalador nativo do Android para finalizar a atualização.
4. Registra a tentativa; se o usuário cancelar a instalação, evita repetir o
   download automático da mesma versão por 24 horas. O botão **Verificar
   atualizações** permite uma nova tentativa manual a qualquer momento.

O Android **pode exigir autorização para instalar aplicativos desta origem e
confirmação final**. Não há bypass nem promessa de instalação silenciosa. Esta
distribuição é por APK externo à Play Store. Para aplicativos publicados pela
Play Store, seguir os mecanismos próprios da loja.

## Fonte oficial e privacidade

O código-fonte permanece PRIVADO em:
`fabriciomatosqa/Aurora-calculadorafarmaceutica`

O APK assinado e seu checksum devem ser publicados como GitHub Release em:
`fabriciomatosqa/aurora-calculadora-farmaceutica-updates`

Esse endereço é **fixo no aplicativo e na workflow**, não configurável pelo
usuário final. Nenhum token de acesso ao GitHub é empacotado no APK. Apenas os
binários de distribuição ficam públicos, não o código-fonte.

**Dependência operacional:** o canal acima deve existir como repositório PÚBLICO,
com Release do APK assinado. Se não existir ou não tiver releases, a atualização
não estará disponível; o app mantém as funções locais. Em 24/10/2026, a
existência desse repositório público ainda não estava confirmada.

## Preparação ÚNICA pelo mantenedor (não pelo usuário do app)

1. Criar o repositório PÚBLICO `aurora-calculadora-farmaceutica-updates`
   na conta `fabriciomatosqa`. Apenas arquivos APK e .sha256 devem ser
   publicados nele.
2. Gerar um keystore de release Android estável; manter backups seguros.
   Configurar os quatro secrets do Actions no repositório privado:
   `AURORA_KEYSTORE_BASE64`, `AURORA_KEYSTORE_PASSWORD`,
   `AURORA_KEY_ALIAS`, `AURORA_KEY_PASSWORD`.
3. Criar um fine-grained PAT com autorização **Contents read/write apenas
   para o repositório público de distribuição** e registrá-lo como secret
   `AURORA_PUBLIC_RELEASE_TOKEN` no repositório privado.
4. Na `.github/workflows/android.yml`, o endereço de distribuição já está
   configurado: não é necessária a variável `AURORA_PUBLIC_RELEASE_REPO`.
5. Publicar na `main` com `version: X.Y.Z+N` crescente em `pubspec.yaml`.
   A Actions executa testes, compila o APK, calcula SHA-256 e publica Release
   versionado no canal público se secrets e permissões estiverem corretos.

Não inserir senhas/tokens no repositório nem no app. A publicação do APK não
deve depender de um campo preenchido no aparelho.

## Assinatura e migração de instalações antigas

Android só permite substituir a instalação atual quando o novo APK usa o
**mesmo applicationId e certificado de assinatura**. O APK de teste debug
gerado pelo Actions em runner efêmero normalmente NÃO compartilha o
certificado com uma versão release. Para esses casos, pode ser preciso
desinstalar a versão debug e instalar a release; fazer backup de dados antes.
Após a primeira instalação release, preservar o mesmo keystore em todas as
versões futuras.

## Checklist de validação

- Confirmar o Release público acessível sem autenticação e com
  `aurora-calculadora-farmaceutica-vX.Y.Z-android.apk` e o arquivo
  `.apk.sha256`.
- Testar em Android físico upgrade de duas versões release assinadas com a
  mesma chave e aumento de versionCode.
- Testar app sem internet, 404, checksum inválido, falta de armazenamento,
  cancelamento do instalador, retorno ao app e atualização manual.
- Nenhuma atualização automática de APK foi validada em Android físico por
  esta alteração de código; validar antes de distribuir.

Para uso farmacêutico profissional, as fórmulas e resultados continuam
dependendo de validação por especialista; atualizar o app não valida
automaticamente conteúdos técnicos nem prescrições.
