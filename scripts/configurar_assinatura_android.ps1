#requires -Version 5.1
<#
  One-time local bootstrap for AURORA Android release signing.
  Generates or reuses a persistent keystore on THIS computer and configures
  the four encrypted GitHub Actions repository secrets using GitHub CLI.
  Never commits, uploads, or prints the private keystore or its password.
#>
[CmdletBinding()]
param(
  [string]$Repository = 'fabriciomatosqa/Aurora-calculadorafarmaceutica',
  [string]$KeystorePath = (Join-Path $HOME 'aurora-farmaceutica-release.jks'),
  [string]$KeyAlias = 'aurora'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Assert-Tool([string]$Command) {
  if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
    throw "Ferramenta '$Command' não encontrada. Instale Java JDK (keytool) e GitHub CLI (gh), conforme a documentação."
  }
}

function SecureString-ToText([Security.SecureString]$Secure) {
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  }
  finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

# Quote dotenv values; GitHub CLI parses them with its dotenv parser.
function Env-Quote([string]$Value) {
  if ($Value -match '[\r\n]') {
    throw 'Senhas com quebra de linha não são aceitas.'
  }
  return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

Assert-Tool 'gh'
Assert-Tool 'keytool'
Write-Host 'Verificando a autenticação do GitHub...'
& gh auth status --hostname github.com 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Autorização do GitHub necessária. O comando abrirá o login oficial.'
  & gh auth login --hostname github.com
  if ($LASTEXITCODE -ne 0) {
    throw 'Não foi possível autenticar com GitHub CLI.'
  }
}

$keystoreExists = Test-Path -LiteralPath $KeystorePath -PathType Leaf
if (-not $keystoreExists) {
  Write-Warning 'ATENÇÃO: a nova chave NÃO atualizará a instalação DEBUG antiga se ela foi assinada por outro certificado.'
  Write-Warning 'Antes de continuar, verifique se você tem uma keystore ANTIGA. Reutilizá-la pode preservar a capacidade de atualização.'
  $confirm = Read-Host 'Criar nova assinatura definitiva? Digite SIM'
  if ($confirm -cne 'SIM') {
    throw 'Operação cancelada. Nenhum Secret foi alterado.'
  }
}

$secure = Read-Host 'Senha da keystore (mínimo de 6 caracteres; guarde-a com segurança)' -AsSecureString
$password = SecureString-ToText $secure
if ([string]::IsNullOrEmpty($password) -or $password.Length -lt 6) {
  throw 'Senha inválida. Use 6 caracteres ou mais.'
}
if ($password -match '[\r\n]') {
  throw 'A senha não pode conter quebra de linha.'
}
$env:AURORA_KEYSTORE_PASSWORD = $password
$env:AURORA_KEY_PASSWORD = $password

try {
  if (-not $keystoreExists) {
    $parent = Split-Path -Parent $KeystorePath
    if (-not (Test-Path -LiteralPath $parent)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Write-Host 'Gerando chave PKCS12 definitiva no computador...'
    & keytool -genkeypair -keystore $KeystorePath -alias $KeyAlias `
      -keyalg RSA -keysize 3072 -validity 10000 -storetype PKCS12 `
      -dname 'CN=AURORA Calculadora Farmaceutica, OU=AURORA, O=AURORA, C=BR' `
      -storepass:env AURORA_KEYSTORE_PASSWORD `
      -keypass:env AURORA_KEY_PASSWORD
    if ($LASTEXITCODE -ne 0) {
      throw 'Falha ao gerar keystore. Nenhum Secret foi alterado.'
    }
  }

  # Confirm credentials/alias before uploading any secret.
  & keytool -list -keystore $KeystorePath -alias $KeyAlias `
    -storepass:env AURORA_KEYSTORE_PASSWORD | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw 'A chave/alias ou a senha não conferem. Nenhum Secret foi alterado.'
  }

  $bytes = [IO.File]::ReadAllBytes($KeystorePath)
  $encoded = [Convert]::ToBase64String($bytes)
  # Pass an in-memory dotenv payload through stdin. No plaintext secret file.
  $lines = @(
    'AURORA_KEYSTORE_BASE64=' + (Env-Quote $encoded)
    'AURORA_KEYSTORE_PASSWORD=' + (Env-Quote $password)
    'AURORA_KEY_ALIAS=' + (Env-Quote $KeyAlias)
    'AURORA_KEY_PASSWORD=' + (Env-Quote $password)
  )
  Write-Host 'Configurando os quatro Secrets de forma criptografada no GitHub...'
  $lines -join "`n" | & gh secret set --app actions --repo $Repository --env-file -
  if ($LASTEXITCODE -ne 0) {
    throw 'Falha no envio dos Secrets. Nenhuma chave foi enviada ao código público.'
  }

  Write-Host 'Verificando os nomes dos Secrets...'
  & gh secret list --app actions --repo $Repository
  if ($LASTEXITCODE -ne 0) {
    throw 'Secrets enviados, mas não foi possível confirmar sua listagem.'
  }

  Write-Host 'Solicitando nova execução de CI para publicar Release assinado...'
  & gh workflow run android.yml --repo $Repository --ref main
  if ($LASTEXITCODE -ne 0) {
    throw 'Os Secrets estão configurados, mas não foi possível iniciar o workflow. Execute-o manualmente em Actions.'
  }
  Write-Host 'Assinatura configurada e workflow solicitado.'
  Write-Host "GUARDE BACKUP SEGURO da keystore em: $KeystorePath"
  Write-Host 'Sem esse arquivo e a senha você perderá a capacidade de assinar futuras atualizações.'
  Write-Host "Acompanhe: https://github.com/$Repository/actions/workflows/android.yml"
}
finally {
  Remove-Item Env:\AURORA_KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
  Remove-Item Env:\AURORA_KEY_PASSWORD -ErrorAction SilentlyContinue
  $password = $null
  $encoded = $null
  $lines = $null
}
