# Resumo de contexto para proxima sessao

Data de encerramento: 2026-09-08  
Workspace: `C:\Users\mnt50\DEV\code_teste_r2`

## Objetivo do projeto

Construir um banco PostgreSQL/PostGIS para inteligencia eleitoral no DF, com dados eleitorais, territoriais e de perfil do eleitorado organizados em camadas `stg`, `dim`, `fato`, `geo` e `aux`.

O banco deve sustentar paineis com KPIs eleitorais, mapas por RA/local/secao, drill-down `DF -> RA -> local -> secao`, ranking/Pareto, top2, lideranca, margem, heatmap, barras empilhadas e tabelas analiticas combinando votacao e perfil do eleitorado.

## Arquitetura atual

- Docker Compose com servico unico `db`.
- Imagem: `postgis/postgis:16-3.5`.
- Container: `eleitoral_postgis`.
- Banco: `eleitoral`.
- Usuario: `eleitoral_app`.
- Porta local: `5432`.
- Volume persistente: `code_teste_r2_postgres_data`.
- Montagens readonly: `./fontes:/fontes:ro`, `./sql:/sql:ro`, `./tests:/tests:ro`.
- Schemas: `stg`, `dim`, `fato`, `geo`, `aux`.
- Extensoes: `postgis`, `unaccent`.

## Diretrizes criticas

- `votacao_secao_2022_DF.csv` nao sera carregado integralmente.
- 2022 fica apenas como amostra piloto/modelagem da estrutura de votacao.
- A carga completa futura sera dos dados de votacao 2026, quando disponiveis na mesma estrutura.
- A chave de local de votacao e `eleicao_id + uf_id + nr_zona + nr_local_votacao`, porque o mesmo numero de local aparece em zonas diferentes.
- Para 2026, os 614 pares `zona + local` coincidentes com o TRE sao os principais oficiais; os 8 pares adicionais do CSV ficam preservados para checagem.
- O numero oficial de secoes principais TRE 2026 e 6.961.
- O CSV `eleitorado_local_votacao_2026_DF.csv` tem 7.050 secoes por incluir agregadas/adicionais.
- Secao agregada deve herdar o local da secao principal indicada em `NR_SECAO_PRINCIPAL`.
- CPF aberto de candidato nao e persistido; usa-se `cpf_hash`.

## Fontes carregadas

- `consulta_cand_2026_DF.csv`: 661 linhas.
- `consulta_cand_complementar_2026_DF.csv`: 661 linhas.
- `eleitorado_local_votacao_2026_DF.csv`: 7.050 linhas.
- `perfil_eleitor_secao_2026_DF.csv`: 1.233.369 linhas.
- Planilhas TRE 2026: locais, locais/secao, locais/secao agrupadas e secoes.
- `geo_ra_centroid_atualizado.json`: 35 centroides.
- `shapefile_ras/regioes_administrativas.*`: 37 poligonos.
- `votacao_secao_2022_DF.csv`: somente amostra piloto ZE 20, 44.464 linhas.

## Estado atual do codigo

Arquivos de implementacao principais:

- `docker-compose.yml`
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
- `sql/03_geoespacial/01_ra_geometria.sql`
- `sql/04_fatos/01_fato_eleitorado_perfil_secao.sql`
- `sql/04_fatos/02_estrutura_votacao_2022.sql`
- `sql/04_fatos/03_carga_piloto_votacao_2022.sql`
- `scripts/load_staging.py`
- `scripts/load_large_staging.py`
- `scripts/load_votacao_piloto.py`

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

Documentacao:

- `docs/modelagem_banco_eleitoral_postgis.md`: referencia consolidada de modelagem/manutencao.
- `docs/planejamento_implementacao_banco_eleitoral.md`: plano atualizado ate Etapa 16.
- `docs/diario_implementacao.md`: diario ate Etapa 14.
- `docs/validacoes_manuais.md`: comandos/resultados ate Etapa 14.
- `docs/resumo_contexto_proxima_sessao.md`: este resumo.

## O que funciona

- Container PostGIS sobe e fica `healthy`.
- Banco aceita conexao via `docker compose exec` e host `localhost:5432`.
- Schemas/extensoes aplicados.
- Staging pequeno/medio carregado.
- Staging de perfil 2026 carregado.
- Staging de votacao 2022 carregado apenas com piloto ZE 20.
- `dim.uf`: DF.
- `dim.eleicao`: 2026 oficial e 2022 piloto.
- `dim.regiao_administrativa` e `geo.ra_geometria`: 37 RAs, geometrias validas, centroides dentro dos poligonos.
- `dim.zona_eleitoral`: 19 zonas.
- `dim.cargo_eleitoral`: 7 cargos.
- `dim.partido_politico`: 29 partidos.
- `dim.federacao`: 5 federacoes reais.
- `dim.coligacao`: 62 coligacoes.
- `dim.local_votacao`: 622 pares 2026 `zona + local`, sendo 614 principais TRE e 8 adicionais CSV.
- `dim.secao_eleitoral`: 7.050 secoes 2026, sendo 6.961 principais TRE, 81 agregadas e 8 adicionais CSV.
- `dim.candidato`: 661 candidatos 2026.
- `dim.perfil_eleitor`: 8.468 perfis.
- `fato.eleitorado_perfil_secao`: 1.219.951 linhas agregadas por secao/perfil; `source_row_count` soma 1.233.369 linhas brutas.
- `dim.votavel`: 838 votaveis do piloto 2022.
- `fato.votacao_candidato_secao`: 44.464 linhas do piloto 2022 ZE 20.
- `fato.apuracao_secao`: 876 agregados do piloto 2022.
- `fato.vw_votacao_drilldown`: funciona para a amostra piloto.
- `aux.qualidade_dado`: registra pendencias das etapas implementadas.
- Suite SQL das Etapas 2 a 14 passou com zero divergencias.

## Contagens validadas

Locais 2026:

- 622 pares `zona + local` no CSV.
- 614 pares oficiais TRE principais.
- 8 pares adicionais para checagem.
- 108 numeros de local distintos.
- 3 locais sem geometria por coordenada sentinela `-1/-1`.

Secoes 2026:

- 7.050 secoes no CSV.
- 6.961 secoes principais oficiais TRE.
- 7.042 secoes confirmadas apos expandir agregadas da planilha TRE.
- 81 secoes agregadas no CSV.
- 8 secoes adicionais CSV.
- 106 divergencias de aptos TRE x soma CSV registradas como aviso.

Perfil 2026:

- 8.468 perfis.
- 1.219.951 linhas fato agregadas.
- 1.233.369 linhas brutas preservadas em `source_row_count`.
- 2.253.132 eleitores.
- 2.126.894 com biometria.
- 24.832 com deficiencia.
- 723 com nome social.

Piloto votacao 2022:

- ZE 20.
- 44.464 linhas staging/fato.
- 18 locais.
- 219 secoes.
- 838 votaveis.
- `nominal`: 39.844 linhas, 228.436 votos.
- `legenda`: 2.869 linhas, 4.604 votos.
- `branco`: 876 linhas, 16.142 votos.
- `nulo`: 875 linhas, 11.822 votos.

## O que esta incompleto

- Etapa 16 ainda nao implementada: views, materializacoes e indices de consulta.
- Etapa 17 ainda nao implementada: suite completa automatizada de qualidade.
- Etapa 18 ainda nao implementada: backup, restore e reprocessamento.
- Views finais para paineis ainda nao existem, exceto `fato.vw_votacao_drilldown`.
- Indices ainda precisam ser revisados para consultas interativas.
- Votacao completa 2026 ainda depende da fonte futura.
- `votacao_secao_2022_DF.csv` nao deve ser carregado completo.
- `aux_teste_persistencia` ainda pode existir como artefato da Etapa 1.
- Textos com problema de encoding ainda nao foram totalmente curados.

## Proximo passo exato

Implementar a Etapa 16 - views, materializacoes e indices de consulta.

Usar como contexto:

- `docs/modelagem_banco_eleitoral_postgis.md`
- `docs/planejamento_implementacao_banco_eleitoral.md`
- `docs/validacoes_manuais.md`
- `fontes/especificacao-tecnica-painel-eleitoral.md`

Entregaveis:

- Revisar `fato.vw_votacao_drilldown`.
- Criar views agregadas por RA, local, secao, cargo, partido e votavel.
- Criar suporte SQL para top2, margem, ranking e Pareto.
- Criar views para heatmap, barras empilhadas e vitorias/zeros por votavel.
- Criar views de eleitorado por RA/local/secao/perfil e categoria dominante por RA.
- Criar views geograficas para mapas de RA e locais.
- Revisar/criar indices B-tree e GiST para filtros por eleicao, cargo, votavel, RA, local, secao e geometria.
- Rodar `explain analyze` nas consultas-alvo com a amostra piloto.
- Criar `tests/sql/13_views_indices_consulta_test.sql`.
- Registrar resultados em `docs/diario_implementacao.md` e `docs/validacoes_manuais.md`.
- Atualizar este resumo ao final da proxima sessao.

Views sugeridas:

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

## Como reiniciar sem perder contexto

Abrir workspace:

```powershell
cd C:\Users\mnt50\DEV\code_teste_r2
```

Ler contexto principal:

```powershell
Get-Content .\docs\resumo_contexto_proxima_sessao.md -Raw
Get-Content .\docs\modelagem_banco_eleitoral_postgis.md -Raw
Get-Content .\docs\planejamento_implementacao_banco_eleitoral.md -Raw
Get-Content .\docs\validacoes_manuais.md -Raw
```

Conferir Git:

```powershell
git status --short
git branch --show-current
git log --oneline -3
git remote -v
```

Estado Git observado no encerramento:

- Branch esperada: `main`.
- Commit inicial existente: `0336204 chore: versiona base inicial do projeto eleitoral`.
- Sem remoto configurado, salvo alteracao manual posterior.
- Ha alteracoes pendentes no working tree das Etapas 9 a 14 e documentos; nao reverter sem pedido explicito.

## Como reiniciar os conteineres

Conferir Docker:

```powershell
docker --version
docker compose version
```

Subir/reiniciar sem apagar dados:

```powershell
docker compose up -d
```

Conferir status:

```powershell
docker compose ps
```

Resultado esperado:

```text
eleitoral_postgis   postgis/postgis:16-3.5   db   Up ... (healthy)   0.0.0.0:5432->5432/tcp
```

Conferir PostgreSQL:

```powershell
docker compose exec -T db pg_isready -U eleitoral_app -d eleitoral
```

Resultado esperado:

```text
/var/run/postgresql:5432 - accepting connections
```

Abrir `psql`:

```powershell
docker compose exec db psql -U eleitoral_app -d eleitoral
```

Parar sem apagar dados:

```powershell
docker compose down
```

Nao executar salvo decisao explicita de reset total:

```powershell
docker compose down -v
```

Esse comando apaga o volume persistente `code_teste_r2_postgres_data` e destruiria os dados carregados.

Observacao: neste Windows, comandos Docker podem exigir permissao elevada ao Docker Engine. Se aparecer `open //./pipe/docker_engine: Access is denied`, repetir o comando com permissao apropriada.

## Validacao rapida ao retomar

Rodar a suite SQL completa:

```powershell
Get-ChildItem tests\sql\*.sql | Sort-Object Name | ForEach-Object { docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f ("/tests/sql/" + $_.Name) }
```

Resultado esperado:

- Todos os testes retornam zero linhas.

Validacao pontual do piloto 2022:

```powershell
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /tests/sql/12_carga_piloto_votacao_2022_test.sql
```

Resultado esperado:

```text
 check_name | expected_value | actual_value
------------+----------------+--------------
(0 rows)
```

## Reprocessamento se o banco estiver vazio

Executar na ordem:

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
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/04_dim_local_votacao.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/05_dim_secao_eleitoral.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/06_dim_candidato.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/07_dim_perfil_eleitor.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/04_fatos/01_fato_eleitorado_perfil_secao.sql
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/04_fatos/02_estrutura_votacao_2022.sql
python scripts\load_votacao_piloto.py
docker compose exec -T db psql -U eleitoral_app -d eleitoral -f /sql/04_fatos/03_carga_piloto_votacao_2022.sql
```

Depois rodar a suite completa indicada acima.

## Cuidados para a proxima sessao

- Nao executar carga completa de 2022.
- Nao usar `python scripts\load_large_staging.py --include-votacao` para carga completa 2022.
- Nao apagar volume Docker.
- Nao reverter alteracoes pendentes sem pedido explicito.
- Ao criar Etapa 16, manter views compativeis com a especificacao de paineis em `fontes/especificacao-tecnica-painel-eleitoral.md`.
