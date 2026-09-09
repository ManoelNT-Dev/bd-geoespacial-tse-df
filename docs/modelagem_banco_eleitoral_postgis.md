# Modelagem do banco eleitoral - PostgreSQL/PostGIS

Este documento descreve a modelagem atual do banco eleitoral DF, incorporando os ajustes executados ate a Etapa 14. Ele deve servir como referencia para manutencao, expansao, validacao e construcao das views/indices das proximas etapas.

## 1. Objetivo e escopo

O banco organiza dados eleitorais e geoespaciais em PostgreSQL/PostGIS para suportar consultas por:

- UF, Regiao Administrativa, zona, local de votacao e secao;
- eleicao, cargo, candidato/votavel, partido, federacao e coligacao;
- perfil do eleitorado por secao, local e RA;
- votacao por secao com drill-down ate RA/local/secao;
- regras de qualidade e conciliacao entre fontes oficiais.

Escopo ja implementado:

- Staging das fontes disponiveis.
- Dimensoes de UF, eleicao, RA, zona, cargo, partido, federacao, coligacao, local, secao, candidato e perfil do eleitor.
- Fato de eleitorado por perfil/secao 2026.
- Estrutura de fato de votacao e apuracao.
- Carga piloto de votacao 2022 somente para a ZE 20, usada para validar a estrutura.

Diretriz de votacao:

- `votacao_secao_2022_DF.csv` nao sera carregado integralmente.
- O arquivo 2022 permanece apenas como amostra piloto/modelagem.
- A carga completa futura sera dos dados de votacao 2026, quando estiverem disponiveis na mesma estrutura.

## 2. Schemas

Schemas criados:

- `stg`: staging bruto das fontes.
- `dim`: dimensoes conformadas.
- `fato`: tabelas fato e views analiticas.
- `geo`: geometrias geoespaciais.
- `aux`: qualidade, conciliacao e apoio.

Extensoes:

- `postgis`
- `unaccent`

## 3. Fontes

| Fonte | Linhas / estrutura | Uso |
|---|---:|---|
| `consulta_cand_2026_DF.csv` | 661 linhas, 50 colunas, Latin-1, `;` | eleicao 2026, cargos, partidos, federacoes, coligacoes e candidatos |
| `consulta_cand_complementar_2026_DF.csv` | 661 linhas, 49 colunas, Latin-1, `;` | dados complementares de candidato |
| `eleitorado_local_votacao_2026_DF.csv` | 7.050 linhas, 41 colunas, Latin-1, `;` | locais, secoes, secoes agregadas, aptos e coordenadas |
| `perfil_eleitor_secao_2026_DF.csv` | 1.233.369 linhas, Latin-1, `;` | perfil demografico agregado por secao |
| `Locais_TRE_DF_2026.xlsx` | 614 linhas uteis + total | locais oficiais TRE 2026 |
| `Locais_Secao_TRE_DF_2026.xlsx` | 614 linhas uteis + total | distribuicao de secoes por local |
| `Locais_Secao_Agrupadas por local_TRE_DF_2026.xlsx` | 614 linhas uteis + total | secoes por local em formato textual |
| `Secoes_TRE-DF_2026.xlsx` | 6.961 linhas uteis + total | secoes principais oficiais TRE |
| `geo_ra_centroid_atualizado.json` | 35 pontos | centroides de RA em EPSG:4326 |
| `perfil_sociodemografico_ra_df_2025_estruturado.json` | 37 RAs | indicadores sociodemograficos por RA, com desdobramento proporcional de 26 de Setembro e Ponte Alta |
| `shapefile_ras/regioes_administrativas.*` | 37 poligonos | limites de RA em SIRGAS 2000 / UTM 23S |
| `votacao_secao_2022_DF.csv` | 1.238.611 linhas, 26 colunas | apenas piloto/modelagem da estrutura de votacao |

Observacoes:

- Planilhas TRE possuem linha de totais e ela e marcada com `is_total`.
- CSVs TSE/TRE foram lidos em Latin-1.
- Alguns arquivos possuem problemas de encoding em textos acentuados; a carga preserva o recebido e a normalizacao ocorre nas dimensoes.
- RA e local/secao nao trazem relacionamento explicito; a RA e derivada por cruzamento espacial quando ha coordenada valida.

## 4. Convencoes de modelagem

- Staging preserva colunas de origem como `text`, com `source_file`, `row_number` e `loaded_at`.
- Dimensoes usam chaves substitutas (`identity`) e restricoes `unique` para chaves naturais.
- Tabelas fato mantem chaves substitutas materializadas (`ra_id`, `local_id`, `secao_id`) para acelerar consultas.
- Geometrias de RAs:
  - `geom_utm geometry(MultiPolygon, 31983)`;
  - `geom geometry(MultiPolygon, 4326)`;
  - `centroid_geom geometry(Point, 4326)`.
- Geometrias de locais/secoes:
  - `geom geometry(Point, 4326)`.
- Valores de dominio como `#NULO`, `#NE`, `-1` e `-3` sao tratados conforme semantica de cada fonte.
- CPF de candidato nao e armazenado aberto; usa-se `cpf_hash`.

## 5. Staging

Tabelas de staging implementadas:

- `stg.consulta_cand_2026_df`
- `stg.consulta_cand_complementar_2026_df`
- `stg.eleitorado_local_votacao_2026_df`
- `stg.perfil_eleitor_secao_2026_df`
- `stg.tre_locais_2026_df`
- `stg.tre_locais_secao_2026_df`
- `stg.tre_locais_secao_agrupadas_2026_df`
- `stg.tre_secoes_2026_df`
- `stg.geo_ra_centroid_atualizado`
- `stg.perfil_sociodemografico_ra_df_json`
- `stg.ra_shapefile`
- `stg.votacao_secao_2022_df`

Estado atual relevante:

- `perfil_eleitor_secao_2026_df`: 1.233.369 linhas.
- `votacao_secao_2022_df`: 44.464 linhas da ZE 20, amostra piloto.
- A carga completa de 2022 nao deve ser executada.

## 6. Dimensoes

### 6.1 `dim.uf`

Unidade federativa.

Campos principais:

- `uf_id`
- `sigla`
- `nome`
- `codigo_ibge`

Chave natural:

- `sigla`

Estado atual:

- 1 registro: `DF`, `Distrito Federal`, IBGE `53`.

### 6.2 `dim.eleicao`

Eleicoes e turnos.

Campos principais:

- `eleicao_id`
- `ano`
- `turno`
- `cd_eleicao`
- `ds_eleicao`
- `cd_tipo_eleicao`
- `nm_tipo_eleicao`
- `dt_eleicao`
- `tp_abrangencia`

Chave natural:

- `ano + turno + cd_eleicao`

Estado atual:

- Eleicao 2026 criada a partir de `consulta_cand_2026_DF.csv`.
- Eleicao 2022 criada pela carga piloto da ZE 20.

Regra:

- Para 2026, a fonte principal de descricao da eleicao e `consulta_cand_2026_DF.csv`, porque `eleitorado_local_votacao_2026_DF.csv` traz descricao resumida como `1o Turno`.

### 6.3 `dim.regiao_administrativa` e `geo.ra_geometria`

Representam as 37 RAs e suas geometrias.

`dim.regiao_administrativa`:

- `ra_id`
- `uf_id`
- `ra_cira`
- `ra_codigo`
- `ra_nome`
- `ra_nome_normalizado`
- `area_km2`
- `status`
- `fonte_poligono`
- `fonte_centroide`

Chaves naturais:

- `uf_id + ra_codigo`
- `uf_id + ra_nome_normalizado`

`geo.ra_geometria`:

- `ra_id`
- `geom_utm`
- `geom`
- `centroid_geom`
- `centroid_lon`
- `centroid_lat`
- `centroid_origem`

Indices:

- GiST em `geom`.
- GiST em `centroid_geom`.

Regras:

- 37 poligonos carregados do shapefile.
- 34 centroides aproveitados diretamente do GeoJSON.
- 3 centroides calculados por `st_pointonsurface`: `VARJAO`, `26 DE SETEMBRO` e `PONTE ALTA`.
- O centroide GeoJSON de `VARJAO` foi descartado porque ficava fora do poligono.
- A regra valida o ponto com `st_covers(geom, centroid_geom)`.

### 6.4 `dim.zona_eleitoral`

Zonas eleitorais do DF.

Campos:

- `zona_id`
- `uf_id`
- `nr_zona`
- `cd_situ_zona`
- `ds_situ_zona`

Chave natural:

- `uf_id + nr_zona`

Estado atual:

- 19 zonas.

### 6.5 `dim.cargo_eleitoral`

Cargos eleitorais.

Campos:

- `cargo_id`
- `cd_cargo`
- `ds_cargo`

Chave natural:

- `cd_cargo`

Estado atual:

- 7 cargos de 2026.
- A votacao piloto 2022 usa 4 cargos: governador, senador, deputado federal e deputado distrital.

### 6.6 `dim.partido_politico`

Partidos.

Campos:

- `partido_id`
- `nr_partido`
- `sigla`
- `nome`

Chaves naturais:

- `nr_partido`
- `sigla`

Estado atual:

- 29 partidos.

### 6.7 `dim.federacao`

Federacoes partidarias.

Campos:

- `federacao_id`
- `nr_federacao`
- `sg_federacao`
- `nm_federacao`
- `ds_composicao_federacao`

Chave natural:

- `nr_federacao + sg_federacao`

Regra:

- `NR_FEDERACAO = -1 / #NULO` representa ausencia de federacao e nao e inserido.

Estado atual:

- 5 federacoes reais.

### 6.8 `dim.coligacao`

Coligacoes por eleicao.

Campos:

- `coligacao_id`
- `eleicao_id`
- `sq_coligacao`
- `nm_coligacao`
- `ds_composicao_coligacao`

Chave natural:

- `eleicao_id + sq_coligacao`

Estado atual:

- 62 coligacoes.
- `PARTIDO ISOLADO` permanece na dimensao quando ha `SQ_COLIGACAO` real.

### 6.9 `dim.local_votacao`

Locais fisicos de votacao por eleicao, zona e numero do local.

Campos principais:

- `local_id`
- `eleicao_id`
- `uf_id`
- `zona_id`
- `ra_id`
- `nr_zona`
- `nr_local_votacao`
- `nome`
- `nome_normalizado`
- `endereco`
- `bairro`
- `cep`
- `telefone`
- `latitude`
- `longitude`
- `geom`
- `cd_tipo_local`
- `ds_tipo_local`
- `cd_situ_local_votacao`
- `ds_situ_local_votacao`
- `status`
- `is_principal`
- `fonte_tre_confirmada`
- `source_priority`

Chave natural:

- `eleicao_id + uf_id + nr_zona + nr_local_votacao`

Regra central:

- `NR_LOCAL_VOTACAO` nao identifica sozinho um local fisico no DF.
- O mesmo numero de local aparece em mais de uma zona; por isso a chave precisa incluir `nr_zona`.
- Para consistencia oficial de 2026, considerar principais os 614 pares `zona + local` coincidentes com a planilha oficial do TRE.
- Pares adicionais do CSV oficial sao preservados com `is_principal = false`, `fonte_tre_confirmada = false` e `source_priority = csv_eleitorado_local_votacao_2026_adicional`.

Estado atual 2026:

- 622 pares `zona + local` vindos do CSV.
- 614 principais confirmados pelo TRE.
- 8 adicionais para checagem futura.
- 108 numeros de local distintos.
- 619 locais com `geom` e `ra_id`.
- 3 locais sem geometria por coordenada sentinela `-1/-1`.
- 0 locais com geometria valida sem RA.

Estado atual piloto 2022:

- 18 locais da ZE 20 criados pela amostra de votacao.
- Sem geometria/RA no piloto quando nao ha coordenada na fonte de votacao.

Indices:

- GiST em `geom`.
- B-tree em `ra_id`.
- B-tree em `zona_id`.
- B-tree em `is_principal`.

### 6.10 `dim.secao_eleitoral`

Secoes eleitorais por eleicao, zona e numero da secao.

Campos principais:

- `secao_id`
- `eleicao_id`
- `uf_id`
- `ra_id`
- `zona_id`
- `local_id`
- `nr_zona`
- `nr_secao`
- `cd_tipo_secao_agregada`
- `ds_tipo_secao_agregada`
- `nr_secao_principal`
- `secao_principal_id`
- `local_principal_id`
- `cd_situ_secao`
- `ds_situ_secao`
- `cd_situ_secao_acessibilidade`
- `ds_situ_secao_acessibilidade`
- `tem_acessibilidade`
- `qt_eleitores_aptos`
- `qt_eleitores_aptos_tre`
- `qt_eleitores_suspensos_tre`
- `latitude`
- `longitude`
- `geom`
- `is_secao_principal_tre`
- `fonte_tre_confirmada`
- `is_adicional_csv`
- `source_file`
- `loaded_at`

Chave natural:

- `eleicao_id + uf_id + nr_zona + nr_secao`

Regras centrais 2026:

- O numero oficial do TRE e 6.961 secoes principais.
- A planilha TRE possui 78 linhas com secoes agregadas entre parenteses.
- Expandindo as agregadas da planilha, o TRE representa 7.042 secoes.
- O CSV `eleitorado_local_votacao_2026_DF.csv` possui 7.050 secoes.
- 81 secoes do CSV tem `DS_TIPO_SECAO_AGREGADA = Agregada`.
- Quando a secao e agregada, o `local_id` efetivo deve ser o local da secao principal indicada em `NR_SECAO_PRINCIPAL`.
- Toda secao agregada deve apontar para `secao_principal_id`.
- As 8 secoes que existem apenas no CSV sao preservadas com `is_adicional_csv = true`.

Estado atual 2026:

- 7.050 secoes carregadas do CSV.
- 6.961 marcadas como `is_secao_principal_tre = true`.
- 7.042 marcadas como `fonte_tre_confirmada = true`.
- 81 agregadas vinculadas a secao principal.
- 8 adicionais para checagem futura.
- 4 secoes sem geometria, herdadas de locais sem coordenada.
- 106 divergencias de aptos entre TRE e soma CSV de principal/agregadas registradas como aviso.

Estado atual piloto 2022:

- 219 secoes da ZE 20 criadas pela amostra.

Indices:

- B-tree em `local_id`.
- B-tree em `ra_id`.
- GiST em `geom`.
- B-tree em `is_secao_principal_tre`.
- B-tree em `fonte_tre_confirmada`.

### 6.11 `dim.candidato`

Candidatos de 2026.

Campos principais:

- chaves: `candidato_id`, `eleicao_id`, `uf_id`, `cargo_id`, `partido_id`, `federacao_id`, `coligacao_id`;
- identificadores: `sq_candidato`, `nr_candidato`;
- nomes: `nm_candidato`, `nm_urna_candidato`, `nm_social_candidato`;
- privacidade: `cpf_hash`, `email_divulgavel`;
- candidatura: situacao, julgamento, urna, totalizacao;
- perfil: genero, instrucao, estado civil, cor/raca, ocupacao, nascimento, nacionalidade, idade, quilombola, etnia indigena;
- campanha: reeleicao, declaracao de bens, despesa maxima;
- linhagem: `source_file`, `source_file_complementar`, `loaded_at`.

Chave natural:

- `eleicao_id + sq_candidato`

Regras:

- `consulta_cand_2026_DF.csv` e `consulta_cand_complementar_2026_DF.csv` sao unidas por `SQ_CANDIDATO`.
- CPF aberto nao e armazenado; `cpf_hash = md5(nr_cpf_candidato)`.
- `st_reeleicao = #NE` vira `null`.
- Campos `S/N` viram booleanos.

Estado atual:

- 661 candidatos.
- Todos possuem cargo, partido, coligacao e hash de CPF.
- 184 possuem federacao.
- 2 quilombolas.
- 458 declararam bens.

Indices:

- `partido_id`
- `cargo_id`
- `federacao_id`
- `coligacao_id`

### 6.12 `dim.perfil_eleitor`

Combinacoes demograficas do perfil do eleitorado.

Campos:

- `perfil_id`
- `perfil_hash`
- genero;
- estado civil;
- faixa etaria;
- grau de escolaridade;
- raca/cor;
- identidade de genero;
- quilombola;
- interprete de Libras.

Chave natural:

- `perfil_hash`, calculado por MD5 da combinacao dos codigos demograficos.

Estado atual:

- 8.468 perfis.

Indices:

- genero;
- faixa etaria;
- escolaridade;
- raca/cor.

## 7. Fatos

### 7.1 `fato.eleitorado_perfil_secao`

Fato de eleitorado 2026 por secao e perfil demografico.

Grao:

- `eleicao_id + secao_id + perfil_id`

Campos principais:

- `eleicao_id`
- `uf_id`
- `ra_id`
- `local_id`
- `secao_id`
- `perfil_id`
- `qt_eleitores`
- `qt_eleitores_biometria`
- `qt_eleitores_deficiencia`
- `qt_eleitores_nome_social`
- `source_row_count`
- `source_file`
- `loaded_at`

Regra:

- A fonte possui duplicidades naturais por `secao + perfil`.
- A fato agrega por soma das medidas e preserva a quantidade de linhas brutas em `source_row_count`.

Estado atual:

- 1.219.951 linhas analiticas agregadas.
- `source_row_count` soma 1.233.369 linhas brutas.
- 7.042 secoes cobertas.
- `qt_eleitores`: 2.253.132.
- biometria: 2.126.894.
- deficiencia: 24.832.
- nome social: 723.
- Sem perfil sem secao.
- Sem divergencia entre soma de perfil e `QT_ELEITOR_SECAO`.

Indices:

- `ra_id`
- `local_id`
- `secao_id`
- `perfil_id`

### 7.2 `dim.votavel`

Dimensao de candidatos/votos especiais usada pela fato de votacao.

Por que existe:

- Nem toda linha de votacao representa candidato nominal.
- Ha votos nominais, votos de legenda, votos brancos e votos nulos.

Campos:

- `votavel_id`
- `eleicao_id`
- `cargo_id`
- `partido_id`
- `candidato_id`
- `nr_votavel`
- `nm_votavel`
- `sq_candidato`
- `tipo_votavel`
- `source_file`
- `loaded_at`

Tipos:

- `nominal`
- `legenda`
- `branco`
- `nulo`

Chave unica:

- indice unico por `eleicao_id + cargo_id + nr_votavel + coalesce(sq_candidato, -999999999999)`.

Regras:

- `SQ_CANDIDATO = -3`: voto de legenda; `NR_VOTAVEL` e numero do partido.
- `SQ_CANDIDATO = -1` e `NR_VOTAVEL = 95`: branco.
- `SQ_CANDIDATO = -1` e `NR_VOTAVEL = 96`: nulo.
- Demais linhas: nominal.
- Para o piloto 2022, `candidato_id` fica nulo porque a dimensao de candidatos carregada e de 2026.

Estado atual piloto 2022:

- 838 votaveis.
- Tipos presentes: nominal, legenda, branco e nulo.

### 7.3 `fato.votacao_candidato_secao`

Fato de votacao por secao, cargo e votavel.

Grao:

- `eleicao_id + secao_id + cargo_id + votavel_id`

Campos principais:

- `eleicao_id`
- `uf_id`
- `ra_id`
- `local_id`
- `secao_id`
- `cargo_id`
- `votavel_id`
- `candidato_id`
- `partido_id`
- `nr_zona`
- `nr_secao`
- `nr_local_votacao`
- `nr_votavel`
- `sq_candidato`
- `nm_votavel`
- `tipo_votavel`
- `qt_votos`
- `source_file`
- `loaded_at`

Estado atual piloto 2022:

- 44.464 linhas para ZE 20.
- Soma por tipo:
  - `nominal`: 39.844 linhas, 228.436 votos.
  - `legenda`: 2.869 linhas, 4.604 votos.
  - `branco`: 876 linhas, 16.142 votos.
  - `nulo`: 875 linhas, 11.822 votos.

Indices atuais:

- `ra_id + cargo_id`
- `uf_id + ra_id + local_id + secao_id`
- `local_id + candidato_id`
- `partido_id`
- `votavel_id`

Indices recomendados para Etapa 16:

- `eleicao_id + cargo_id + votavel_id`
- `eleicao_id + cargo_id + ra_id`
- `eleicao_id + cargo_id + local_id`
- `eleicao_id + cargo_id + secao_id`
- `eleicao_id + cargo_id + tipo_votavel`

### 7.4 `fato.apuracao_secao`

Fato agregada por secao e cargo.

Grao:

- `eleicao_id + secao_id + cargo_id`

Campos:

- `eleicao_id`
- `uf_id`
- `ra_id`
- `local_id`
- `secao_id`
- `cargo_id`
- `qt_aptos`
- `qt_comparecimento`
- `qt_abstencoes`
- `qt_votos_nominais`
- `qt_votos_legenda`
- `qt_votos_brancos`
- `qt_votos_nulos`
- `source_file`
- `loaded_at`

Estado atual piloto 2022:

- 876 linhas.
- As medidas de votos sao derivadas de `fato.votacao_candidato_secao`.
- `qt_aptos`, `qt_comparecimento` e `qt_abstencoes` ainda ficam nulos porque nao foram carregados de uma fonte especifica de apuracao/boletim.

### 7.5 `dim.indicador_sociodemografico`

Catalogo flexivel de indicadores sociodemograficos.

Campos:

- `indicador_id`
- `codigo`
- `grupo`
- `subgrupo`
- `metrica`
- `descricao`
- `unidade`

Chave natural:

- `codigo`

### 7.6 `fato.sociodemografia_ra`

Fato de indicadores sociodemograficos por RA.

Grao:

- `ra_id + indicador_id + ano_referencia`

Campos principais:

- `ra_id`
- `indicador_id`
- `ano_referencia`
- `valor_num`
- `percentual`
- `fonte`
- `metodo`
- `source_file`

Regras:

- fonte estruturada: `perfil_sociodemografico_ra_df_2025_estruturado.json`;
- `26 DE SETEMBRO` herda distribuicoes de `VICENTE PIRES`;
- `PONTE ALTA` herda distribuicoes de `GAMA`;
- `VICENTE PIRES` e `GAMA` sao ajustadas pela subtracao das populacoes das novas RAs;
- quantidades sao ajustadas proporcionalmente e percentuais/medias sao preservados quando nao ha microdados.

### 7.7 `fato.sociodemografia_ra_resumo`

Texto analitico curto por RA e ano.

Grao:

- `ra_id + ano_referencia`

## 8. Views atuais e planejadas

### 8.1 View atual

`fato.vw_votacao_drilldown`

Uso:

- Expor a votacao por secao com dimensoes de eleicao, UF, RA, local, secao, cargo, partido e candidato/votavel.

Campos principais:

- ano, turno, `cd_eleicao`, `ds_eleicao`;
- UF;
- RA;
- local de votacao;
- zona e secao;
- cargo;
- tipo de votavel, numero e nome do votavel;
- partido;
- candidato nominal quando existir;
- `qt_votos`.

### 8.2 Views planejadas para Etapa 16

A especificacao `fontes/especificacao-tecnica-painel-eleitoral.md` indica consumo futuro por mapas, KPIs, rankings/Pareto, top2, margem, heatmap, barras empilhadas, tabelas analiticas e drill-down.

Views recomendadas:

- `fato.vw_votacao_resultado_nivel`
- `fato.vw_votacao_ra_candidato`
- `fato.vw_votacao_local_candidato`
- `fato.vw_votacao_secao_candidato`
- `fato.vw_votacao_rank_pareto`
- `fato.vw_votacao_top2_margem`
- `fato.vw_votacao_heatmap_top5`
- `fato.vw_votacao_stacked_ra_top5`
- `fato.vw_vitorias_zeros_votavel`
- `fato.vw_eleitorado_perfil_ra`
- `fato.vw_eleitorado_perfil_local`
- `fato.vw_eleitorado_perfil_secao`
- `fato.vw_eleitorado_dominante_ra`
- `geo.vw_ra_mapa`
- `geo.vw_local_votacao_mapa`

Contratos minimos:

- Views de resultado devem expor eleicao, cargo, nivel, RA, local, secao, votavel, partido, votos, votos validos do nivel, percentual no nivel e percentual no total.
- Views de ranking devem expor `ranking`, `cum_pct` e `dentro_pareto80`.
- Views de top2/margem devem expor lider, segundo colocado, margem em votos, margem percentual e classificacao de competitividade.
- Views geograficas devem expor latitude, longitude, geometria, intensidade e totais.
- Views de eleitorado devem expor dimensao demografica, codigo, descricao, quantidade, percentual e categoria dominante quando aplicavel.

## 9. Auxiliares e qualidade

### 9.1 `aux.qualidade_dado`

Tabela generica de ocorrencias de qualidade.

Campos:

- `qualidade_id`
- `entidade`
- `chave_natural`
- `severidade`
- `regra`
- `detalhe`
- `source_file`
- `detected_at`

Regras implementadas:

`local_votacao`:

- `local_sem_coordenada`
- `local_sem_ra`
- `local_csv_sem_tre`
- `nr_local_votacao_reutilizado_em_zonas`

`secao_eleitoral`:

- `secao_csv_sem_tre`
- `secao_csv_sem_perfil`
- `secao_sem_local`
- `secao_sem_ra`
- `secao_agregada_sem_principal`
- `secao_agregada_local_diferente_principal`
- `divergencia_aptos_tre_csv`

`candidato`:

- `candidato_sem_complementar`
- `candidato_sem_cargo`
- `candidato_sem_partido`
- `candidato_sem_federacao`
- `candidato_sem_coligacao`

`eleitorado_perfil_secao`:

- `perfil_sem_secao`
- `perfil_secao_diverge_aptos_csv`

Estado atual de qualidade mais relevante:

- 8 locais CSV sem TRE.
- 3 locais sem coordenada.
- 90 numeros de local reutilizados em mais de uma zona.
- 8 secoes CSV sem TRE.
- 8 secoes CSV sem perfil.
- 106 divergencias de aptos TRE x CSV.
- 0 erros de candidato.
- 0 erros de perfil sem secao.

### 9.2 `aux.local_votacao_alias`

Preserva nomes, enderecos e coordenadas originais por fonte para conciliacao de locais.

Campos:

- `alias_id`
- `local_id`
- `nr_zona`
- `nr_local_votacao`
- `nome_original`
- `endereco_original`
- `bairro_original`
- `latitude_original`
- `longitude_original`
- `source_file`

Estado atual:

- 1.236 aliases de fonte:
  - 622 do CSV oficial;
  - 614 da planilha TRE.

### 9.3 `aux.ra_alias`

Prevista para conciliacao de codigos/nomes de RA entre fontes. Ainda nao foi populada como parte das etapas executadas.

## 10. Relacionamentos principais

Fluxo geografico:

```text
dim.uf
  -> dim.regiao_administrativa
  -> geo.ra_geometria
  -> dim.local_votacao
  -> dim.secao_eleitoral
```

Fluxo eleitoral:

```text
dim.eleicao
  -> dim.cargo_eleitoral
  -> dim.partido_politico / dim.federacao / dim.coligacao
  -> dim.candidato
  -> dim.votavel
  -> fato.votacao_candidato_secao
  -> fato.apuracao_secao
```

Fluxo de eleitorado:

```text
dim.eleicao
  -> dim.secao_eleitoral
  -> dim.perfil_eleitor
  -> fato.eleitorado_perfil_secao
```

## 11. Fluxo de carga atual

Ordem implementada:

1. Criar schemas/extensoes.
2. Criar staging pequeno/medio.
3. Carregar CSVs pequenos, XLSX, GeoJSON e shapefile.
4. Criar staging grande.
5. Carregar `perfil_eleitor_secao_2026_DF.csv`.
6. Criar `dim.uf`.
7. Criar `dim.eleicao` 2026.
8. Criar RAs e geometrias.
9. Criar zonas, cargos, partidos, federacoes e coligacoes.
10. Criar locais de votacao 2026.
11. Criar secoes eleitorais 2026.
12. Criar candidatos 2026.
13. Criar perfis de eleitor.
14. Criar fato de eleitorado por perfil/secao.
15. Criar estrutura de votacao.
16. Carregar amostra piloto 2022 da ZE 20.
17. Popular votaveis, votacao e apuracao para a amostra piloto.

Para reprocessamento completo com volume vazio, seguir a ordem documentada em `docs/resumo_contexto_proxima_sessao.md`.

## 12. Regras de negocio criticas

Locais:

- Usar chave `eleicao_id + uf_id + nr_zona + nr_local_votacao`.
- Preservar 614 pares oficiais TRE como principais.
- Preservar os 8 pares adicionais do CSV como nao principais para checagem futura.

Secoes:

- O numero oficial TRE 2026 e 6.961 secoes principais.
- O CSV possui 7.050 secoes por incluir agregadas e adicionais.
- Secao agregada herda o local da secao principal.
- `fonte_tre_confirmada` cobre 7.042 secoes apos expansao das agregadas da planilha.

Perfil:

- A fonte bruta possui duplicidades naturais por `secao + perfil`.
- A fato deve consolidar duplicidades por soma.
- `source_row_count` preserva a rastreabilidade com a fonte bruta.

Votacao:

- `SQ_CANDIDATO = -1` representa branco/nulo.
- `SQ_CANDIDATO = -3` representa legenda.
- `NR_VOTAVEL = 95` com `SQ_CANDIDATO = -1` e branco.
- `NR_VOTAVEL = 96` com `SQ_CANDIDATO = -1` e nulo.
- 2022 e piloto; carga completa sera 2026 quando a fonte existir.

Privacidade:

- CPF aberto de candidato nao e persistido em dimensao analitica.
- `cpf_hash` permite deduplicacao/auditoria sem expor CPF.

## 13. Consultas suportadas

Com o estado atual, o banco suporta:

- eleitorado por RA, local, secao e perfil demografico;
- contagem de locais e secoes por RA/zona;
- auditoria de locais oficiais TRE x adicionais CSV;
- auditoria de secoes oficiais, agregadas e adicionais;
- votacao piloto por RA/local/secao/cargo/votavel;
- classificacao de votavel em nominal, legenda, branco e nulo;
- drill-down de votacao via `fato.vw_votacao_drilldown`;
- cruzamentos iniciais de eleitorado 2026 com estrutura geografica/eleitoral.

Com a Etapa 16, o banco deve passar a suportar tambem:

- KPIs de paineis eleitorais;
- rankings e Pareto por RA/local/secao;
- top2 e margem por nivel;
- heatmap e barras empilhadas;
- views geograficas para mapas;
- tabelas analiticas combinando resultado e perfil do eleitorado.

## 14. Pendencias e expansao

Pendencias conhecidas:

- Criar views e materializacoes da Etapa 16.
- Revisar indices voltados a consultas interativas.
- Automatizar regras completas de qualidade na Etapa 17.
- Criar scripts de backup/restore/reprocessamento na Etapa 18.
- Definir como tratar `QT_ELEITORES_NAO_APTOS` no nivel de local/secao.
- Definir se zonas eleitorais terao geometria propria; as fontes atuais nao trazem limites de zona.
- Padronizar ou curar textos com problemas de encoding, sem perder a linhagem dos arquivos originais.

Expansao prevista:

- Quando a fonte de votacao 2026 estiver disponivel na mesma estrutura de `votacao_secao_2022_DF.csv`, criar staging/carga completa para 2026.
- Reaproveitar `dim.votavel`, `fato.votacao_candidato_secao`, `fato.apuracao_secao` e views da Etapa 16.
- Adaptar carga para vincular votaveis 2026 a `dim.candidato` 2026 por `SQ_CANDIDATO` quando o identificador estiver presente.

## 15. Arquivos de implementacao

Scripts SQL:

- `sql/00_extensions_schemas.sql`
- `sql/01_staging/01_staging_small_medium.sql`
- `sql/01_staging/02_staging_large.sql`
- `sql/02_dimensoes/01_dim_uf.sql`
- `sql/02_dimensoes/02_dim_eleicao.sql`
- `sql/02_dimensoes/03_dimensoes_eleitorais_basicas.sql`
- `sql/02_dimensoes/04_dim_local_votacao.sql`
- `sql/02_dimensoes/05_dim_secao_eleitoral.sql`
- `sql/02_dimensoes/06_dim_candidato.sql`
- `sql/02_dimensoes/07_dim_perfil_eleitor.sql`
- `sql/02_dimensoes/08_dim_municipio_recorte_pmb.sql`
- `sql/03_geoespacial/01_ra_geometria.sql`
- `sql/04_fatos/01_fato_eleitorado_perfil_secao.sql`
- `sql/04_fatos/02_estrutura_votacao_2022.sql`
- `sql/04_fatos/03_carga_piloto_votacao_2022.sql`
- `sql/04_fatos/04_fato_eleitorado_perfil_municipio_pmb.sql`
- `sql/04_fatos/05_fato_sociodemografia_ra.sql`

Loaders:

- `scripts/load_staging.py`
- `scripts/load_large_staging.py`
- `scripts/load_votacao_piloto.py`
- `scripts/build_pmb_eleitorado_json.py`
- `scripts/build_ra_sociodemografia_json.py`

Testes SQL:

- `tests/sql/00_extensions_schemas_test.sql`
- `tests/sql/01_staging_small_medium_test.sql`
- `tests/sql/02_staging_large_test.sql`
- `tests/sql/03_dim_uf_test.sql`
- `tests/sql/04_dim_eleicao_test.sql`
- `tests/sql/05_ra_geometria_test.sql`
- `tests/sql/06_dimensoes_eleitorais_basicas_test.sql`
- `tests/sql/07_dim_local_votacao_test.sql`
- `tests/sql/08_dim_secao_eleitoral_test.sql`
- `tests/sql/09_dim_candidato_test.sql`
- `tests/sql/10_perfil_eleitor_test.sql`
- `tests/sql/11_estrutura_votacao_2022_test.sql`
- `tests/sql/12_carga_piloto_votacao_2022_test.sql`
