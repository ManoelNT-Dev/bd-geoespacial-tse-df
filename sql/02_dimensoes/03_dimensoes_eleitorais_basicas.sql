create table if not exists dim.zona_eleitoral (
    zona_id bigint generated always as identity primary key,
    uf_id smallint not null references dim.uf (uf_id),
    nr_zona integer not null,
    cd_situ_zona integer,
    ds_situ_zona text,
    unique (uf_id, nr_zona)
);

create table if not exists dim.cargo_eleitoral (
    cargo_id smallint generated always as identity primary key,
    cd_cargo integer not null unique,
    ds_cargo text not null
);

create table if not exists dim.partido_politico (
    partido_id bigint generated always as identity primary key,
    nr_partido integer not null,
    sigla text not null,
    nome text not null,
    unique (nr_partido),
    unique (sigla)
);

create table if not exists dim.federacao (
    federacao_id bigint generated always as identity primary key,
    nr_federacao integer,
    sg_federacao text,
    nm_federacao text,
    ds_composicao_federacao text,
    unique (nr_federacao, sg_federacao)
);

create table if not exists dim.coligacao (
    coligacao_id bigint generated always as identity primary key,
    eleicao_id bigint not null references dim.eleicao (eleicao_id),
    sq_coligacao bigint,
    nm_coligacao text,
    ds_composicao_coligacao text,
    unique (eleicao_id, sq_coligacao)
);

with uf_df as (
    select uf_id
    from dim.uf
    where sigla = 'DF'
),
source_zona as (
    select
        uf_df.uf_id,
        nr_zona::integer as nr_zona,
        min(nullif(cd_situ_zona, '')::integer) as cd_situ_zona,
        min(nullif(ds_situ_zona, '')) as ds_situ_zona
    from stg.eleitorado_local_votacao_2026_df
    cross join uf_df
    where nullif(nr_zona, '') is not null
    group by uf_df.uf_id, nr_zona::integer
)
insert into dim.zona_eleitoral (uf_id, nr_zona, cd_situ_zona, ds_situ_zona)
select uf_id, nr_zona, cd_situ_zona, ds_situ_zona
from source_zona
on conflict (uf_id, nr_zona) do update
set cd_situ_zona = excluded.cd_situ_zona,
    ds_situ_zona = excluded.ds_situ_zona;

with source_cargo as (
    select
        cd_cargo::integer as cd_cargo,
        min(ds_cargo) as ds_cargo
    from stg.consulta_cand_2026_df
    where nullif(cd_cargo, '') is not null
    group by cd_cargo::integer
)
insert into dim.cargo_eleitoral (cd_cargo, ds_cargo)
select cd_cargo, ds_cargo
from source_cargo
on conflict (cd_cargo) do update
set ds_cargo = excluded.ds_cargo;

with source_partido as (
    select
        nr_partido::integer as nr_partido,
        min(sg_partido) as sigla,
        min(nm_partido) as nome
    from stg.consulta_cand_2026_df
    where nullif(nr_partido, '') is not null
      and nr_partido::integer > 0
    group by nr_partido::integer
)
insert into dim.partido_politico (nr_partido, sigla, nome)
select nr_partido, sigla, nome
from source_partido
on conflict (nr_partido) do update
set sigla = excluded.sigla,
    nome = excluded.nome;

with source_federacao as (
    select
        nr_federacao::integer as nr_federacao,
        min(sg_federacao) as sg_federacao,
        min(nm_federacao) as nm_federacao,
        min(ds_composicao_federacao) as ds_composicao_federacao
    from stg.consulta_cand_2026_df
    where nullif(nr_federacao, '') is not null
      and nr_federacao::integer > 0
    group by nr_federacao::integer
)
insert into dim.federacao (
    nr_federacao,
    sg_federacao,
    nm_federacao,
    ds_composicao_federacao
)
select
    nr_federacao,
    sg_federacao,
    nm_federacao,
    ds_composicao_federacao
from source_federacao
on conflict (nr_federacao, sg_federacao) do update
set nm_federacao = excluded.nm_federacao,
    ds_composicao_federacao = excluded.ds_composicao_federacao;

with eleicao_2026 as (
    select eleicao_id
    from dim.eleicao
    where ano = 2026
      and turno = 1
      and cd_eleicao = 6259
),
source_coligacao as (
    select
        eleicao_2026.eleicao_id,
        sq_coligacao::bigint as sq_coligacao,
        min(nm_coligacao) as nm_coligacao,
        min(ds_composicao_coligacao) as ds_composicao_coligacao
    from stg.consulta_cand_2026_df
    cross join eleicao_2026
    where nullif(sq_coligacao, '') is not null
      and sq_coligacao::bigint > 0
    group by eleicao_2026.eleicao_id, sq_coligacao::bigint
)
insert into dim.coligacao (
    eleicao_id,
    sq_coligacao,
    nm_coligacao,
    ds_composicao_coligacao
)
select
    eleicao_id,
    sq_coligacao,
    nm_coligacao,
    ds_composicao_coligacao
from source_coligacao
on conflict (eleicao_id, sq_coligacao) do update
set nm_coligacao = excluded.nm_coligacao,
    ds_composicao_coligacao = excluded.ds_composicao_coligacao;
