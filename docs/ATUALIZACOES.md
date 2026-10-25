# Atualização online do AURORA — Android v0.6.2

## O erro "o pacote tem um conflito com um pacote já existente"

Se o arquivo que você está instalando é `app-debug.apk` de um Artifact `aurora-farmaceutica-debug-N`, **não é o APK oficial de atualização**. Esses APKs de teste foram gerados em máquinas temporárias do GitHub Actions e podiam usar certificados diferentes entre execuções. O Android bloqueia atualização com assinatura distinta, mesmo com o mesmo nome e package ID.

A partir da v0.6.2, a CI isola builds de teste sob `br.com.aurora.aurora_calculadora_farmaceutica.debug`. Eles não substituem o pacote de produção `br.com.aurora.aurora_calculadora_farmaceutica`. Os Artifacts de teste são explicitamente identificados como **NÃO ATUALIZA**.

A CI publica um Release instalável somente se quatro Secrets de assinatura persistente estiverem configurados. O fluxo valida o ID de pacote, `versionCode` e assinatura via `apksigner`, publicando também `assinatura-android.txt` para permitir conferência da impressão digital do certificado. Sem assinatura, o workflow indica falha de distribuição; a execução não deve ser considerada uma entrega online bem-sucedida.

### Configuração inicial obrigatória para atualizar sem reinstalar posteriormente

1. No seu PC, localize a **chave original** (keystore) usada para assinar o aplicativo que deseja manter. Se existir, reutilize-a, com alias e senha correspondentes.
2. Configure os quatro Secrets `AURORA_KEYSTORE_BASE64`, `AURORA_KEYSTORE_PASSWORD`, `AURORA_KEY_ALIAS` e `AURORA_KEY_PASSWORD` em `Settings → Secrets and variables → Actions`.
3. Execute o workflow Android e confirme que o job gerou um Release (não somente um Artifact), com `aurora-calculadora-farmaceutica-vX.Y.Z-android.apk`, `.sha256` e `assinatura-android.txt`.
4. Após uma instalação Release **assinada pela mesma chave** do aplicativo já instalado, a atualização poderá acontecer pela interface do AURORA. O Android continuará pedindo confirmação.
5. **Se a instalação atual for debug e a chave original estiver perdida**, não há correção de código que permita sobrepor o APK sem a assinatura anterior. Preserve os dados existentes antes de qualquer desinstalação; a primeira migração para o Release definitivo pode exigir reinstalação e pode apagar favoritos/configurações. Não desinstale sem avaliar esses dados.

Para confirmar a assinatura de dois APKs no computador com Android SDK:

```bash
apksigner verify --print-certs app-antigo.apk
apksigner verify --print-certs aurora-calculadora-farmaceutica-vX.Y.Z-android.apk
```

Compare `Signer #1 certificate SHA-256 digest` e o mesmo nome de pacote via `aapt dump badging`. Se diferentes, a atualização é incompatível.



## Como funciona

O aplicativo AURORA Calculadora Farmacêutica consulta automaticamente os **Releases públicos do próprio repositório oficial**:

`https://github.com/fabriciomatosqa/Aurora-calculadorafarmaceutica/releases`

O código do app usa `GET https://api.github.com/repos/fabriciomatosqa/Aurora-calculadorafarmaceutica/releases/latest`, compara a versão instalada com a versão publicada e, quando existe atualização, mostra um diálogo com as novidades. Depois de o usuário confirmar, baixa o APK *por dentro do app*, verifica o SHA-256 do download e abre o instalador do Android. Não há necessidade de o usuário navegar ao GitHub ou baixar manualmente o arquivo.

**O Android sempre requer autorização/confirmação do usuário para a instalação.** Não há instalação silenciosa, reinicialização automática garantida nem contorno de requisitos do Android.

A consulta na abertura não interfere no uso offline das calculadoras. O botão com ícone de atualização permite conferir manualmente. A versão 0.5.0 remove a antiga configuração de repositório de distribuição, pois o projeto oficial já está público.

## Publicação automática no GitHub Actions

O workflow `.github/workflows/android.yml` executa no push para `main`:

1. Gera os arquivos de plataforma Android necessários com `flutter create`, isolando o package ID de DEBUG.
2. Configura permissões de internet e instalador Android.
3. Executa `flutter analyze` e `flutter test`, com diagnóstico nos logs em caso de erro.
4. Compila APK de teste (debug), com package ID distinto e identificado como **NÃO ATUALIZA** nos Artifacts.
5. Se a assinatura de distribuição estiver configurada, compila um APK **release assinado**.
6. Gera o arquivo `aurora-calculadora-farmaceutica-vX.Y.Z-android.apk` e seu `.apk.sha256`.
7. Publica o Release **no próprio repositório público**, usando `github.token`. Não é necessário criar outro repositório ou adicionar um token pessoal para publicação.

O Release usa a versão em `pubspec.yaml`; se já existir uma Release com a mesma tag, o workflow não a substitui. Atualize `version: MAJOR.MINOR.PATCH+BUILD` para uma nova versão, com BUILD crescente.

### Configuração obrigatória: assinatura

A geração automática de Releases assinados **depende de quatro Actions Secrets**, que o proprietário precisa configurar uma única vez no repositório oficial:

- `AURORA_KEYSTORE_BASE64`: arquivo keystore convertido para Base64;
- `AURORA_KEYSTORE_PASSWORD`: senha do arquivo;
- `AURORA_KEY_ALIAS`: alias da chave;
- `AURORA_KEY_PASSWORD`: senha da chave.

Se ainda não tem keystore de distribuição, crie **uma única chave segura** no próprio computador usando `keytool`:

```bash
keytool -genkeypair -v -keystore aurora-release.jks -keyalg RSA -keysize 3072 -validity 10000 -alias aurora -storetype PKCS12
```

Para gerar o valor Base64 no PowerShell Windows:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('aurora-release.jks'))
```

Nunca faça commit do arquivo `.jks`, do Base64 nem das senhas. Guarde uma cópia de segurança do keystore fora do repositório. **A mesma assinatura precisa ser mantida nas próximas versões**. O instalador Android rejeita a atualização se a assinatura e/ou o package ID não forem compatíveis.

Sem secrets, a CI pode produzir um APK de teste nos Artifacts, mas **não** cria o Release Android de produção; há um aviso explícito no resumo do workflow.

### Atenção: migração de versões DEBUG instaladas anteriormente

É provável que versões iniciais tenham sido instaladas com `app-debug.apk`. APKs debug de diferentes runners e APKs release assinam com chaves diferentes. **Não é possível garantir que um APK release sobrescreva uma instalação debug.** Para migrar, preserve informações importantes por backup apropriado e pode ser necessário desinstalar a versão debug e instalar uma Release assinada. Depois da primeira instalação release assinada com a chave definitiva, as próximas atualizações podem ser realizadas diretamente pelo aplicativo.

### Como testar

- Abra `Actions > Android - testes, APK e Release` e inspecione a execução mais recente.
- Confirme que os testes e o `flutter build apk --release` foram concluídos com sucesso.
- Confira em `Releases` a tag, o APK e o arquivo `.sha256`.
- Teste em um Android real, inclusive verificando assinatura com `apksigner verify --print-certs`.
- Teste a instalação de uma release, a atualização para uma **versão superior** assinada com a mesma chave, a preservação de dados, cancelamento, falhas de rede e checksum incorreto.
- Em caso de ausência de Releases públicos, o botão manual deve explicar que ainda não existe uma versão publicada. Isso não é sinal de que não existem commits recentes na `main`.

**Para distribuição pela Play Store**, utilize o mecanismo de atualização aprovado pela loja; o auto-instalador deste projeto destina-se a APKs obtidos fora da Play Store.

A AURORA Calculadora Farmacêutica permanece protótipo técnico: não foi validada para uso em processos farmacêuticos regulados, decisão clínica ou liberação de lotes.
