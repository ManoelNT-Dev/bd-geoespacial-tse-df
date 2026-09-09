# Planejamento de implementacao do banco eleitoral PostgreSQL/PostGIS

Este plano organiza a implementacao do banco de dados relacional e geoespacial descrito em `modelagem_banco_eleitoral_postgis.md`. A execucao deve ser incremental: cada etapa entrega uma parte isolada, testavel e validavel antes de avancar.

## Premissas

- Banco em conteineres com persistencia de dados.
- PostgreSQL com PostGIS habilitado.
- Carga inicial focada em estrutura, staging, dimensoes e fatos derivadas das fontes disponiveis.
- `votacao_secao_2022_DF.csv` sera usado apenas como amostra piloto/modelagem da estrutura de votacao. A carga completa ocorrera somente com os dados de votacao 2026, quando estiverem disponiveis na mesma estrutura.
- Arquivos fonte permanecem em `fontes/`.
- Toda etapa deve ter script proprio, teste proprio e consultas manuais de conferencia.

## Estrutura recomendada do projeto

```text
.
├── docker-compose.yml
├── .env.example
├── fontes/
├── modelagem_banco_eleitoral_postgis.md
├── planejamento_implementacao_banco_eleitoral.md
├── sql/
│   ├── 00_extensions_schemas.sql
│   ├── 01_staging/
│   ├── 02_dimensoes/
│   ├── 03_geoespacial/
│   ├── 04_fatos/
│   ├── 05_views/
│   └── 99_qualidade/
├── scripts/
│   ├── load_staging.py
│   ├── load_shapefile.py
│   ├── transform_dimensoes.py
│   └── run_quality_checks.py
├── tests/
│   ├── sql/
│   └── expected/
└── docs/
    ├── diario_implementacao.md
    └── validacoes_manuais.md
```

## Estrategia de conteineres

Servico minimo:

- `db`: PostgreSQL + PostGIS.
- Volume persistente para `/var/lib/postgresql/data`.
- Volume somente leitura para `fontes/`, quando scripts de carga rodarem dentro do conteiner.
- Healthcheck com `pg_isready`.

Opcional:

- `adminer` ou `pgadmin` para inspecao visual.
- `etl`: conteiner Python para cargas e validacoes.

Variaveis esperadas:

```text
POSTGRES_DB=eleitoral
POSTGRES_USER=eleitoral_app
POSTGRES_PASSWORD=trocar_senha
POSTGRES_HOST=db
POSTGRES_PORT=5432
```

## Padrao de trabalho por etapa

Cada etapa deve seguir o mesmo ciclo:

1. Criar ou alterar somente os arquivos da etapa.
2. Executar scripts SQL/migracao.
3. Rodar testes automatizados simples.
4. Rodar consultas manuais de validacao.
5. Registrar resultado em `docs/diario_implementacao.md`.
6. So entao avancar para a etapa seguinte.

Formato recomendado para registro:

```md
## Etapa X - Nome

- Data:
- Scripts executados:
- Resultado:
- Consultas manuais:
- Divergencias encontradas:
- Decisao:
```

## Etapa 0 - Preparacao do workspace

Objetivo: criar a estrutura inicial de pastas e padroes de scripts.

Entregaveis:

- Pastas `sql/`, `scripts/`, `tests/` e `docs/`.
- `.env.example`.
- `docs/diario_implementacao.md`.
- `docs/validacoes_manuais.md`.

Validacao:

```powershell
Get-ChildItem -Recurse -Depth 2
```

Criterio de aceite:

- Estrutura criada.
- Nenhum arquivo fonte em `fontes/` alterado.

## Etapa 1 - Conteineres e persistencia

Objetivo: criar e validar o ambiente Docker.

Entregaveis:

- `docker-compose.yml`.
- Volume nomeado, por exemplo `postgres_data`.
- Healthcheck do banco.
- Porta local exposta, por exemplo `5432:5432`.

Testes:

```powershell
docker compose up -d
docker compose ps
docker compose exec db pg_isready -U eleitoral_app -d eleitoral
```

Validacao de persistencia:

```sql
create table if not exists aux_teste_persistencia (id int primary key);
insert into aux_teste_persistencia values (1) on conflict do nothing;
```

Depois reiniciar:

```powershell
docker compose down
docker compose up -d
```

Conferir:

```sql
select * from aux_teste_persistencia;
```

Criterio de aceite:

- Banco sobe saudavel.
- Dados permanecem apos reinicio.
- Conexao local funciona por `psql`, DBeaver, DataGrip ou pgAdmin.

## Etapa 2 - Extensoes e schemas

Objetivo: instalar extensoes e criar schemas base.

Script:

- `sql/00_extensions_schemas.sql`

Conteudo esperado:

```sql
create extension if not exists postgis;
create extension if not exists unaccent;

create schema if not exists stg;
create schema if not exists dim;
create schema if not exists fato;
create schema if not exists geo;
create schema if not exists aux;
```

Consultas manuais:

```sql
select postgis_full_version();

select schema_name
from information_schema.schemata
where schema_name in ('stg', 'dim', 'fato', 'geo', 'aux')
order by schema_name;
```

Criterio de aceite:

- PostGIS ativo.
- Schemas criados.

## Etapa 3 - Staging dos arquivos pequenos e medios

Objetivo: criar e testar tabelas de staging sem transformacao de negocio.

Escopo inicial:

- `stg.consulta_cand_2026_df`
- `stg.consulta_cand_complementar_2026_df`
- `stg.eleitorado_local_votacao_2026_df`
- `stg.tre_locais_2026_df`
- `stg.tre_locais_secao_2026_df`
- `stg.tre_locais_secao_agrupadas_2026_df`
- `stg.tre_secoes_2026_df`
- `stg.geo_ra_centroid_atualizado`
- `stg.ra_shapefile`

Entregaveis:

- Scripts DDL em `sql/01_staging/`.
- Script de carga parametrizado em `scripts/load_staging.py`.
- Log de carga com quantidade de linhas por arquivo.

Regras:

- Preservar colunas originais como `text`.
- Incluir `source_file`, `loaded_at` e `row_number`.
- Ignorar a primeira linha `Totais` nas planilhas XLSX apenas na carga operacional; opcionalmente manter em staging com flag `is_total`.
- CSVs TSE/TRE devem ser lidos como Latin-1 e delimitador `;`.

Consultas manuais:

```sql
select count(*) from stg.consulta_cand_2026_df;
select count(*) from stg.consulta_cand_complementar_2026_df;
select count(*) from stg.eleitorado_local_votacao_2026_df;
select count(*) from stg.tre_locais_2026_df;
select count(*) from stg.tre_secoes_2026_df;

select source_file, count(*)
from stg.consulta_cand_2026_df
group by source_file;
```

Valores esperados:

- Candidatos 2026: 661 linhas.
- Candidatos complementar 2026: 661 linhas.
- Eleitorado local 2026: 7.050 linhas.
- Locais TRE 2026: 614 linhas uteis.
- Secoes TRE 2026: 6.961 linhas uteis.

Criterio de aceite:

- Contagens batem com a analise.
- Amostras de acentuacao estao legiveis ou ha decisao documentada de encoding.
- Nenhuma transformacao destrutiva foi aplicada.

## Etapa 4 - Staging dos arquivos grandes

Objetivo: preparar a carga dos CSVs grandes com controle de desempenho.

Escopo:

- `stg.perfil_eleitor_secao_2026_df`
- `stg.votacao_secao_2022_df`

Observacao:

- A tabela de staging de votacao pode ser criada agora. O arquivo `votacao_secao_2022_DF.csv` deve permanecer restrito a amostra piloto; a carga completa sera feita somente com dados de votacao 2026 quando disponiveis na mesma estrutura.

Estrategia:

- Criar tabelas sem indices secundarios durante carga.
- Usar `COPY` ou carga em chunks.
- Criar indices apenas apos carga.
- Registrar tempo de carga e linhas processadas.

Consultas manuais para perfil:

```sql
select count(*) from stg.perfil_eleitor_secao_2026_df;

select count(distinct sg_uf || '-' || nr_zona || '-' || nr_secao)
from stg.perfil_eleitor_secao_2026_df;
```

Valores esperados:

- Perfil eleitor secao 2026: 1.233.369 linhas.
- Secoes distintas no perfil: 7.042.

Consultas manuais para votacao, quando a carga for autorizada:

```sql
select count(*) from stg.votacao_secao_2022_df;

select ano_eleicao, cd_eleicao, nr_turno, sg_uf, count(*)
from stg.votacao_secao_2022_df
group by ano_eleicao, cd_eleicao, nr_turno, sg_uf;

select cd_cargo, ds_cargo, count(*)
from stg.votacao_secao_2022_df
group by cd_cargo, ds_cargo
order by cd_cargo;
```

Valores esperados para votacao:

- Votacao 2022: 1.238.611 linhas.
- Eleicao unica: 2022, codigo 546, turno 1, DF.
- Cargos: 3, 5, 6 e 8.

Criterio de aceite:

- Tabelas grandes carregam sem estouro de memoria.
- Contagens batem.
- Tempo de carga registrado.

## Etapa 5 - Dimensao UF

Objetivo: criar e popular `dim.uf`.

Entregaveis:

- `sql/02_dimensoes/01_dim_uf.sql`
- Teste SQL em `tests/sql/01_dim_uf_test.sql`

Consulta manual:

```sql
select *
from dim.uf
order by sigla;
```

Resultado esperado:

- Uma linha para `DF` com nome `Distrito Federal`.

Criterio de aceite:

- `sigla` unica.
- `uf_id` referenciavel pelas demais dimensoes.

## Etapa 6 - Dimensao eleicao

Objetivo: criar e popular `dim.eleicao`.

Fontes:

- `stg.consulta_cand_2026_df`
- `stg.eleitorado_local_votacao_2026_df`
- `stg.votacao_secao_2022_df`, apenas quando carregada

Consulta manual:

```sql
select ano, turno, cd_eleicao, ds_eleicao, dt_eleicao
from dim.eleicao
order by ano, turno, cd_eleicao;
```

Validacoes:

```sql
select ano, turno, cd_eleicao, count(*)
from dim.eleicao
group by ano, turno, cd_eleicao
having count(*) > 1;
```

Criterio de aceite:

- Eleicao 2026 criada a partir das fontes de 2026.
- Eleicao 2022 criada quando a etapa de votacao for executada.
- Nenhuma duplicidade em `ano + turno + cd_eleicao`.

## Etapa 7 - Geoespacial de RAs

Objetivo: criar `dim.regiao_administrativa` e `geo.ra_geometria`.

Entregaveis:

- `sql/03_geoespacial/01_ra_geometria.sql`
- Script de importacao do shapefile.
- Carga dos centroides do GeoJSON.
- Regra para calcular centroides ausentes.

Regras:

- Importar shapefile em EPSG:31983 e transformar para EPSG:4326.
- Carregar 37 RAs.
- Importar 35 centroides do GeoJSON.
- Calcular centroides faltantes por `st_pointonsurface(geom)`.
- Marcar origem em `centroid_origem`.

Consultas manuais:

```sql
select count(*) from dim.regiao_administrativa;

select centroid_origem, count(*)
from geo.ra_geometria
group by centroid_origem
order by centroid_origem;

select ra.ra_codigo, ra.ra_nome, g.centroid_origem,
       st_x(g.centroid_geom) as lon,
       st_y(g.centroid_geom) as lat
from dim.regiao_administrativa ra
join geo.ra_geometria g on g.ra_id = ra.ra_id
where ra.ra_codigo in ('RA-XXXVI', 'RA-XXXVII')
   or ra.ra_nome_normalizado in ('26 DE SETEMBRO', 'PONTE ALTA');
```

Valores esperados:

- 37 RAs.
- 35 centroides com origem `geojson`.
- 2 centroides com origem `calculado_shapefile`.

Criterio de aceite:

- Todas as RAs tem geometria.
- Todas as RAs tem centroide.
- Pontos calculados ficam dentro dos respectivos poligonos.

Validacao espacial:

```sql
select ra.ra_codigo, ra.ra_nome
from dim.regiao_administrativa ra
join geo.ra_geometria g on g.ra_id = ra.ra_id
where not st_contains(g.geom, g.centroid_geom);
```

Resultado esperado: zero linhas.

## Etapa 8 - Dimensoes eleitorais basicas

Objetivo: criar dimensoes auxiliares de classificacao.

Escopo:

- `dim.zona_eleitoral`
- `dim.cargo_eleitoral`
- `dim.partido_politico`
- `dim.federacao`
- `dim.coligacao`

Consultas manuais:

```sql
select count(*) from dim.zona_eleitoral;

select cd_cargo, ds_cargo
from dim.cargo_eleitoral
order by cd_cargo;

select nr_partido, sigla, nome
from dim.partido_politico
order by nr_partido;
```

Validacoes:

```sql
select nr_partido, count(*)
from dim.partido_politico
group by nr_partido
having count(*) > 1;

select cd_cargo, count(*)
from dim.cargo_eleitoral
group by cd_cargo
having count(*) > 1;
```

Criterio de aceite:

- Codigos unicos.
- Partidos e cargos populados a partir das fontes disponiveis.
- Zonas derivadas de eleitorado/local/secoes.

## Etapa 9 - Dimensao local de votacao

Objetivo: criar e popular `dim.local_votacao`.

Fontes:

- `stg.eleitorado_local_votacao_2026_df`
- `stg.tre_locais_2026_df`
- `stg.votacao_secao_2022_df`, quando a carga de votacao for feita

Regras:

- Chave natural: `eleicao_id + uf_id + nr_zona + nr_local_votacao`.
- Considerar como principais os 614 pares `zona + local` coincidentes com a planilha oficial do TRE.
- Preservar pares adicionais encontrados no CSV oficial com flag de nao principal para checagem futura.
- Gerar `geom` a partir de latitude/longitude quando disponiveis.
- Derivar `ra_id` por intersecao espacial.
- Para locais sem coordenada, registrar pendencia em `aux.qualidade_dado`.

Consultas manuais:

```sql
select count(*) from dim.local_votacao;

select count(*) as locais_sem_geom
from dim.local_votacao
where geom is null;

select count(*) as locais_sem_ra
from dim.local_votacao
where ra_id is null;

select ra.ra_nome, count(*) as locais
from dim.local_votacao lv
left join dim.regiao_administrativa ra on ra.ra_id = lv.ra_id
group by ra.ra_nome
order by locais desc;
```

Valores esperados para 2026:

- 108 numeros de locais distintos.
- 622 combinacoes `zona + local` no CSV oficial.
- 614 combinacoes `zona + local` nas planilhas TRE, todas contidas no CSV oficial e marcadas como principais.
- 8 combinacoes adicionais do CSV oficial, preservadas para checagem futura.

Criterio de aceite:

- Locais com coordenada valida possuem RA.
- Locais sem RA ficam explicitamente listados para curadoria.
- Nomes/endereco preservados em alias quando houver divergencia entre fontes.

## Etapa 10 - Dimensao secao eleitoral

Objetivo: criar e popular `dim.secao_eleitoral`.

Fontes:

- `stg.eleitorado_local_votacao_2026_df`
- `stg.tre_secoes_2026_df`
- `stg.votacao_secao_2022_df`, quando carregada

Regras:

- Chave natural: `eleicao_id + uf_id + nr_zona + nr_secao`.
- Herdar `ra_id`, `latitude`, `longitude` e `geom` do local efetivo.
- Para `DS_TIPO_SECAO_AGREGADA = Agregada`, considerar o `NR_LOCAL_VOTACAO` como local da secao principal indicada em `NR_SECAO_PRINCIPAL`; validar que a secao principal existe e que a agregada herda seu `local_id`.
- Registrar secoes agregadas e a secao principal.
- Conciliar `QT_ELEITOR_SECAO`, `APTOS` e `SUSPENSOS`.

Consultas manuais:

```sql
select count(*) from dim.secao_eleitoral;

select ds_tipo_secao_agregada, count(*)
from dim.secao_eleitoral
group by ds_tipo_secao_agregada;

select count(*) as secoes_sem_local
from dim.secao_eleitoral
where local_id is null;

select count(*) as secoes_sem_ra
from dim.secao_eleitoral
where ra_id is null;
```

Valores esperados para 2026:

- 7.050 secoes no CSV `eleitorado_local_votacao_2026_DF.csv`.
- 6.961 secoes principais oficiais na planilha TRE.
- 7.042 secoes representadas pela planilha TRE quando expandidas as secoes agregadas entre parenteses.
- 81 secoes agregadas no CSV.
- 8 secoes adicionais presentes apenas no CSV, preservadas com flag para checagem futura.

Criterio de aceite:

- Divergencia entre fontes documentada em `aux.qualidade_dado`.
- Secoes com local e RA quando houver coordenadas.

## Etapa 11 - Dimensao candidato

Objetivo: criar e popular `dim.candidato`.

Fontes:

- `stg.consulta_cand_2026_df`
- `stg.consulta_cand_complementar_2026_df`

Regras:

- Unir por `SQ_CANDIDATO`.
- Relacionar partido, cargo, federacao e coligacao.
- Tratar CPF como dado sensivel; preferir hash ou nao carregar.

Consultas manuais:

```sql
select count(*) from dim.candidato;

select ce.ds_cargo, count(*) as candidatos
from dim.candidato c
join dim.cargo_eleitoral ce on ce.cargo_id = c.cargo_id
group by ce.ds_cargo
order by candidatos desc;

select pp.sigla, count(*) as candidatos
from dim.candidato c
left join dim.partido_politico pp on pp.partido_id = c.partido_id
group by pp.sigla
order by candidatos desc;
```

Valor esperado:

- 661 candidatos para 2026.

Criterio de aceite:

- Todos os candidatos 2026 carregados.
- Nenhum `SQ_CANDIDATO` duplicado por eleicao.
- Dados complementares incorporados quando existem.

## Etapa 12 - Perfil do eleitor

Objetivo: criar `dim.perfil_eleitor` e `fato.eleitorado_perfil_secao`.

Fonte:

- `stg.perfil_eleitor_secao_2026_df`

Regras:

- Atributos demograficos em `dim.perfil_eleitor`.
- Contagens em `fato.eleitorado_perfil_secao`.
- Relacionar cada linha a `secao_id`, `local_id` e `ra_id`.
- Consolidar duplicidades naturais de `secao + perfil` por soma das medidas, preservando a quantidade de linhas brutas em `source_row_count`.

Consultas manuais:

```sql
select count(*) from dim.perfil_eleitor;
select count(*) from fato.eleitorado_perfil_secao;

select sum(qt_eleitores) as eleitores
from fato.eleitorado_perfil_secao;

select ra.ra_nome, sum(f.qt_eleitores) as eleitores
from fato.eleitorado_perfil_secao f
left join dim.regiao_administrativa ra on ra.ra_id = f.ra_id
group by ra.ra_nome
order by eleitores desc;
```

Validacao por secao:

```sql
select se.secao_id,
       se.qt_eleitores_aptos,
       sum(f.qt_eleitores) as soma_perfil
from dim.secao_eleitoral se
join fato.eleitorado_perfil_secao f on f.secao_id = se.secao_id
group by se.secao_id, se.qt_eleitores_aptos
having se.qt_eleitores_aptos is not null
   and se.qt_eleitores_aptos <> sum(f.qt_eleitores)
limit 50;
```

Criterio de aceite:

- Fato representa todas as linhas do perfil por agregacao `secao + perfil`.
- A soma de `source_row_count` deve bater com as 1.233.369 linhas brutas da fonte.
- Divergencias entre perfil e aptos por secao registradas.

## Etapa 13 - Estrutura de votacao de 2022

Objetivo: criar as tabelas e views para votacao sem executar a importacao completa.

Escopo:

- `stg.votacao_secao_2022_df`
- `dim.votavel`
- `fato.votacao_candidato_secao`
- `fato.apuracao_secao`
- `fato.vw_votacao_drilldown`

Regras de modelagem:

- `tipo_votavel = nominal` quando `SQ_CANDIDATO` for candidato real.
- `tipo_votavel = legenda` quando `SQ_CANDIDATO = -3`.
- `tipo_votavel = branco` quando `NR_VOTAVEL = 95` e `SQ_CANDIDATO = -1`.
- `tipo_votavel = nulo` quando `NR_VOTAVEL = 96` e `SQ_CANDIDATO = -1`.
- `candidato_id` nulo para legenda, branco e nulo.
- `ra_id` herdado do local de votacao.

Testes sem carga:

```sql
select table_schema, table_name
from information_schema.tables
where (table_schema, table_name) in (
  ('dim', 'votavel'),
  ('fato', 'votacao_candidato_secao'),
  ('fato', 'apuracao_secao')
)
order by table_schema, table_name;

select table_schema, table_name
from information_schema.views
where table_schema = 'fato'
  and table_name = 'vw_votacao_drilldown';
```

Criterio de aceite:

- Tabelas criadas.
- Indices criados.
- View compila.
- Nenhuma carga massiva executada nesta etapa.

## Etapa 14 - Carga piloto de votacao

Objetivo: testar a estrutura de votacao com subconjunto pequeno antes da carga completa.

Estrategia:

- Carregar apenas uma amostra controlada.
- Implementado na Etapa 14 com amostra deterministica da ZE 20: 44.464 linhas.
- Popular `dim.votavel` para a amostra.
- Popular `fato.votacao_candidato_secao`.
- Popular `fato.apuracao_secao`.
- Validar drill-down.

Consultas manuais:

```sql
select tipo_votavel, count(*), sum(qt_votos)
from fato.votacao_candidato_secao
group by tipo_votavel
order by tipo_votavel;

select uf, ra_nome, local_votacao, nr_zona, nr_secao, ds_cargo,
       tipo_votavel, nr_votavel, nm_votavel, qt_votos
from fato.vw_votacao_drilldown
order by uf, ra_nome, local_votacao, nr_zona, nr_secao, ds_cargo, qt_votos desc
limit 100;
```

Consulta de drill-down por candidato/votavel:

```sql
select uf, ra_nome, sum(qt_votos) as votos
from fato.vw_votacao_drilldown
where ds_cargo = 'DEPUTADO DISTRITAL'
  and tipo_votavel = 'nominal'
group by uf, ra_nome
order by votos desc;
```

Criterio de aceite:

- Soma de votos da amostra bate com staging da amostra.
- Branco, nulo, legenda e nominal aparecem classificados corretamente.
- A view responde em tempo aceitavel para amostra.
- Carga completa de `votacao_secao_2022_DF.csv` nao ocorrera; 2022 permanece apenas como piloto tecnico.

## Etapa 15 - Recorte PMB

Objetivo: incorporar a Periferia Metropolitana de Brasilia como recorte de municipios goianos, sem misturar municipios com RAs do DF.

Fontes:

- `fontes/eleitorado_PMB_2026.json`
- `fontes/perfil_eleitor_secao_2026_GO.csv`

Entregaveis:

- `scripts/build_pmb_eleitorado_json.py`
- `stg.eleitorado_pmb_2026_json`
- `stg.perfil_eleitor_secao_2026_go`
- `dim.municipio`
- `dim.recorte_geografico`
- `dim.recorte_municipio`
- `fato.eleitorado_perfil_municipio`
- `docs/modelagem_pmb.md`

Regras:

- `municipio_codigo` preserva o codigo TSE.
- `municipio_codigo_ibge` e usado para integracao territorial e populacao IBGE.
- PMB e recorte de municipios, nao RA.
- Perfil PMB e agregado a partir do CSV GO por municipio e combinacao demografica.
- Populacao municipal vem de IBGE/SIDRA, tabela 6579, variavel 9324, periodo 2025.

Validacoes:

```powershell
python scripts\build_pmb_eleitorado_json.py
python -m json.tool fontes\eleitorado_PMB_2026.json
python scripts\load_large_staging.py --include-pmb-go
```

Consultas manuais:

```sql
select count(*) from dim.municipio;

select rg.codigo, count(*)
from dim.recorte_geografico rg
join dim.recorte_municipio rm on rm.recorte_id = rg.recorte_id
group by rg.codigo;

select sum(qt_eleitores)
from fato.eleitorado_perfil_municipio;
```

Valores esperados:

- 12 municipios no recorte PMB.
- 759.538 eleitores no JSON PMB.
- 1.362.821 habitantes na soma IBGE/SIDRA 2025.

Criterio de aceite:

- Recorte PMB carrega sem afetar RAs do DF.
- Todos os municipios possuem codigo TSE e IBGE.
- Soma da fato municipal fecha com o JSON PMB.

## Etapa 16 - Sociodemografia por RA

Objetivo: incorporar indicadores sociodemograficos por RA em estrutura separada da modelagem eleitoral.

Fontes:

- `fontes/perfil_eleitorado_df_2025_consolidado_12jan2026.json`
- `fontes/perfil_sociodemografico_ra_df_2025_estruturado.json`

Entregaveis:

- `scripts/build_ra_sociodemografia_json.py`
- `stg.perfil_sociodemografico_ra_df_json`
- `dim.indicador_sociodemografico`
- `fato.sociodemografia_ra`
- `fato.sociodemografia_ra_resumo`
- `docs/modelo_arquivo_sociodemografia_ra_df.md`

Regras:

- O arquivo estruturado deve conter apenas sociodemografia, sem `totais` ou `perfil` eleitoral.
- `26 DE SETEMBRO` herda proporcionalmente os indicadores de `VICENTE PIRES`.
- `PONTE ALTA` herda proporcionalmente os indicadores de `GAMA`.
- `VICENTE PIRES` e `GAMA` sao ajustadas pela populacao subtraida.
- Quantidades sao ajustadas proporcionalmente e arredondadas para fechamento.
- Percentuais e medias sao preservados quando nao ha microdados.
- A soma das RAs deve fechar no total oficial do DF: 2.982.816.
- As quatro RAs do desdobramento ficam fixas; a diferenca remanescente e rateada proporcionalmente nas demais 33 RAs.
- A fato sociodemografica se relaciona ao restante do banco por `ra_id`.

Validacoes:

```powershell
python scripts\build_ra_sociodemografia_json.py
python -m json.tool fontes\perfil_sociodemografico_ra_df_2025_estruturado.json
```

Consultas manuais:

```sql
select count(distinct ra_id), count(*)
from fato.sociodemografia_ra;

select ra.ra_nome, i.codigo, f.valor_num, f.percentual
from fato.sociodemografia_ra f
join dim.regiao_administrativa ra on ra.ra_id = f.ra_id
join dim.indicador_sociodemografico i on i.indicador_id = f.indicador_id
where ra.ra_nome_normalizado in ('GAMA', 'VICENTE PIRES', '26 DE SETEMBRO', 'PONTE ALTA')
  and i.codigo = 'populacao_total'
order by ra.ra_nome;
```

Valores esperados:

- 37 RAs no JSON estruturado.
- Populacao por RA soma 2.982.816.
- `GAMA`: 88.496.
- `VICENTE PIRES`: 75.668.
- `26 DE SETEMBRO`: 29.394.
- `PONTE ALTA`: 45.452.

Criterio de aceite:

- Nenhuma RA sociodemografica sem correspondencia em `dim.regiao_administrativa`.
- `fato.sociodemografia_ra` possui registros para 37 RAs.
- Campos eleitorais permanecem fora do JSON estruturado.

## Etapa 17 - Carga completa de votacao de 2026 futura

Objetivo: carregar os dados completos de votacao 2026 quando estiverem disponiveis na mesma estrutura validada com a amostra piloto 2022.

Estrategia:

- Carregar staging por `COPY` ou chunks.
- Criar/atualizar locais e secoes de 2026 a partir da fonte.
- Conciliar locais com coordenadas conhecidas.
- Popular `dim.votavel`.
- Popular `fato.votacao_candidato_secao`.
- Popular `fato.apuracao_secao`.

Consultas manuais:

```sql
select count(*) from stg.votacao_secao_2022_df;
select count(*) from fato.votacao_candidato_secao;

select tipo_votavel, count(*) as linhas, sum(qt_votos) as votos
from fato.votacao_candidato_secao
group by tipo_votavel
order by tipo_votavel;

select cargo_id, count(*) as linhas, sum(qt_votos) as votos
from fato.votacao_candidato_secao
group by cargo_id
order by cargo_id;
```

Valores esperados:

- Contagem oficial da fonte de votacao 2026 na staging.
- Mesma contagem na fato, salvo regra documentada de exclusao/agregacao.

Criterio de aceite:

- Contagens batem.
- Fato sem duplicidade de chave primaria.
- Drill-down UF -> RA -> local -> secao operacional.
- Pendencias de RA/local sem coordenada registradas.

## Etapa 18 - Views, materializacoes e indices de consulta

Objetivo: preparar o banco para consulta interativa.

Observacao: esta etapa pode avancar antes da carga completa de votacao 2026, usando a amostra piloto 2022 da ZE 20 e os fatos completos de eleitorado 2026.

Contexto de consumo futuro:

- A especificacao `fontes/especificacao-tecnica-painel-eleitoral.md` indica que as views devem atender paineis de mapa, KPIs, rankings, Pareto, heatmap, barras empilhadas, tabelas analiticas e drill-down.
- A hierarquia principal de navegacao sera `DF -> RA -> local de votacao -> secao`, com filtros por eleicao, cargo, turno, candidato/votavel, lider, margem, busca textual e Pareto.
- Os paineis de resultados gerais precisam de total bruto, votos validos, brancos, nulos, top candidatos, lider por RA/local/secao, segundo colocado, margem em votos e percentual, regioes competitivas e cobertura de zonas/locais/secoes.
- Os paineis candidato-especificos precisam de votos do candidato, percentual no nivel filtrado, percentual no total, posicao/ranking, top2 comparativo, Pareto 80%, vitorias e zeros por RA/local/secao.
- O painel de perfil do eleitor precisa de agregacoes por RA/local/secao e dimensao demografica, com dominante por genero, faixa etaria, estado civil, escolaridade e demais atributos disponiveis.
- As respostas futuras devem se aproximar dos formatos atuais dos JSONs legados para reduzir refatoracao do frontend.

Entregaveis:

- Views de drill-down.
- Views agregadas por RA, local, secao, candidato e partido.
- Indices B-tree e GiST revisados.
- Possiveis materialized views para consultas pesadas.

Views recomendadas:

- `fato.vw_votacao_drilldown`
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

Contratos minimos de colunas:

- Views de resultado por nivel: `eleicao_id`, `ano`, `turno`, `cd_eleicao`, `cargo_id`, `cd_cargo`, `ds_cargo`, `nivel`, `ra_id`, `ra_codigo`, `ra_nome`, `local_id`, `nr_local_votacao`, `local_votacao`, `secao_id`, `nr_zona`, `nr_secao`, `votavel_id`, `nr_votavel`, `nm_votavel`, `tipo_votavel`, `partido_id`, `sg_partido`, `qt_votos`, `votos_validos_nivel`, `percentual_no_nivel`, `percentual_no_total`, `ranking`, `cum_pct`, `dentro_pareto80`.
- Views de top2/margem: chaves do nivel, `lider_nr_votavel`, `lider_nm_votavel`, `lider_votos`, `lider_percentual`, `segundo_nr_votavel`, `segundo_nm_votavel`, `segundo_votos`, `margem_votos`, `margem_percentual`, `tipo_regiao`.
- Views geograficas: chaves do nivel, nome, endereco quando aplicavel, latitude, longitude, `geom`, totais de votos/eleitores e metricas de intensidade para mapa.
- Views de eleitorado: chaves de RA/local/secao, dimensao, codigo, descricao, quantidade, percentual e campos auxiliares para identificar categoria dominante.

Indices prioritarios:

- `fato.votacao_candidato_secao(eleicao_id, cargo_id, votavel_id)`.
- `fato.votacao_candidato_secao(eleicao_id, cargo_id, ra_id)`.
- `fato.votacao_candidato_secao(eleicao_id, cargo_id, local_id)`.
- `fato.votacao_candidato_secao(eleicao_id, cargo_id, secao_id)`.
- `fato.votacao_candidato_secao(eleicao_id, cargo_id, tipo_votavel)`.
- `dim.votavel(eleicao_id, cargo_id, nr_votavel)`.
- `dim.local_votacao(eleicao_id, uf_id, ra_id, nr_zona, nr_local_votacao)`.
- `dim.secao_eleitoral(eleicao_id, uf_id, local_id, nr_zona, nr_secao)`.
- GiST em geometrias de `geo.ra_geometria` e `dim.local_votacao` quando ainda nao existir.

Consultas manuais:

```sql
explain analyze
select ra_nome, nm_votavel, sum(qt_votos)
from fato.vw_votacao_drilldown
where ds_cargo = 'DEPUTADO DISTRITAL'
group by ra_nome, nm_votavel
order by sum(qt_votos) desc
limit 20;
```

Criterio de aceite:

- Consultas principais usam indices adequados.
- Tempo de resposta aceitavel para filtros por RA/local/cargo/votavel.

## Etapa 19 - Qualidade de dados

Objetivo: automatizar validacoes e registrar divergencias.

Entregaveis:

- `sql/99_qualidade/*.sql`
- `scripts/run_quality_checks.py`
- Popular `aux.qualidade_dado`

Regras minimas:

- RA sem geometria.
- RA sem centroide.
- Local com coordenada invalida.
- Local com ponto fora das RAs.
- Secao sem local.
- Secao sem RA.
- Divergencia de aptos entre fontes.
- Candidato sem partido.
- Voto de legenda sem partido.
- Votacao sem secao correspondente.
- Votacao sem votavel correspondente.

Consulta manual:

```sql
select severidade, regra, count(*)
from aux.qualidade_dado
group by severidade, regra
order by severidade, regra;
```

Criterio de aceite:

- Regras executam sem erro.
- Divergencias sao rastreaveis por entidade, chave natural e arquivo fonte.

## Etapa 20 - Backup, restore e reprocessamento

Objetivo: garantir recuperacao e repetibilidade.

Entregaveis:

- Script de backup.
- Script de restore.
- Procedimento de reset controlado de schemas de staging e mart.

Testes:

```powershell
docker compose exec db pg_dump -U eleitoral_app -d eleitoral -Fc -f /tmp/eleitoral.dump
docker compose exec db pg_restore -l /tmp/eleitoral.dump
```

Criterio de aceite:

- Backup gerado.
- Restore listavel.
- Procedimento documentado.

## Estrategia geral de testes

### Testes automatizados simples

Usar SQL com consultas que devem retornar zero linhas para erro:

```sql
-- Exemplo: duplicidade de UF
select sigla, count(*)
from dim.uf
group by sigla
having count(*) > 1;
```

Padrao:

- Arquivo em `tests/sql/`.
- Cada teste retorna zero linhas quando passa.
- Testes de contagem retornam valor esperado documentado.

### Testes manuais por camada

Staging:

```sql
select source_file, count(*)
from stg.consulta_cand_2026_df
group by source_file;
```

Dimensoes:

```sql
select count(*) from dim.regiao_administrativa;
select count(*) from dim.local_votacao;
select count(*) from dim.secao_eleitoral;
```

Geoespacial:

```sql
select ra.ra_nome, st_area(g.geom::geography) / 1000000 as area_km2_calculada
from dim.regiao_administrativa ra
join geo.ra_geometria g on g.ra_id = ra.ra_id
order by area_km2_calculada desc
limit 10;
```

Eleitorado:

```sql
select ra.ra_nome, sum(f.qt_eleitores) as eleitores
from fato.eleitorado_perfil_secao f
join dim.regiao_administrativa ra on ra.ra_id = f.ra_id
group by ra.ra_nome
order by eleitores desc;
```

Votacao:

```sql
select ra_nome, local_votacao, nr_zona, nr_secao, nm_votavel, sum(qt_votos)
from fato.vw_votacao_drilldown
where tipo_votavel = 'nominal'
group by ra_nome, local_votacao, nr_zona, nr_secao, nm_votavel
order by sum(qt_votos) desc
limit 50;
```

## Sequencia recomendada de sessoes de trabalho

Sessao 1:

- Etapa 0 e Etapa 1.
- Resultado: conteiner PostgreSQL/PostGIS com persistencia validada.

Sessao 2:

- Etapa 2 e parte da Etapa 3.
- Resultado: schemas e staging dos arquivos pequenos criados.

Sessao 3:

- Finalizar Etapa 3.
- Resultado: staging de CSVs pequenos, XLSX, GeoJSON e shapefile validada.

Sessao 4:

- Etapa 4 para `perfil_eleitor_secao_2026_DF.csv`.
- Resultado: staging grande de perfil carregada e validada.

Sessao 5:

- Etapas 5, 6 e 7.
- Resultado: UF, eleicao e RAs com geometrias/centroides.

Sessao 6:

- Etapas 8, 9 e 10.
- Resultado: zonas, locais e secoes.

Sessao 7:

- Etapas 11 e 12.
- Resultado: candidatos e perfil do eleitorado.

Sessao 8:

- Etapa 13.
- Resultado: estrutura de votacao de 2022 pronta, sem carga completa.

Sessao 9:

- Etapa 14.
- Resultado: carga piloto de votacao validada.

Sessao 10:

- Etapas 15 e 16.
- Resultado atual: scripts, SQLs e documentacao de PMB e sociodemografia por RA criados; JSONs derivados gerados; cargas executadas no Postgres; testes SQL das Etapas 15 e 16 criados e aprovados.

Sessao 11:

- Retomar por views/indices, qualidade automatizada e rotina unica de execucao das cargas/testes.

Sessao 12:

- Etapa 20.
- Resultado: backup, restore e reprocessamento documentados.

## Ordem de dependencia

```text
Conteineres
  -> Extensoes e schemas
  -> Staging
  -> UF
  -> Eleicao
  -> RAs geoespaciais
  -> Zona / cargo / partido / federacao / coligacao
  -> Local de votacao
  -> Secao eleitoral
  -> Candidato
  -> Perfil eleitor
  -> PMB municipio/recorte
  -> Sociodemografia por RA
  -> Estrutura de votacao
  -> Carga piloto de votacao
  -> Carga completa de votacao
  -> Views / indices
  -> Qualidade
  -> Backup / restore
```

## Estado de encerramento em 2026-09-09

- Etapas 0 a 14 foram executadas no banco e validadas com testes SQL existentes.
- Etapa 15 foi implementada, carregada no PostgreSQL e validada por `tests/sql/13_pmb_test.sql`.
- Etapa 16 foi implementada, carregada no PostgreSQL e validada por `tests/sql/14_sociodemografia_ra_test.sql`.
- Regra final de RA: o numero oficial considerado no projeto e 37. `26 DE SETEMBRO` e `PONTE ALTA` sao novas RAs.
- Regra final de populacao sociodemografica: total oficial DF 2.982.816; `26 DE SETEMBRO = 29394`, `PONTE ALTA = 45452`, `VICENTE PIRES = 75668`, `GAMA = 88496`; diferenca remanescente rateada nas outras 33 RAs.
- Os dados eleitorais continuam totalizados pela modelagem existente; o JSON sociodemografico estruturado nao deve carregar `totais` nem `perfil` eleitoral.
- Proximo passo operacional: implementar views/indices de consulta, consolidar qualidade automatizada e criar rotina unica de execucao das cargas/testes.

## Criterio final de conclusao

A implementacao pode ser considerada concluida quando:

- O banco roda em conteiner com persistencia validada.
- Todas as tabelas da modelagem foram criadas.
- Fontes de 2026 foram carregadas nas camadas previstas.
- RAs possuem geometrias e centroides, incluindo os 2 centroides calculados.
- Locais e secoes possuem relacao com RA quando houver coordenada.
- Perfil do eleitorado esta consultavel por UF, RA, local e secao.
- PMB esta consultavel por municipio e perfil demografico.
- Indicadores sociodemograficos estao consultaveis por RA/ano/indicador.
- Estrutura de votacao 2022 esta criada.
- Carga piloto de votacao foi validada.
- Carga completa de votacao foi executada apenas se autorizada.
- Consultas manuais de validacao estao documentadas.
- Regras de qualidade registram divergencias em `aux.qualidade_dado`.
- Backup e restore foram testados.
