# Modelagem relacional para inteligencia eleitoral - PostgreSQL/PostGIS

## 1. Fontes analisadas

Pasta `fontes`:

| Arquivo | Estrutura | Uso principal |
|---|---:|---|
| `consulta_cand_2026_DF.csv` | 661 linhas, 50 colunas, `;`, Latin-1 | candidaturas, partidos, cargos, federacoes e coligacoes |
| `consulta_cand_complementar_2026_DF.csv` | 661 linhas, 49 colunas, `;`, Latin-1 | dados complementares da candidatura, julgamento, nacionalidade, quilombola, etnia indigena |
| `eleitorado_local_votacao_2026_DF.csv` | 7.050 linhas, 41 colunas, `;`, Latin-1 | secoes por local, agregacao de secao, eleitorado por secao, coordenadas dos locais |
| `perfil_eleitor_secao_2026_DF.csv` | 1.233.369 linhas, 30 colunas, `;`, Latin-1 | perfil agregado do eleitorado por secao e atributos demograficos |
| `Locais_TRE_DF_2026.xlsx` | 614 linhas uteis, 11 colunas | locais de votacao com endereco, coordenadas, secoes, aptos e nao aptos |
| `Locais_Secao_TRE_DF_2026.xlsx` | 614 linhas uteis, 11 colunas | indicadores de distribuicao de secoes por local |
| `Locais_Secao_Agrupadas por local_TRE_DF_2026.xlsx` | 614 linhas uteis, 8 colunas | lista textual de secoes por local e totais |
| `Secoes_TRE-DF_2026.xlsx` | 6.961 linhas uteis, 7 colunas | secoes TRE com aptos e suspensos |
| `geo_ra_centroid_atualizado.json` | GeoJSON, 35 pontos, EPSG:4326 | centroides de RAs |
| `shapefile_ras/regioes_administrativas.*` | 37 poligonos, SIRGAS 2000 / UTM 23S | limites oficiais das RAs |
| `votacao_secao_2022_DF.csv` | 1.238.611 linhas, 26 colunas, `;`, Latin-1 | resultado de votacao de 2022 por cargo, votavel, local, zona e secao |

Observacoes:

- As planilhas XLSX possuem primeira linha de totais e ela deve ser ignorada na carga operacional.
- O shapefile possui 37 RAs. O GeoJSON de centroides possui 35 RAs; faltam `RA-XXXVI` / `26 DE SETEMBRO` e `XXXVII` / `PONTE ALTA`. Os centroides dessas duas RAs devem ser calculados a partir dos poligonos do shapefile.
- O arquivo `votacao_secao_2022_DF.csv` ja permite modelar a fato de votacao por secao. A importacao dos dados de 2022 fica fora deste primeiro momento, mas a estrutura deve estar preparada para ela.
- Local de votacao e secao nao trazem RA explicitamente. A RA deve ser derivada por cruzamento espacial do ponto do local com o poligono da RA.

## 2. Principios de modelagem

- Usar `stg_*` para preservar dados brutos carregados das fontes.
- Usar chaves substitutas (`bigserial`/`identity`) nas dimensoes e chaves naturais em `unique`.
- Armazenar geometrias em PostGIS:
  - `geom_utm geometry(MultiPolygon, 31983)` para limites de RA.
  - `geom geometry(MultiPolygon, 4326)` para visualizacao web.
  - `centroid_geom geometry(Point, 4326)` para centroides.
  - `geom geometry(Point, 4326)` para locais de votacao.
- Representar medidas agregaveis em tabelas de fato, nao em dimensoes.
- Manter campos de codigo e descricao da fonte para auditoria e compatibilidade com TSE/TRE.
- Tratar `#NULO`, `#NE`, `-1` e similares como valores de dominio conhecidos; converter para `NULL` apenas quando a semantica for ausencia real de dado.

## 3. Esquemas recomendados

```sql
create schema if not exists stg;
create schema if not exists dim;
create schema if not exists fato;
create schema if not exists geo;
create schema if not exists aux;

create extension if not exists postgis;
create extension if not exists unaccent;
```

## 4. Tabelas de staging

As tabelas de staging devem refletir as colunas originais, preferencialmente todas como `text` no primeiro carregamento. Isso evita perda por formato regional de numero, codigos com zeros a esquerda e datas em formatos mistos.

```sql
create table stg.consulta_cand_2026_df (
  source_file text not null,
  loaded_at timestamptz not null default now(),
  row_number bigint not null,
  dt_geracao text,
  hh_geracao text,
  ano_eleicao text,
  cd_tipo_eleicao text,
  nm_tipo_eleicao text,
  nr_turno text,
  cd_eleicao text,
  ds_eleicao text,
  dt_eleicao text,
  tp_abrangencia text,
  sg_uf text,
  sg_ue text,
  nm_ue text,
  cd_cargo text,
  ds_cargo text,
  sq_candidato text,
  nr_candidato text,
  nm_candidato text,
  nm_urna_candidato text,
  nm_social_candidato text,
  nr_cpf_candidato text,
  ds_email text,
  cd_situacao_candidatura text,
  ds_situacao_candidatura text,
  tp_agremiacao text,
  nr_partido text,
  sg_partido text,
  nm_partido text,
  nr_federacao text,
  nm_federacao text,
  sg_federacao text,
  ds_composicao_federacao text,
  sq_coligacao text,
  nm_coligacao text,
  ds_composicao_coligacao text,
  sg_uf_nascimento text,
  dt_nascimento text,
  nr_titulo_eleitoral_candidato text,
  cd_genero text,
  ds_genero text,
  cd_grau_instrucao text,
  ds_grau_instrucao text,
  cd_estado_civil text,
  ds_estado_civil text,
  cd_cor_raca text,
  ds_cor_raca text,
  cd_ocupacao text,
  ds_ocupacao text,
  cd_sit_tot_turno text,
  ds_sit_tot_turno text,
  primary key (source_file, row_number)
);
```

Criar tabelas equivalentes para:

- `stg.consulta_cand_complementar_2026_df`
- `stg.eleitorado_local_votacao_2026_df`
- `stg.perfil_eleitor_secao_2026_df`
- `stg.tre_locais_2026_df`
- `stg.tre_locais_secao_2026_df`
- `stg.tre_locais_secao_agrupadas_2026_df`
- `stg.tre_secoes_2026_df`
- `stg.geo_ra_centroid_atualizado`
- `stg.ra_shapefile`
- `stg.votacao_secao_2022_df`

Estrutura recomendada para staging da votacao de 2022:

```sql
create table stg.votacao_secao_2022_df (
  source_file text not null,
  loaded_at timestamptz not null default now(),
  row_number bigint not null,
  dt_geracao text,
  hh_geracao text,
  ano_eleicao text,
  cd_tipo_eleicao text,
  nm_tipo_eleicao text,
  nr_turno text,
  cd_eleicao text,
  ds_eleicao text,
  dt_eleicao text,
  tp_abrangencia text,
  sg_uf text,
  sg_ue text,
  nm_ue text,
  cd_municipio text,
  nm_municipio text,
  nr_zona text,
  nr_secao text,
  cd_cargo text,
  ds_cargo text,
  nr_votavel text,
  nm_votavel text,
  qt_votos text,
  nr_local_votacao text,
  sq_candidato text,
  nm_local_votacao text,
  ds_local_votacao_endereco text,
  primary key (source_file, row_number)
);
```

## 5. Dimensoes principais

### 5.1 Eleicao

```sql
create table dim.eleicao (
  eleicao_id bigint generated always as identity primary key,
  ano smallint not null,
  turno smallint not null,
  cd_eleicao integer,
  ds_eleicao text not null,
  cd_tipo_eleicao integer,
  nm_tipo_eleicao text,
  dt_eleicao date,
  tp_abrangencia text,
  unique (ano, turno, cd_eleicao)
);
```

Fonte: `consulta_cand_2026_DF.csv`, `eleitorado_local_votacao_2026_DF.csv` e `votacao_secao_2022_DF.csv`.

### 5.2 Unidade da federacao

```sql
create table dim.uf (
  uf_id smallint generated always as identity primary key,
  sigla char(2) not null unique,
  nome text not null,
  codigo_ibge integer
);
```

Para a base atual: `DF`, `Distrito Federal`.

### 5.3 Regiao administrativa

```sql
create table dim.regiao_administrativa (
  ra_id bigint generated always as identity primary key,
  uf_id smallint not null references dim.uf (uf_id),
  ra_cira integer,
  ra_codigo text not null,
  ra_nome text not null,
  ra_nome_normalizado text not null,
  area_km2 numeric(14,8),
  status text not null default 'ativa',
  fonte_poligono text,
  fonte_centroide text,
  unique (uf_id, ra_codigo),
  unique (uf_id, ra_nome_normalizado)
);

create table geo.ra_geometria (
  ra_id bigint primary key references dim.regiao_administrativa (ra_id),
  geom_utm geometry(MultiPolygon, 31983),
  geom geometry(MultiPolygon, 4326) not null,
  centroid_geom geometry(Point, 4326),
  centroid_lon numeric(11,8),
  centroid_lat numeric(11,8),
  centroid_origem text not null default 'geojson'
);

create index ra_geometria_geom_gix on geo.ra_geometria using gist (geom);
create index ra_geometria_centroid_gix on geo.ra_geometria using gist (centroid_geom);
```

Regras:

- Carregar os 37 poligonos do shapefile.
- Cruzar centroides por `ra_codigo` quando existirem no GeoJSON.
- Para RAs sem centroide no GeoJSON, calcular o centroide com base no poligono do shapefile. Usar preferencialmente `st_pointonsurface(geom)` para garantir ponto dentro do poligono; caso seja necessario o centro geometrico, manter tambem `st_centroid(geom)` em coluna auxiliar ou view.
- Registrar `centroid_origem = 'geojson'` para os 35 centroides importados e `centroid_origem = 'calculado_shapefile'` para `RA-XXXVI` / `26 DE SETEMBRO` e `XXXVII` / `PONTE ALTA`.
- Corrigir a anomalia de codigo `XXXVII` para `RA-XXXVII` em camada de curadoria, preservando o valor original em staging.

Exemplo da regra de complemento:

```sql
update geo.ra_geometria
set centroid_geom = st_pointonsurface(geom),
    centroid_lon = st_x(st_pointonsurface(geom)),
    centroid_lat = st_y(st_pointonsurface(geom)),
    centroid_origem = 'calculado_shapefile'
where centroid_geom is null;
```

### 5.4 Local de votacao

```sql
create table dim.local_votacao (
  local_id bigint generated always as identity primary key,
  eleicao_id bigint not null references dim.eleicao (eleicao_id),
  uf_id smallint not null references dim.uf (uf_id),
  ra_id bigint references dim.regiao_administrativa (ra_id),
  nr_local_votacao integer not null,
  nome text not null,
  nome_normalizado text not null,
  endereco text,
  bairro text,
  cep text,
  telefone text,
  latitude numeric(11,8),
  longitude numeric(11,8),
  geom geometry(Point, 4326),
  cd_tipo_local integer,
  ds_tipo_local text,
  cd_situ_local_votacao integer,
  ds_situ_local_votacao text,
  status text not null default 'ativo',
  source_priority text,
  unique (eleicao_id, uf_id, nr_local_votacao)
);

create index local_votacao_geom_gix on dim.local_votacao using gist (geom);
create index local_votacao_ra_idx on dim.local_votacao (ra_id);
```

Fontes:

- Preferir `eleitorado_local_votacao_2026_DF.csv` para status, tipo local e endereco operacional.
- Usar `Locais_TRE_DF_2026.xlsx` para `QTDE_ELEITORES_NAO_APTOS` e como fonte de conferencia de coordenadas.
- Para 2022, usar `votacao_secao_2022_DF.csv` para criar registros de local com `NR_LOCAL_VOTACAO`, `NM_LOCAL_VOTACAO` e `DS_LOCAL_VOTACAO_ENDERECO`; coordenadas e RA devem ser enriquecidas por cruzamento com bases georreferenciadas ou conciliacao com locais de outros anos.

Regra espacial para RA:

```sql
update dim.local_votacao lv
set ra_id = ra.ra_id
from dim.regiao_administrativa ra
join geo.ra_geometria rg on rg.ra_id = ra.ra_id
where lv.ra_id is null
  and lv.geom is not null
  and st_contains(rg.geom, lv.geom);
```

### 5.5 Zona eleitoral

```sql
create table dim.zona_eleitoral (
  zona_id bigint generated always as identity primary key,
  uf_id smallint not null references dim.uf (uf_id),
  nr_zona integer not null,
  cd_situ_zona integer,
  ds_situ_zona text,
  unique (uf_id, nr_zona)
);
```

### 5.6 Secao eleitoral

```sql
create table dim.secao_eleitoral (
  secao_id bigint generated always as identity primary key,
  eleicao_id bigint not null references dim.eleicao (eleicao_id),
  uf_id smallint not null references dim.uf (uf_id),
  ra_id bigint references dim.regiao_administrativa (ra_id),
  zona_id bigint not null references dim.zona_eleitoral (zona_id),
  local_id bigint not null references dim.local_votacao (local_id),
  nr_zona integer not null,
  nr_secao integer not null,
  cd_tipo_secao_agregada integer,
  ds_tipo_secao_agregada text,
  nr_secao_principal integer,
  secao_principal_id bigint references dim.secao_eleitoral (secao_id),
  local_principal_id bigint references dim.local_votacao (local_id),
  cd_situ_secao integer,
  ds_situ_secao text,
  cd_situ_secao_acessibilidade integer,
  ds_situ_secao_acessibilidade text,
  tem_acessibilidade boolean,
  qt_eleitores_aptos integer,
  qt_eleitores_nao_aptos integer,
  qt_eleitores_suspensos integer,
  latitude numeric(11,8),
  longitude numeric(11,8),
  geom geometry(Point, 4326),
  unique (eleicao_id, uf_id, nr_zona, nr_secao)
);

create index secao_local_idx on dim.secao_eleitoral (local_id);
create index secao_ra_idx on dim.secao_eleitoral (ra_id);
create index secao_geom_gix on dim.secao_eleitoral using gist (geom);
```

Regras:

- A chave natural atual para secao e unica em `SG_UF + NR_ZONA + NR_SECAO`.
- Coordenadas da secao herdam o ponto do local de votacao efetivo.
- Para secao agregada, `local_principal_id` deve apontar para o local da secao principal quando identificado.
- `qt_eleitores_aptos` vem de `QT_ELEITOR_SECAO` do CSV oficial ou de `APTOS` da planilha de secoes; divergencias devem ir para tabela de qualidade.
- `qt_eleitores_nao_aptos` existe no nivel local em `Locais_TRE_DF_2026.xlsx`; se necessario por secao, manter nulo ou calcular somente com regra documentada.

### 5.7 Partido politico

```sql
create table dim.partido_politico (
  partido_id bigint generated always as identity primary key,
  nr_partido integer not null,
  sigla text not null,
  nome text not null,
  unique (nr_partido),
  unique (sigla)
);
```

### 5.8 Cargo eleitoral

```sql
create table dim.cargo_eleitoral (
  cargo_id smallint generated always as identity primary key,
  cd_cargo integer not null unique,
  ds_cargo text not null
);
```

Na fonte atual existem 7 cargos: governador, vice-governador, senador, suplentes, deputado federal e deputado distrital.

### 5.9 Federacao e coligacao

```sql
create table dim.federacao (
  federacao_id bigint generated always as identity primary key,
  nr_federacao integer,
  sg_federacao text,
  nm_federacao text,
  ds_composicao_federacao text,
  unique (nr_federacao, sg_federacao)
);

create table dim.coligacao (
  coligacao_id bigint generated always as identity primary key,
  eleicao_id bigint not null references dim.eleicao (eleicao_id),
  sq_coligacao bigint,
  nm_coligacao text,
  ds_composicao_coligacao text,
  unique (eleicao_id, sq_coligacao)
);
```

### 5.10 Candidato

```sql
create table dim.candidato (
  candidato_id bigint generated always as identity primary key,
  eleicao_id bigint not null references dim.eleicao (eleicao_id),
  uf_id smallint not null references dim.uf (uf_id),
  cargo_id smallint not null references dim.cargo_eleitoral (cargo_id),
  partido_id bigint references dim.partido_politico (partido_id),
  federacao_id bigint references dim.federacao (federacao_id),
  coligacao_id bigint references dim.coligacao (coligacao_id),
  sq_candidato bigint not null,
  nr_candidato integer not null,
  nm_candidato text not null,
  nm_urna_candidato text,
  nm_social_candidato text,
  cpf_hash text,
  email_divulgavel text,
  tp_agremiacao text,
  cd_situacao_candidatura integer,
  ds_situacao_candidatura text,
  cd_detalhe_situacao_cand integer,
  ds_detalhe_situacao_cand text,
  cd_genero integer,
  ds_genero text,
  cd_grau_instrucao integer,
  ds_grau_instrucao text,
  cd_estado_civil integer,
  ds_estado_civil text,
  cd_cor_raca text,
  ds_cor_raca text,
  cd_ocupacao integer,
  ds_ocupacao text,
  sg_uf_nascimento char(2),
  cd_municipio_nascimento integer,
  nm_municipio_nascimento text,
  dt_nascimento date,
  cd_nacionalidade integer,
  ds_nacionalidade text,
  nr_idade_data_posse integer,
  st_quilombola boolean,
  cd_etnia_indigena integer,
  ds_etnia_indigena text,
  st_reeleicao boolean,
  st_declarar_bens boolean,
  vr_despesa_max_campanha numeric(16,2),
  cd_situacao_julgamento integer,
  ds_situacao_julgamento text,
  cd_situacao_candidato_urna integer,
  ds_situacao_candidato_urna text,
  cd_sit_tot_turno integer,
  ds_sit_tot_turno text,
  unique (eleicao_id, sq_candidato)
);

create index candidato_partido_idx on dim.candidato (partido_id);
create index candidato_cargo_idx on dim.candidato (cargo_id);
```

Regras:

- `consulta_cand_2026_DF.csv` e `consulta_cand_complementar_2026_DF.csv` se unem por `SQ_CANDIDATO`.
- Evitar armazenar CPF aberto. Se for indispensavel, usar coluna protegida e perfil de acesso separado; para inteligencia eleitoral, `cpf_hash` normalmente basta.

## 6. Perfil do eleitor

A solicitacao chama "perfil do eleitor" de dimensao, mas os campos `QT_ELEITORES`, `QT_ELEITORES_BIOMETRIA`, `QT_ELEITORES_DEFICIENCIA` e `QT_ELEITORES_NOME_SOCIAL` sao medidas agregaveis. A modelagem recomendada separa uma dimensao de atributos de perfil e uma fato de contagem por secao.

```sql
create table dim.perfil_eleitor (
  perfil_id bigint generated always as identity primary key,
  cd_genero integer,
  ds_genero text,
  cd_estado_civil integer,
  ds_estado_civil text,
  cd_faixa_etaria integer,
  ds_faixa_etaria text,
  cd_grau_escolaridade integer,
  ds_grau_escolaridade text,
  cd_raca_cor integer,
  ds_raca_cor text,
  cd_identidade_genero integer,
  ds_identidade_genero text,
  cd_quilombola integer,
  ds_quilombola text,
  cd_interprete_libras integer,
  ds_interprete_libras text,
  unique (
    cd_genero, cd_estado_civil, cd_faixa_etaria, cd_grau_escolaridade,
    cd_raca_cor, cd_identidade_genero, cd_quilombola, cd_interprete_libras
  )
);

create table fato.eleitorado_perfil_secao (
  eleicao_id bigint not null references dim.eleicao (eleicao_id),
  uf_id smallint not null references dim.uf (uf_id),
  ra_id bigint references dim.regiao_administrativa (ra_id),
  local_id bigint not null references dim.local_votacao (local_id),
  secao_id bigint not null references dim.secao_eleitoral (secao_id),
  perfil_id bigint not null references dim.perfil_eleitor (perfil_id),
  qt_eleitores integer not null,
  qt_eleitores_biometria integer not null,
  qt_eleitores_deficiencia integer not null,
  qt_eleitores_nome_social integer not null,
  primary key (eleicao_id, secao_id, perfil_id)
);

create index eleitorado_perfil_ra_idx on fato.eleitorado_perfil_secao (ra_id);
create index eleitorado_perfil_local_idx on fato.eleitorado_perfil_secao (local_id);
create index eleitorado_perfil_perfil_idx on fato.eleitorado_perfil_secao (perfil_id);
```

Essa fato permite consultas como:

- eleitorado feminino por RA;
- perfil etario por zona;
- eleitores com biometria por local;
- eleitores aptos com deficiencia ou mobilidade reduzida por secao;
- solicitacao de nome social por local/RA/secao.

## 7. Fatos eleitorais para votacao

O arquivo `votacao_secao_2022_DF.csv` possui a granularidade necessaria para o drill-down de votacao:

`UF -> Regiao Administrativa -> Local de Votacao -> Secao Eleitoral -> Cargo -> Votavel`.

Estrutura analisada:

- 1.238.611 linhas.
- Eleicao unica na amostra: `ANO_ELEICAO = 2022`, `CD_ELEICAO = 546`, `NR_TURNO = 1`, `SG_UF = DF`.
- 6.748 secoes distintas por `SG_UF + NR_ZONA + NR_SECAO`.
- 4 cargos: governador, senador, deputado federal e deputado distrital.
- A chave natural da linha e unica em `SG_UF + NR_ZONA + NR_SECAO + NR_LOCAL_VOTACAO + CD_CARGO + NR_VOTAVEL + SQ_CANDIDATO`.
- `SQ_CANDIDATO = -1` representa votaveis especiais `95 VOTO BRANCO` e `96 VOTO NULO`.
- `SQ_CANDIDATO = -3` representa voto de legenda para cargos proporcionais; nesse caso `NR_VOTAVEL` e o numero do partido.

Como a importacao dos dados de 2022 nao sera feita neste primeiro momento, a tabela abaixo fica preparada para receber a carga posterior sem perder a semantica da fonte.

### 7.1 Dimensao de votavel

Nem toda linha da votacao aponta para um candidato. Ha voto nominal, voto de legenda, voto branco e voto nulo. Por isso, a modelagem deve ter uma dimensao propria de votavel.

```sql
create table dim.votavel (
  votavel_id bigint generated always as identity primary key,
  eleicao_id bigint not null references dim.eleicao (eleicao_id),
  cargo_id smallint not null references dim.cargo_eleitoral (cargo_id),
  partido_id bigint references dim.partido_politico (partido_id),
  candidato_id bigint references dim.candidato (candidato_id),
  nr_votavel integer not null,
  nm_votavel text not null,
  sq_candidato bigint,
  tipo_votavel text not null check (
    tipo_votavel in ('nominal', 'legenda', 'branco', 'nulo')
  )
);
```

Regras:

- `tipo_votavel = 'nominal'` quando `SQ_CANDIDATO` e um identificador real de candidato.
- `tipo_votavel = 'legenda'` quando `SQ_CANDIDATO = -3`; vincular `partido_id` por `NR_VOTAVEL = NR_PARTIDO`.
- `tipo_votavel = 'branco'` quando `NR_VOTAVEL = 95` e `SQ_CANDIDATO = -1`.
- `tipo_votavel = 'nulo'` quando `NR_VOTAVEL = 96` e `SQ_CANDIDATO = -1`.
- `candidato_id` deve ser nulo para legenda, branco e nulo.

Em PostgreSQL, a restricao `unique` com `coalesce` deve ser implementada como indice unico:

```sql
create unique index votavel_uk
on dim.votavel (
  eleicao_id,
  cargo_id,
  nr_votavel,
  (coalesce(sq_candidato, -999999999999))
);
```

### 7.2 Fato de votacao por secao

```sql
create table fato.votacao_candidato_secao (
  eleicao_id bigint not null references dim.eleicao (eleicao_id),
  uf_id smallint not null references dim.uf (uf_id),
  ra_id bigint references dim.regiao_administrativa (ra_id),
  local_id bigint not null references dim.local_votacao (local_id),
  secao_id bigint not null references dim.secao_eleitoral (secao_id),
  cargo_id smallint not null references dim.cargo_eleitoral (cargo_id),
  votavel_id bigint not null references dim.votavel (votavel_id),
  candidato_id bigint references dim.candidato (candidato_id),
  partido_id bigint references dim.partido_politico (partido_id),
  nr_zona integer not null,
  nr_secao integer not null,
  nr_local_votacao integer not null,
  nr_votavel integer not null,
  sq_candidato bigint,
  nm_votavel text not null,
  tipo_votavel text not null check (
    tipo_votavel in ('nominal', 'legenda', 'branco', 'nulo')
  ),
  qt_votos integer not null,
  source_file text,
  loaded_at timestamptz not null default now(),
  primary key (eleicao_id, secao_id, cargo_id, votavel_id)
);

create index votacao_ra_cargo_idx on fato.votacao_candidato_secao (ra_id, cargo_id);
create index votacao_uf_ra_local_secao_idx on fato.votacao_candidato_secao (uf_id, ra_id, local_id, secao_id);
create index votacao_local_candidato_idx on fato.votacao_candidato_secao (local_id, candidato_id);
create index votacao_partido_idx on fato.votacao_candidato_secao (partido_id);
create index votacao_votavel_idx on fato.votacao_candidato_secao (votavel_id);
```

View recomendada para consumo do sistema:

```sql
create or replace view fato.vw_votacao_drilldown as
select
  e.ano,
  e.turno,
  uf.sigla as uf,
  ra.ra_codigo,
  ra.ra_nome,
  lv.nr_local_votacao,
  lv.nome as local_votacao,
  se.nr_zona,
  se.nr_secao,
  ce.ds_cargo,
  vc.tipo_votavel,
  vc.nr_votavel,
  vc.nm_votavel,
  pp.sigla as partido,
  c.nm_urna_candidato,
  vc.qt_votos
from fato.votacao_candidato_secao vc
join dim.eleicao e on e.eleicao_id = vc.eleicao_id
join dim.uf uf on uf.uf_id = vc.uf_id
left join dim.regiao_administrativa ra on ra.ra_id = vc.ra_id
join dim.local_votacao lv on lv.local_id = vc.local_id
join dim.secao_eleitoral se on se.secao_id = vc.secao_id
join dim.cargo_eleitoral ce on ce.cargo_id = vc.cargo_id
left join dim.partido_politico pp on pp.partido_id = vc.partido_id
left join dim.candidato c on c.candidato_id = vc.candidato_id;
```

Observacoes para drill-down:

- `uf_id`, `ra_id`, `local_id` e `secao_id` ficam materializados na fato para acelerar consultas geoespaciais e agregacoes interativas.
- `ra_id` deve ser herdado do local de votacao. O local, por sua vez, deve ter RA derivada por `st_contains`/`st_intersects` quando houver coordenada.
- Para dados de 2022 sem coordenada propria no CSV de votacao, criar o local de votacao a partir de `NR_LOCAL_VOTACAO`, `NM_LOCAL_VOTACAO` e `DS_LOCAL_VOTACAO_ENDERECO`, e enriquecer coordenadas por fontes complementares quando disponiveis.
- Se o local de 2022 coincidir com local existente em 2026 por `UF + NR_LOCAL_VOTACAO` e nome/endereco compativeis, as coordenadas podem ser reaproveitadas com uma regra de confianca registrada em `aux.qualidade_dado` ou em tabela de linhagem.
- A tabela preserva `nr_zona`, `nr_secao`, `nr_local_votacao`, `nr_votavel`, `sq_candidato`, `nm_votavel` e `tipo_votavel` para auditoria e para consultas mesmo quando alguma dimensao ainda nao estiver perfeitamente conciliada.

### 7.3 Fato agregada de apuracao por secao

Tambem e recomendavel criar uma fato agregada por secao/cargo a partir de `fato.votacao_candidato_secao` ou de fonte oficial de boletim de urna:

```sql
create table fato.apuracao_secao (
  eleicao_id bigint not null references dim.eleicao (eleicao_id),
  secao_id bigint not null references dim.secao_eleitoral (secao_id),
  cargo_id smallint not null references dim.cargo_eleitoral (cargo_id),
  qt_aptos integer,
  qt_comparecimento integer,
  qt_abstencoes integer,
  qt_votos_nominais integer,
  qt_votos_legenda integer,
  qt_votos_brancos integer,
  qt_votos_nulos integer,
  primary key (eleicao_id, secao_id, cargo_id)
);
```

## 8. Tabelas auxiliares de qualidade e conciliacao

```sql
create table aux.qualidade_dado (
  qualidade_id bigint generated always as identity primary key,
  entidade text not null,
  chave_natural text not null,
  severidade text not null,
  regra text not null,
  detalhe text,
  source_file text,
  detected_at timestamptz not null default now()
);

create table aux.local_votacao_alias (
  alias_id bigint generated always as identity primary key,
  local_id bigint not null references dim.local_votacao (local_id),
  nr_local_votacao integer,
  nome_original text,
  endereco_original text,
  source_file text,
  unique (local_id, source_file, nome_original)
);

create table aux.ra_alias (
  alias_id bigint generated always as identity primary key,
  ra_id bigint not null references dim.regiao_administrativa (ra_id),
  ra_codigo_original text,
  ra_nome_original text,
  source_file text,
  unique (source_file, ra_codigo_original, ra_nome_original)
);
```

Regras de qualidade prioritarias:

- Secoes no `perfil_eleitor_secao_2026_DF.csv` sem correspondencia em `dim.secao_eleitoral`.
- Secoes em `eleitorado_local_votacao_2026_DF.csv` ausentes na planilha `Secoes_TRE-DF_2026.xlsx`.
- Divergencia entre `QT_ELEITOR_SECAO` e `APTOS`.
- Local sem coordenada valida.
- Local com ponto fora de qualquer poligono de RA.
- RA do GeoJSON sem correspondente no shapefile e vice-versa.
- RA sem centroide importado do GeoJSON e com centroide calculado a partir do shapefile.
- Linha de votacao de 2022 sem correspondencia em `dim.secao_eleitoral`.
- Linha de votacao de 2022 sem correspondencia em `dim.votavel`.
- Voto de legenda com `NR_VOTAVEL` sem correspondencia em `dim.partido_politico.nr_partido`.
- Duplicidade de `SQ_CANDIDATO` ou ausencia no complementar.

## 9. Fluxo de carga recomendado

1. Carregar arquivos brutos em `stg`.
2. Normalizar textos com `upper(unaccent(trim(...)))` em campos de chave textual.
3. Criar `dim.uf`.
4. Criar `dim.eleicao`.
5. Importar shapefile para `geo.ra_geometria` com `shp2pgsql -s 31983:4326`.
6. Popular `dim.regiao_administrativa` e vincular geometrias.
7. Importar centroides do GeoJSON; para as RAs ausentes no GeoJSON, calcular centroide a partir dos poligonos do shapefile com `st_pointonsurface`.
8. Popular `dim.zona_eleitoral`.
9. Popular `dim.local_votacao`, gerar `geom` e derivar `ra_id` por `st_contains`/`st_intersects`.
10. Popular `dim.secao_eleitoral`, herdando RA e coordenadas do local.
11. Popular `dim.partido_politico`, `dim.cargo_eleitoral`, `dim.federacao`, `dim.coligacao`.
12. Popular `dim.candidato` juntando candidatura principal e complementar por `SQ_CANDIDATO`.
13. Popular `dim.perfil_eleitor`.
14. Popular `fato.eleitorado_perfil_secao`.
15. Modelar e criar `dim.votavel` e `fato.votacao_candidato_secao` com base em `votacao_secao_2022_DF.csv`, sem executar a carga neste primeiro momento.
16. Quando a carga de votacao de 2022 for autorizada, popular `dim.votavel`, `fato.votacao_candidato_secao` e `fato.apuracao_secao`.
17. Executar regras de qualidade em `aux.qualidade_dado`.

## 10. Consultas que a modelagem suporta

- Votacao por candidato, partido ou cargo por RA, zona, local e secao.
- Ranking de candidatos por RA ou local.
- Comparativo de desempenho entre RAs.
- Mapa de calor por local de votacao.
- Cruzamento de votos com perfil de eleitorado por faixa etaria, genero, escolaridade, raca/cor, biometria, deficiencia e nome social.
- Analise de locais bloqueados/inativos.
- Auditoria de secoes agregadas e local da secao principal.
- Visualizacao de limites, centroides e pontos de votacao em mapas web.

## 11. Ajustes recomendados antes da implementacao fisica

- A fonte `votacao_secao_2022_DF.csv` ja define a estrutura de votacao por secao; confirmar apenas as proximas fontes/anos que tambem deverao alimentar a mesma fato.
- Confirmar se `QT_ELEITORES_NAO_APTOS` deve permanecer no nivel de local ou ser rateado/ignorado no nivel de secao.
- Definir politica de privacidade para CPF e titulo eleitoral de candidato.
- Padronizar encoding de shapefile/GeoJSON para evitar perda de acentos na carga.
- Validar se a RA `XXXVII` deve ser corrigida para `RA-XXXVII`.
- Definir se zonas eleitorais terao geometria propria; as fontes atuais nao trazem limites de zona.
