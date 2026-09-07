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
