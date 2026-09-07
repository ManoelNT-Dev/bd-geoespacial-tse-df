create table if not exists dim.eleicao (
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

insert into dim.eleicao (
    ano,
    turno,
    cd_eleicao,
    ds_eleicao,
    cd_tipo_eleicao,
    nm_tipo_eleicao,
    dt_eleicao,
    tp_abrangencia
)
select distinct
    ano_eleicao::smallint as ano,
    nr_turno::smallint as turno,
    cd_eleicao::integer as cd_eleicao,
    ds_eleicao,
    cd_tipo_eleicao::integer as cd_tipo_eleicao,
    nm_tipo_eleicao,
    to_date(dt_eleicao, 'DD/MM/YYYY') as dt_eleicao,
    tp_abrangencia
from stg.consulta_cand_2026_df
where ano_eleicao <> ''
  and nr_turno <> ''
  and cd_eleicao <> ''
on conflict (ano, turno, cd_eleicao) do update
set ds_eleicao = excluded.ds_eleicao,
    cd_tipo_eleicao = excluded.cd_tipo_eleicao,
    nm_tipo_eleicao = excluded.nm_tipo_eleicao,
    dt_eleicao = excluded.dt_eleicao,
    tp_abrangencia = excluded.tp_abrangencia;
