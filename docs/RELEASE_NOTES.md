# AURORA Calculadora Farmacêutica v0.6.2 — Android

## Correção do sistema de atualizações

- Resolve a origem dos conflitos entre APKs de depuração gerados em máquinas diferentes do GitHub Actions: builds DEBUG agora usam um **identificador separado** (`.debug`) e não tentam substituir o aplicativo oficial.
- O APK de produção continua com o mesmo identificador permanente `br.com.aurora.aurora_calculadora_farmaceutica` e exige assinatura estável por keystore nos Secrets do GitHub Actions.
- A publicação do Release agora verifica **identificador do pacote, versionCode e assinatura digital**, registra a impressão digital SHA-256 do certificado e inclui esse relatório entre os arquivos da Release.
- Sem chave permanente configurada, o workflow sinaliza falha de distribuição, em vez de informar sucesso como se houvesse uma atualização disponível.
- O app de desenvolvimento passa a informar que um APK DEBUG não pode seguir o canal de atualizações oficiais.
- O fluxo para instalações oficiais continua integrado: consulta GitHub Releases no app, mostra novidades, baixa APK, verifica SHA-256 e abre o instalador Android.

## Funcionalidades mantidas

- Prescrições: importar foto, galeria, PDF ou imagem, revisar texto por OCR local e confirmar os dados antes do cálculo.
- Favoritos como a primeira aba do catálogo.
- 22 ferramentas para cálculos farmacêuticos.

## Migração de instalações anteriores

**Não é possível atualizar sobre uma instalação Android que use certificado de assinatura diferente.** Instalações criadas com `app-debug.apk` dos antigos Artifacts poderão exigir uma **migração única** para a versão Release assinada com a chave definitiva.

**Antes de qualquer desinstalação, preserve seus dados locais.** A remoção do app pode apagar favoritos e configurações. Se a chave original ainda estiver disponível, assinar o novo APK com ela pode permitir a atualização sem reinstalar; caso contrário, o Android bloqueará a substituição. O aplicativo não pode desativar essa verificação de segurança.

Não use o APK DEBUG dos Artifacts como versão de atualização. Use apenas o APK de uma Release oficial assinada e verificada. A confirmação de instalação pelo Android é obrigatória.

Uso farmacêutico regulamentado exige validação técnica e profissional independente.
