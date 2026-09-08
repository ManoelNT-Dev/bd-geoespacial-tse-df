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
- A opcao `--include-votacao` nao deve ser usada para carga completa de 2022; o arquivo 2022 fica restrito a piloto/modelagem.

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

## Etapa 9 - Dimensao local de votacao

Aplicar DDL/populacao:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/04_dim_local_votacao.sql
```

Executar teste automatizado simples:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/07_dim_local_votacao_test.sql
```

Resultado obtido:

```text
 check_name | expected_value | actual_value
------------+----------------+--------------
(0 rows)
```

Consultas manuais executadas:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) as locais, count(*) filter (where is_principal) as principais_tre, count(*) filter (where not is_principal) as adicionais_checar, count(distinct nr_local_votacao) as numeros_local, count(*) filter (where geom is null) as locais_sem_geom, count(*) filter (where geom is not null and ra_id is null) as locais_com_geom_sem_ra from dim.local_votacao;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select is_principal, fonte_tre_confirmada, source_priority, count(*) from dim.local_votacao group by is_principal, fonte_tre_confirmada, source_priority order by is_principal desc, source_priority;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select regra, severidade, count(*) from aux.qualidade_dado where entidade = 'local_votacao' group by regra, severidade order by regra;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select coalesce(ra.ra_nome, 'SEM RA') as ra_nome, count(*) as locais from dim.local_votacao lv left join dim.regiao_administrativa ra on ra.ra_id = lv.ra_id group by coalesce(ra.ra_nome, 'SEM RA') order by locais desc, ra_nome limit 12;"
```

Resultados obtidos:

```text
 locais | principais_tre | adicionais_checar | numeros_local | locais_sem_geom | locais_com_geom_sem_ra
--------+----------------+-------------------+---------------+-----------------+------------------------
    622 |            614 |                 8 |           108 |               3 |                      0
```

```text
 is_principal | fonte_tre_confirmada |               source_priority               | count
--------------+----------------------+---------------------------------------------+-------
 t            | t                    | tre_locais_2026_confirmado                  |   614
 f            | f                    | csv_eleitorado_local_votacao_2026_adicional |     8
```

```text
                 regra                 | severidade | count
---------------------------------------+------------+-------
 local_csv_sem_tre                     | aviso      |     8
 local_sem_coordenada                  | erro       |     3
 nr_local_votacao_reutilizado_em_zonas | info       |    90
```

```text
     ra_nome      | locais
------------------+--------
 CEILANDIA        |     77
 PLANO PILOTO     |     58
 TAGUATINGA       |     57
 PLANALTINA       |     44
 SAMAMBAIA        |     36
 GAMA             |     31
 BRAZLANDIA       |     30
 GUARA            |     28
 SOBRADINHO       |     26
 SANTA MARIA      |     23
 RECANTO DAS EMAS |     21
 PARANOA          |     20
```

Observacoes:

- `NR_LOCAL_VOTACAO` nao e chave fisica unica: 90 numeros aparecem em mais de uma zona com endereco/coordenada diferente.
- A chave natural de `dim.local_votacao` ficou como `eleicao_id + uf_id + nr_zona + nr_local_votacao`.
- O CSV oficial contem 622 pares `zona + local`; a planilha `Locais_TRE_DF_2026.xlsx` contem 614, todos presentes no CSV e marcados como `is_principal = true`.
- Os 8 pares adicionais do CSV foram mantidos com `is_principal = false` e registrados como aviso de qualidade.
- Tres locais usam coordenada sentinela `-1/-1`; por isso ficaram sem `geom` e sem RA, com pendencia registrada em `aux.qualidade_dado`.

## Etapa 10 - Dimensao secao eleitoral

Aplicar DDL/populacao:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/05_dim_secao_eleitoral.sql
```

Executar teste automatizado simples:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/08_dim_secao_eleitoral_test.sql
```

Resultado obtido:

```text
 check_name | expected_value | actual_value
------------+----------------+--------------
(0 rows)
```

Consultas manuais executadas:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) as secoes_csv, count(*) filter (where is_secao_principal_tre) as oficiais_tre, count(*) filter (where fonte_tre_confirmada) as tre_expandida, count(*) filter (where ds_tipo_secao_agregada = 'Agregada') as agregadas, count(*) filter (where is_adicional_csv) as adicionais_csv, count(*) filter (where geom is null) as secoes_sem_geom from dim.secao_eleitoral;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select regra, severidade, count(*) from aux.qualidade_dado where entidade = 'secao_eleitoral' group by regra, severidade order by regra;"
```

Resultados obtidos:

```text
 secoes_csv | oficiais_tre | tre_expandida | agregadas | adicionais_csv | secoes_sem_geom
------------+--------------+---------------+-----------+----------------+-----------------
       7050 |         6961 |          7042 |        81 |              8 |               4
```

```text
           regra           | severidade | count
---------------------------+------------+-------
 divergencia_aptos_tre_csv | aviso      |   106
 secao_csv_sem_perfil      | aviso      |     8
 secao_csv_sem_tre         | aviso      |     8
```

Observacoes:

- A planilha TRE possui 6.961 linhas oficiais; 78 linhas trazem secoes agregadas entre parenteses.
- Expandindo os parenteses, a planilha TRE representa 7.042 secoes, o mesmo total de secoes distintas do perfil do eleitorado.
- O CSV `eleitorado_local_votacao_2026_DF.csv` possui 7.050 secoes: 6.969 principais e 81 agregadas.
- As 81 agregadas referenciam secoes principais existentes e herdaram o local da secao principal.
- As 8 secoes adicionais existem apenas no CSV oficial de eleitorado/local e foram preservadas com `is_adicional_csv = true`.

## Etapa 11 - Dimensao candidato

Aplicar DDL/populacao:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/06_dim_candidato.sql
```

Executar teste automatizado simples:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/09_dim_candidato_test.sql
```

Resultado obtido:

```text
 check_name | expected_value | actual_value
------------+----------------+--------------
(0 rows)
```

Consultas manuais executadas:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select ce.ds_cargo, count(*) as candidatos from dim.candidato c join dim.cargo_eleitoral ce on ce.cargo_id = c.cargo_id group by ce.ds_cargo order by candidatos desc, ce.ds_cargo;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) as candidatos, count(*) filter (where federacao_id is not null) as com_federacao, count(*) filter (where coligacao_id is not null) as com_coligacao, count(*) filter (where st_quilombola) as quilombolas, count(*) filter (where st_declarar_bens) as declararam_bens from dim.candidato; select regra, severidade, count(*) from aux.qualidade_dado where entidade = 'candidato' group by regra, severidade order by regra;"
```

Resultados obtidos:

```text
      ds_cargo      | candidatos
--------------------+------------
 DEPUTADO DISTRITAL |        431
 DEPUTADO FEDERAL   |        168
 2o SUPLENTE        |         14
 1o SUPLENTE        |         13
 SENADOR            |         13
 GOVERNADOR         |         11
 VICE-GOVERNADOR    |         11
```

```text
 candidatos | com_federacao | com_coligacao | quilombolas | declararam_bens
------------+---------------+---------------+-------------+-----------------
        661 |           184 |           661 |           2 |             458
```

```text
 regra | severidade | count
-------+------------+-------
(0 rows)
```

Observacoes:

- CPF nao foi armazenado aberto; `dim.candidato.cpf_hash` usa `md5(nr_cpf_candidato)`.
- `st_reeleicao = #NE` foi tratado como `null`.

## Etapa 12 - Perfil do eleitor e fato eleitorado por perfil/secao

Aplicar DDL/populacao:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/07_dim_perfil_eleitor.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/04_fatos/01_fato_eleitorado_perfil_secao.sql
```

Executar teste automatizado simples:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/10_perfil_eleitor_test.sql
```

Resultado obtido:

```text
 check_name | expected_value | actual_value
------------+----------------+--------------
(0 rows)
```

Consultas manuais executadas:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) as perfis from dim.perfil_eleitor; select count(*) as linhas_fato, sum(source_row_count) as linhas_origem, count(distinct secao_id) as secoes, sum(qt_eleitores) as eleitores, sum(qt_eleitores_biometria) as biometria, sum(qt_eleitores_deficiencia) as deficiencia, sum(qt_eleitores_nome_social) as nome_social from fato.eleitorado_perfil_secao; select regra, severidade, count(*) from aux.qualidade_dado where entidade = 'eleitorado_perfil_secao' group by regra, severidade order by regra;"
```

Resultados obtidos:

```text
 perfis
--------
   8468
```

```text
 linhas_fato | linhas_origem | secoes | eleitores | biometria | deficiencia | nome_social
-------------+---------------+--------+-----------+-----------+-------------+-------------
     1219951 |       1233369 |   7042 |   2253132 |   2126894 |       24832 |         723
```

```text
 regra | severidade | count
-------+------------+-------
(0 rows)
```

Observacoes:

- A fato foi agregada por `eleicao_id + secao_id + perfil_id`, porque a fonte possui duplicidades naturais em `secao + perfil`.
- `source_row_count` preserva a contagem das 1.233.369 linhas brutas de origem.

## Etapa 13 - Estrutura de votacao de 2022

Aplicar DDL:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/04_fatos/02_estrutura_votacao_2022.sql
```

Executar teste automatizado simples:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/11_estrutura_votacao_2022_test.sql
```

Resultado obtido:

```text
 check_name | expected_value | actual_value
------------+----------------+--------------
(0 rows)
```

Consulta manual executada:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select (select count(*) from stg.votacao_secao_2022_df) as stg_votacao, (select count(*) from dim.votavel) as votaveis, (select count(*) from fato.votacao_candidato_secao) as fato_votacao, (select count(*) from fato.apuracao_secao) as apuracao, (select count(*) from fato.vw_votacao_drilldown) as view_drilldown;"
```

Resultado obtido:

```text
 stg_votacao | votaveis | fato_votacao | apuracao | view_drilldown
-------------+----------+--------------+----------+----------------
           0 |        0 |            0 |        0 |              0
```

Observacao:

- Nenhuma carga de `votacao_secao_2022_DF.csv` foi executada nesta etapa.

## Etapa 14 - Carga piloto de votacao 2022

Carregar amostra piloto da ZE 20:

```powershell
python scripts\load_votacao_piloto.py
```

Resultado obtido:

```text
stg.votacao_secao_2022_df: 44464 linhas carregadas para NR_ZONA=20
```

Aplicar populacao dimensional/fato da amostra:

```powershell
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/04_fatos/03_carga_piloto_votacao_2022.sql
```

Resultado obtido:

```text
INSERT 0 1
INSERT 0 18
INSERT 0 219
INSERT 0 838
INSERT 0 44464
INSERT 0 876
```

Executar teste automatizado simples:

```powershell
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /tests/sql/12_carga_piloto_votacao_2022_test.sql
```

Resultado obtido:

```text
 check_name | expected_value | actual_value
------------+----------------+--------------
(0 rows)
```

Consulta manual executada:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select tipo_votavel, count(*) as linhas, sum(qt_votos) as votos from fato.votacao_candidato_secao vc join dim.eleicao e on e.eleicao_id = vc.eleicao_id where e.ano = 2022 and e.cd_eleicao = 546 group by tipo_votavel order by tipo_votavel;"
```

Resultado obtido:

```text
 tipo_votavel | linhas | votos
--------------+--------+--------
 branco       |    876 |  16142
 legenda      |   2869 |   4604
 nominal      |  39844 | 228436
 nulo         |    875 |  11822
```

Validacao completa executada:

```powershell
Get-ChildItem tests\sql\*.sql | Sort-Object Name | ForEach-Object { docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f ("/tests/sql/" + $_.Name) }
```

Resultado: todos os testes SQL das Etapas 2 a 14 retornaram zero divergencias.

Observacoes:

- A carga piloto usa apenas `NR_ZONA = 20`.
- `tests/sql/02_staging_large_test.sql`, `tests/sql/04_dim_eleicao_test.sql`, `tests/sql/07_dim_local_votacao_test.sql`, `tests/sql/08_dim_secao_eleitoral_test.sql` e `tests/sql/11_estrutura_votacao_2022_test.sql` foram ajustados para refletir o novo estado com piloto 2022 e manter as contagens oficiais de 2026 isoladas.
- A carga completa de `votacao_secao_2022_DF.csv` nao ocorrera. O arquivo 2022 permanece apenas como amostra piloto/modelagem; a carga completa futura sera dos dados de votacao 2026 na mesma estrutura.
