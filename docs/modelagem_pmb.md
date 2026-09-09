# Modelagem PMB - perfil do eleitorado 2026

## Fontes analisadas

### `fontes/eleitorado_PMB_2026.json`

Arquivo curado do recorte Periferia Metropolitana de Brasilia. A estrutura atualizada passou a usar o bloco `pmb` para evitar confusao com `dim.regiao_administrativa`, que permanece restrita as RAs do DF.

Estrutura principal:

- `metadata`: ano, UF, fontes, data de geracao e observacoes de linhagem.
- `pmb`: identificacao do recorte, total de municipios e lista `municipios`.
- `pmb.municipios`: um registro por municipio do recorte.
- `totais_gerais`: medidas agregadas do recorte.
- `perfil_geral`: distribuicoes marginais do perfil eleitoral no recorte.

Em cada municipio:

- `municipio_codigo`: codigo TSE preservado para compatibilidade com as fontes eleitorais.
- `municipio_codigo_tse`: repeticao explicita do codigo TSE.
- `municipio_codigo_ibge`: codigo oficial IBGE de sete digitos para integracao territorial.
- `pop_municipio`: populacao oficial IBGE/SIDRA.
- `area_km2` e `centroid`: atributos territoriais preservados do JSON original.
- `totais`: soma de eleitores, biometria, deficiencia e nome social.
- `perfil`: distribuicoes por genero, estado civil, faixa etaria, escolaridade, raca/cor, identidade de genero, quilombola e interprete de Libras.

### `fontes/perfil_eleitor_secao_2026_GO.csv`

CSV TSE em `latin-1`, separado por `;`, com perfil do eleitorado no grao de secao eleitoral e combinacao demografica. O arquivo contem os campos:

- identificacao da fonte: `DT_GERACAO`, `HH_GERACAO`, `AA_ELEICAO`, `SG_UF`;
- territorio eleitoral: `CD_MUNICIPIO`, `NM_MUNICIPIO`, `NR_ZONA`, `NR_SECAO`, `NR_LOCAL_VOTACAO`, `NM_LOCAL_VOTACAO`;
- perfil: `CD/DS_GENERO`, `CD/DS_ESTADO_CIVIL`, `CD/DS_FAIXA_ETARIA`, `CD/DS_GRAU_ESCOLARIDADE`, `CD/DS_RACA_COR`, `CD/DS_IDENTIDADE_GENERO`, `CD/DS_QUILOMBOLA`, `CD/DS_INTERPRETE_LIBRAS`;
- medidas: `QT_ELEITORES`, `QT_ELEITORES_BIOMETRIA`, `QT_ELEITORES_DEFICIENCIA`, `QT_ELEITORES_NOME_SOCIAL`.

O JSON PMB e recalculado pela soma das medidas do CSV apenas para os 12 `CD_MUNICIPIO` presentes no recorte.

### `fontes/perfil_eleitor_secao_2026_GO_dicionario de dados.pdf`

O dicionario acompanha a mesma estrutura do CSV TSE de perfil por secao. No ambiente local atual nao ha extrator de PDF instalado, entao a validacao operacional foi feita pelos cabecalhos do CSV e pela estrutura ja usada em `stg.perfil_eleitor_secao_2026_df`.

## Populacao IBGE

`pop_municipio` foi atualizado com a estimativa oficial IBGE/SIDRA:

- tabela SIDRA: 6579;
- variavel: 9324, populacao residente estimada;
- periodo: 2025;
- data de referencia: 2025-07-01;
- recorte de consulta: municipios de Goias (`n6/in n3 52`).

O JSON tambem guarda a URL SIDRA usada em `pop_municipio_fonte.url`.

## Estrutura no banco

PMB deve ser tratada como recorte de municipios, nao como RA. Para isso foram adicionadas as estruturas:

- `dim.municipio`: municipio com codigo TSE, codigo IBGE, nome normalizado, populacao, area e centroide.
- `dim.recorte_geografico`: cadastro de recortes analiticos como `PMB`.
- `dim.recorte_municipio`: ponte N:N entre recortes e municipios.
- `fato.eleitorado_perfil_municipio`: fato agregada por eleicao, municipio e perfil demografico completo.

Essa modelagem preserva a linha atual DF:

- RAs continuam em `dim.regiao_administrativa`.
- O perfil demografico continua conformado em `dim.perfil_eleitor`.
- A eleicao e UF continuam em `dim.eleicao` e `dim.uf`.

## Ordem de carga recomendada

1. `sql/00_extensions_schemas.sql`
2. `sql/01_staging/01_staging_small_medium.sql`
3. `sql/01_staging/02_staging_large.sql`
4. `scripts/load_staging.py`
5. `scripts/load_large_staging.py --include-pmb-go`
6. `sql/02_dimensoes/01_dim_uf.sql`
7. `sql/02_dimensoes/02_dim_eleicao.sql`
8. `sql/02_dimensoes/07_dim_perfil_eleitor.sql`
9. `sql/02_dimensoes/08_dim_municipio_recorte_pmb.sql`
10. `sql/04_fatos/04_fato_eleitorado_perfil_municipio_pmb.sql`

O JSON pode ser regenerado antes da carga com:

```powershell
python scripts\build_pmb_eleitorado_json.py
```
