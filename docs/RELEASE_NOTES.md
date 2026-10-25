# AURORA Calculadora Farmacêutica v0.6.3 — Android

## Atualização online no mesmo padrão do AURORA IPTV

- O aplicativo consulta os Releases públicos do repositório oficial e agora lê um manifesto **aurora-update.json** publicado junto do APK.
- O manifesto contém nome e código da versão, identificador do pacote Android, Android mínimo, tamanho, SHA-256, certificado da assinatura e notas da versão.
- O download ocorre no próprio AURORA, sem navegar no GitHub; o arquivo só é encaminhado ao instalador depois de verificar hash, tamanho, pacote, versão e certificado instalado.
- O Android confirma a instalação. Versões não assinadas com o mesmo certificado são recusadas, protegendo o aplicativo existente.
- A publicação no GitHub Actions passa pelo fluxo **rascunho → anexar APK + manifesto + checksum → publicar**, evitando divulgar Releases incompletos.
- Novos releases são bloqueados se o certificado mudar em relação a versões anteriores, como no processo já usado pelo AURORA IPTV.
- APKs DEBUG continuam isolados da versão oficial. Não instale arquivos de Artifacts como se fossem atualizações.

## Recursos preservados

- 22 calculadoras farmacêuticas.
- Favoritos como primeira aba.
- Importação de prescrições por câmera, galeria e arquivo PDF/imagem, com leitura local e conferência humana antes dos cálculos.

## Assinatura e primeira instalação

**Para ativar a publicação automática, é indispensável configurar os Secrets de assinatura permanente do Android**. Se ausentes, a CI não publica um Release oficial, mesmo que os testes do código passem.

O repositório contém o utilitário local `scripts/configurar_assinatura_android.ps1`, que configura os Secrets sem publicar a chave privada. A configuração é necessária somente uma vez para as versões seguintes.

**Uma instalação DEBUG antiga, assinada com outra chave, não pode ser atualizada sobre a mesma instalação**. A primeira migração para o APK Release assinado poderá exigir reinstalação e pode apagar dados locais. Faça backup antes de qualquer remoção.

Ferramenta de apoio matemático ainda não validada para uso farmacêutico regulamentado.
