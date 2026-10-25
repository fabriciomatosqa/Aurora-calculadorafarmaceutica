#requires -Version 5.1
<#
  Cria um repositorio publico novo, migra codigo e historico do AURORA,
  reconfigura URLs e inicia a configuracao dos secrets de assinatura.
  Requer Git e GitHub CLI no Windows. Nao altera o repositorio original.
#>
[CmdletBinding()]
param(
  [string]$NovoRepositorio = 'fabriciomatosqa/aurora-farmaceutica-android',
  [string]$PastaLocal = '',
  [string]$ChaveExistente = '',
  [string]$AliasDaChave = 'aurora',
  [switch]$PularAssinatura
)

$ErrorActionPreference = 'Stop'
$Origem = 'fabriciomatosqa/Aurora-calculadorafarmaceutica'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Exigir-Comando([string]$nome) {
  if (-not (Get-Command $nome -ErrorAction SilentlyContinue)) {
    throw "Instale $nome antes de continuar (Git para Windows e GitHub CLI)."
  }
}
function Verificar-Exit([string]$descricao) {
  if ($LASTEXITCODE -ne 0) {
    throw "$descricao falhou (codigo $LASTEXITCODE)."
  }
}
function Ler-Arquivo([string]$nome) {
  return [IO.File]::ReadAllText((Join-Path $PastaLocal $nome), [Text.Encoding]::UTF8)
}
function Gravar-Arquivo([string]$nome, [string]$conteudo) {
  [IO.File]::WriteAllText((Join-Path $PastaLocal $nome), $conteudo, $utf8)
}

Exigir-Comando 'git'
Exigir-Comando 'gh'
if ($NovoRepositorio -notmatch '^fabriciomatosqa/[a-zA-Z0-9._-]+$' -or $NovoRepositorio -eq $Origem) {
  throw 'Destino invalido. Use outro repositorio na conta fabriciomatosqa.'
}
$ErrorActionPreference = 'Continue'
& gh auth status --hostname github.com *> $null
$autenticado = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = 'Stop'
if (-not $autenticado) {
  Write-Host 'Autenticando pelo GitHub CLI...'
  & gh auth login --hostname github.com --scopes 'repo,workflow'
  Verificar-Exit 'Login GitHub'
}
$login = (& gh api user --jq '.login').Trim()
Verificar-Exit 'Consulta da conta GitHub'
if ($login -ne 'fabriciomatosqa') {
  throw "Conta conectada: $login. Use a conta fabriciomatosqa."
}
& gh auth setup-git
Verificar-Exit 'Autorizacao do acesso Git'

$ErrorActionPreference = 'Continue'
& gh repo view $NovoRepositorio --json nameWithOwner *> $null
$jaExiste = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = 'Stop'
if ($jaExiste) {
  throw "O repositorio $NovoRepositorio ja existe; nao sera sobrescrito."
}

if ([string]::IsNullOrWhiteSpace($PastaLocal)) {
  $documentos = [Environment]::GetFolderPath('MyDocuments')
  if ([string]::IsNullOrWhiteSpace($documentos)) { $documentos = $HOME }
  $PastaLocal = Join-Path $documentos 'Aurora-Farmaceutica-Android'
}
$PastaLocal = [IO.Path]::GetFullPath($PastaLocal)
if (Test-Path -LiteralPath $PastaLocal) {
  throw "A pasta $PastaLocal ja existe. Informe outra com -PastaLocal."
}

Write-Host "Clonando codigo e historico completo de $Origem..."
& git clone --branch main --single-branch "https://github.com/$Origem.git" $PastaLocal
Verificar-Exit 'Clone Git'
Push-Location $PastaLocal
try {
  Write-Host 'Alterando as referencias para o novo GitHub...'
  $arquivos = @(& git grep -Il -F $Origem --)
  if ($LASTEXITCODE -ne 0 -or $arquivos.Count -eq 0) {
    throw 'Nenhuma referencia do repositorio original encontrada.'
  }
  foreach ($relativo in $arquivos) {
    $conteudo = Ler-Arquivo $relativo
    $corrigido = $conteudo.Replace($Origem, $NovoRepositorio)
    if ($corrigido -ne $conteudo) { Gravar-Arquivo $relativo $corrigido }
  }

  # Bump da versao sem alterar applicationId/certificado Android.
  $pubspec = Ler-Arquivo 'pubspec.yaml'
  $padrao = [regex]'(?m)^version: *(\d+)\.(\d+)\.(\d+)\+(\d+) *(?=\r?$)'
  $achado = $padrao.Match($pubspec)
  if (-not $achado.Success) { throw 'Versao nao encontrada no pubspec.yaml.' }
  $novoMajor = [int]$achado.Groups[1].Value
  $novoMinor = [int]$achado.Groups[2].Value + 1
  $novoBuild = [int]$achado.Groups[4].Value + 1
  $novaVersao = "$novoMajor.$novoMinor.0"
  $pubspec = $padrao.Replace($pubspec, "version: $novaVersao+$novoBuild", 1)
  Gravar-Arquivo 'pubspec.yaml' $pubspec

  $principal = Ler-Arquivo 'lib/main.dart'
  $principal = [regex]::Replace(
    $principal, "applicationVersion:\s*'[0-9]+\.[0-9]+\.[0-9]+'",
    "applicationVersion: '$novaVersao'")
  Gravar-Arquivo 'lib/main.dart' $principal

  $notas = Ler-Arquivo 'docs/RELEASE_NOTES.md'
  $notas = [regex]::Replace(
    $notas, '(?m)^# AURORA Calculadora Farmacêutica v\d+\.\d+\.\d+',
    "# AURORA Calculadora Farmacêutica v$novaVersao")
  $cabecalho = "Primeira versao do AURORA Farmaceutica no novo repositorio oficial. " +
    "O app e o atualizador agora apontam para o novo GitHub." + [Environment]::NewLine +
    [Environment]::NewLine
  Gravar-Arquivo 'docs/RELEASE_NOTES.md' ($cabecalho + $notas)

  $informacoes = @'
# Migracao do AURORA Calculadora Farmaceutica

Repositorio antigo (backup): ORIGINAL
Repositorio novo oficial: DESTINO
Versao inicial no novo Git: VERSAO

O repositorio foi copiado com historico de commits, Flutter, Android,
testes, GitHub Actions, scripts de assinatura e atualizador online.

Para funcionar o download direto no celular, a CI deve publicar o
Release completo, com APK assinado, aurora-update.json e SHA-256.
Os quatro Secrets da chave Android precisam ser configurados neste
novo repositorio e NAO podem ser transferidos automaticamente do antigo.

Uma chave nova nao consegue atualizar uma instalacao Android assinada
com a chave antiga. Preserve os dados do aplicativo antes de desinstalar.
O primeiro upgrade pode requerer migracao; os proximos sao no proprio app.
'@
  $informacoes = $informacoes.Replace('ORIGINAL', $Origem)
  $informacoes = $informacoes.Replace('DESTINO', $NovoRepositorio)
  $informacoes = $informacoes.Replace('VERSAO', $novaVersao)
  Gravar-Arquivo 'docs/NOVO_REPOSITORIO.md' $informacoes

  $updater = Ler-Arquivo 'lib/services/update_service.dart'
  $preparador = Ler-Arquivo 'release/prepare_android.py'
  $novaDeclaracao = 'REPOSITORY = ' + [char]34 + $NovoRepositorio + [char]34
  if (-not $updater.Contains("const updateRepository = '$NovoRepositorio'") -or
      -not $preparador.Contains($novaDeclaracao)) {
    throw 'Algum endereco do atualizador nao foi atualizado.'
  }
  # Preencha identidade APENAS no clone migrado se o Git local nao possuir.
  $nomeGit = (& git config --get user.name)
  if ([string]::IsNullOrWhiteSpace($nomeGit)) {
    & git config user.name $login
    Verificar-Exit 'Configuracao de nome Git'
  }
  $emailGit = (& git config --get user.email)
  if ([string]::IsNullOrWhiteSpace($emailGit)) {
    & git config user.email "$login@users.noreply.github.com"
    Verificar-Exit 'Configuracao de e-mail Git local'
  }
  & git diff --check
  Verificar-Exit 'Validacao das diferencas'
  & git add --all
  Verificar-Exit 'Preparacao dos arquivos'
  & git commit -m "chore: migrar para $NovoRepositorio; iniciar v$novaVersao"
  Verificar-Exit 'Commit da migracao'

  Write-Host "Criando e enviando o novo repositorio publico: $NovoRepositorio"
  & gh repo create $NovoRepositorio --public --source . --remote aurora-novo --push --description 'AURORA Calculadora Farmaceutica Android com atualizacao online'
  Verificar-Exit 'Criacao e push do novo repositorio'
  & gh repo view $NovoRepositorio --json nameWithOwner --jq '.nameWithOwner'
  Verificar-Exit 'Confirmacao da publicacao'

  Write-Host ''
  Write-Host "NOVO REPOSITORIO: https://github.com/$NovoRepositorio"
  Write-Host "COPIA LOCAL: $PastaLocal"
  Write-Host "VERSAO: $novaVersao+$novoBuild"
  Write-Host "BACKUP ORIGINAL: https://github.com/$Origem"

  if (-not $PularAssinatura) {
    $configurador = Join-Path $PastaLocal 'scripts/configurar_assinatura_android.ps1'
    $params = @{ Repository = $NovoRepositorio; KeyAlias = $AliasDaChave }
    if (-not [string]::IsNullOrWhiteSpace($ChaveExistente)) {
      $params.KeystorePath = $ChaveExistente
    }
    Write-Host 'Configurando Secrets de assinatura para o novo repositorio...'
    try {
      & $configurador @params
      if (-not $?) { throw 'A assinatura nao foi concluida.' }
    } catch {
      Write-Warning "Novo repositorio criado, mas assinatura pendente: $($_.Exception.Message)"
      Write-Warning 'Rode o configurador da assinatura na nova pasta para finalizar.'
    }
  } else {
    Write-Warning 'Assinatura nao configurada: nenhum Release de producao sera gerado.'
  }
  Write-Host "GITHUB ACTIONS: https://github.com/$NovoRepositorio/actions/workflows/android.yml"
  Write-Host "RELEASES: https://github.com/$NovoRepositorio/releases"
  Write-Host 'A atualizacao dentro do app requer Release assinado compatível.'
} finally {
  Pop-Location
}
