# AURORA Calculadora Farmacêutica v0.6.1 — Android

## Correções desta versão

- Corrige erro na compilação Android causado pela incompatibilidade do file_picker 11.0.3 com Android Gradle Plugin 9.
- Atualiza o seletor de documentos para file_picker 12.3.x, com suporte a PDF, JPG, JPEG e PNG.
- Corrige acesso a arquivos selecionados pelo Android Storage Access Framework (SAF), processando-os temporariamente em armazenamento privado e removendo a cópia após o uso.
- Mantém em Prescrições os três botões evidentes: Tirar foto, Galeria e Arquivo / PDF, com revisão obrigatória dos campos extraídos.
- Mantém Favoritos como a primeira aba.
- A checagem de atualização permanece integrada ao aplicativo e consulta as Releases oficiais do GitHub, com download interno, conferência do SHA-256 e abertura do instalador Android.

## Segurança e implantação

As prescrições são processadas no aparelho. A leitura automática não valida a receita nem define a dose máxima. Os campos extraídos exigem revisão profissional.

A atualização sobre uma instalação Android existente depende de assinatura e identificador de pacote compatíveis; a implantação do Release requer secrets de assinatura corretamente configurados no GitHub Actions.

**Atenção:** aplicação técnica ainda sem validação para atividades farmacêuticas regulamentadas.
