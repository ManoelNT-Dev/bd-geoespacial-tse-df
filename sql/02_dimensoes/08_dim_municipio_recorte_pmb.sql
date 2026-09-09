create table if not exists dim.municipio (
    municipio_id bigint generated always as identity primary key,
    uf_id smallint not null references dim.uf (uf_id),
    municipio_codigo_tse integer,
    municipio_codigo_ibge integer not null,
    municipio_nome text not null,
    municipio_nome_normalizado text not null,
    area_km2 numeric(12, 2),
    pop_municipio integer,
    pop_municipio_ano integer,
    pop_municipio_data_referencia date,
    latitude numeric(12, 8),
    longitude numeric(12, 8),
    geom geometry(Point, 4326),
    source_file text,
    loaded_at timestamptz not null default now(),
    unique (uf_id, municipio_codigo_ibge),
    unique (uf_id, municipio_codigo_tse)
);

create index if not exists municipio_geom_idx on dim.municipio using gist (geom);
create index if not exists municipio_nome_normalizado_idx on dim.municipio (municipio_nome_normalizado);

create table if not exists dim.recorte_geografico (
    recorte_id bigint generated always as identity primary key,
    codigo text not null unique,
    nome text not null,
    tipo text not null,
    descricao text,
    source_file text,
    loaded_at timestamptz not null default now()
);

create table if not exists dim.recorte_municipio (
    recorte_id bigint not null references dim.recorte_geografico (recorte_id),
    municipio_id bigint not null references dim.municipio (municipio_id),
    loaded_at timestamptz not null default now(),
    primary key (recorte_id, municipio_id)
);

with pmb_json as (
    select payload, source_file
    from stg.eleitorado_pmb_2026_json
    where source_file = 'eleitorado_PMB_2026.json'
    order by loaded_at desc
    limit 1
),
pmb as (
    select
        payload #>> '{pmb,codigo}' as codigo,
        payload #>> '{pmb,nome}' as nome,
        'municipios_pmb'::text as tipo,
        payload #>> '{pmb,descricao}' as descricao,
        source_file
    from pmb_json
)
insert into dim.recorte_geografico (codigo, nome, tipo, descricao, source_file)
select codigo, nome, tipo, descricao, source_file
from pmb
on conflict (codigo) do update
set nome = excluded.nome,
    tipo = excluded.tipo,
    descricao = excluded.descricao,
    source_file = excluded.source_file,
    loaded_at = now();

with pmb_json as (
    select payload, source_file
    from stg.eleitorado_pmb_2026_json
    where source_file = 'eleitorado_PMB_2026.json'
    order by loaded_at desc
    limit 1
),
uf_go as (
    select uf_id
    from dim.uf
    where sigla = 'GO'
),
source_municipio as (
    select
        uf_go.uf_id,
        (municipio ->> 'municipio_codigo_tse')::integer as municipio_codigo_tse,
        (municipio ->> 'municipio_codigo_ibge')::integer as municipio_codigo_ibge,
        municipio ->> 'municipio_nome' as municipio_nome,
        upper(unaccent(municipio ->> 'municipio_nome')) as municipio_nome_normalizado,
        nullif(municipio ->> 'area_km2', '')::numeric(12, 2) as area_km2,
        (municipio ->> 'pop_municipio')::integer as pop_municipio,
        (municipio #>> '{pop_municipio_fonte,periodo}')::integer as pop_municipio_ano,
        (municipio #>> '{pop_municipio_fonte,data_referencia}')::date as pop_municipio_data_referencia,
        (municipio #>> '{centroid,latitude}')::numeric(12, 8) as latitude,
        (municipio #>> '{centroid,longitude}')::numeric(12, 8) as longitude,
        pmb_json.source_file
    from pmb_json
    cross join uf_go
    cross join lateral jsonb_array_elements(pmb_json.payload #> '{pmb,municipios}') as municipio
)
insert into dim.municipio (
    uf_id,
    municipio_codigo_tse,
    municipio_codigo_ibge,
    municipio_nome,
    municipio_nome_normalizado,
    area_km2,
    pop_municipio,
    pop_municipio_ano,
    pop_municipio_data_referencia,
    latitude,
    longitude,
    geom,
    source_file
)
select
    uf_id,
    municipio_codigo_tse,
    municipio_codigo_ibge,
    municipio_nome,
    municipio_nome_normalizado,
    area_km2,
    pop_municipio,
    pop_municipio_ano,
    pop_municipio_data_referencia,
    latitude,
    longitude,
    st_setsrid(st_makepoint(longitude, latitude), 4326) as geom,
    source_file
from source_municipio
on conflict (uf_id, municipio_codigo_ibge) do update
set municipio_codigo_tse = excluded.municipio_codigo_tse,
    municipio_nome = excluded.municipio_nome,
    municipio_nome_normalizado = excluded.municipio_nome_normalizado,
    area_km2 = excluded.area_km2,
    pop_municipio = excluded.pop_municipio,
    pop_municipio_ano = excluded.pop_municipio_ano,
    pop_municipio_data_referencia = excluded.pop_municipio_data_referencia,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    geom = excluded.geom,
    source_file = excluded.source_file,
    loaded_at = now();

with recorte_pmb as (
    select recorte_id
    from dim.recorte_geografico
    where codigo = 'PMB'
),
municipios_pmb as (
    select municipio_id
    from dim.municipio
    where municipio_codigo_tse in (
        select (municipio ->> 'municipio_codigo_tse')::integer
        from stg.eleitorado_pmb_2026_json json_source
        cross join lateral jsonb_array_elements(json_source.payload #> '{pmb,municipios}') as municipio
        where json_source.source_file = 'eleitorado_PMB_2026.json'
    )
)
insert into dim.recorte_municipio (recorte_id, municipio_id)
select recorte_pmb.recorte_id, municipios_pmb.municipio_id
from recorte_pmb
cross join municipios_pmb
on conflict (recorte_id, municipio_id) do nothing;
