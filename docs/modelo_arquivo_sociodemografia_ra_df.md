# Modelo de arquivo sociodemografico por RA

## Objetivo

Este modelo padroniza a entrada de indicadores sociodemograficos por Regiao Administrativa do DF para carga no banco eleitoral. Ele separa essas informacoes das dimensoes eleitorais, mas mantem compatibilidade com `dim.regiao_administrativa` por `ra_codigo` e `ra_nome_normalizado`.

Arquivo estruturado gerado:

- `fontes/perfil_sociodemografico_ra_df_2025_estruturado.json`

Arquivo original analisado:

- `fontes/perfil_eleitorado_df_2025_consolidado_12jan2026.json`

## Estrutura recomendada

```json
{
  "schema_version": "1.0.0",
  "metadata": {
    "titulo": "Indicadores Sociodemograficos por Regiao Administrativa - Distrito Federal",
    "ano_referencia_demografica": "2024",
    "fontes": ["IPEDF/DIEPS/PDAD-A, 2024"],
    "data_consolidacao": "2025-12-31",
    "data_ultima_atualizacao": "2026-01-13 01:04:48",
    "data_normalizacao": "2026-09-09",
    "estrutura": "DF > Regiao Administrativa > Indicadores sociodemograficos"
  },
  "regras_transformacao": {
    "encoding": "Texto normalizado para UTF-8",
    "desdobramentos": [],
    "proporcionalidade": "Descricao da regra aplicada",
    "consistencia_total_df": "Descricao da regra de fechamento contra o total oficial do DF"
  },
  "sociodemografia_geral_df": {},
  "regioes_administrativas": []
}
```

## Registro de RA

Cada item em `regioes_administrativas` deve conter:

- `ra_codigo`: codigo da RA conforme `dim.regiao_administrativa.ra_codigo`.
- `ra_cira`: codigo numerico CIRA, quando conhecido.
- `ra_nome`: nome oficial.
- `centroid`: latitude e longitude, quando disponivel.
- `area_km2`: area da RA.
- `populacao_raca_cor`: total populacional e distribuicao negra/nao negra por sexo.
- `religiao`: distribuicao percentual por categoria.
- `renda`: medias de renda.
- `animais_estimacao`: percentual e quantidade de domicilios com pets.
- `perfil_resumido`: texto analitico curto.
- `derivacao`: opcional, usado quando a RA for criada por desdobramento ou ajuste proporcional.

## Regras para desdobramentos

Quando uma nova RA herda dados de uma RA de origem sem microdados proprios:

- informar `origem_ra_codigo`, `origem_ra_nome` e `populacao_estimada`;
- calcular `fator_proporcional = populacao_estimada / populacao_origem_original`;
- multiplicar quantidades pelo fator proporcional;
- preservar percentuais e medias herdadas quando nao houver base desagregada;
- ajustar a RA de origem para `populacao_original - populacao_estimada`;
- recalcular totais internos para fechamento por arredondamento.
- apos o desdobramento, fechar a soma das RAs contra o total oficial do DF.

Aplicado neste ciclo:

- `26 DE SETEMBRO`, RA-XXXVI, herda `VICENTE PIRES`, RA-XXX, com populacao 29.394.
- `PONTE ALTA`, XXXVII, herda `GAMA`, RA-II, com populacao 45.452.
- `VICENTE PIRES` fica fixada em 75.668.
- `GAMA` fica fixada em 88.496.
- A diferenca entre a soma das RAs apos desdobramento e o total oficial 2.982.816 e rateada proporcionalmente nas demais 33 RAs.

## Modelo relacional

As informacoes estruturadas sao carregadas em:

- `stg.perfil_sociodemografico_ra_df_json`: JSON bruto/estruturado.
- `dim.indicador_sociodemografico`: catalogo flexivel de indicadores.
- `fato.sociodemografia_ra`: valores numericos e percentuais por RA, ano e indicador.
- `fato.sociodemografia_ra_resumo`: texto de perfil resumido por RA e ano.

Essa abordagem evita criar colunas novas para cada indicador futuro. Para atualizar o banco com novos indicadores, o fluxo recomendado e:

1. Atualizar o JSON seguindo este modelo.
2. Adicionar o indicador em `dim.indicador_sociodemografico` no SQL de carga.
3. Adicionar a extracao do caminho JSON em `source_medida`.
4. Executar novamente a carga de staging e a fato.

## Consistencia de populacao

O valor oficial de populacao total do DF e 2.982.816, vindo de `perfil_geral_df.demografia_raca_cor_geral.total_geral` no arquivo original. O arquivo estruturado faz a soma das 37 RAs fechar exatamente nesse total em `sociodemografia_geral_df.demografia_raca_cor_geral.total_geral`.

Como as novas RAs e suas origens ajustadas possuem valores explicitamente definidos, o fechamento e feito assim:

- manter fixas `26 DE SETEMBRO = 29.394`, `PONTE ALTA = 45.452`, `VICENTE PIRES = 75.668` e `GAMA = 88.496`;
- ratear proporcionalmente a diferenca remanescente nas outras 33 RAs;
- recalcular `populacao_raca_cor.total_geral`, `negra.total`, `nao_negra.total` e quantidades por sexo para manter fechamento interno.
