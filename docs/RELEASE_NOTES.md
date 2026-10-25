# AURORA Calculadora Farmacêutica v0.6.0 — Android

## Novidades

- **Prescrições → Importar prescrição**: nova área em destaque no topo da tela, com acesso a câmera, galeria e seletor de arquivo PDF/JPG/PNG.
- Leitura de fotos e imagens com reconhecimento de texto (OCR) executado no dispositivo; extração de texto de PDFs digitais, sem upload a servidor.
- Texto extraído editável e conferível. Sugestões limitadas de apresentação, dose e frequência só são copiadas para a calculadora com confirmação do usuário.
- Limite máximo diário **não é inferido**: o profissional deve continuar informando e conferindo a fonte aplicável.
- **Favoritos como primeira aba**, antes de Todas e das categorias.
- Atualizações pelo próprio app continuam consultando os Releases oficiais, sem baixar APK manualmente no GitHub; o Android solicita confirmação para a instalação.

## Limitações e segurança

- PDFs digitalizados sem camada de texto exigem uma foto/imagem para OCR nesta versão.
- OCR pode confundir números, medicamentos, frequências e unidades, especialmente em receitas manuscritas; o resultado não é avaliação clínica nem autorização de dispensação.
- A atualização sobre versão instalada exige mesmo package ID e certificado de assinatura. A CI publica o APK release somente com secrets de assinatura configurados.
- Projeto em fase de teste, não validado para processos regulamentados.
