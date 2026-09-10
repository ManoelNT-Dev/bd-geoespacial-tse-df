# Resumo de contexto para proxima sessao

Data de encerramento: 2026-09-10
Workspace: `C:\Users\mnt50\DEV\code_teste_r2`  
Projeto: banco eleitoral PostgreSQL/PostGIS para DF, PMB e indicadores sociodemograficos por RA.

## Objetivo

Construir um banco relacional/geoespacial em PostgreSQL/PostGIS para inteligencia eleitoral no DF, com camadas `stg`, `dim`, `fato`, `geo` e `aux`. A arquitetura separa fontes brutas, dimensoes conformadas, fatos eleitorais, geografia, recortes metropolitanos, sociodemografia e qualidade de dados. RA e entidade territorial do DF. PMB e recorte de municipios goianos, nao RA.

## Estado atual

- Branch: `main`.
- Ultimo commit conhecido antes das alteracoes pendentes: `1254250 Versao - R4. PMB + SOCIODEMOGRAFIA`.
- Existem alteracoes versionaveis pendentes em `docs/`, `sql/05_views/` e `tests/sql/`; nao reverter sem pedido explicito.
- `fontes/` esta no `.gitignore`; JSONs derivados e CSVs fonte nao aparecem em `git status`.
- Etapas 0 a 16 estao implementadas, carregadas no PostgreSQL e validadas.
- Etapa 18 esta parcialmente implementada: indices, materializacoes/views de votacao e views de eleitorado DF.
- Suite `tests/sql/00` a `18` passou com zero divergencias no encerramento.
- Contrato revisado de votacao: o banco mantem apenas `TOP 5`; `TOP 2`, margem, lider/segundo e competitividade serao calculados no front-end a partir de `ranking_top5`.

## Arquivos principais

Documentacao:

- `docs/resumo_contexto_proxima_sessao.md`
- `docs/views_materializacoes_indices.md`
- `docs/planejamento_implementacao_banco_eleitoral.md`
- `docs/diario_implementacao.md`
- `docs/validacoes_manuais.md`
- `docs/modelagem_banco_eleitoral_postgis.md`
- `docs/modelagem_pmb.md`
- `docs/modelo_arquivo_sociodemografia_ra_df.md`

Implementacao:

- `scripts/build_pmb_eleitorado_json.py`
- `scripts/build_ra_sociodemografia_json.py`
- `scripts/load_staging.py`
- `scripts/load_large_staging.py`
- `scripts/load_votacao_piloto.py`
- `sql/00_extensions_schemas.sql`
- `sql/01_staging/*.sql`
- `sql/02_dimensoes/*.sql`
- `sql/03_geoespacial/01_ra_geometria.sql`
- `sql/04_fatos/*.sql`
- `sql/05_views/01_indices_consulta.sql`
- `sql/05_views/02_votacao_materializacoes.sql`
- `sql/05_views/03_votacao_views.sql`
- `sql/05_views/04_eleitorado_views.sql`
- `tests/sql/00` a `18`

## Ambiente e conteineres

- Docker Compose com servico `db`.
- Imagem: `postgis/postgis:16-3.5`.
- Container: `eleitoral_postgis`.
- Banco: `eleitoral`.
- Usuario: `eleitoral_app`.
- Porta local: `5432`.
- Volume persistente: `code_teste_r2_postgres_data`.
- Montagens readonly: `./fontes:/fontes:ro`, `./sql:/sql:ro`, `./tests:/tests:ro`.
- Extensoes usadas: `postgis`, `unaccent`, `pg_trgm`.

Reiniciar conteineres:

```powershell
cd C:\Users\mnt50\DEV\code_teste_r2
docker compose up -d
docker compose ps
docker compose exec -T db pg_isready -U eleitoral_app -d eleitoral
```

Resultado esperado:

```text
/var/run/postgresql:5432 - accepting connections
```

Entrar no `psql`:

```powershell
docker compose exec db psql -U eleitoral_app -d eleitoral
```

Parar sem apagar dados:

```powershell
docker compose down
```

Nao executar sem decisao explicita:

```powershell
docker compose down -v
```

`docker compose down -v` apaga o volume persistente `code_teste_r2_postgres_data`.

## Arquitetura implementada

Schemas:

- `stg`: staging bruto.
- `dim`: dimensoes conformadas.
- `fato`: fatos, materialized views e views analiticas.
- `geo`: geometrias.
- `aux`: qualidade, conciliacao e apoio.

Dimensoes principais:

- `dim.uf`: `DF` e `GO`.
- `dim.eleicao`: eleicao DF 2026 e piloto tecnico 2022.
- `dim.regiao_administrativa`: 37 RAs oficiais do DF, incluindo `26 DE SETEMBRO` e `PONTE ALTA`.
- `geo.ra_geometria`: 37 geometrias; centroides de `VARJAO`, `26 DE SETEMBRO` e `PONTE ALTA` calculados.
- `dim.zona_eleitoral`, `dim.local_votacao`, `dim.secao_eleitoral`.
- `dim.cargo_eleitoral`, `dim.partido_politico`, `dim.federacao`, `dim.coligacao`, `dim.candidato`, `dim.votavel`.
- `dim.perfil_eleitor`: 13.628 combinacoes demograficas apos incorporar DF e GO/PMB.
- `dim.municipio`, `dim.recorte_geografico`, `dim.recorte_municipio`: suporte PMB.
- `dim.indicador_sociodemografico`: catalogo flexivel de indicadores por RA.

Fatos:

- `fato.eleitorado_perfil_secao`: eleitorado DF 2026 por secao e perfil.
- `fato.votacao_candidato_secao`: votacao piloto 2022 da ZE 20.
- `fato.apuracao_secao`: agregados da votacao piloto 2022.
- `fato.eleitorado_perfil_municipio`: eleitorado PMB/GO 2026 por municipio e perfil.
- `fato.sociodemografia_ra`: indicadores sociodemograficos por RA/ano/indicador.
- `fato.sociodemografia_ra_resumo`: textos resumidos por RA/ano.

Views/materializacoes implementadas:

- `fato.vw_votacao_drilldown`: operacional para a amostra piloto 2022.
- `fato.mv_votacao_nivel`: 55.219 linhas agregadas por nivel/votavel no piloto 2022.
- `fato.mv_votacao_top5`: 4.779 linhas de ranking TOP 5 no piloto 2022.
- `fato.vw_votacao_resultado_nivel`.
- `fato.vw_votacao_top5`.
- `fato.vw_votacao_rank_pareto`.
- `fato.vw_vitorias_zeros_votavel`.
- `fato.vw_votacao_heatmap_top5`.
- `fato.vw_votacao_stacked_ra_top5`.
- `fato.mv_eleitorado_perfil_nivel`: 346.143 linhas em formato longo por nivel e dimensao demografica.
- `fato.vw_eleitorado_perfil_ra`.
- `fato.vw_eleitorado_perfil_local`.
- `fato.vw_eleitorado_perfil_secao`.
- `fato.vw_eleitorado_dominante_nivel`.

Scripts de views/indices:

- `sql/05_views/01_indices_consulta.sql`: `pg_trgm`, indices de consulta para votacao, eleitorado DF, sociodemografia, geografia, PMB, candidaturas, busca textual e staging grande; executa `analyze`.
- `sql/05_views/02_votacao_materializacoes.sql`: `fato.mv_votacao_nivel` e `fato.mv_votacao_top5`; tambem remove objetos antigos `top2` se existirem.
- `sql/05_views/03_votacao_views.sql`: views de resultado, top5, ranking/Pareto, vitorias/zeros, heatmap e stacked top5.
- `sql/05_views/04_eleitorado_views.sql`: materializacao longa do perfil do eleitorado DF por RA/local/secao, views por nivel e dominante demografico. Usa `set enable_memoize = off` durante a materializacao por erro interno do planner observado no PostgreSQL.

## Regras criticas

- O numero oficial atual de RAs e 37. Toda especificacao nova deve considerar 37 RAs.
- Referencias a 35 RAs em fontes legadas sao historico dos JSONs estaticos antigos, nao contrato novo.
- `26 DE SETEMBRO` e `PONTE ALTA` devem aparecer em mapas, tabelas, perfil e sociodemografia quando a fonte permitir.
- PMB e recorte de municipios goianos, nao RA.
- Nao carregar `votacao_secao_2022_DF.csv` completo; 2022 e apenas piloto/modelagem.
- `local_votacao` usa chave natural `eleicao_id + uf_id + nr_zona + nr_local_votacao`.
- `secao_eleitoral` usa chave natural `eleicao_id + uf_id + nr_zona + nr_secao`.
- Secao agregada herda o local da secao principal indicada em `NR_SECAO_PRINCIPAL`.
- CPF aberto de candidato nao e persistido; `dim.candidato` usa `cpf_hash`.
- Views territoriais devem carregar `eleicao_id` e, quando aplicavel, `ano`, `turno` e `cd_eleicao`, para nao misturar 2026 com piloto 2022.
- Resumos PMB nao devem somar `pop_municipio` depois de join direto com fato de perfil; isso multiplica populacao pelo numero de perfis.
- Executar `analyze` apos cargas grandes antes de confiar em `pg_stat_user_tables` ou planos de consulta.
- Contrato de votacao: manter apenas `TOP 5` no banco. `TOP 2`, margem, lider/segundo e competitividade ficam no front-end.

## Contagens validadas

RAs/geografia:

- `dim.regiao_administrativa`: 37 RAs.
- `geo.ra_geometria`: 37 geometrias.
- Centroides: 34 `geojson`, 3 `calculado_shapefile`.

Locais/secoes 2026:

- Oficiais TRE por `Locais_TRE_DF_2026.xlsx`: 614 locais, 6.961 secoes, 2.253.238 aptos, 308.799 nao aptos, 2.562.037 total.
- CSV TSE `eleitorado_local_votacao_2026_DF.csv`: 622 pares `zona + local`, 7.050 secoes, 2.253.132 aptos.
- Diferenca aptos TRE x CSV/perfil: 106, registrada como `divergencia_aptos_tre_csv`.
- `dim.local_votacao` 2026: 622 locais, sendo 614 principais TRE e 8 adicionais CSV.
- `dim.secao_eleitoral` 2026: 7.050 secoes, sendo 6.961 principais TRE, 7.042 confirmadas por TRE expandida, 81 agregadas CSV e 8 adicionais CSV.
- `dim.local_votacao` total: 640 locais, pois inclui 622 de 2026 + 18 do piloto 2022.
- `dim.secao_eleitoral` total: 7.269 secoes, pois inclui 7.050 de 2026 + 219 do piloto 2022.
- O numero `641` nao fecha como total de locais nas bases carregadas; aparece como numero de secao em registros de fonte.

Eleitorado DF:

- `fato.eleitorado_perfil_secao`: 1.219.951 linhas; `source_row_count` soma 1.233.369; total 2.253.132 eleitores.
- `fato.mv_eleitorado_perfil_nivel`: 346.143 linhas.
- `vw_eleitorado_perfil_ra`: 1.951 linhas; 36 RAs identificadas e grupo de RA nula.
- `vw_eleitorado_perfil_local`: 31.168 linhas; 614 locais com perfil.
- `vw_eleitorado_perfil_secao`: 313.024 linhas; 7.042 secoes com perfil.
- `vw_eleitorado_dominante_nivel`: 61.544 linhas.
- A dimensao `genero` fecha 2.253.132 eleitores nos niveis RA, local e secao.
- RA nula no perfil: 603 eleitores; `26 DE SETEMBRO` nao possui perfil territorial associado na fonte eleitoral carregada.

Piloto votacao 2022:

- ZE 20 com 44.464 linhas.
- 18 locais, 219 secoes, 838 votaveis.
- Votos: nominal 228.436, legenda 4.604, branco 16.142, nulo 11.822; total 261.004.
- `fato.mv_votacao_nivel`: 55.219 linhas; preserva 261.004 votos em cada nivel.
- `fato.mv_votacao_top5`: 4.779 linhas; 20 em `geral`, 20 em `ra`, 360 em `local`, 4.379 em `secao`; ranking maximo 5.
- Objetos `top2` no schema `fato`: 0.
- Indices `top2` no schema `fato`: 0.

PMB:

- 12 municipios.
- `fato.eleitorado_perfil_municipio`: 34.927 linhas.
- Eleitores PMB: 759.538.
- Populacao IBGE/SIDRA 2025 PMB: 1.362.821.

Sociodemografia RA:

- JSON estruturado: 37 RAs.
- `fato.sociodemografia_ra`: 592 indicadores.
- `fato.sociodemografia_ra_resumo`: 37 resumos.
- Populacao total DF: 2.982.816.
- Fixos: `GAMA = 88496`, `VICENTE PIRES = 75668`, `26 DE SETEMBRO = 29394`, `PONTE ALTA = 45452`.
- `adjusted_count = 33` para rateio proporcional nas demais RAs.

Qualidade atual:

- `divergencia_aptos_tre_csv`: 106 avisos.
- `local_csv_sem_tre`: 8 avisos.
- `secao_csv_sem_perfil`: 8 avisos.
- `secao_csv_sem_tre`: 8 avisos.
- `local_sem_coordenada`: 3 erros.
- `nr_local_votacao_reutilizado_em_zonas`: 90 infos.

## O que funciona

- Docker/PostGIS sobe com persistencia.
- Staging pequeno/medio e grande carregam.
- Scripts Python compilam e geram JSON PMB/sociodemografia.
- Modelagem DF 2026 de RAs, locais, secoes, candidatos e eleitorado por perfil esta carregada.
- PMB esta carregada como recorte municipal.
- Sociodemografia por RA esta carregada separadamente de eleitorado/votacao.
- Votacao piloto 2022 ZE 20 esta carregada e validada.
- Indices de consulta principais estao aplicados.
- Materializacoes/views de votacao e eleitorado DF estao implementadas.
- Suite SQL `00` a `18` passa com zero divergencias.

## O que esta incompleto

- `sql/05_views/05_sociodemografia_views.sql` ainda nao foi implementado.
- `sql/05_views/06_geo_views.sql` ainda nao foi implementado.
- `sql/05_views/07_pmb_views.sql` ainda nao foi implementado.
- Expansoes opcionais `08_expansao_views.sql` e `09_expansao_materializacoes.sql` ainda nao foram implementadas.
- Qualidade automatizada completa em `sql/99_qualidade/` ainda nao foi implementada.
- Rotina unica de carga/testes ainda nao existe.
- Backup/restore e procedimento de reprocessamento ainda nao foram testados/documentados em script.
- Carga completa de votacao 2026 depende de fonte futura.

## Como retomar sem perder contexto

```powershell
cd C:\Users\mnt50\DEV\code_teste_r2
git status --short
git branch --show-current
git log --oneline -3
Get-Content .\docs\resumo_contexto_proxima_sessao.md -Raw
Get-Content .\docs\views_materializacoes_indices.md -Raw
```

Subir e validar banco:

```powershell
docker compose up -d
docker compose ps
docker compose exec -T db pg_isready -U eleitoral_app -d eleitoral
```

Rodar suite:

```powershell
Get-ChildItem tests\sql\*.sql | Sort-Object Name | ForEach-Object { docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f ("/tests/sql/" + $_.Name) }
```

Validacao rapida:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) from dim.regiao_administrativa;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) filter (where e.ano=2026) locais_2026, count(*) filter (where e.ano=2022) locais_2022 from dim.local_votacao lv join dim.eleicao e on e.eleicao_id=lv.eleicao_id;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) filter (where e.ano=2026) secoes_2026, count(*) filter (where e.ano=2022) secoes_2022 from dim.secao_eleitoral se join dim.eleicao e on e.eleicao_id=se.eleicao_id;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) as locais, sum(qtde_secoes::int) secoes, sum(qtde_eleitores_aptos::int) aptos, sum(qtde_eleitores_nao_aptos::int) nao_aptos, sum(qtde_eleitores_aptos::int)+sum(qtde_eleitores_nao_aptos::int) total from stg.tre_locais_2026_df where not is_total;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(distinct ra_id), count(*) from fato.sociodemografia_ra;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*), max(ranking_top5) from fato.mv_votacao_top5;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select sum(qt_eleitores) from fato.eleitorado_perfil_municipio;"
```

Resultados esperados:

- RAs: 37.
- Locais: 622 em 2026, 18 em piloto 2022, 640 total.
- Secoes: 7.050 em 2026, 219 em piloto 2022, 7.269 total.
- TRE locais 2026: 614 locais, 6.961 secoes, 2.253.238 aptos, 308.799 nao aptos, 2.562.037 total.
- Sociodemografia: 37 RAs, 592 indicadores.
- `mv_votacao_top5`: 4.779 linhas, ranking maximo 5.
- PMB: 759.538 eleitores.

## Reprocessamento completo se o banco estiver vazio

```powershell
docker compose up -d
python scripts\build_pmb_eleitorado_json.py
python scripts\build_ra_sociodemografia_json.py
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/00_extensions_schemas.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/01_staging/01_staging_small_medium.sql
python scripts\load_staging.py
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/01_staging/02_staging_large.sql
python scripts\load_large_staging.py --include-pmb-go
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/01_dim_uf.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/02_dim_eleicao.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/03_dimensoes_eleitorais_basicas.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/03_geoespacial/01_ra_geometria.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/04_dim_local_votacao.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/05_dim_secao_eleitoral.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/06_dim_candidato.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/07_dim_perfil_eleitor.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/08_dim_municipio_recorte_pmb.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/04_fatos/01_fato_eleitorado_perfil_secao.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/04_fatos/02_estrutura_votacao_2022.sql
python scripts\load_votacao_piloto.py
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/04_fatos/03_carga_piloto_votacao_2022.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/04_fatos/04_fato_eleitorado_perfil_municipio_pmb.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/04_fatos/05_fato_sociodemografia_ra.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/05_views/01_indices_consulta.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/05_views/02_votacao_materializacoes.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/05_views/03_votacao_views.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/05_views/04_eleitorado_views.sql
Get-ChildItem tests\sql\*.sql | Sort-Object Name | ForEach-Object { docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f ("/tests/sql/" + $_.Name) }
```

## Proximos passos exatos

1. Confirmar `git status --short` e preservar alteracoes pendentes.
2. Subir Docker e rodar `pg_isready`.
3. Rodar suite `tests/sql/00` a `18`.
4. Implementar `sql/05_views/05_sociodemografia_views.sql`.
5. Criar `tests/sql/19_sociodemografia_views_test.sql`.
6. Implementar `sql/05_views/06_geo_views.sql`.
7. Criar teste SQL para views geograficas.
8. Implementar `sql/05_views/07_pmb_views.sql`.
9. Criar teste SQL para views PMB.
10. Opcional apos o basico: `08_expansao_views.sql` e `09_expansao_materializacoes.sql`.
11. Rodar `analyze` e `explain analyze` nas consultas principais.
12. Depois da Etapa 18, consolidar qualidade automatizada em `sql/99_qualidade/`.
13. Criar rotina unica de carga/testes.
14. Criar e testar backup/restore.
