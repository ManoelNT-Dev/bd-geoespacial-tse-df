create table if not exists dim.local_votacao (
    local_id bigint generated always as identity primary key,
    eleicao_id bigint not null references dim.eleicao (eleicao_id),
    uf_id smallint not null references dim.uf (uf_id),
    zona_id bigint not null references dim.zona_eleitoral (zona_id),
    ra_id bigint references dim.regiao_administrativa (ra_id),
    nr_zona integer not null,
    nr_local_votacao integer not null,
    nome text not null,
    nome_normalizado text not null,
    endereco text,
    bairro text,
    cep text,
    telefone text,
    latitude numeric(11, 8),
    longitude numeric(11, 8),
    geom geometry(Point, 4326),
    cd_tipo_local integer,
    ds_tipo_local text,
    cd_situ_local_votacao integer,
    ds_situ_local_votacao text,
    status text not null default 'ativo',
    is_principal boolean not null default false,
    fonte_tre_confirmada boolean not null default false,
    source_priority text,
    unique (eleicao_id, uf_id, nr_zona, nr_local_votacao)
);

alter table dim.local_votacao
    add column if not exists is_principal boolean not null default false;

alter table dim.local_votacao
    add column if not exists fonte_tre_confirmada boolean not null default false;

create index if not exists local_votacao_geom_gix on dim.local_votacao using gist (geom);
create index if not exists local_votacao_ra_idx on dim.local_votacao (ra_id);
create index if not exists local_votacao_zona_idx on dim.local_votacao (zona_id);
create index if not exists local_votacao_principal_idx on dim.local_votacao (is_principal);

create table if not exists aux.qualidade_dado (
    qualidade_id bigint generated always as identity primary key,
    entidade text not null,
    chave_natural text not null,
    severidade text not null,
    regra text not null,
    detalhe text,
    source_file text,
    detected_at timestamptz not null default now()
);

create table if not exists aux.local_votacao_alias (
    alias_id bigint generated always as identity primary key,
    local_id bigint not null references dim.local_votacao (local_id),
    nr_zona integer,
    nr_local_votacao integer,
    nome_original text,
    endereco_original text,
    bairro_original text,
    latitude_original numeric(11, 8),
    longitude_original numeric(11, 8),
    source_file text,
    unique (local_id, source_file, nome_original, endereco_original)
);

delete from aux.qualidade_dado
where entidade = 'local_votacao'
  and regra in (
      'local_sem_coordenada',
      'local_sem_ra',
      'local_csv_sem_tre',
      'nr_local_votacao_reutilizado_em_zonas'
  );

with eleicao_2026 as (
    select eleicao_id
    from dim.eleicao
    where ano = 2026
      and turno = 1
      and cd_eleicao = 6259
),
uf_df as (
    select uf_id
    from dim.uf
    where sigla = 'DF'
),
tre_pairs as (
    select distinct
        ze::integer as nr_zona,
        num_local::integer as nr_local_votacao
    from stg.tre_locais_2026_df
    where not is_total
      and nullif(ze, '') is not null
      and nullif(num_local, '') is not null
),
source_csv as (
    select distinct on (src.nr_zona::integer, src.nr_local_votacao::integer)
        eleicao_2026.eleicao_id,
        uf_df.uf_id,
        zona.zona_id,
        src.nr_zona::integer as nr_zona,
        src.nr_local_votacao::integer as nr_local_votacao,
        nullif(trim(src.nm_local_votacao), '') as nome,
        upper(unaccent(trim(src.nm_local_votacao))) as nome_normalizado,
        nullif(trim(src.ds_endereco), '') as endereco,
        nullif(trim(src.nm_bairro), '') as bairro,
        nullif(trim(src.nr_cep), '') as cep,
        nullif(trim(src.nr_telefone_local), '') as telefone,
        nullif(replace(src.nr_latitude, ',', '.'), '')::numeric(11, 8) as latitude,
        nullif(replace(src.nr_longitude, ',', '.'), '')::numeric(11, 8) as longitude,
        nullif(src.cd_tipo_local, '')::integer as cd_tipo_local,
        nullif(src.ds_tipo_local, '') as ds_tipo_local,
        nullif(src.cd_situ_local_votacao, '')::integer as cd_situ_local_votacao,
        nullif(src.ds_situ_local_votacao, '') as ds_situ_local_votacao,
        lower(coalesce(nullif(src.ds_situ_local_votacao, ''), 'ativo')) as status,
        (tre_pairs.nr_zona is not null) as is_principal,
        (tre_pairs.nr_zona is not null) as fonte_tre_confirmada,
        case
            when tre_pairs.nr_zona is not null then 'tre_locais_2026_confirmado'
            else 'csv_eleitorado_local_votacao_2026_adicional'
        end as source_priority
    from stg.eleitorado_local_votacao_2026_df src
    cross join eleicao_2026
    cross join uf_df
    join dim.zona_eleitoral zona
      on zona.uf_id = uf_df.uf_id
     and zona.nr_zona = src.nr_zona::integer
    left join tre_pairs
      on tre_pairs.nr_zona = src.nr_zona::integer
     and tre_pairs.nr_local_votacao = src.nr_local_votacao::integer
    where nullif(src.nr_zona, '') is not null
      and nullif(src.nr_local_votacao, '') is not null
    order by src.nr_zona::integer, src.nr_local_votacao::integer, src.row_number
),
source_with_geom as (
    select
        *,
        case
            when latitude between -16.50 and -15.00
             and longitude between -48.50 and -47.00 then
                st_setsrid(st_makepoint(longitude, latitude), 4326)::geometry(Point, 4326)
            else null
        end as geom
    from source_csv
),
source_with_ra as (
    select
        src.*,
        ra.ra_id
    from source_with_geom src
    left join lateral (
        select rg.ra_id
        from geo.ra_geometria rg
        where src.geom is not null
          and st_covers(rg.geom, src.geom)
        order by st_area(rg.geom::geography)
        limit 1
    ) ra on true
)
insert into dim.local_votacao (
    eleicao_id,
    uf_id,
    zona_id,
    ra_id,
    nr_zona,
    nr_local_votacao,
    nome,
    nome_normalizado,
    endereco,
    bairro,
    cep,
    telefone,
    latitude,
    longitude,
    geom,
    cd_tipo_local,
    ds_tipo_local,
    cd_situ_local_votacao,
    ds_situ_local_votacao,
    status,
    is_principal,
    fonte_tre_confirmada,
    source_priority
)
select
    eleicao_id,
    uf_id,
    zona_id,
    ra_id,
    nr_zona,
    nr_local_votacao,
    nome,
    nome_normalizado,
    endereco,
    bairro,
    cep,
    telefone,
    latitude,
    longitude,
    geom,
    cd_tipo_local,
    ds_tipo_local,
    cd_situ_local_votacao,
    ds_situ_local_votacao,
    status,
    is_principal,
    fonte_tre_confirmada,
    source_priority
from source_with_ra
on conflict (eleicao_id, uf_id, nr_zona, nr_local_votacao) do update
set zona_id = excluded.zona_id,
    ra_id = excluded.ra_id,
    nome = excluded.nome,
    nome_normalizado = excluded.nome_normalizado,
    endereco = excluded.endereco,
    bairro = excluded.bairro,
    cep = excluded.cep,
    telefone = excluded.telefone,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    geom = excluded.geom,
    cd_tipo_local = excluded.cd_tipo_local,
    ds_tipo_local = excluded.ds_tipo_local,
    cd_situ_local_votacao = excluded.cd_situ_local_votacao,
    ds_situ_local_votacao = excluded.ds_situ_local_votacao,
    status = excluded.status,
    is_principal = excluded.is_principal,
    fonte_tre_confirmada = excluded.fonte_tre_confirmada,
    source_priority = excluded.source_priority;

with csv_alias as (
    select distinct on (src.nr_zona::integer, src.nr_local_votacao::integer)
        lv.local_id,
        src.nr_zona::integer as nr_zona,
        src.nr_local_votacao::integer as nr_local_votacao,
        nullif(trim(src.nm_local_votacao), '') as nome_original,
        nullif(trim(src.ds_endereco), '') as endereco_original,
        nullif(trim(src.nm_bairro), '') as bairro_original,
        nullif(replace(src.nr_latitude, ',', '.'), '')::numeric(11, 8) as latitude_original,
        nullif(replace(src.nr_longitude, ',', '.'), '')::numeric(11, 8) as longitude_original,
        src.source_file
    from stg.eleitorado_local_votacao_2026_df src
    join dim.eleicao e
      on e.ano = 2026
     and e.turno = 1
     and e.cd_eleicao = 6259
    join dim.uf uf
      on uf.sigla = 'DF'
    join dim.local_votacao lv
      on lv.eleicao_id = e.eleicao_id
     and lv.uf_id = uf.uf_id
     and lv.nr_zona = src.nr_zona::integer
     and lv.nr_local_votacao = src.nr_local_votacao::integer
    where nullif(src.nr_zona, '') is not null
      and nullif(src.nr_local_votacao, '') is not null
    order by src.nr_zona::integer, src.nr_local_votacao::integer, src.row_number
),
tre_alias as (
    select
        lv.local_id,
        tre.ze::integer as nr_zona,
        tre.num_local::integer as nr_local_votacao,
        nullif(trim(tre.nom_local), '') as nome_original,
        nullif(trim(tre.endereco_local), '') as endereco_original,
        nullif(trim(tre.bairro_local), '') as bairro_original,
        case
            when replace(trim(tre.num_latitude_local), ',', '.') ~ '^-?[0-9]+(\.[0-9]+)?$' then
                replace(trim(tre.num_latitude_local), ',', '.')::numeric(11, 8)
            else null
        end as latitude_original,
        case
            when replace(trim(tre.num_longitude_local), ',', '.') ~ '^-?[0-9]+(\.[0-9]+)?$' then
                replace(trim(tre.num_longitude_local), ',', '.')::numeric(11, 8)
            else null
        end as longitude_original,
        tre.source_file
    from stg.tre_locais_2026_df tre
    join dim.eleicao e
      on e.ano = 2026
     and e.turno = 1
     and e.cd_eleicao = 6259
    join dim.uf uf
      on uf.sigla = 'DF'
    join dim.local_votacao lv
      on lv.eleicao_id = e.eleicao_id
     and lv.uf_id = uf.uf_id
     and lv.nr_zona = tre.ze::integer
     and lv.nr_local_votacao = tre.num_local::integer
    where not tre.is_total
      and nullif(tre.ze, '') is not null
      and nullif(tre.num_local, '') is not null
)
insert into aux.local_votacao_alias (
    local_id,
    nr_zona,
    nr_local_votacao,
    nome_original,
    endereco_original,
    bairro_original,
    latitude_original,
    longitude_original,
    source_file
)
select * from csv_alias
union all
select * from tre_alias
on conflict (local_id, source_file, nome_original, endereco_original) do update
set nr_zona = excluded.nr_zona,
    nr_local_votacao = excluded.nr_local_votacao,
    bairro_original = excluded.bairro_original,
    latitude_original = excluded.latitude_original,
    longitude_original = excluded.longitude_original;

insert into aux.qualidade_dado (
    entidade,
    chave_natural,
    severidade,
    regra,
    detalhe,
    source_file
)
select
    'local_votacao',
    concat('2026|DF|ZE=', nr_zona, '|LOCAL=', nr_local_votacao),
    'erro',
    'local_sem_coordenada',
    concat('Local sem coordenada valida: ', nome),
    source_priority
from dim.local_votacao
where geom is null
on conflict do nothing;

insert into aux.qualidade_dado (
    entidade,
    chave_natural,
    severidade,
    regra,
    detalhe,
    source_file
)
select
    'local_votacao',
    concat('2026|DF|ZE=', nr_zona, '|LOCAL=', nr_local_votacao),
    'erro',
    'local_sem_ra',
    concat('Local com coordenada fora das RAs: ', nome),
    source_priority
from dim.local_votacao
where geom is not null
  and ra_id is null
on conflict do nothing;

with csv_pairs as (
    select distinct
        nr_zona::integer as nr_zona,
        nr_local_votacao::integer as nr_local_votacao,
        source_file
    from stg.eleitorado_local_votacao_2026_df
    where nullif(nr_zona, '') is not null
      and nullif(nr_local_votacao, '') is not null
),
tre_pairs as (
    select distinct
        ze::integer as nr_zona,
        num_local::integer as nr_local_votacao
    from stg.tre_locais_2026_df
    where not is_total
      and nullif(ze, '') is not null
      and nullif(num_local, '') is not null
)
insert into aux.qualidade_dado (
    entidade,
    chave_natural,
    severidade,
    regra,
    detalhe,
    source_file
)
select
    'local_votacao',
    concat('2026|DF|ZE=', csv_pairs.nr_zona, '|LOCAL=', csv_pairs.nr_local_votacao),
    'aviso',
    'local_csv_sem_tre',
    'Par zona/local presente no CSV oficial e ausente na planilha Locais_TRE_DF_2026.xlsx',
    csv_pairs.source_file
from csv_pairs
left join tre_pairs
  on tre_pairs.nr_zona = csv_pairs.nr_zona
 and tre_pairs.nr_local_votacao = csv_pairs.nr_local_votacao
where tre_pairs.nr_zona is null
on conflict do nothing;

with reused as (
    select
        nr_local_votacao::integer as nr_local_votacao,
        count(distinct nr_zona::integer) as zonas
    from stg.eleitorado_local_votacao_2026_df
    where nullif(nr_zona, '') is not null
      and nullif(nr_local_votacao, '') is not null
    group by nr_local_votacao::integer
    having count(distinct nr_zona::integer) > 1
)
insert into aux.qualidade_dado (
    entidade,
    chave_natural,
    severidade,
    regra,
    detalhe,
    source_file
)
select
    'local_votacao',
    concat('2026|DF|LOCAL=', nr_local_votacao),
    'info',
    'nr_local_votacao_reutilizado_em_zonas',
    concat('Numero de local reutilizado em ', zonas, ' zonas; chave fisica usa zona + local.'),
    'eleitorado_local_votacao_2026_DF.csv'
from reused
on conflict do nothing;
