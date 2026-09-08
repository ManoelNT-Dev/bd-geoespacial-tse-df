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
from stg.votacao_secao_2022_df
where nullif(ano_eleicao, '') is not null
  and nullif(nr_turno, '') is not null
  and nullif(cd_eleicao, '') is not null
on conflict (ano, turno, cd_eleicao) do update
set ds_eleicao = excluded.ds_eleicao,
    cd_tipo_eleicao = excluded.cd_tipo_eleicao,
    nm_tipo_eleicao = excluded.nm_tipo_eleicao,
    dt_eleicao = excluded.dt_eleicao,
    tp_abrangencia = excluded.tp_abrangencia;

with eleicao_2022 as (
    select eleicao_id
    from dim.eleicao
    where ano = 2022
      and turno = 1
      and cd_eleicao = 546
),
uf_df as (
    select uf_id
    from dim.uf
    where sigla = 'DF'
),
source_local as (
    select
        eleicao_2022.eleicao_id,
        uf_df.uf_id,
        zona.zona_id,
        src.nr_zona::integer as nr_zona,
        src.nr_local_votacao::integer as nr_local_votacao,
        min(nullif(src.nm_local_votacao, '')) as nome,
        upper(unaccent(min(nullif(src.nm_local_votacao, '')))) as nome_normalizado,
        min(nullif(src.ds_local_votacao_endereco, '')) as endereco,
        'votacao_2022_piloto' as source_priority
    from stg.votacao_secao_2022_df src
    cross join eleicao_2022
    cross join uf_df
    join dim.zona_eleitoral zona
      on zona.uf_id = uf_df.uf_id
     and zona.nr_zona = src.nr_zona::integer
    where nullif(src.nr_zona, '') is not null
      and nullif(src.nr_local_votacao, '') is not null
    group by
        eleicao_2022.eleicao_id,
        uf_df.uf_id,
        zona.zona_id,
        src.nr_zona::integer,
        src.nr_local_votacao::integer
)
insert into dim.local_votacao (
    eleicao_id,
    uf_id,
    zona_id,
    nr_zona,
    nr_local_votacao,
    nome,
    nome_normalizado,
    endereco,
    status,
    is_principal,
    fonte_tre_confirmada,
    source_priority
)
select
    eleicao_id,
    uf_id,
    zona_id,
    nr_zona,
    nr_local_votacao,
    nome,
    nome_normalizado,
    endereco,
    'ativo',
    false,
    false,
    source_priority
from source_local
on conflict (eleicao_id, uf_id, nr_zona, nr_local_votacao) do update
set zona_id = excluded.zona_id,
    nome = excluded.nome,
    nome_normalizado = excluded.nome_normalizado,
    endereco = excluded.endereco,
    status = excluded.status,
    source_priority = excluded.source_priority;

with eleicao_2022 as (
    select eleicao_id
    from dim.eleicao
    where ano = 2022
      and turno = 1
      and cd_eleicao = 546
),
uf_df as (
    select uf_id
    from dim.uf
    where sigla = 'DF'
),
source_secao as (
    select distinct
        eleicao_2022.eleicao_id,
        uf_df.uf_id,
        zona.zona_id,
        local.local_id,
        local.ra_id,
        local.latitude,
        local.longitude,
        local.geom,
        src.nr_zona::integer as nr_zona,
        src.nr_secao::integer as nr_secao,
        src.source_file
    from stg.votacao_secao_2022_df src
    cross join eleicao_2022
    cross join uf_df
    join dim.zona_eleitoral zona
      on zona.uf_id = uf_df.uf_id
     and zona.nr_zona = src.nr_zona::integer
    join dim.local_votacao local
      on local.eleicao_id = eleicao_2022.eleicao_id
     and local.uf_id = uf_df.uf_id
     and local.nr_zona = src.nr_zona::integer
     and local.nr_local_votacao = src.nr_local_votacao::integer
    where nullif(src.nr_zona, '') is not null
      and nullif(src.nr_secao, '') is not null
)
insert into dim.secao_eleitoral (
    eleicao_id,
    uf_id,
    ra_id,
    zona_id,
    local_id,
    nr_zona,
    nr_secao,
    cd_situ_secao,
    ds_situ_secao,
    latitude,
    longitude,
    geom,
    is_secao_principal_tre,
    fonte_tre_confirmada,
    is_adicional_csv,
    source_file
)
select
    eleicao_id,
    uf_id,
    ra_id,
    zona_id,
    local_id,
    nr_zona,
    nr_secao,
    null,
    null,
    latitude,
    longitude,
    geom,
    false,
    false,
    false,
    source_file
from source_secao
on conflict (eleicao_id, uf_id, nr_zona, nr_secao) do update
set zona_id = excluded.zona_id,
    local_id = excluded.local_id,
    ra_id = excluded.ra_id,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    geom = excluded.geom,
    source_file = excluded.source_file,
    loaded_at = now();

with eleicao_2022 as (
    select eleicao_id
    from dim.eleicao
    where ano = 2022
      and turno = 1
      and cd_eleicao = 546
),
source_votavel as (
    select distinct
        eleicao_2022.eleicao_id,
        cargo.cargo_id,
        partido.partido_id,
        null::bigint as candidato_id,
        src.nr_votavel::integer as nr_votavel,
        src.nm_votavel,
        nullif(src.sq_candidato, '')::bigint as sq_candidato,
        case
            when src.sq_candidato = '-3' then 'legenda'
            when src.sq_candidato = '-1' and src.nr_votavel = '95' then 'branco'
            when src.sq_candidato = '-1' and src.nr_votavel = '96' then 'nulo'
            else 'nominal'
        end as tipo_votavel,
        min(src.source_file) as source_file
    from stg.votacao_secao_2022_df src
    cross join eleicao_2022
    join dim.cargo_eleitoral cargo
      on cargo.cd_cargo = src.cd_cargo::integer
    left join dim.partido_politico partido
      on partido.nr_partido = case
          when src.sq_candidato = '-3' then src.nr_votavel::integer
          when src.sq_candidato not in ('-1', '-3') then left(src.nr_votavel, 2)::integer
          else null
      end
    where nullif(src.nr_votavel, '') is not null
    group by
        eleicao_2022.eleicao_id,
        cargo.cargo_id,
        partido.partido_id,
        src.nr_votavel::integer,
        src.nm_votavel,
        nullif(src.sq_candidato, '')::bigint,
        case
            when src.sq_candidato = '-3' then 'legenda'
            when src.sq_candidato = '-1' and src.nr_votavel = '95' then 'branco'
            when src.sq_candidato = '-1' and src.nr_votavel = '96' then 'nulo'
            else 'nominal'
        end
)
insert into dim.votavel (
    eleicao_id,
    cargo_id,
    partido_id,
    candidato_id,
    nr_votavel,
    nm_votavel,
    sq_candidato,
    tipo_votavel,
    source_file
)
select
    eleicao_id,
    cargo_id,
    partido_id,
    candidato_id,
    nr_votavel,
    nm_votavel,
    sq_candidato,
    tipo_votavel,
    source_file
from source_votavel src
where not exists (
    select 1
    from dim.votavel alvo
    where alvo.eleicao_id = src.eleicao_id
      and alvo.cargo_id = src.cargo_id
      and alvo.nr_votavel = src.nr_votavel
      and coalesce(alvo.sq_candidato, -999999999999) = coalesce(src.sq_candidato, -999999999999)
);

with eleicao_2022 as (
    select eleicao_id
    from dim.eleicao
    where ano = 2022
      and turno = 1
      and cd_eleicao = 546
),
uf_df as (
    select uf_id
    from dim.uf
    where sigla = 'DF'
),
source_votacao as (
    select
        eleicao_2022.eleicao_id,
        uf_df.uf_id,
        secao.ra_id,
        secao.local_id,
        secao.secao_id,
        cargo.cargo_id,
        votavel.votavel_id,
        votavel.candidato_id,
        votavel.partido_id,
        src.nr_zona::integer as nr_zona,
        src.nr_secao::integer as nr_secao,
        src.nr_local_votacao::integer as nr_local_votacao,
        src.nr_votavel::integer as nr_votavel,
        src.sq_candidato::bigint as sq_candidato,
        src.nm_votavel,
        votavel.tipo_votavel,
        sum(src.qt_votos::integer) as qt_votos,
        min(src.source_file) as source_file
    from stg.votacao_secao_2022_df src
    cross join eleicao_2022
    cross join uf_df
    join dim.cargo_eleitoral cargo
      on cargo.cd_cargo = src.cd_cargo::integer
    join dim.secao_eleitoral secao
      on secao.eleicao_id = eleicao_2022.eleicao_id
     and secao.uf_id = uf_df.uf_id
     and secao.nr_zona = src.nr_zona::integer
     and secao.nr_secao = src.nr_secao::integer
    join dim.votavel votavel
      on votavel.eleicao_id = eleicao_2022.eleicao_id
     and votavel.cargo_id = cargo.cargo_id
     and votavel.nr_votavel = src.nr_votavel::integer
     and coalesce(votavel.sq_candidato, -999999999999) = coalesce(src.sq_candidato::bigint, -999999999999)
    group by
        eleicao_2022.eleicao_id,
        uf_df.uf_id,
        secao.ra_id,
        secao.local_id,
        secao.secao_id,
        cargo.cargo_id,
        votavel.votavel_id,
        votavel.candidato_id,
        votavel.partido_id,
        src.nr_zona::integer,
        src.nr_secao::integer,
        src.nr_local_votacao::integer,
        src.nr_votavel::integer,
        src.sq_candidato::bigint,
        src.nm_votavel,
        votavel.tipo_votavel
)
insert into fato.votacao_candidato_secao (
    eleicao_id,
    uf_id,
    ra_id,
    local_id,
    secao_id,
    cargo_id,
    votavel_id,
    candidato_id,
    partido_id,
    nr_zona,
    nr_secao,
    nr_local_votacao,
    nr_votavel,
    sq_candidato,
    nm_votavel,
    tipo_votavel,
    qt_votos,
    source_file
)
select
    eleicao_id,
    uf_id,
    ra_id,
    local_id,
    secao_id,
    cargo_id,
    votavel_id,
    candidato_id,
    partido_id,
    nr_zona,
    nr_secao,
    nr_local_votacao,
    nr_votavel,
    sq_candidato,
    nm_votavel,
    tipo_votavel,
    qt_votos,
    source_file
from source_votacao
on conflict (eleicao_id, secao_id, cargo_id, votavel_id) do update
set uf_id = excluded.uf_id,
    ra_id = excluded.ra_id,
    local_id = excluded.local_id,
    candidato_id = excluded.candidato_id,
    partido_id = excluded.partido_id,
    nr_zona = excluded.nr_zona,
    nr_secao = excluded.nr_secao,
    nr_local_votacao = excluded.nr_local_votacao,
    nr_votavel = excluded.nr_votavel,
    sq_candidato = excluded.sq_candidato,
    nm_votavel = excluded.nm_votavel,
    tipo_votavel = excluded.tipo_votavel,
    qt_votos = excluded.qt_votos,
    source_file = excluded.source_file,
    loaded_at = now();

insert into fato.apuracao_secao (
    eleicao_id,
    uf_id,
    ra_id,
    local_id,
    secao_id,
    cargo_id,
    qt_votos_nominais,
    qt_votos_legenda,
    qt_votos_brancos,
    qt_votos_nulos,
    source_file
)
select
    eleicao_id,
    uf_id,
    ra_id,
    local_id,
    secao_id,
    cargo_id,
    sum(qt_votos) filter (where tipo_votavel = 'nominal') as qt_votos_nominais,
    sum(qt_votos) filter (where tipo_votavel = 'legenda') as qt_votos_legenda,
    sum(qt_votos) filter (where tipo_votavel = 'branco') as qt_votos_brancos,
    sum(qt_votos) filter (where tipo_votavel = 'nulo') as qt_votos_nulos,
    min(source_file) as source_file
from fato.votacao_candidato_secao
group by eleicao_id, uf_id, ra_id, local_id, secao_id, cargo_id
on conflict (eleicao_id, secao_id, cargo_id) do update
set uf_id = excluded.uf_id,
    ra_id = excluded.ra_id,
    local_id = excluded.local_id,
    qt_votos_nominais = excluded.qt_votos_nominais,
    qt_votos_legenda = excluded.qt_votos_legenda,
    qt_votos_brancos = excluded.qt_votos_brancos,
    qt_votos_nulos = excluded.qt_votos_nulos,
    source_file = excluded.source_file,
    loaded_at = now();
