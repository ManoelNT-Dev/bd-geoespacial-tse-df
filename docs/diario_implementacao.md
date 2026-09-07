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
