# Referências técnicas, escopo e riscos — v0.1.0

Data da pesquisa: **24/10/2026**. Este documento orienta o escopo inicial, **não é declaração de conformidade regulatória**.

## Fontes oficiais consultadas

1. **ANVISA — Farmacopeia Brasileira 8ª edição**, aprovada pela RDC 1.026/2026, em vigor desde 01/07/2026. https://www.gov.br/anvisa/pt-br/assuntos/farmacopeia/farmacopeia-brasileira
2. **ANVISA — RDC 658/2022**, Boas Práticas de Fabricação (BPF). Em particular, controles sobre métodos analíticos, registros e conferência crítica dos cálculos; consultar texto vigente e alterações. https://anvisalegis.datalegis.net/action/ActionDatalegis.php?acao=abrirTextoAto&cod_menu=9434&cod_modulo=310&numeroAto=00000658&orgao=RDC%2FDC%2FANVISA%2FMS&pesquisa=true&seqAto=000&tipo=RDC&valorAno=2022
3. **ICH Q2(R2)** — Validation of Analytical Procedures (versão final março de 2024): conceitos de exatidão, precisão, DL/QL e outros parâmetros. https://www.fda.gov/regulatory-information/search-fda-guidance-documents/q2r2-validation-analytical-procedures
4. **ICH Q14** — Analytical Procedure Development (março 2024). https://www.fda.gov/regulatory-information/search-fda-guidance-documents/q14-analytical-procedure-development
5. **OMS** — TRS 1052, Anexo 4 (2024), boas práticas para laboratórios de controle de qualidade farmacêutico. https://www.who.int/publications/m/item/who-good-practices-for-pharmaceutical-quality-control-laboratories

Os cálculos de conversão e estequiometria são identidades matemáticas gerais e **não equivalem a procedimentos compendiais completos**. A calculadora LD/LQ implementa somente a estimativa σ/inclinação (3,3σ/S e 10σ/S); não verifica se o modelo e a demonstração experimental satisfazem a diretriz.

## Cuidados relevantes

- Concentrações %m/v, %v/v e mg/L **não são intercambiáveis** sem base dimensional e densidade. mg/L não equivale universalmente a ppm.
- Diluição e mistura assumem ausência de reação, mesma substância, mesmas unidades e aditividade aproximada dos volumes.
- Correção de pureza não inclui automaticamente umidade, base seca, equivalência estequiométrica, conteúdo de sal/hidrato ou bases de certificado.
- DP e DPR são **amostrais** (`n−1`) com entradas não negativas e média positiva; aceitar/rejeitar depende do POP e de análise estatística adequada.
- Perda por secagem mede massa volatilizada e não é necessariamente teor de água.
- Escalonamento e massa teórica não contemplam mudanças de processo, perdas, validação, compressibilidade e sobrepesos.
- Não há prescrição de dose humana, pediátrica, quimioterapia, cálculo de infusão clínica nem interpretação automática de especificações.
- A precisão de apresentação é de cerca de 7 dígitos significativos; **não significa incerteza de medição, limite de aceitação ou regras de arredondamento reguladas**.
- Não usar o recurso copiar como trilha auditável. Não há controle de acesso, registros protegidos, assinatura, versionamento de resultados ou validação GxP.

## Itens para pesquisas e versões futuras

- Cálculos de titulação volumétrica por monografia/POP específico; fator de equivalência e branco.
- Umidade por Karl Fischer com unidades e correção de branco específicas ao método.
- Ensaios de dissolução, uniformidade de doses, impurezas e potência **somente** após mapear monografias e critérios aceitos.
- Linearidade, regressão, intervalos de confiança, controle estatístico de processo e cartas de controle.
- Balanço de massa e reconciliação por etapa com registro de lote.
- Conversões unitárias rastreáveis, incerteza, significância e regras de arredondamento configuráveis por método.
- Validação com exemplos de laboratório revisados por farmacêutico responsável, trilha auditável e planos de testes assinados.
