# AURORA Android — quantidade de unidades para prescrições

> Protótipo educacional e de apoio técnico, NÃO homologado/validado para dispensação, tomada de decisão clínica, prescrição ou atendimento de requisitos GxP.

## Objetivo

Com base em uma prescrição legível e previamente avaliada pelo profissional, calcular **quantidade matemática** de unidades farmacêuticas para completar um tratamento **regular de dose fixa**, comparar o total diário prescrito com um **limite numérico previamente verificado e digitado pelo usuário**, e estimar embalagens comerciais quando informadas.

Não substitui a revisão da prescrição pelo farmacêutico, a avaliação do paciente, nem o contato com o prescritor quando necessário.

## Dados necessários

- Forma farmacêutica: comprimidos, cápsulas e sachês **inteiros**, ou soluções/suspensões orais expressas em mL.
- Concentração da apresentação **mg por unidade** (sólidos) ou **mg/mL** (líquidos).
- Dose prescrita em **mg por administração**.
- Número inteiro de administrações diárias (1–24), em esquema fixo.
- Número inteiro de dias (1–365).
- **Dose máxima diária aplicável em mg/dia e sua fonte/contexto**. O app não supõe nem pesquisa autonomamente esse valor. Conferir bula profissional, indicação, apresentação, via, população e eventual ajuste individual.
- Capacidade opcional por caixa em unidades inteiras ou volume por frasco em mL.

Não registrar nome, telefone ou outros identificadores do paciente no app.

## Fórmulas

Unidades por administração = dose prescrita (mg) ÷ concentração (mg/unidade).

Para líquidos orais: mL por administração = dose prescrita (mg) ÷ concentração (mg/mL).

Dose diária prescrita (mg/dia) = dose por administração (mg) × número de administrações por dia.

Quantidade total de unidades ou mL = unidades por administração × administrações por dia × dias.

Embalagens inteiras estimadas = teto(quantidade total ÷ capacidade da embalagem).

Alerta numérico = dose diária prescrita superior à dose máxima diária **informada** pelo profissional.

**A ausência de alerta não equivale a segurança nem conformidade da prescrição**. O app não prova que o limite digitado é verdadeiro/aplicável. Uma receita com dose abaixo do limite ainda pode estar errada, ser contraindicada ou exigir ajuste.

## Tratamento de condições especiais

Para comprimidos, cápsulas e sachês, **não** se presume que as unidades podem ser divididas. Se uma tomada resultar em 1,5 unidade, a calculadora rejeita a operação; só um processo próprio de revisão técnica poderia permitir divisão de apresentações autorizadas, e essa função ainda não foi implementada.

O modelo deliberadamente **não aceita**, sem desenvolvimento e validação específicos:
- Posologia variável (redução progressiva, titulação, dias alternados e uso "se necessário" / SOS);
- Equivalência entre sais, pró-fármacos, bases ou diferentes apresentações;
- Formulações com concentração expressa em UI, %, gotas ou mg/kg/dose sem conversão e verificação externas;
- Administração injetável, administração em bomba, tempo de infusão, dispositivos multidose ou preparação;
- Prescrições pediátricas, dose por superfície corporal, ajuste por função renal/hepática, interação farmacológica, idade, gravidez ou comorbidades;
- Fracionamento comercial, legislação de controlados e outras condições de dispensação.

O cálculo de caixas integrais **não autoriza** entrega de quantidade excedente ou fracionamento sem os requisitos legais. O tratamento real deve seguir a prescrição, os POPs e as normas aplicáveis.

## Referências oficiais

1. [Bulário Eletrônico ANVISA](https://consultas.anvisa.gov.br/#/bulario/) — consultar as bulas para profissionais de saúde, apresentação e informações de posologia. A bula se refere a um produto registrado, não a uma tabela universal de "máximos".
2. [ANVISA RDC 44/2009, arts. 42–46](https://anvisalegis.datalegis.net/action/ActionDatalegis.php?acao=abrirTextoAto&cod_menu=8542&cod_modulo=310&link=S&numeroAto=00000044&orgao=RDC%2FDC%2FANVISA%2FMS&seqAto=000&tipo=RDC&valorAno=2009) — orientação e avaliação de receitas.
3. [ANVISA RDC 67/2007, seção 5.18](https://anvisalegis.datalegis.net/action/ActionDatalegis.php?acao=abrirTextoAto&cod_menu=8542&cod_modulo=310&link=S&numeroAto=00000067&orgao=RDC%2FDC%2FANVISA%2FMS&seqAto=002&tipo=RDC&valorAno=2007) — requisitos específicos para avaliação farmacêutica de prescrições de manipulados.
4. [Ministério da Saúde — Protocolo de Segurança na Prescrição, Uso e Administração de Medicamentos](https://www.gov.br/saude/pt-br/composicao/saes/seguranca-do-paciente/publicacoes/protocolos-de-seguranca-do-paciente/protocolo-seguraca-na-prescricao-uso-e-administracao-de-medicamentos.pdf/view).

## Testes automatizados

`test/prescription_test.dart` cobre posologia fixa, sólidos e líquidos, arredondamento apenas de **embalagens comerciais**, erro para unidades sólidas fracionárias, limites diários, entrada inválida e preservação da dose prescrita.

Validação de referência farmacológica e ensaios com exemplos reais ainda **não realizados**. Não inserir exemplos de dose máxima real sem a confirmação documental de fonte, forma e indicação.
