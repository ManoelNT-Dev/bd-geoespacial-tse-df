# Resumo de contexto para proxima sessao

Data de encerramento: 2026-09-09  
Workspace: `C:\Users\mnt50\DEV\code_teste_r2`  
Projeto: banco eleitoral PostgreSQL/PostGIS para DF, PMB e indicadores sociodemograficos por RA.

## Objetivo

Construir um banco relacional/geoespacial em PostgreSQL/PostGIS para inteligencia eleitoral no DF, com camadas `stg`, `dim`, `fato`, `geo` e `aux`. O desenho separa eleitorado, votacao, territorio, recortes metropolitanos e indicadores sociodemograficos. PMB e tratada como recorte de municipios goianos; RA e entidade territorial do DF.

## Estado atual

- Ha alteracoes pendentes versionaveis em SQL, scripts e docs. Nao reverter nada sem pedido explicito.
- `fontes/` esta no `.gitignore`; JSONs gerados ali nao aparecem em `git status`.
- Etapas 0 a 14 foram executadas no banco e validadas.
- Etapas 15 e 16 foram implementadas, executadas no PostgreSQL e validadas com testes SQL proprios.

Arquivos novos ou relevantes:

- `scripts/build_pmb_eleitorado_json.py`
- `scripts/build_ra_sociodemografia_json.py`
- `scripts/load_staging.py`
- `scripts/load_large_staging.py`
- `sql/01_staging/01_staging_small_medium.sql`
- `sql/01_staging/02_staging_large.sql`
- `sql/02_dimensoes/01_dim_uf.sql`
- `sql/02_dimensoes/07_dim_perfil_eleitor.sql`
- `sql/02_dimensoes/08_dim_municipio_recorte_pmb.sql`
- `sql/04_fatos/04_fato_eleitorado_perfil_municipio_pmb.sql`
- `sql/04_fatos/05_fato_sociodemografia_ra.sql`
- `docs/modelagem_pmb.md`
- `docs/modelo_arquivo_sociodemografia_ra_df.md`

Arquivos gerados em `fontes/`:

- `fontes/eleitorado_PMB_2026.json`
- `fontes/perfil_sociodemografico_ra_df_2025_estruturado.json`

## Ambiente

- Docker Compose com servico `db`.
- Imagem: `postgis/postgis:16-3.5`.
- Container: `eleitoral_postgis`.
- Banco: `eleitoral`.
- Usuario: `eleitoral_app`.
- Porta local: `5432`.
- Volume persistente: `code_teste_r2_postgres_data`.
- Montagens readonly: `./fontes:/fontes:ro`, `./sql:/sql:ro`, `./tests:/tests:ro`.
- Extensoes usadas: `postgis`, `unaccent`.

## Arquitetura implementada

Dimensoes:

- `dim.uf`: inclui `DF` e `GO`.
- `dim.eleicao`: eleicao oficial DF 2026 e piloto tecnico 2022.
- `dim.regiao_administrativa`: 37 RAs oficiais do DF, incluindo `26 DE SETEMBRO` e `PONTE ALTA`.
- `geo.ra_geometria`: geometrias das 37 RAs; centroides calculados quando ausentes ou invalidos.
- `dim.zona_eleitoral`, `dim.local_votacao`, `dim.secao_eleitoral`.
- `dim.cargo_eleitoral`, `dim.partido_politico`, `dim.federacao`, `dim.coligacao`, `dim.candidato`, `dim.votavel`.
- `dim.perfil_eleitor`: combinacoes demograficas eleitorais, preparada para DF e GO.
- `dim.municipio`, `dim.recorte_geografico`, `dim.recorte_municipio`: suporte ao recorte PMB.
- `dim.indicador_sociodemografico`: catalogo flexivel de indicadores por RA.

Fatos:

- `fato.eleitorado_perfil_secao`: eleitorado DF 2026 por secao e perfil.
- `fato.votacao_candidato_secao`: votacao piloto 2022 da ZE 20.
- `fato.apuracao_secao`: agregados da votacao piloto 2022.
- `fato.eleitorado_perfil_municipio`: eleitorado PMB/GO 2026 por municipio e perfil.
- `fato.sociodemografia_ra`: indicadores sociodemograficos por RA, ano e indicador.
- `fato.sociodemografia_ra_resumo`: textos resumidos por RA/ano.

View:

- `fato.vw_votacao_drilldown`: funciona para a amostra piloto 2022.

## Fontes processadas

DF eleitoral:

- `consulta_cand_2026_DF.csv`: 661 linhas.
- `consulta_cand_complementar_2026_DF.csv`: 661 linhas.
- `eleitorado_local_votacao_2026_DF.csv`: 7.050 linhas.
- `perfil_eleitor_secao_2026_DF.csv`: 1.233.369 linhas.
- Planilhas TRE de locais, locais/secao, agrupadas e secoes.
- `geo_ra_centroid_atualizado.json`: 35 centroides; 34 aproveitados, 1 substituido por centroide calculado.
- `shapefile_ras/regioes_administrativas.*`: 37 poligonos.
- `votacao_secao_2022_DF.csv`: usado somente como piloto tecnico ZE 20.

PMB/GO:

- `fontes/eleitorado_PMB_2026.json`: atualizado pelo script.
- `fontes/perfil_eleitor_secao_2026_GO.csv`: CSV TSE GO em Latin-1, usado para agregar os 12 municipios da PMB.
- Populacao municipal: IBGE/SIDRA tabela 6579, variavel 9324, periodo 2025, referencia 2025-07-01.

Sociodemografia RA:

- Original: `fontes/perfil_eleitorado_df_2025_consolidado_12jan2026.json`.
- Estruturado: `fontes/perfil_sociodemografico_ra_df_2025_estruturado.json`.
- O estruturado contem apenas sociodemografia: populacao/raca-cor, religiao, renda, animais de estimacao e resumo.
- Campos eleitorais do original (`totais`, `perfil` e distribuicoes eleitorais) foram removidos porque o banco ja totaliza eleitorado pela modelagem existente.

## Regras criticas

- Nao carregar `votacao_secao_2022_DF.csv` completo. O arquivo 2022 e apenas piloto/modelagem. A carga completa futura deve ser dos dados de votacao 2026 quando existirem.
- `local_votacao` usa chave natural `eleicao_id + uf_id + nr_zona + nr_local_votacao`; `nr_local_votacao` sozinho nao identifica local fisico.
- `secao_eleitoral` usa chave natural `eleicao_id + uf_id + nr_zona + nr_secao`.
- Secao agregada herda o local da secao principal indicada em `NR_SECAO_PRINCIPAL`.
- CPF de candidato nao e persistido aberto; `dim.candidato` usa `cpf_hash`.
- PMB e recorte de municipios goianos, nao RA.
- Sociodemografia de RA fica separada de eleitorado/votacao e se conecta ao restante por `ra_id`.
- O numero oficial de RAs considerado no projeto e 37.
- `26 DE SETEMBRO` e `PONTE ALTA` sao novas RAs.
- `26 DE SETEMBRO` herda proporcionalmente indicadores de `VICENTE PIRES`.
- `PONTE ALTA` herda proporcionalmente indicadores de `GAMA`.
- Populacoes fixas apos desdobramento: `26 DE SETEMBRO` 29.394; `PONTE ALTA` 45.452; `VICENTE PIRES` 75.668; `GAMA` 88.496.
- O total oficial de populacao DF usado na sociodemografia e 2.982.816. As quatro RAs do desdobramento ficam fixas e a diferenca remanescente e rateada proporcionalmente nas outras 33 RAs.
- Quantidades sociodemograficas sao ajustadas por fator populacional e arredondadas para fechamento; percentuais e medias sao preservados quando nao ha microdados.

## Contagens validadas

DF eleitorado:

- `dim.regiao_administrativa`: 37 RAs.
- `geo.ra_geometria`: 37 geometrias.
- Centroides: 34 `geojson`, 3 `calculado_shapefile` (`VARJAO`, `26 DE SETEMBRO`, `PONTE ALTA`).
- `dim.local_votacao`: 622 pares `zona + local`; 614 principais TRE; 8 adicionais CSV; 3 sem geometria.
- `dim.secao_eleitoral`: 7.050 secoes; 6.961 principais TRE; 81 agregadas; 8 adicionais CSV.
- `dim.candidato`: 661 candidatos.
- `dim.perfil_eleitor`: 8.468 perfis antes da carga GO; pode aumentar apos `--include-pmb-go`.
- `fato.eleitorado_perfil_secao`: 1.219.951 linhas; `source_row_count` soma 1.233.369; total 2.253.132 eleitores.

Piloto votacao 2022:

- ZE 20 carregada com 44.464 linhas.
- 18 locais, 219 secoes, 838 votaveis.
- Votos: nominal 228.436, legenda 4.604, branco 16.142, nulo 11.822.

PMB:

- 12 municipios.
- 759.538 eleitores.
- Populacao IBGE/SIDRA 2025: 1.362.821.
- `perfil_geral` do JSON PMB fecha 759.538 em todas as dimensoes.

Sociodemografia RA:

- JSON estruturado: 37 RAs.
- Populacao por RA fecha 2.982.816.
- Nenhuma RA do JSON estruturado contem `totais` ou `perfil`.
- Divergencia documentada: o arquivo original trazia 35 registros de RA somando 2.861.057, mas o cadastro oficial considerado no projeto tem 37 RAs e o total oficial global e 2.982.816.
- Valores fixos validados: `GAMA = 88496`, `VICENTE PIRES = 75668`, `26 DE SETEMBRO = 29394`, `PONTE ALTA = 45452`.
- `adjusted_count = 33` para rateio proporcional nas demais RAs.

## O que funciona

- Scripts Python compilam.
- JSON PMB e JSON sociodemografico estruturado foram gerados e validados localmente.
- `scripts/load_staging.py` carrega os JSONs PMB e sociodemografico em staging.
- `scripts/load_large_staging.py` aceita `--include-pmb-go` para carregar o CSV GO.
- SQLs novos de PMB e sociodemografia foram criados.
- O modelo evita misturar municipio PMB com RA do DF.
- O arquivo sociodemografico estruturado nao duplica dados eleitorais.

## O que esta incompleto

- Falta consolidar as novas validacoes PMB/sociodemografia no fluxo padrao de CI ou script unico de testes.
- Views finais de painel ainda nao foram implementadas, exceto `fato.vw_votacao_drilldown`.
- Falta consolidar indices finais, qualidade automatizada completa, backup e restore.

## Como retomar sem perder contexto

```powershell
cd C:\Users\mnt50\DEV\code_teste_r2
Get-Content .\docs\resumo_contexto_proxima_sessao.md -Raw
Get-Content .\docs\modelagem_banco_eleitoral_postgis.md -Raw
Get-Content .\docs\modelagem_pmb.md -Raw
Get-Content .\docs\modelo_arquivo_sociodemografia_ra_df.md -Raw
Get-Content .\docs\planejamento_implementacao_banco_eleitoral.md -Raw
Get-Content .\docs\validacoes_manuais.md -Raw
git status --short
git branch --show-current
git log --oneline -3
```

## Como reiniciar os conteineres

```powershell
cd C:\Users\mnt50\DEV\code_teste_r2
docker --version
docker compose version
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

## Proximos passos exatos

1. Subir o Docker e conferir `pg_isready`.
2. Conferir `git status --short` e preservar alteracoes pendentes.
3. Regenerar JSONs derivados se `fontes/` tiver mudado:

```powershell
python scripts\build_pmb_eleitorado_json.py
python scripts\build_ra_sociodemografia_json.py
```

4. Se for necessario reexecutar as cargas PMB/sociodemografia, aplicar o bloco:

```powershell
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/01_staging/01_staging_small_medium.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/01_staging/02_staging_large.sql
python scripts\load_staging.py
python scripts\load_large_staging.py --include-pmb-go
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/01_dim_uf.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/07_dim_perfil_eleitor.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/02_dimensoes/08_dim_municipio_recorte_pmb.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/04_fatos/04_fato_eleitorado_perfil_municipio_pmb.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f /sql/04_fatos/05_fato_sociodemografia_ra.sql
```

5. Testes SQL novos ja criados:

- `tests/sql/13_pmb_test.sql`: valida 12 municipios, recorte PMB, 34.927 linhas na fato municipal, soma `qt_eleitores = 759538` e ausencia de erro PMB.
- `tests/sql/14_sociodemografia_ra_test.sql`: valida 37 RAs, 592 indicadores, 37 resumos, populacao total 2.982.816, quatro RAs do desdobramento e ausencia de erro sociodemografico.

6. Rodar suite de testes e consultas manuais:

```powershell
Get-ChildItem tests\sql\*.sql | Sort-Object Name | ForEach-Object { docker compose exec -T db psql -v ON_ERROR_STOP=1 -U eleitoral_app -d eleitoral -f ("/tests/sql/" + $_.Name) }
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(*) from dim.municipio;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select rg.codigo, count(*) from dim.recorte_geografico rg join dim.recorte_municipio rm on rm.recorte_id = rg.recorte_id group by rg.codigo;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select sum(qt_eleitores) from fato.eleitorado_perfil_municipio;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select count(distinct ra_id), count(*) from fato.sociodemografia_ra;"
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select severidade, regra, count(*) from aux.qualidade_dado group by severidade, regra order by severidade, regra;"
```

7. Implementar views/indices de consulta para paineis, priorizando agregacoes eleitorais por RA/local/secao e joins opcionais com `fato.sociodemografia_ra`.
8. Criar rotina unica de execucao das cargas/testes para reduzir comandos manuais.

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
```

## Validacao rapida ao retomar

```powershell
python scripts\build_ra_sociodemografia_json.py
python -X utf8 -c "import json; d=json.load(open('fontes/perfil_sociodemografico_ra_df_2025_estruturado.json',encoding='utf-8')); ras=d['regioes_administrativas']; print('ras', len(ras)); print('global', d['sociodemografia_geral_df']['demografia_raca_cor_geral']['total_geral']); print('sum', sum(ra['populacao_raca_cor']['total_geral'] for ra in ras)); print('fixed', [(ra['ra_nome'], ra['populacao_raca_cor']['total_geral']) for ra in ras if ra['ra_nome'] in ['GAMA','VICENTE PIRES','26 DE SETEMBRO','PONTE ALTA']]); print('adjusted_count', sum(1 for ra in ras if ra.get('derivacao',{}).get('tipo_ajuste_total_df') == 'rateio_proporcional_total_oficial'))"
```

Resultado esperado:

```text
RAs estruturadas: 37
Populacao DF: 2982816
ras 37
global 2982816
sum 2982816
fixed [('GAMA', 88496), ('VICENTE PIRES', 75668), ('26 DE SETEMBRO', 29394), ('PONTE ALTA', 45452)]
adjusted_count 33
```
