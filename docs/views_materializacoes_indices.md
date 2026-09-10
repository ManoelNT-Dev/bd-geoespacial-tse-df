# Views, materializacoes e indices para paineis

Data de consolidacao: 2026-09-09

Este documento consolida o planejamento da Etapa 18: views, materialized views e indices de consulta para consumo futuro por paineis eleitorais. Ele cruza a implementacao atual do banco com a especificacao `fontes/especificacao-tecnica-painel-eleitoral.md`.

## Regra mandatoria de RAs

A nova especificacao deve considerar sempre o numero atual e oficial de 37 Regioes Administrativas do Distrito Federal.

Regras operacionais:

- `dim.regiao_administrativa` e a fonte oficial para contagem e cadastro de RAs.
- `geo.vw_ra_mapa`, views analiticas por RA, rankings por RA e KPIs de cobertura devem retornar ou considerar 37 RAs quando nao houver filtro territorial restritivo.
- Campos futuros equivalentes a `total_regioes`, `total_ras`, `cobertura_ras` ou `ras` devem ser calculados por `count(distinct ra_id)` a partir da dimensao atual, nao por constantes legadas.
- As referencias a 35 RAs na especificacao original em `fontes/especificacao-tecnica-painel-eleitoral.md` sao somente historico dos JSONs estaticos anteriores.
- As RAs `26 DE SETEMBRO` e `PONTE ALTA` devem aparecer nos contratos de mapa, tabela analitica, perfil, sociodemografia e qualquer agregacao territorial por RA.

## Contexto analisado

### Estado implementado

- Banco PostgreSQL/PostGIS com schemas `stg`, `dim`, `fato`, `geo` e `aux`.
- Etapas 0 a 16 implementadas, carregadas e validadas por `tests/sql/00` a `14`.
- Etapa 18.1 implementada em `sql/05_views/01_indices_consulta.sql` e validada por `tests/sql/15_views_indices_test.sql`: `pg_trgm`, 30 indices de consulta e `analyze` das tabelas principais.
- Etapa 18.2 implementada em `sql/05_views/02_votacao_materializacoes.sql` e validada por `tests/sql/16_votacao_materializacoes_test.sql`: `fato.mv_votacao_nivel` e `fato.mv_votacao_top5`.
- Etapa 18.3 implementada em `sql/05_views/03_votacao_views.sql` e validada por `tests/sql/17_votacao_views_test.sql`: views de resultado, top5, ranking/Pareto, vitorias/zeros e top5 por RA.
- Etapa 18.4 implementada em `sql/05_views/04_eleitorado_views.sql` e validada por `tests/sql/18_eleitorado_views_test.sql`: materializacao longa de eleitorado e views por nivel/dominancia.
- `dim.regiao_administrativa` e `geo.ra_geometria` usam 37 RAs oficiais do DF.
- `dim.local_votacao` usa chave natural `eleicao_id + uf_id + nr_zona + nr_local_votacao`.
- `dim.secao_eleitoral` usa chave natural `eleicao_id + uf_id + nr_zona + nr_secao`.
- `fato.eleitorado_perfil_secao` possui eleitorado DF 2026 por secao e perfil.
- `fato.eleitorado_perfil_municipio` possui eleitorado PMB/GO 2026 por municipio e perfil.
- `fato.sociodemografia_ra` possui indicadores sociodemograficos por RA.
- `fato.votacao_candidato_secao` possui apenas piloto tecnico 2022 da ZE 20.
- View existente: `fato.vw_votacao_drilldown`.

### Diferencas contra a especificacao legada

A especificacao do painel foi extraida de uma aplicacao com JSONs estaticos e historico de 35 RAs. O banco atual deve manter a regra revisada de 37 RAs. Portanto:

- Nao recriar a modelagem antiga de 35 RAs.
- Nao usar `nr_local_votacao` isolado como identificador de local.
- Nao importar ranks/Pareto estaticos; recalcular por SQL.
- PMB deve continuar como recorte de municipios, nao como RA.
- A votacao 2022 completa continua fora do escopo; as views de votacao devem funcionar com piloto 2022 e estar prontas para 2026.
- Shapes de resposta podem ser compativeis com os JSONs legados, mas as views devem usar chaves substitutas e naturais corretas do banco atual.

## Informacoes que serao consumidas

Os paineis futuros precisam de quatro familias de dados.

### 1. Resultados eleitorais

Consumo esperado:

- KPIs gerais: votos brutos, votos validos, brancos, nulos, cobertura de RAs/locais/secoes e lider geral.
- Mapa por RA, local e secao com latitude/longitude, geometria quando houver, total de votos e intensidade.
- Resultado por votavel, cargo e nivel geografico.
- Top candidatos por RA/local/secao.
- Ranking TOP 5 por nivel/territorio. Lider, segundo colocado, margem em votos e margem percentual devem ser derivados no front-end a partir desse TOP 5.
- Classificacao de competitividade: `competitiva`, `disputa`, `neutra`, `reduto`.
- Ranking e Pareto 80 por candidato/votavel em RA/local/secao.
- Heatmap top N candidatos por RA.
- Barras empilhadas top N por RA.
- Analise de vitorias e zeros por candidato.

Fonte principal:

- `fato.votacao_candidato_secao`
- `fato.apuracao_secao`
- `dim.votavel`
- `dim.cargo_eleitoral`
- `dim.eleicao`
- `dim.regiao_administrativa`
- `dim.local_votacao`
- `dim.secao_eleitoral`
- `geo.ra_geometria`

Observacao: no estado atual, as views retornarao somente a amostra piloto 2022 da ZE 20. Quando a votacao 2026 for carregada, os mesmos contratos devem atender o painel completo.

### 2. Perfil do eleitorado DF

Consumo esperado:

- Eleitorado por RA/local/secao.
- Percentuais por genero, faixa etaria, estado civil, escolaridade, raca/cor, identidade de genero, quilombola e interprete de Libras.
- Categorias dominantes por RA/local/secao, ignorando categorias invalidas ou nao informadas quando aplicavel.
- Indicadores operacionais: biometria, deficiencia e nome social.

Fonte principal:

- `fato.eleitorado_perfil_secao`
- `dim.perfil_eleitor`
- `dim.regiao_administrativa`
- `dim.local_votacao`
- `dim.secao_eleitoral`

### 3. Sociodemografia por RA

Consumo esperado:

- Populacao total por RA.
- Populacao negra/nao negra e recortes por sexo.
- Religiao em percentuais.
- Renda media domiciliar e per capita.
- Animais de estimacao.
- Texto resumido por RA.
- Tabela analitica enriquecida combinando resultado eleitoral, eleitorado e sociodemografia.

Fonte principal:

- `fato.sociodemografia_ra`
- `fato.sociodemografia_ra_resumo`
- `dim.indicador_sociodemografico`
- `dim.regiao_administrativa`

### 4. PMB

Consumo esperado:

- Eleitorado PMB por municipio.
- Perfil demografico por municipio e recorte PMB consolidado.
- Populacao municipal IBGE/SIDRA.
- Centroide municipal para mapa.

Fonte principal:

- `dim.municipio`
- `dim.recorte_geografico`
- `dim.recorte_municipio`
- `fato.eleitorado_perfil_municipio`
- `dim.perfil_eleitor`

## Inventario estrutural para expansao

Estado confirmado em 2026-09-09:

- `dim.regiao_administrativa`: 37 RAs oficiais.
- `dim.local_votacao`: 640 locais no total, sendo 622 de 2026 DF e 18 criados pelo piloto 2022.
- `dim.secao_eleitoral`: 7.269 secoes no total, sendo 7.050 de 2026 DF e 219 criadas pelo piloto 2022.
- `dim.perfil_eleitor`: 13.628 combinacoes demograficas apos incorporar DF e GO/PMB.
- `dim.municipio`: 12 municipios da PMB.
- `fato.eleitorado_perfil_secao`: 1.219.951 linhas, 2.253.132 eleitores DF 2026.
- `fato.eleitorado_perfil_municipio`: 34.927 linhas, 759.538 eleitores PMB.
- `fato.sociodemografia_ra`: 592 registros, 37 RAs x 16 indicadores.
- `fato.votacao_candidato_secao`: 44.464 linhas da votacao piloto 2022, ZE 20.
- `stg.perfil_eleitor_secao_2026_go`: 3.056.357 linhas carregadas para suporte PMB.

Implicacoes:

- Qualquer view territorial deve sempre carregar `eleicao_id` e, quando aplicavel, `ano`, `turno` e `cd_eleicao`.
- Contagens globais de local/secao nao devem misturar 2026 DF e piloto 2022 sem filtro explicito.
- Resumos PMB nao devem somar populacao municipal depois de join direto com fato de perfil, porque isso multiplica `pop_municipio` pelo numero de perfis. A populacao deve vir de subconsulta no grao de municipio ou de view propria.
- Views de votacao por RA devem aceitar `ra_id` nulo no piloto 2022, pois a fonte de votacao piloto nao tem coordenadas/RA.
- Estatisticas do PostgreSQL podem ficar desatualizadas apos cargas grandes; executar `analyze` antes de usar `pg_stat_user_tables` ou antes de comparar planos de consulta.

## Propostas para expansoes futuras

As propostas abaixo vao alem da especificacao original do painel. Elas preparam o banco para novas eleicoes, novos recortes territoriais, auditoria, busca, API, comparativos historicos e analises geoespaciais.

### Catalogo e cobertura de dados

#### `aux.vw_catalogo_fontes`

Tipo: view.

Uso: inventario de fontes carregadas, linhagem e disponibilidade por dominio.

Colunas:

- `schema_name`, `table_name`, `source_file`
- `dominio`: `candidatos`, `eleitorado`, `votacao`, `geografia`, `sociodemografia`, `pmb`
- `ano_referencia`
- `uf`
- `linhas_carregadas`
- `loaded_at_min`, `loaded_at_max`

Expansao atendida: painel administrativo de ingestao e auditoria de cargas.

#### `aux.vw_cobertura_dados_eleicao`

Tipo: view.

Uso: verificar rapidamente quais camadas existem para cada eleicao.

Grao:

- `eleicao_id`

Colunas:

- `ano`, `turno`, `cd_eleicao`, `ds_eleicao`
- flags: `tem_candidatos`, `tem_locais`, `tem_secoes`, `tem_eleitorado_perfil`, `tem_votacao`, `tem_apuracao`
- contagens: `candidatos`, `locais`, `secoes`, `perfis`, `linhas_votacao`, `votos`

Expansao atendida: onboarding de 2026, multiplos turnos e comparacao entre cargas incompletas.

#### `aux.vw_qualidade_resumo`

Tipo: view.

Uso: monitorar pendencias por entidade, regra e severidade.

Colunas:

- `entidade`, `regra`, `severidade`
- `ocorrencias`
- `primeira_ocorrencia`, `ultima_ocorrencia`
- `amostra_chave_natural`

Expansao atendida: governanca de dados e priorizacao de curadoria.

### Territorio unificado e recortes

#### `geo.vw_territorio_analitico`

Tipo: view.

Uso: expor em uma unica estrutura RAs do DF e municipios de recortes externos como PMB.

Grao:

- uma linha por territorio analitico.

Colunas:

- `tipo_territorio`: `RA` ou `MUNICIPIO`
- `territorio_id`: chave textual estavel, por exemplo `RA:RA-I` ou `MUN:5200258`
- `uf`, `codigo`, `nome`, `nome_normalizado`
- `recorte_codigo` quando aplicavel
- `latitude`, `longitude`, `geom`
- `area_km2`, `populacao`

Expansao atendida: mapas e comparativos DF x PMB sem misturar municipio com RA nas dimensoes de origem.

#### `dim.vw_recorte_territorial_expandido`

Tipo: view.

Uso: preparar novos recortes analiticos, como regioes de campanha, zonas prioritarias, bacias eleitorais ou agrupamentos customizados.

Colunas:

- `recorte_id`, `recorte_codigo`, `recorte_nome`, `recorte_tipo`
- `tipo_territorio`, `territorio_id`, `codigo`, `nome`
- `peso`, inicialmente `1.0` para recortes discretos

Expansao atendida: comparacao por agrupamentos definidos pelo usuario ou pela estrategia eleitoral.

#### `geo.mv_ra_vizinhas`

Tipo: materialized view.

Uso: analises espaciais de vizinhanca entre RAs.

Colunas:

- `ra_id`, `ra_codigo`, `ra_nome`
- `ra_vizinha_id`, `ra_vizinha_codigo`, `ra_vizinha_nome`
- `tipo_relacao`: `toca` ou `distancia`
- `distancia_km`

Regra: usar `st_touches`/`st_intersects`; para RAs que nao tocam, permitir matriz por distancia minima parametrizada na carga.

Expansao atendida: analise de contiguidade, spillover eleitoral e mapas de influencia.

### Eleitorado e segmentacao

#### `fato.mv_eleitorado_segmento_territorio`

Tipo: materialized view.

Uso: segmentacao flexivel por territorio e perfil, incluindo DF e PMB.

Grao:

- `tipo_territorio`
- `territorio_id`
- `eleicao_id`
- `dimensao`
- `codigo`

Colunas:

- `tipo_territorio`, `territorio_id`, `codigo_territorio`, `nome_territorio`
- `eleicao_id`, `ano`
- `dimensao`, `codigo`, `descricao`
- `qt_eleitores`
- `total_eleitores_territorio`
- `percentual`
- `ranking_no_recorte`

Expansao atendida: comparativos RA x municipio PMB, filtros por segmentos e exportacoes analiticas.

#### `fato.mv_eleitorado_metricas_territorio`

Tipo: materialized view.

Uso: KPIs de eleitorado prontos por territorio.

Colunas:

- chaves territoriais e de eleicao
- `total_eleitores`
- `total_biometria`, `pct_biometria`
- `total_deficiencia`, `pct_deficiencia`
- `total_nome_social`, `pct_nome_social`
- dominantes: `genero_dominante`, `faixa_etaria_dominante`, `escolaridade_dominante`, `raca_cor_dominante`

Expansao atendida: cards, rankings de segmentos, planejamento de comunicacao.

#### `fato.vw_sociodemografia_percentis_ra`

Tipo: view.

Uso: classificar RAs por renda, populacao, religiao, pets e raca/cor em quartis/decis.

Colunas:

- `ra_id`, `ra_codigo`, `ra_nome`
- `indicador_codigo`, `valor_num`, `percentual`
- `quartil_df`, `decil_df`, `ranking_df`

Expansao atendida: segmentacao socioeconomica, priorizacao de campanha e filtros de mapa.

### Votacao e comparativos historicos

#### `fato.mv_resultado_partido_nivel`

Tipo: materialized view.

Uso: desempenho por partido, independentemente de candidato nominal.

Grao:

- `eleicao_id`, `cargo_id`, `nivel`, territorio, `partido_id`

Colunas:

- chaves de eleicao, cargo, nivel e territorio
- `partido_id`, `nr_partido`, `sg_partido`
- `votos_nominais`
- `votos_legenda`
- `votos_total_partido`
- `percentual_validos`
- `ranking_partido_nivel`

Expansao atendida: analise partidaria, federacoes, coligacoes e comparacoes legislativas.

#### `fato.mv_resultado_coligacao_nivel`

Tipo: materialized view.

Uso: desempenho agregado por coligacao/federacao quando candidatos estiverem vinculados a candidaturas carregadas.

Colunas:

- `eleicao_id`, `cargo_id`, `nivel`, territorio
- `coligacao_id`, `nm_coligacao`
- `federacao_id`, `sg_federacao`
- `qt_votos`, `percentual_validos`, `ranking`

Expansao atendida: analise de blocos politicos e composicoes partidarias.

#### `fato.mv_votacao_comparativo_eleicao`

Tipo: materialized view.

Uso: comparar duas eleicoes ou dois turnos no mesmo nivel territorial.

Grao:

- `nivel`, territorio, `cargo_id`, `nr_votavel` ou agrupamento parametrizado.

Colunas:

- `eleicao_id_base`, `eleicao_id_comparada`
- `nivel`, chaves territoriais
- `nr_votavel`, `nm_votavel`
- `votos_base`, `pct_base`
- `votos_comparada`, `pct_comparada`
- `delta_votos`, `delta_pontos_percentuais`

Expansao atendida: 2022 x 2026, turno 1 x turno 2, evolucao territorial.

#### `fato.vw_secao_volatilidade`

Tipo: view futura, dependente de multiplas eleicoes carregadas.

Uso: identificar secoes/locais com maior mudanca de preferencia entre eleicoes.

Colunas:

- `secao_id`, `local_id`, `ra_id`
- `eleicao_id_base`, `eleicao_id_comparada`
- `lider_base`, `lider_comparada`
- `mudou_lider`
- `delta_margem_percentual`
- `indice_volatilidade`

Expansao atendida: analise de persuasao e mudanca territorial.

### Candidaturas e atores politicos

#### `dim.vw_candidato_enriquecido`

Tipo: view.

Uso: consulta unificada de candidatos com partido, cargo, coligacao, federacao e atributos de perfil.

Colunas:

- `eleicao_id`, `ano`, `turno`, `cd_eleicao`
- `cargo_id`, `cd_cargo`, `ds_cargo`
- `candidato_id`, `sq_candidato`, `nr_candidato`, `nm_urna_candidato`
- `partido_id`, `nr_partido`, `sg_partido`
- `federacao_id`, `sg_federacao`
- `coligacao_id`, `nm_coligacao`
- atributos de genero, instrucao, cor/raca, ocupacao, idade, reeleicao, bens

Expansao atendida: filtros de candidatos, perfis de candidatura e paineis de oferta eleitoral.

#### `fato.mv_candidatura_metricas`

Tipo: materialized view futura.

Uso: juntar resultado eleitoral, partido e perfil de candidato quando a votacao 2026 estiver carregada com `SQ_CANDIDATO`.

Colunas:

- chaves de candidato/eleicao/cargo/partido
- `total_votos`
- `ranking_cargo`
- `percentual_validos`
- `ras_com_voto`
- `locais_com_voto`
- `secoes_com_voto`
- `melhor_ra`, `pior_ra`

Expansao atendida: paginas de candidato e comparativos de desempenho.

### Busca, API e cache

#### `aux.vw_busca_global`

Tipo: view.

Uso: busca textual unificada para API/admin.

Colunas:

- `tipo_entidade`: `RA`, `LOCAL`, `SECAO`, `MUNICIPIO`, `CANDIDATO`, `PARTIDO`
- `entidade_id`
- `codigo`
- `titulo`
- `subtitulo`
- `texto_busca_normalizado`

Expansao atendida: autocomplete e navegacao rapida.

#### `aux.mv_api_payload_resumo`

Tipo: materialized view opcional.

Uso: cache de payloads JSON para endpoints muito acessados.

Colunas:

- `payload_tipo`
- `payload_chave`
- `eleicao_id`
- `gerado_em`
- `payload jsonb`

Expansao atendida: compatibilidade temporaria com frontend baseado em JSON estatico e reducao de custo de consultas complexas.

### Operacao e performance

#### `aux.vw_tamanho_tabelas`

Tipo: view.

Uso: monitoramento do crescimento de tabelas e materialized views.

Colunas:

- `schema_name`, `relation_name`, `relation_kind`
- `total_bytes`, `table_bytes`, `index_bytes`
- `pretty_total_size`

Expansao atendida: manutencao, tuning e decisao de particionamento.

#### `aux.vw_indices_uso`

Tipo: view.

Uso: identificar indices pouco usados ou ausentes apos carga completa.

Colunas:

- `schema_name`, `table_name`, `index_name`
- `idx_scan`, `idx_tup_read`, `idx_tup_fetch`
- `index_size`

Expansao atendida: tuning continuo depois que o painel estiver em uso.

## Regras de calculo

- Votos validos: soma de `qt_votos` onde `tipo_votavel in ('nominal', 'legenda')`.
- Votos brancos: soma de `qt_votos` onde `tipo_votavel = 'branco'`.
- Votos nulos: soma de `qt_votos` onde `tipo_votavel = 'nulo'`.
- Votos brutos: soma de todos os tipos.
- Percentual do votavel no nivel: `votos_votavel / votos_validos_nivel * 100`.
- Percentual do votavel no total: `votos_votavel / votos_validos_total_filtro * 100`.
- Margem de vitoria: `votos_lider - votos_segundo`.
- Margem percentual: `margem_votos / votos_validos_nivel * 100`.
- Tipo de regiao/local/secao:
  - `< 10`: `competitiva`
  - `>= 10 and < 20`: `disputa`
  - `>= 20 and < 30`: `neutra`
  - `>= 30`: `reduto`
- Pareto 80: ordenar por votos desc, calcular percentual acumulado e marcar `dentro_pareto80` ate incluir a linha que ultrapassa 80%.
- Intensidade de mapa para candidato: `votos_votavel / max(votos_votavel) over (particao do filtro)`.
- Categoria dominante de eleitorado: maior quantidade da dimensao, ignorando descricoes normalizadas como `NAO INFORMADO`, `NAO SE APLICA`, `INVALIDO` e vazias quando houver alternativa valida.

## Views e materializacoes propostas

### Camada base de votacao

#### `fato.vw_votacao_drilldown`

Status: existente.

Uso: consulta analitica detalhada no grao de secao/votavel.

Ajuste recomendado:

- Incluir IDs: `eleicao_id`, `uf_id`, `ra_id`, `local_id`, `secao_id`, `cargo_id`, `votavel_id`, `partido_id`.
- Incluir coordenadas de RA/local/secao quando disponiveis.
- Manter colunas textuais atuais para compatibilidade.

#### `fato.mv_votacao_nivel`

Tipo: materialized view.

Status: implementada em `sql/05_views/02_votacao_materializacoes.sql`.

Uso: base agregada para todos os paineis de resultado.

Grao:

- `eleicao_id`
- `cargo_id`
- `nivel` (`geral`, `ra`, `local`, `secao`)
- chaves territoriais aplicaveis
- `votavel_id`

Colunas:

- identificacao: `eleicao_id`, `ano`, `turno`, `cd_eleicao`, `cargo_id`, `cd_cargo`, `ds_cargo`, `nivel`
- territorio: `uf_id`, `uf`, `ra_id`, `ra_codigo`, `ra_nome`, `local_id`, `nr_zona`, `nr_local_votacao`, `local_votacao`, `secao_id`, `nr_secao`
- mapa: `latitude`, `longitude`, `geom`
- votavel: `votavel_id`, `nr_votavel`, `nm_votavel`, `tipo_votavel`, `partido_id`, `sg_partido`
- medidas: `qt_votos`, `votos_validos_nivel`, `votos_brutos_nivel`, `votos_brancos_nivel`, `votos_nulos_nivel`, `percentual_no_nivel`, `percentual_no_total`

Observacao: deve agregar a partir de `fato.votacao_candidato_secao`, nao da view de drill-down.

#### `fato.vw_votacao_resultado_nivel`

Tipo: view sobre `fato.mv_votacao_nivel`.

Status: implementada em `sql/05_views/03_votacao_views.sql`.

Uso: endpoint generico de resultado por nivel, com filtros por eleicao, cargo, nivel, RA, local, secao, votavel e tipo de votavel.

Contrato minimo: mesmas colunas da materializacao, com campos calculados de ranking quando barato no filtro corrente.

### TOP 5, lideranca e margem

#### `fato.mv_votacao_top5`

Tipo: materialized view.

Status: implementada em `sql/05_views/02_votacao_materializacoes.sql`.

Uso: mapas, side panels, tabela analitica, ranking resumido e base para calculos de lideranca/margem no front-end.

Grao:

- `eleicao_id`
- `cargo_id`
- `nivel`
- chaves territoriais aplicaveis
- `ranking_top5`

Colunas:

- chaves de eleicao/cargo/nivel/territorio/votavel
- `ranking_top5`
- `qt_votos`
- `votos_validos_nivel`
- `votos_brutos_nivel`
- `votos_brancos_nivel`
- `votos_nulos_nivel`
- `percentual_validos_nivel`
- `percentual_no_nivel`
- `percentual_no_total`
- `total_locais`
- `total_secoes`
- `total_zonas`

Regra: considerar apenas `tipo_votavel in ('nominal', 'legenda')` para o TOP 5.

Observacao: a visualizacao TOP 2, lider/segundo, margem em votos, margem percentual e classificacao de competitividade serao calculadas no front-end a partir de `ranking_top5 in (1, 2)`.

#### `fato.vw_votacao_top5`

Tipo: view sobre `fato.mv_votacao_top5`.

Status: implementada em `sql/05_views/03_votacao_views.sql`.

Uso: consumo direto do painel e filtros por votavel/ranking.

### Ranking, Pareto, vitorias e zeros

#### `fato.vw_votacao_rank_pareto`

Tipo: view.

Status: implementada em `sql/05_views/03_votacao_views.sql`.

Uso: rankings dinamicos por votavel e nivel.

Parametros esperados no consumo:

- `eleicao_id`
- `cargo_id`
- `votavel_id` ou `nr_votavel`
- `nivel`
- filtros opcionais de RA/local

Colunas:

- chaves de eleicao/cargo/nivel/territorio/votavel
- `label`
- `qt_votos`
- `percentual_no_nivel`
- `percentual_no_total`
- `ranking`
- `cum_pct`
- `dentro_pareto80`
- `latitude`
- `longitude`

Implementacao: window functions sobre `fato.mv_votacao_nivel`.

#### `fato.vw_vitorias_zeros_votavel`

Tipo: view.

Status: implementada em `sql/05_views/03_votacao_views.sql`.

Uso: aba de vitorias e zeros de paineis candidato-especificos.

Colunas:

- chaves de eleicao/cargo/nivel/territorio/votavel
- `nr_votavel`
- `nm_votavel`
- `qt_votos`
- `ranking_no_nivel`
- `venceu_nivel`
- `zerou_nivel`
- dados do segundo e terceiro colocados quando existirem
- `latitude`
- `longitude`

Regra:

- `venceu_nivel = ranking_no_nivel = 1`
- `zerou_nivel = qt_votos = 0` para territorios com votos validos no cargo

### Heatmap e barras

#### `fato.vw_votacao_heatmap_top5`

Tipo: view.

Status: implementada em `sql/05_views/03_votacao_views.sql`.

Uso: matriz candidato x RA.

Grao:

- `eleicao_id`
- `cargo_id`
- `ra_id`
- top 5 votaveis gerais do cargo

Colunas:

- `eleicao_id`, `cargo_id`, `ra_id`, `ra_codigo`, `ra_nome`
- `votavel_id`, `nr_votavel`, `nm_votavel`
- `qt_votos`
- `percentual_na_ra`
- `ranking_geral`
- `ranking_ra`

#### `fato.vw_votacao_stacked_ra_top5`

Tipo: view.

Status: implementada em `sql/05_views/03_votacao_views.sql`.

Uso: barras empilhadas por RA.

Contrato recomendado: formato longo, nao pivotado:

- `eleicao_id`, `cargo_id`, `ra_id`, `ra_codigo`, `ra_nome`
- `votavel_id`, `nr_votavel`, `nm_votavel`
- `qt_votos`
- `percentual_na_ra`
- `ranking_geral`

O frontend ou API pode pivotar para `cand_15`, `cand_43` etc. O banco deve evitar colunas dinamicas por candidato.

### Eleitorado DF

#### `fato.mv_eleitorado_perfil_nivel`

Tipo: materialized view.

Status: implementada em `sql/05_views/04_eleitorado_views.sql`.

Uso: agregacoes rapidas por RA/local/secao e dimensao demografica.

Grao:

- `eleicao_id`
- `nivel` (`ra`, `local`, `secao`)
- chaves territoriais aplicaveis
- `dimensao`
- `codigo`
- `descricao`

Colunas:

- chaves de eleicao/nivel/territorio
- `dimensao`: `genero`, `estado_civil`, `faixa_etaria`, `escolaridade`, `raca_cor`, `identidade_genero`, `quilombola`, `interprete_libras`
- `codigo`
- `descricao`
- `qt_eleitores`
- `qt_eleitores_biometria`
- `qt_eleitores_deficiencia`
- `qt_eleitores_nome_social`
- `total_eleitores_nivel`
- `percentual`

Observacao: materializar em formato longo permite atender donuts, barras, filtros e tabelas sem criar uma view por dimensao.

Observacao de cobertura: a fonte de perfil eleitoral 2026 fecha 2.253.132 eleitores, mas no nivel RA possui 36 RAs identificadas e 603 eleitores sem RA associada; `26 DE SETEMBRO` nao possui perfil territorial associado nessa fonte.

#### `fato.vw_eleitorado_perfil_ra`

Tipo: view sobre `fato.mv_eleitorado_perfil_nivel`.

Status: implementada em `sql/05_views/04_eleitorado_views.sql`.

Filtro fixo: `nivel = 'ra'`.

#### `fato.vw_eleitorado_perfil_local`

Tipo: view sobre `fato.mv_eleitorado_perfil_nivel`.

Status: implementada em `sql/05_views/04_eleitorado_views.sql`.

Filtro fixo: `nivel = 'local'`.

#### `fato.vw_eleitorado_perfil_secao`

Tipo: view sobre `fato.mv_eleitorado_perfil_nivel`.

Status: implementada em `sql/05_views/04_eleitorado_views.sql`.

Filtro fixo: `nivel = 'secao'`.

#### `fato.vw_eleitorado_dominante_nivel`

Tipo: view.

Status: implementada em `sql/05_views/04_eleitorado_views.sql`.

Uso: tabela analitica e resumo por territorio.

Colunas:

- chaves de eleicao/nivel/territorio
- `dimensao`
- `codigo_dominante`
- `descricao_dominante`
- `qt_eleitores_dominante`
- `percentual_dominante`
- `total_eleitores_nivel`

### Sociodemografia

#### `fato.vw_sociodemografia_ra_pivot`

Tipo: view.

Uso: tabela analitica por RA e cards de perfil.

Grao:

- `ra_id`
- `ano_referencia`

Colunas recomendadas:

- `ra_id`, `ra_codigo`, `ra_nome`, `ano_referencia`
- `populacao_total`
- `populacao_negra_total`
- `populacao_nao_negra_total`
- `populacao_negra_percentual`
- `religiao_catolicos_pct`
- `religiao_evangelicos_pct`
- `religiao_espiritas_pct`
- `religiao_sem_religiao_pct`
- `religiao_outras_crencas_pct`
- `renda_domiciliar_media`
- `renda_per_capita_media`
- `domicilios_com_pets_pct`
- `domicilios_com_pets_qtd`
- `perfil_resumido`

#### `fato.vw_ra_analitica`

Tipo: view.

Uso: tabela analitica principal por RA.

Regra de cobertura: deve retornar 37 linhas para o DF quando nao houver filtro que restrinja RAs.

Fonte:

- `fato.mv_votacao_top5` no nivel RA, quando houver votacao.
- `fato.mv_eleitorado_perfil_nivel` e `fato.vw_eleitorado_dominante_nivel`.
- `fato.vw_sociodemografia_ra_pivot`.
- `geo.ra_geometria`.

Colunas:

- RA, coordenadas, area, totais de eleitorado, biometria, deficiencia.
- TOP 5 e ranking quando houver votacao; lider, segundo e margem sao derivados no front-end.
- mulheres percentual, populacao negra percentual.
- faixa etaria dominante, escolaridade dominante, religiao dominante.
- renda e pets.

### Geografia e mapas

#### `geo.vw_ra_mapa`

Tipo: view.

Uso: mapas por RA, inclusive sem votacao carregada.

Regra de cobertura: deve retornar 37 RAs oficiais, incluindo `26 DE SETEMBRO` e `PONTE ALTA`.

Colunas:

- `ra_id`, `ra_codigo`, `ra_nome`, `area_km2`
- `latitude`, `longitude`
- `geom`
- `centroid_origem`
- `total_eleitores`
- `populacao_total`
- medidas eleitorais quando parametrizadas por join na API ou via view especifica de resultado

#### `geo.vw_local_votacao_mapa`

Tipo: view.

Uso: mapas de locais.

Colunas:

- `eleicao_id`, `uf_id`, `ra_id`, `ra_codigo`, `ra_nome`
- `local_id`, `nr_zona`, `nr_local_votacao`, `local_votacao`, `endereco`
- `latitude`, `longitude`, `geom`
- `is_principal`, `fonte_tre_confirmada`
- `total_secoes`
- `total_eleitores`

#### `geo.vw_secao_mapa`

Tipo: view.

Uso: drill-down em secao.

Colunas:

- `eleicao_id`, `uf_id`, `ra_id`, `local_id`, `secao_id`
- `nr_zona`, `nr_secao`, `nr_local_votacao`
- `latitude`, `longitude`, `geom`
- `qt_eleitores_aptos`
- flags de secao agregada/TRE/adicional

### PMB

#### `fato.mv_eleitorado_pmb_perfil_municipio`

Tipo: materialized view.

Uso: perfil do eleitor PMB por municipio em formato longo.

Colunas:

- `eleicao_id`, `recorte_id`, `recorte_codigo`
- `municipio_id`, `municipio_codigo_tse`, `municipio_codigo_ibge`, `municipio_nome`
- `latitude`, `longitude`, `geom`, `area_km2`, `pop_municipio`
- `dimensao`, `codigo`, `descricao`
- `qt_eleitores`, `total_eleitores_municipio`, `percentual`
- `qt_eleitores_biometria`, `qt_eleitores_deficiencia`, `qt_eleitores_nome_social`

#### `fato.vw_eleitorado_pmb_resumo`

Tipo: view.

Uso: KPIs PMB.

Colunas:

- `recorte_id`, `recorte_codigo`, `recorte_nome`
- `total_municipios`
- `total_eleitores`
- `total_biometria`
- `total_deficiencia`
- `total_nome_social`
- `populacao_total`
- maior municipio por eleitores e por populacao

## Indices recomendados

### Votacao

Criar antes de materializar as views de painel:

```sql
create index if not exists votacao_eleicao_cargo_votavel_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, votavel_id);

create index if not exists votacao_eleicao_cargo_ra_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, ra_id);

create index if not exists votacao_eleicao_cargo_local_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, local_id);

create index if not exists votacao_eleicao_cargo_secao_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, secao_id);

create index if not exists votacao_eleicao_cargo_tipo_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, tipo_votavel);

create index if not exists votacao_eleicao_cargo_nr_votavel_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, nr_votavel);
```

Indices unicos nas materialized views:

```sql
create unique index if not exists mv_votacao_nivel_uk
on fato.mv_votacao_nivel (
  eleicao_id, cargo_id, nivel,
  coalesce(ra_id, -1),
  coalesce(local_id, -1),
  coalesce(secao_id, -1),
  votavel_id
);

create unique index if not exists mv_votacao_top5_uk
on fato.mv_votacao_top5 (
  eleicao_id, cargo_id, nivel,
  coalesce(ra_id, -1),
  coalesce(local_id, -1),
  coalesce(secao_id, -1),
  ranking_top5
);
```

Observacao: esses indices unicos sao pre-requisito para `refresh materialized view concurrently`.

### Eleitorado DF

```sql
create index if not exists eleitorado_perfil_eleicao_ra_idx
on fato.eleitorado_perfil_secao (eleicao_id, ra_id);

create index if not exists eleitorado_perfil_eleicao_local_idx
on fato.eleitorado_perfil_secao (eleicao_id, local_id);

create index if not exists eleitorado_perfil_eleicao_secao_idx
on fato.eleitorado_perfil_secao (eleicao_id, secao_id);

create index if not exists eleitorado_perfil_eleicao_perfil_idx
on fato.eleitorado_perfil_secao (eleicao_id, perfil_id);
```

Materializacao:

```sql
create unique index if not exists mv_eleitorado_perfil_nivel_uk
on fato.mv_eleitorado_perfil_nivel (
  eleicao_id, nivel,
  coalesce(ra_id, -1),
  coalesce(local_id, -1),
  coalesce(secao_id, -1),
  dimensao,
  codigo
);
```

### Sociodemografia

```sql
create index if not exists sociodemografia_ra_ano_indicador_idx
on fato.sociodemografia_ra (ano_referencia, indicador_id);

create index if not exists indicador_sociodemografico_grupo_idx
on dim.indicador_sociodemografico (grupo, subgrupo, metrica);
```

### Geografia

Ja existem GiST para `geo.ra_geometria.geom`, `geo.ra_geometria.centroid_geom`, `dim.local_votacao.geom`, `dim.secao_eleitoral.geom` e `dim.municipio.geom`.

Adicionar para filtros comuns:

```sql
create index if not exists local_votacao_eleicao_ra_idx
on dim.local_votacao (eleicao_id, ra_id, nr_zona, nr_local_votacao);

create index if not exists secao_eleitoral_eleicao_local_idx
on dim.secao_eleitoral (eleicao_id, local_id, nr_zona, nr_secao);

create index if not exists secao_eleitoral_eleicao_ra_idx
on dim.secao_eleitoral (eleicao_id, ra_id, nr_zona, nr_secao);
```

### PMB

```sql
create index if not exists eleitorado_perfil_municipio_eleicao_recorte_idx
on fato.eleitorado_perfil_municipio (eleicao_id, recorte_id);

create index if not exists eleitorado_perfil_municipio_eleicao_municipio_idx
on fato.eleitorado_perfil_municipio (eleicao_id, municipio_id);
```

### Expansoes futuras

Indices para comparativos historicos e consultas por ator politico:

```sql
create index if not exists votacao_eleicao_cargo_partido_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, partido_id);

create index if not exists votacao_eleicao_cargo_candidato_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, candidato_id);

create index if not exists votacao_eleicao_cargo_zona_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, nr_zona);

create index if not exists candidato_eleicao_cargo_partido_idx
on dim.candidato (eleicao_id, cargo_id, partido_id);

create index if not exists candidato_eleicao_nr_candidato_idx
on dim.candidato (eleicao_id, nr_candidato);
```

Indices para busca textual. Requer decisao explicita de habilitar `pg_trgm`:

```sql
create extension if not exists pg_trgm;

create index if not exists ra_nome_normalizado_trgm_idx
on dim.regiao_administrativa using gin (ra_nome_normalizado gin_trgm_ops);

create index if not exists local_votacao_nome_normalizado_trgm_idx
on dim.local_votacao using gin (nome_normalizado gin_trgm_ops);

create index if not exists municipio_nome_normalizado_trgm_idx
on dim.municipio using gin (municipio_nome_normalizado gin_trgm_ops);

create index if not exists candidato_nm_urna_trgm_idx
on dim.candidato using gin (nm_urna_candidato gin_trgm_ops);
```

Indices para materialized views futuras:

```sql
create unique index if not exists mv_eleitorado_segmento_territorio_uk
on fato.mv_eleitorado_segmento_territorio (
  tipo_territorio,
  territorio_id,
  eleicao_id,
  dimensao,
  codigo
);

create unique index if not exists mv_resultado_partido_nivel_uk
on fato.mv_resultado_partido_nivel (
  eleicao_id,
  cargo_id,
  nivel,
  coalesce(ra_id, -1),
  coalesce(local_id, -1),
  coalesce(secao_id, -1),
  partido_id
);

create unique index if not exists mv_ra_vizinhas_uk
on geo.mv_ra_vizinhas (ra_id, ra_vizinha_id, tipo_relacao);
```

Indices de staging para reprocessamento e auditoria em arquivos grandes:

```sql
create index if not exists stg_perfil_df_zona_secao_idx
on stg.perfil_eleitor_secao_2026_df (sg_uf, nr_zona, nr_secao);

create index if not exists stg_perfil_go_municipio_zona_secao_idx
on stg.perfil_eleitor_secao_2026_go (cd_municipio, nr_zona, nr_secao);

create index if not exists stg_votacao_2022_zona_secao_cargo_idx
on stg.votacao_secao_2022_df (nr_zona, nr_secao, cd_cargo);
```

Observacao: indices em staging devem ser criados apos cargas grandes e podem ser omitidos em ambientes de carga descartavel. Para arquivos completos futuros de votacao 2026, avaliar particionamento por `eleicao_id` ou por `cargo_id` antes de criar muitos indices globais.

## Ordem de implementacao recomendada

1. Concluido: `sql/05_views/01_indices_consulta.sql` com os indices de fatos e dimensoes.
2. Concluido: `tests/sql/15_views_indices_test.sql` validando `pg_trgm` e 30 indices esperados.
3. Concluido: `sql/05_views/02_votacao_materializacoes.sql` com `fato.mv_votacao_nivel` e `fato.mv_votacao_top5`.
4. Concluido: `tests/sql/16_votacao_materializacoes_test.sql` validando materializacoes, indices e fechamentos.
5. Concluido: `sql/05_views/03_votacao_views.sql` com resultado, rank/Pareto, top5, heatmap, stacked e vitorias/zeros.
6. Concluido: `tests/sql/17_votacao_views_test.sql` validando views de votacao.
7. Concluido: `sql/05_views/04_eleitorado_views.sql` com materializacao longa de perfil e dominantes.
8. Concluido: `tests/sql/18_eleitorado_views_test.sql` validando views de eleitorado.
9. Criar `sql/05_views/05_sociodemografia_views.sql` com pivot de indicadores e RA analitica.
10. Criar `sql/05_views/06_geo_views.sql` com RA/local/secao para mapa.
11. Criar `sql/05_views/07_pmb_views.sql` com resumo e perfil PMB.
12. Criar `sql/05_views/08_expansao_views.sql` com catalogo, cobertura, territorio unificado, busca global e visoes operacionais.
13. Criar `sql/05_views/09_expansao_materializacoes.sql` com materializacoes opcionais de segmento, partido, comparativo historico e vizinhanca.
14. Criar testes SQL especificos para views restantes.
15. Rodar `analyze` apos cargas grandes e `explain analyze` nas consultas principais para ajustar indices com base no plano real.

## Testes minimos da Etapa 18

O teste SQL deve validar:

- todas as views/materialized views existem;
- materialized views possuem indices unicos quando forem usadas com refresh concorrente;
- `geo.vw_ra_mapa` retorna 37 RAs;
- `geo.vw_local_votacao_mapa` retorna 622 locais 2026;
- `geo.vw_secao_mapa` retorna 7.050 secoes 2026;
- `fato.mv_eleitorado_perfil_nivel` fecha `2.253.132` eleitores no nivel RA para 2026, com 36 RAs identificadas e grupo de RA nula;
- `fato.vw_eleitorado_pmb_resumo` fecha `759.538` eleitores;
- `fato.vw_sociodemografia_ra_pivot` retorna 37 RAs e populacao total `2.982.816`;
- views de votacao retornam os totais do piloto 2022 quando filtradas por `ano = 2022`, `cd_eleicao = 546`;
- nenhuma view duplica votos por join com dimensoes.

## Decisoes abertas

- Definir se a API fara pivot JSON no backend ou se algumas views devem gerar JSON diretamente com `jsonb_build_object`.
- Definir paleta/cor de candidato: hoje deve ficar fora do banco ou em tabela auxiliar futura.
- Definir se materialized views serao atualizadas por script manual, job agendado ou etapa do pipeline de carga.
- Definir politica para filtros textuais: `ILIKE`, `unaccent` direto ou coluna normalizada com indice especifico.
- Definir se a tabela analitica deve expor somente RA ou tambem local/secao com sociodemografia herdada da RA.
