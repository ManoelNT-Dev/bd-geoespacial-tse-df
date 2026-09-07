# Validacoes manuais

Este arquivo consolida consultas e comandos manuais usados para validar cada etapa.

## Etapa 0 - Preparacao do workspace

Comando de conferencia da estrutura:

```powershell
Get-ChildItem -Recurse -Depth 2
```

Criterios:

- Pastas `sql/`, `scripts/`, `tests/` e `docs/` existem.
- Arquivo `.env.example` existe.
- Arquivo `docs/diario_implementacao.md` existe.
- Arquivo `docs/validacoes_manuais.md` existe.
- Arquivos em `fontes/` nao foram alterados.

## Etapa 1 - Conteineres e persistencia

Validar sintaxe do Compose:

```powershell
docker compose config
```

Subir o banco:

```powershell
docker compose up -d
```

Conferir status:

```powershell
docker compose ps
```

Resultado esperado:

- Servico `db` usando imagem `postgis/postgis:16-3.5`.
- Conteiner `eleitoral_postgis`.
- Status `healthy`.
- Porta `5432` publicada.

Conferir disponibilidade do PostgreSQL:

```powershell
docker compose exec -T db pg_isready -U eleitoral_app -d eleitoral
```

Resultado esperado:

```text
/var/run/postgresql:5432 - accepting connections
```

Teste de persistencia:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "create table if not exists aux_teste_persistencia (id int primary key); insert into aux_teste_persistencia values (1) on conflict do nothing; select * from aux_teste_persistencia;"
docker compose down
docker compose up -d
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select * from aux_teste_persistencia;"
```

Resultado esperado:

```text
 id
----
  1
```

Observacao:

- No Windows, o Docker pode exigir acesso elevado ao daemon.
- O aviso `Error loading config file ... .docker\config.json: Access is denied` nao impediu a execucao neste ambiente.

## Etapa 2 - Extensoes e schemas

Aplicar script:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/00_extensions_schemas.sql
```

Executar teste automatizado simples:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/00_extensions_schemas_test.sql
```

Resultado esperado:

- Zero linhas retornadas pelo teste.

Consultas manuais:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select postgis_full_version();"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select schema_name from information_schema.schemata where schema_name in ('stg', 'dim', 'fato', 'geo', 'aux') order by schema_name;"
```

Resultado esperado:

- `postgis_full_version()` retorna a versao do PostGIS.
- A consulta de schemas retorna cinco linhas: `aux`, `dim`, `fato`, `geo`, `stg`.

## Etapa 3 - Staging dos arquivos pequenos e medios

Aplicar DDL:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/01_staging/01_staging_small_medium.sql
```

Executar carga:

```powershell
python scripts\load_staging.py
```

Executar teste automatizado simples:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/01_staging_small_medium_test.sql
```

Resultado obtido:

```text
 table_name | expected_count | actual_count
------------+----------------+--------------
(0 rows)
```

Contagens carregadas:

```text
stg.consulta_cand_2026_df: 661 linhas carregadas
stg.consulta_cand_complementar_2026_df: 661 linhas carregadas
stg.eleitorado_local_votacao_2026_df: 7050 linhas carregadas
stg.tre_locais_2026_df: 615 linhas carregadas
stg.tre_locais_secao_2026_df: 615 linhas carregadas
stg.tre_locais_secao_agrupadas_2026_df: 615 linhas carregadas
stg.tre_secoes_2026_df: 6962 linhas carregadas
stg.geo_ra_centroid_atualizado: 35 linhas carregadas
stg.ra_shapefile: 37 linhas carregadas
```

Observacao:

- As planilhas TRE incluem uma linha `Totais`; por isso os testes validam linhas uteis com `where not is_total`.
- O shapefile carregou 37 geometrias e todas passaram em `st_isvalid`.
- Alguns XLSX, o GeoJSON e registros do shapefile possuem caracteres de substituicao em strings acentuadas. A carga preserva os dados recebidos; a normalizacao/correcao de nomes deve ser tratada em dimensoes/geoespacial.

Consultas manuais executadas:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) as ras, count(geom) as geoms, count(*) filter (where not st_isvalid(geom)) as geoms_invalidas from stg.ra_shapefile;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) filter (where is_total) as totais, count(*) filter (where not is_total) as linhas_uteis from stg.tre_secoes_2026_df;"
```

Resultados obtidos:

```text
 ras | geoms | geoms_invalidas
-----+-------+-----------------
  37 |    37 |               0
```

```text
 totais | linhas_uteis
--------+--------------
      1 |         6961
```

## Etapa 4 - Staging dos arquivos grandes

Aplicar DDL:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/01_staging/02_staging_large.sql
```

Executar carga do perfil do eleitorado:

```powershell
python scripts\load_large_staging.py
```

Observacao:

- Esse comando carrega `perfil_eleitor_secao_2026_DF.csv`.
- Por padrao, ele nao carrega `votacao_secao_2022_DF.csv`.
- Para carregar votacao seria necessario usar `--include-votacao`, mas isso continua fora do escopo ate autorizacao explicita.

Executar teste automatizado simples:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/02_staging_large_test.sql
```

Resultado obtido:

```text
 check_name | expected_value | actual_value
------------+----------------+--------------
(0 rows)
```

Consultas manuais executadas:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) as linhas, count(distinct sg_uf || '-' || nr_zona || '-' || nr_secao) as secoes_distintas, sum(nullif(qt_eleitores, '')::integer) as eleitores from stg.perfil_eleitor_secao_2026_df;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) as linhas_votacao from stg.votacao_secao_2022_df;"
```

Resultados obtidos:

```text
 linhas  | secoes_distintas | eleitores
---------+------------------+-----------
 1233369 |             7042 |   2253132
```

```text
 linhas_votacao
----------------
              0
```

## Etapa 5 - Dimensao UF

Aplicar DDL/populacao:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/01_dim_uf.sql
```

Executar teste automatizado simples:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/03_dim_uf_test.sql
```

Resultado obtido:

```text
 check_name | expected_value | actual_value
------------+----------------+--------------
(0 rows)
```

Consulta manual executada:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select uf_id, sigla, nome, codigo_ibge from dim.uf order by sigla;"
```

Resultado obtido:

```text
 uf_id | sigla |       nome       | codigo_ibge
-------+-------+------------------+-------------
     1 | DF    | Distrito Federal |          53
```

## Etapa 6 - Dimensao eleicao

Aplicar DDL/populacao:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/02_dim_eleicao.sql
```

Executar teste automatizado simples:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/04_dim_eleicao_test.sql
```

Resultado obtido:

```text
 check_name | expected_value | actual_value
------------+----------------+--------------
(0 rows)
```

Consulta manual executada:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select eleicao_id, ano, turno, cd_eleicao, ds_eleicao, cd_tipo_eleicao, nm_tipo_eleicao, dt_eleicao, tp_abrangencia from dim.eleicao order by ano, turno, cd_eleicao;"
```

Resultado obtido:

```text
 eleicao_id | ano  | turno | cd_eleicao |           ds_eleicao           | cd_tipo_eleicao |  nm_tipo_eleicao  | dt_eleicao | tp_abrangencia
------------+------+-------+------------+--------------------------------+-----------------+-------------------+------------+----------------
          1 | 2026 |     1 |       6259 | Eleições Gerais Estaduais 2026 |               2 | ELEIÇÃO ORDINÁRIA | 2026-10-04 | ESTADUAL
```

## Etapa 7 - Geoespacial de RAs

Aplicar DDL/populacao:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/03_geoespacial/01_ra_geometria.sql
```

Executar teste automatizado simples:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/05_ra_geometria_test.sql
```

Resultado obtido:

```text
 check_name | expected_value | actual_value
------------+----------------+--------------
(0 rows)
```

Consultas manuais executadas:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select centroid_origem, count(*) from geo.ra_geometria group by centroid_origem order by centroid_origem;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select ra.ra_codigo, ra.ra_nome, g.centroid_origem, g.centroid_lon, g.centroid_lat from dim.regiao_administrativa ra join geo.ra_geometria g on g.ra_id = ra.ra_id where g.centroid_origem = 'calculado_shapefile' order by ra.ra_codigo;"
```

Resultados obtidos:

```text
   centroid_origem   | count
---------------------+-------
 calculado_shapefile |     3
 geojson             |    34
```

```text
 ra_codigo |    ra_nome     |   centroid_origem   | centroid_lon | centroid_lat
-----------+----------------+---------------------+--------------+--------------
 RA-XXIII  | VARJÃO         | calculado_shapefile | -47.87858550 | -15.71048432
 RA-XXXVI  | 26 DE SETEMBRO | calculado_shapefile | -48.02582803 | -15.76951826
 XXXVII    | PONTE ALTA     | calculado_shapefile | -48.07296069 | -15.97097450
```

Observacao:

- O GeoJSON tinha 35 centroides, mas o ponto de `RA-XXIII / VARJÃO` caiu fora do poligono. A carga final usa `st_pointonsurface` para essa RA e para as duas RAs ausentes no GeoJSON.

## Etapa 8 - Dimensoes eleitorais basicas

Aplicar DDL/populacao:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/03_dimensoes_eleitorais_basicas.sql
```

Executar teste automatizado simples:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/06_dimensoes_eleitorais_basicas_test.sql
```

Resultado obtido:

```text
 check_name | expected_value | actual_value
------------+----------------+--------------
(0 rows)
```

Consultas manuais executadas:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select cd_cargo, ds_cargo from dim.cargo_eleitoral order by cd_cargo;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) as zonas from dim.zona_eleitoral; select count(*) as partidos from dim.partido_politico; select count(*) as federacoes from dim.federacao; select count(*) as coligacoes from dim.coligacao;"
```

Resultados obtidos:

```text
 cd_cargo |      ds_cargo
----------+--------------------
        3 | GOVERNADOR
        4 | VICE-GOVERNADOR
        5 | SENADOR
        6 | DEPUTADO FEDERAL
        8 | DEPUTADO DISTRITAL
        9 | 1º SUPLENTE
       10 | 2º SUPLENTE
```

```text
zonas: 19
partidos: 29
federacoes: 5
coligacoes: 62
```

Observacao:

- `NR_FEDERACAO = -1 / #NULO` foi tratado como ausencia de federacao e nao foi inserido em `dim.federacao`.
