# Diario de implementacao

Este arquivo registra a execucao de cada etapa do planejamento.

## Etapa 0 - Preparacao do workspace

- Data: 2026-09-07
- Scripts executados: nenhum script de banco; criacao da estrutura de diretorios e arquivos base.
- Resultado: estrutura inicial criada para SQL, scripts, testes e documentacao.
- Consultas manuais: nao aplicavel nesta etapa.
- Divergencias encontradas: nenhuma.
- Decisao: avancar para a Etapa 1, conteineres e persistencia.

## Etapa 1 - Conteineres e persistencia

- Data: 2026-09-07
- Scripts executados: `docker compose config`, `docker compose up -d`, `docker compose ps`, `pg_isready`, teste SQL de persistencia, `docker compose down`, `docker compose up -d`.
- Resultado: conteiner `eleitoral_postgis` criado com imagem `postgis/postgis:16-3.5`, porta `5432`, volume nomeado `code_teste_r2_postgres_data` e montagem readonly de `fontes/`.
- Consultas manuais: criada tabela `aux_teste_persistencia`, inserido `id = 1`, confirmado o registro antes e depois do reinicio do conteiner.
- Divergencias encontradas: o Docker no Windows exigiu acesso elevado ao daemon; tambem emitiu aviso de permissao ao ler `C:\Users\mnt50\.docker\config.json`, mas os comandos executaram com sucesso.
- Decisao: Etapa 1 validada; avancar para a Etapa 2, extensoes e schemas.

## Etapa 2 - Extensoes e schemas

- Data: 2026-09-07
- Scripts executados: `docker compose config`, `docker compose up -d`, `docker compose ps`, `pg_isready`, `sql/00_extensions_schemas.sql` e `tests/sql/00_extensions_schemas_test.sql`.
- Resultado: `docker-compose.yml` atualizado para montar `./sql` em `/sql` e `./tests` em `/tests`, ambos somente leitura; extensao `unaccent` criada; extensao `postgis` confirmada; schemas `stg`, `dim`, `fato`, `geo` e `aux` criados.
- Consultas manuais: `postgis_full_version()` retornou PostGIS `3.5.2`; consulta em `information_schema.schemata` retornou `aux`, `dim`, `fato`, `geo` e `stg`; teste SQL retornou zero linhas.
- Divergencias encontradas: `postgis` ja existia no banco e foi mantida por `create extension if not exists`; Docker continuou exigindo acesso elevado ao daemon no Windows.
- Decisao: Etapa 2 validada; avancar para a Etapa 3, staging dos arquivos pequenos e medios.

## Etapa 3 - Staging dos arquivos pequenos e medios

- Data: 2026-09-07
- Scripts executados: `sql/01_staging/01_staging_small_medium.sql`, `scripts/load_staging.py` e `tests/sql/01_staging_small_medium_test.sql`.
- Resultado: criadas e carregadas nove tabelas de staging em `stg`: candidatos 2026, candidatos complementar 2026, eleitorado por local/secao 2026, quatro planilhas TRE, centroides GeoJSON e shapefile de RAs.
- Consultas manuais: teste de contagens retornou zero linhas; `stg.ra_shapefile` ficou com 37 registros, 37 geometrias preenchidas e zero geometrias invalidas; `stg.tre_secoes_2026_df` ficou com 1 linha de totais e 6.961 linhas uteis.
- Divergencias encontradas: os XLSX e o GeoJSON contem caracteres de substituicao em algumas strings acentuadas; o shapefile tambem tem inconsistencias de encoding e foi lido com `utf-8` e `encodingErrors="replace"` para preservar a carga completa. Correcao fina de nomes deve ocorrer na etapa geoespacial/dimensao RA.
- Decisao: Etapa 3 validada; avancar para a Etapa 4, staging dos arquivos grandes, mantendo a carga completa de `votacao_secao_2022_DF.csv` fora do escopo ate autorizacao explicita.

## Etapa 4 - Staging dos arquivos grandes

- Data: 2026-09-07
- Scripts executados: `sql/01_staging/02_staging_large.sql`, `scripts/load_large_staging.py` e `tests/sql/02_staging_large_test.sql`.
- Resultado: criadas as tabelas `stg.perfil_eleitor_secao_2026_df` e `stg.votacao_secao_2022_df`; carregado somente `perfil_eleitor_secao_2026_DF.csv`; a tabela de votacao foi criada, mas permaneceu vazia.
- Consultas manuais: teste de contagens retornou zero linhas; perfil carregou 1.233.369 linhas, 7.042 secoes distintas e soma de `qt_eleitores` igual a 2.253.132; `stg.votacao_secao_2022_df` retornou zero linhas.
- Divergencias encontradas: nenhuma na carga do perfil; a carga completa de `votacao_secao_2022_DF.csv` segue bloqueada por decisao de escopo/autorizacao futura.
- Decisao: Etapa 4 validada; avancar para a Etapa 5, dimensao UF.

## Etapa 5 - Dimensao UF

- Data: 2026-09-07
- Scripts executados: `sql/02_dimensoes/01_dim_uf.sql` e `tests/sql/03_dim_uf_test.sql`.
- Resultado: tabela `dim.uf` criada e populada de forma idempotente com `DF / Distrito Federal / 53`.
- Consultas manuais: teste SQL retornou zero linhas; consulta em `dim.uf` retornou uma linha com `uf_id = 1`, `sigla = DF`, `nome = Distrito Federal`, `codigo_ibge = 53`.
- Divergencias encontradas: nenhuma.
- Decisao: Etapa 5 validada; avancar para a Etapa 6, dimensao eleicao.

## Etapa 6 - Dimensao eleicao

- Data: 2026-09-07
- Scripts executados: `sql/02_dimensoes/02_dim_eleicao.sql` e `tests/sql/04_dim_eleicao_test.sql`.
- Resultado: tabela `dim.eleicao` criada e populada de forma idempotente com a eleicao 2026 derivada de `stg.consulta_cand_2026_df`.
- Consultas manuais: teste SQL retornou zero linhas; consulta em `dim.eleicao` retornou `ano = 2026`, `turno = 1`, `cd_eleicao = 6259`, `ds_eleicao = Eleições Gerais Estaduais 2026`, `cd_tipo_eleicao = 2`, `nm_tipo_eleicao = ELEIÇÃO ORDINÁRIA`, `dt_eleicao = 2026-10-04`, `tp_abrangencia = ESTADUAL`.
- Divergencias encontradas: `stg.eleitorado_local_votacao_2026_df.ds_eleicao` traz `1º Turno`, por isso a dimensao usou `stg.consulta_cand_2026_df` como fonte principal para preservar a descricao oficial completa da eleicao.
- Decisao: Etapa 6 validada; avancar para a Etapa 7, geoespacial de RAs.

## Etapa 7 - Geoespacial de RAs

- Data: 2026-09-07
- Scripts executados: `sql/03_geoespacial/01_ra_geometria.sql` e `tests/sql/05_ra_geometria_test.sql`.
- Resultado: criadas e populadas `dim.regiao_administrativa` e `geo.ra_geometria`; 37 RAs carregadas com geometria UTM 31983 e geometria 4326.
- Consultas manuais: teste SQL retornou zero linhas; origens de centroide ficaram em 34 `geojson` e 3 `calculado_shapefile`; centroides calculados para `RA-XXIII / VARJÃO`, `RA-XXXVI / 26 DE SETEMBRO` e `XXXVII / PONTE ALTA`.
- Divergencias encontradas: o centroide do GeoJSON para `RA-XXIII / VARJÃO` ficou fora do poligono; a regra foi ajustada para usar ponto do GeoJSON somente quando `st_covers(geom, centroid_geom)` for verdadeiro, calculando `st_pointonsurface` nos demais casos.
- Decisao: Etapa 7 validada; avancar para a Etapa 8, dimensoes eleitorais basicas.

## Etapa 8 - Dimensoes eleitorais basicas

- Data: 2026-09-07
- Scripts executados: `sql/02_dimensoes/03_dimensoes_eleitorais_basicas.sql` e `tests/sql/06_dimensoes_eleitorais_basicas_test.sql`.
- Resultado: criadas e populadas `dim.zona_eleitoral`, `dim.cargo_eleitoral`, `dim.partido_politico`, `dim.federacao` e `dim.coligacao`.
- Consultas manuais: teste SQL retornou zero linhas; foram carregadas 19 zonas, 7 cargos, 29 partidos, 5 federacoes reais e 62 coligacoes.
- Divergencias encontradas: `NR_FEDERACAO = -1 / #NULO` aparece na staging, mas foi excluido de `dim.federacao` por representar ausencia de federacao, nao uma federacao real.
- Decisao: Etapa 8 validada; avancar para a Etapa 9, dimensao local de votacao.

## Modelo de registro para proximas etapas

```md
## Etapa X - Nome

- Data:
- Scripts executados:
- Resultado:
- Consultas manuais:
- Divergencias encontradas:
- Decisao:
```
