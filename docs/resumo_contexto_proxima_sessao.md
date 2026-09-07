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
- `perfil_eleitor_secao_2026_DF.csv`: 1.233.369 linhas, carregado em staging.
- `votacao_secao_2022_DF.csv`: 1.238.611 linhas, estrutura criada em staging, mas ainda nao carregado; carga completa continua fora do escopo ate autorizacao explicita.
- Planilhas TRE 2026 em `.xlsx`: locais, locais/secao, locais/secao agrupadas e secoes.
- `geo_ra_centroid_atualizado.json`: 35 centroides em EPSG:4326; 34 aproveitados diretamente e 1 descartado por cair fora do poligono (`RA-XXIII / VARJÃO`).
- `fontes/shapefile_ras/regioes_administrativas.*`: 37 poligonos de RAs, SIRGAS 2000 / UTM Zone 23S, carregado no staging como SRID 31983.

Pontos de negocio ja identificados:

- Faltavam centroides no GeoJSON para `RA-XXXVI / 26 DE SETEMBRO` e `RA-XXXVII / PONTE ALTA`; ambos foram calculados a partir dos poligonos com `st_pointonsurface`.
- O centroide do GeoJSON para `RA-XXIII / VARJÃO` caiu fora do poligono e tambem foi substituido por centroide calculado.
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
- `sql/01_staging/02_staging_large.sql`
- `scripts/load_large_staging.py`
- `sql/02_dimensoes/01_dim_uf.sql`
- `sql/02_dimensoes/02_dim_eleicao.sql`
- `sql/02_dimensoes/03_dimensoes_eleitorais_basicas.sql`
- `sql/03_geoespacial/01_ra_geometria.sql`
- `tests/sql/00_extensions_schemas_test.sql`
- `tests/sql/01_staging_small_medium_test.sql`
- `tests/sql/02_staging_large_test.sql`
- `tests/sql/03_dim_uf_test.sql`
- `tests/sql/04_dim_eleicao_test.sql`
- `tests/sql/05_ra_geometria_test.sql`
- `tests/sql/06_dimensoes_eleitorais_basicas_test.sql`
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

Etapa 4 - Staging dos arquivos grandes:

- Criado e executado `sql/01_staging/02_staging_large.sql`.
- Criado e executado `scripts/load_large_staging.py`.
- Criado e executado `tests/sql/02_staging_large_test.sql`.
- Tabelas criadas em `stg`:
  - `perfil_eleitor_secao_2026_df`.
  - `votacao_secao_2022_df`.
- Carga executada:
  - `perfil_eleitor_secao_2026_df`: 1.233.369 linhas.
  - secoes distintas no perfil: 7.042.
  - soma de `qt_eleitores`: 2.253.132.
- Carga nao executada:
  - `votacao_secao_2022_df`: 0 linhas, por falta de autorizacao explicita para carga completa.
- Validacao:
  - teste SQL da Etapa 4 retornou zero linhas.

Etapa 5 - Dimensao UF:

- Criado e executado `sql/02_dimensoes/01_dim_uf.sql`.
- Criado e executado `tests/sql/03_dim_uf_test.sql`.
- Tabela criada: `dim.uf`.
- Registro carregado:
  - `uf_id = 1`
  - `sigla = DF`
  - `nome = Distrito Federal`
  - `codigo_ibge = 53`
- Validacao:
  - teste SQL retornou zero linhas.
  - consulta direta em `dim.uf` retornou exatamente a linha esperada para DF.

Etapa 6 - Dimensao eleicao:

- Criado e executado `sql/02_dimensoes/02_dim_eleicao.sql`.
- Criado e executado `tests/sql/04_dim_eleicao_test.sql`.
- Tabela criada: `dim.eleicao`.
- Registro carregado:
  - `eleicao_id = 1`
  - `ano = 2026`
  - `turno = 1`
  - `cd_eleicao = 6259`
  - `ds_eleicao = Eleições Gerais Estaduais 2026`
  - `cd_tipo_eleicao = 2`
  - `nm_tipo_eleicao = ELEIÇÃO ORDINÁRIA`
  - `dt_eleicao = 2026-10-04`
  - `tp_abrangencia = ESTADUAL`
- Fonte principal: `stg.consulta_cand_2026_df`.
- Observacao: `stg.eleitorado_local_votacao_2026_df.ds_eleicao` traz `1º Turno`, entao nao foi usada como descricao principal.
- Validacao:
  - teste SQL retornou zero linhas.
  - nenhuma eleicao 2022 foi criada porque `stg.votacao_secao_2022_df` segue vazia.

Etapa 7 - Geoespacial de RAs:

- Criado e executado `sql/03_geoespacial/01_ra_geometria.sql`.
- Criado e executado `tests/sql/05_ra_geometria_test.sql`.
- Tabelas criadas/populadas:
  - `dim.regiao_administrativa`: 37 RAs.
  - `geo.ra_geometria`: 37 geometrias.
- Geometrias:
  - `geom_utm`: MultiPolygon SRID 31983.
  - `geom`: MultiPolygon SRID 4326.
- Centroides:
  - 34 com origem `geojson`.
  - 3 com origem `calculado_shapefile`.
  - calculados para `RA-XXIII / VARJÃO`, `RA-XXXVI / 26 DE SETEMBRO` e `XXXVII / PONTE ALTA`.
- Validacao:
  - teste SQL retornou zero linhas.
  - todas as RAs tem geometria e centroide.
  - todas as geometrias sao validas.
  - todos os centroides ficam cobertos pelo poligono correspondente.

Etapa 8 - Dimensoes eleitorais basicas:

- Criado e executado `sql/02_dimensoes/03_dimensoes_eleitorais_basicas.sql`.
- Criado e executado `tests/sql/06_dimensoes_eleitorais_basicas_test.sql`.
- Tabelas criadas/populadas:
  - `dim.zona_eleitoral`: 19 zonas.
  - `dim.cargo_eleitoral`: 7 cargos.
  - `dim.partido_politico`: 29 partidos.
  - `dim.federacao`: 5 federacoes reais.
  - `dim.coligacao`: 62 coligacoes.
- Regra adotada:
  - `NR_FEDERACAO = -1 / #NULO` foi tratado como ausencia de federacao e excluido de `dim.federacao`.
  - coligacoes com `PARTIDO ISOLADO` foram mantidas em `dim.coligacao` porque possuem `SQ_COLIGACAO` real e serao usadas no relacionamento de candidatos.
- Validacao:
  - teste SQL retornou zero linhas.
  - nao ha duplicidade nas chaves naturais validadas.

## Observacoes Tecnicas

- `scripts/load_staging.py` usa Python local com `psycopg`, `openpyxl` e `pyshp`.
- `scripts/load_large_staging.py` usa Python local com `psycopg` e carrega CSVs grandes por streaming via `COPY`.
- `scripts/load_large_staging.py` carrega apenas perfil por padrao; a votacao so carrega com `--include-votacao`, que nao deve ser usado sem autorizacao explicita.
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
- Alteracoes posteriores ao commit inicial podem estar pendentes no working tree; conferir com `git status --short` antes de novo commit/push manual.

## O Que Funciona

- Ambiente Docker/PostGIS sobe e fica `healthy`.
- Banco aceita conexao via `docker compose exec` e via host em `localhost:5432`.
- Extensoes e schemas base estao aplicados.
- Staging pequeno/medio esta criado e carregado.
- Staging de perfil do eleitorado esta criado e carregado.
- Estrutura de staging de votacao esta criada e vazia.
- `dim.uf` esta criada e populada com DF.
- `dim.eleicao` esta criada e populada com a eleicao 2026.
- `dim.regiao_administrativa` e `geo.ra_geometria` estao criadas e populadas com 37 RAs.
- Dimensoes eleitorais basicas estao criadas e populadas.
- Testes SQL das Etapas 2, 3, 4, 5, 6, 7 e 8 passam retornando zero linhas.
- Geometrias brutas das RAs estao carregadas em `stg.ra_shapefile.geom` com SRID 31983 e sao validas.

## O Que Ainda Esta Incompleto

- Etapa 9 ainda nao implementada.
- `votacao_secao_2022_DF.csv` ainda nao foi carregado; nao carregar integralmente sem autorizacao explicita.
- Nenhuma dimensao final alem de `dim.uf`, `dim.eleicao`, `dim.regiao_administrativa`, `dim.zona_eleitoral`, `dim.cargo_eleitoral`, `dim.partido_politico`, `dim.federacao` e `dim.coligacao` foi criada/populada.
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

10. Conferir staging grande:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/02_staging_large_test.sql
```

Resultado esperado: zero linhas.

11. Conferir dimensao UF:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/03_dim_uf_test.sql
```

Resultado esperado: zero linhas.

12. Conferir dimensao eleicao:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/04_dim_eleicao_test.sql
```

Resultado esperado: zero linhas.

13. Conferir geoespacial de RAs:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/05_ra_geometria_test.sql
```

Resultado esperado: zero linhas.

14. Conferir dimensoes eleitorais basicas:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/06_dimensoes_eleitorais_basicas_test.sql
```

Resultado esperado: zero linhas.

15. Se o volume tiver sido perdido ou se o banco estiver vazio, reaplicar na ordem:

```powershell
docker compose up -d
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/00_extensions_schemas.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/01_staging/01_staging_small_medium.sql
python scripts\load_staging.py
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/01_staging/02_staging_large.sql
python scripts\load_large_staging.py
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/01_dim_uf.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/02_dim_eleicao.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/03_dimensoes_eleitorais_basicas.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/03_geoespacial/01_ra_geometria.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/00_extensions_schemas_test.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/01_staging_small_medium_test.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/02_staging_large_test.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/03_dim_uf_test.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/04_dim_eleicao_test.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/05_ra_geometria_test.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /tests/sql/06_dimensoes_eleitorais_basicas_test.sql
```

## Proximo Passo Exato

Implementar a Etapa 9 - Dimensao local de votacao.

Entregaveis esperados:

- DDL/populacao em `sql/02_dimensoes/04_dim_local_votacao.sql`.
- Teste SQL em `tests/sql/07_dim_local_votacao_test.sql` ou nome equivalente coerente.
- Criar e popular `dim.local_votacao`.
- Usar fontes `stg.eleitorado_local_votacao_2026_df` e `stg.tre_locais_2026_df`.
- Gerar `geom` de latitude/longitude quando disponiveis.
- Derivar `ra_id` por intersecao espacial com `geo.ra_geometria`.
- Registrar ou ao menos identificar locais sem coordenada/RA para futura qualidade.
- Registrar resultados em `docs/diario_implementacao.md` e `docs/validacoes_manuais.md`.
- Atualizar este resumo ao final da proxima sessao.

Estrategia recomendada para Etapa 9:

- A chave natural deve ser `eleicao_id + uf_id + nr_local_votacao`.
- Consolidar nome/endereco por local a partir do CSV oficial e planilhas TRE.
- Usar coordenadas do CSV quando validas; se necessario, complementar com `tre_locais_2026_df`.
- Validar quantidade esperada de 108 numeros de locais distintos para 2026.
- Validar `locais_sem_geom` e `locais_sem_ra`; se houver, documentar.

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
