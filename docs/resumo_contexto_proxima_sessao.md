# Resumo de contexto para proxima sessao

Data de encerramento: 2026-09-07
Workspace: `C:\Users\mnt50\DEV\code_teste_r2`

## Objetivo

Construir um banco PostgreSQL/PostGIS para inteligencia eleitoral no DF, com camadas `stg`, `dim`, `fato`, `geo` e `aux`, capaz de suportar consultas e cruzamentos por UF, regiao administrativa, local de votacao, zona, secao, cargo, candidato/votavel e perfil do eleitorado.

## Arquitetura Atual

- Banco em Docker Compose com servico unico `db`.
- Imagem: `postgis/postgis:16-3.5`.
- Container: `eleitoral_postgis`.
- Banco: `eleitoral`.
- Usuario: `eleitoral_app`.
- Porta local: `5432`.
- Volume persistente: `code_teste_r2_postgres_data`.
- Montagens readonly:
  - `./fontes:/fontes:ro`
  - `./sql:/sql:ro`
  - `./tests:/tests:ro`
- Schemas criados no banco: `stg`, `dim`, `fato`, `geo`, `aux`.
- Extensoes ativas: `postgis` e `unaccent`.
- PostGIS validado: `3.5.2`.

## Fontes de Dados

Diretorio de fontes: `fontes/`.

- `consulta_cand_2026_DF.csv`: 661 linhas, 50 colunas, `;`, Latin-1.
- `consulta_cand_complementar_2026_DF.csv`: 661 linhas, 49 colunas, `;`, Latin-1.
- `eleitorado_local_votacao_2026_DF.csv`: 7.050 linhas, 41 colunas, `;`, Latin-1.
- `perfil_eleitor_secao_2026_DF.csv`: 1.233.369 linhas, ainda nao carregado.
- `votacao_secao_2022_DF.csv`: 1.238.611 linhas, ainda nao carregado; carga completa continua fora do escopo ate autorizacao explicita.
- Planilhas TRE 2026 em `.xlsx`: locais, locais/secao, locais/secao agrupadas e secoes.
- `geo_ra_centroid_atualizado.json`: 35 centroides em EPSG:4326.
- `fontes/shapefile_ras/regioes_administrativas.*`: 37 poligonos de RAs, SIRGAS 2000 / UTM Zone 23S, carregado no staging como SRID 31983.

Pontos de negocio ja identificados:

- Faltam centroides no GeoJSON para `RA-XXXVI / 26 DE SETEMBRO` e `RA-XXXVII / PONTE ALTA`; calcular depois a partir dos poligonos com `st_pointonsurface`.
- `SQ_CANDIDATO = -1` representa branco/nulo na votacao.
- `SQ_CANDIDATO = -3` representa voto de legenda.
- Votacao 2022 deve permitir granularidade `UF -> RA -> Local -> Secao -> Cargo -> Votavel`.

## Estado do Codigo

Arquivos principais:

- `.env.example`
- `.gitignore`
- `docker-compose.yml`
- `sql/00_extensions_schemas.sql`
- `sql/01_staging/01_staging_small_medium.sql`
- `scripts/load_staging.py`
- `tests/sql/00_extensions_schemas_test.sql`
- `tests/sql/01_staging_small_medium_test.sql`
- `docs/modelagem_banco_eleitoral_postgis.md`
- `docs/planejamento_implementacao_banco_eleitoral.md`
- `docs/diario_implementacao.md`
- `docs/validacoes_manuais.md`
- `docs/resumo_contexto_proxima_sessao.md`

Pastas prontas para proximas etapas:

- `sql/02_dimensoes/`
- `sql/03_geoespacial/`
- `sql/04_fatos/`
- `sql/05_views/`
- `sql/99_qualidade/`
- `tests/expected/`

## Etapas Concluidas

Etapa 0 - Preparacao do workspace:

- Estrutura inicial de pastas criada.
- READMEs de apoio criados.
- `.env.example` criado.
- Nenhuma fonte em `fontes/` alterada.

Etapa 1 - Conteineres e persistencia:

- `docker-compose.yml` criado.
- Container `eleitoral_postgis` subiu com PostGIS.
- `pg_isready` validado.
- Persistencia validada com tabela temporaria/de validacao `aux_teste_persistencia`, contendo `id = 1`, preservada apos `docker compose down` e novo `docker compose up -d`.

Etapa 2 - Extensoes e schemas:

- Criado e executado `sql/00_extensions_schemas.sql`.
- Criado e executado `tests/sql/00_extensions_schemas_test.sql`.
- `postgis` confirmada.
- `unaccent` criada.
- Schemas `stg`, `dim`, `fato`, `geo`, `aux` criados.
- Teste SQL retornou zero linhas.

Etapa 3 - Staging dos arquivos pequenos e medios:

- Criado e executado `sql/01_staging/01_staging_small_medium.sql`.
- Criado e executado `scripts/load_staging.py`.
- Criado e executado `tests/sql/01_staging_small_medium_test.sql`.
- Tabelas carregadas em `stg`:
  - `consulta_cand_2026_df`: 661 linhas.
  - `consulta_cand_complementar_2026_df`: 661 linhas.
  - `eleitorado_local_votacao_2026_df`: 7.050 linhas.
  - `tre_locais_2026_df`: 615 linhas brutas, 614 uteis, 1 linha `Totais`.
  - `tre_locais_secao_2026_df`: 615 linhas brutas, 614 uteis, 1 linha `Totais`.
  - `tre_locais_secao_agrupadas_2026_df`: 615 linhas brutas, 614 uteis, 1 linha `Totais`.
  - `tre_secoes_2026_df`: 6.962 linhas brutas, 6.961 uteis, 1 linha `Totais`.
  - `geo_ra_centroid_atualizado`: 35 linhas.
  - `ra_shapefile`: 37 linhas.
- Validacoes:
  - teste de contagens retornou zero linhas.
  - `stg.ra_shapefile`: 37 registros, 37 geometrias preenchidas, 0 geometrias invalidas por `st_isvalid`.
  - `stg.tre_secoes_2026_df`: 1 linha `Totais`, 6.961 linhas uteis.

## Observacoes Tecnicas

- `scripts/load_staging.py` usa Python local com `psycopg`, `openpyxl` e `pyshp`.
- O loader e idempotente por padrao: trunca as tabelas antes da carga, salvo uso de `--no-truncate`.
- Campos de origem foram preservados como `text`.
- Todas as tabelas de staging incluem `source_file`, `loaded_at` e `row_number`.
- Tabelas vindas de XLSX incluem `is_total` para separar a linha `Totais`.
- CSVs TSE foram lidos corretamente em Latin-1.
- Alguns XLSX, o GeoJSON e registros do shapefile apresentam caracteres de substituicao em textos acentuados. A carga preserva os dados recebidos; normalizacao/correcao de nomes deve ser feita nas etapas de dimensoes/geoespacial, especialmente em RA.
- O shapefile foi lido com `utf-8` e `encodingErrors="replace"` para garantir carga completa; tentativa com `cp1252` corrigiu um nome mas quebrou outro registro (`ÁGUAS CLARAS`).

## Git

- Repositorio Git local inicializado.
- Branch atual: `main`.
- Autor configurado localmente:
  - `user.name=ManoelNT-DEV`
  - `user.email=manoelbarros.iesb@gmail.com`
- Commit inicial criado:
  - `0336204 chore: versiona base inicial do projeto eleitoral`
- `.gitignore` ignora `.env`, `.env.*` exceto `.env.example`, `fontes/`, caches Python e arquivos temporarios/logs.
- Nao ha remoto configurado.
- Nao houve push para GitHub.
- O usuario decidiu publicar no GitHub manualmente depois.
- Esta atualizacao do resumo ocorreu apos o commit inicial; se desejado, incluir este arquivo em um proximo commit local antes do push manual.

## O Que Funciona

- Ambiente Docker/PostGIS sobe e fica `healthy`.
- Banco aceita conexao via `docker compose exec` e via host em `localhost:5432`.
- Extensoes e schemas base estao aplicados.
- Staging pequeno/medio esta criado e carregado.
- Testes SQL das Etapas 2 e 3 passam retornando zero linhas.
- Geometrias brutas das RAs estao carregadas em `stg.ra_shapefile.geom` com SRID 31983 e sao validas.

## O Que Ainda Esta Incompleto

- Etapa 4 ainda nao implementada.
- Staging dos arquivos grandes ainda nao criado/carregado.
- `perfil_eleitor_secao_2026_DF.csv` ainda nao foi carregado.
- `votacao_secao_2022_DF.csv` ainda nao foi carregado; nao carregar integralmente sem autorizacao explicita.
- Nenhuma dimensao final (`dim.*`) foi criada/populada.
- Nenhuma fato (`fato.*`) foi criada/populada.
- Nenhuma view final foi criada.
- Nenhuma regra automatizada de qualidade em `aux.qualidade_dado` foi implementada.
- Tabela `aux_teste_persistencia` ainda existe apenas como artefato de validacao da Etapa 1.

## Como Reiniciar os Trabalhos

1. Abrir o workspace:

```powershell
cd C:\Users\mnt50\DEV\code_teste_r2
```

2. Conferir contexto e plano:

```powershell
Get-Content .\docs\resumo_contexto_proxima_sessao.md -Raw
Get-Content .\docs\diario_implementacao.md -Raw
Get-Content .\docs\planejamento_implementacao_banco_eleitoral.md -Raw
```

3. Conferir Git local:

```powershell
git status --short
git branch --show-current
git log --oneline -3
git remote -v
```

Estado esperado:

- Branch `main`.
- Commit inicial `0336204` no historico.
- Sem remoto configurado, salvo se o usuario tiver configurado manualmente depois.

4. Conferir Docker:

```powershell
docker --version
docker compose version
```

5. Subir/reiniciar container:

```powershell
docker compose up -d
```

Observacao: neste Windows, comandos Docker podem exigir acesso elevado ao Docker Engine. Se aparecer `open //./pipe/docker_engine: Access is denied`, executar com permissao elevada.

6. Conferir container:

```powershell
docker compose ps
```

Resultado esperado:

```text
eleitoral_postgis   postgis/postgis:16-3.5   db   Up ... (healthy)   0.0.0.0:5432->5432/tcp
```

7. Conferir PostgreSQL:

```powershell
docker compose exec -T db pg_isready -U eleitoral_app -d eleitoral
```

Resultado esperado:

```text
/var/run/postgresql:5432 - accepting connections
```

8. Conferir schemas/extensoes:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/00_extensions_schemas_test.sql
```

Resultado esperado: zero linhas.

9. Conferir staging pequeno/medio:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/01_staging_small_medium_test.sql
```

Resultado esperado: zero linhas.

10. Se o volume tiver sido perdido ou se o banco estiver vazio, reaplicar na ordem:

```powershell
docker compose up -d
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/00_extensions_schemas.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/01_staging/01_staging_small_medium.sql
python scripts\load_staging.py
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/00_extensions_schemas_test.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/01_staging_small_medium_test.sql
```

## Proximo Passo Exato

Implementar a Etapa 4 - Staging dos arquivos grandes.

Entregaveis esperados:

- DDL em `sql/01_staging/02_staging_large.sql` ou nome equivalente coerente.
- Teste SQL em `tests/sql/02_staging_large_test.sql`.
- Ajuste ou novo loader para `perfil_eleitor_secao_2026_DF.csv`.
- Criar estrutura de staging para `votacao_secao_2022_DF.csv`, mas nao executar a carga completa sem autorizacao explicita.
- Registrar resultados em `docs/diario_implementacao.md` e `docs/validacoes_manuais.md`.
- Atualizar este resumo ao final da proxima sessao.

Estrategia recomendada para Etapa 4:

- Ler cabeçalhos reais de `perfil_eleitor_secao_2026_DF.csv` e `votacao_secao_2022_DF.csv`.
- Criar tabelas com colunas de origem como `text` e metadados `source_file`, `loaded_at`, `row_number`.
- Carregar `perfil_eleitor_secao_2026_DF.csv` por streaming/chunks ou `COPY`, evitando leitura integral em memoria.
- Validar `perfil_eleitor_secao_2026_DF.csv`:
  - total esperado: 1.233.369 linhas.
  - secoes distintas esperadas: 7.042.
- Para `votacao_secao_2022_DF.csv`, criar DDL e teste estrutural; carga completa continua pendente de autorizacao.

## Comandos Uteis

Subir container:

```powershell
docker compose up -d
```

Parar sem apagar dados:

```powershell
docker compose down
```

Ver logs:

```powershell
docker compose logs db
```

Abrir `psql`:

```powershell
docker compose exec db psql -U eleitoral_app -d eleitoral
```

Executar SQL inline:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select current_database(), current_user;"
```

Listar volumes:

```powershell
docker volume ls
```

Nao executar salvo decisao explicita de reset total:

```powershell
docker compose down -v
```

Esse comando apaga o volume persistente e destruiria os dados carregados no banco.
