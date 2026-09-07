create table if not exists dim.regiao_administrativa (
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

create table if not exists geo.ra_geometria (
    ra_id bigint primary key references dim.regiao_administrativa (ra_id),
    geom_utm geometry(MultiPolygon, 31983),
    geom geometry(MultiPolygon, 4326) not null,
    centroid_geom geometry(Point, 4326),
    centroid_lon numeric(11,8),
    centroid_lat numeric(11,8),
    centroid_origem text not null default 'geojson'
);

create index if not exists ra_geometria_geom_gix on geo.ra_geometria using gist (geom);
create index if not exists ra_geometria_centroid_gix on geo.ra_geometria using gist (centroid_geom);

with uf_df as (
    select uf_id
    from dim.uf
    where sigla = 'DF'
),
source_ra as (
    select
        uf_df.uf_id,
        nullif(ra_cira, '')::integer as ra_cira,
        trim(ra_codigo) as ra_codigo,
        trim(ra_nome) as ra_nome,
        upper(unaccent(trim(ra_nome))) as ra_nome_normalizado,
        nullif(ra_areakm2, '')::numeric(14, 8) as area_km2,
        source_file as fonte_poligono
    from stg.ra_shapefile
    cross join uf_df
)
insert into dim.regiao_administrativa (
    uf_id,
    ra_cira,
    ra_codigo,
    ra_nome,
    ra_nome_normalizado,
    area_km2,
    fonte_poligono
)
select
    uf_id,
    ra_cira,
    ra_codigo,
    ra_nome,
    ra_nome_normalizado,
    area_km2,
    fonte_poligono
from source_ra
on conflict (uf_id, ra_codigo) do update
set ra_cira = excluded.ra_cira,
    ra_nome = excluded.ra_nome,
    ra_nome_normalizado = excluded.ra_nome_normalizado,
    area_km2 = excluded.area_km2,
    fonte_poligono = excluded.fonte_poligono;

with source_geom_base as (
    select
        ra.ra_id,
        st_multi(stg.geom)::geometry(MultiPolygon, 31983) as geom_utm,
        st_transform(st_multi(stg.geom), 4326)::geometry(MultiPolygon, 4326) as geom,
        case
            when centroid.ra_codigo is not null then
                st_setsrid(
                    st_makepoint(
                        nullif(centroid.longitude, '')::numeric,
                        nullif(centroid.latitude, '')::numeric
                    ),
                    4326
                )::geometry(Point, 4326)
            else null
        end as geojson_centroid_geom
    from stg.ra_shapefile stg
    join dim.regiao_administrativa ra
      on ra.ra_codigo = trim(stg.ra_codigo)
    join dim.uf uf
      on uf.uf_id = ra.uf_id
     and uf.sigla = 'DF'
    left join stg.geo_ra_centroid_atualizado centroid
      on trim(centroid.ra_codigo) = trim(stg.ra_codigo)
),
source_geom as (
    select
        ra_id,
        geom_utm,
        geom,
        case
            when geojson_centroid_geom is not null
             and st_covers(geom, geojson_centroid_geom) then
                geojson_centroid_geom
            else
                st_pointonsurface(geom)::geometry(Point, 4326)
        end as centroid_geom,
        case
            when geojson_centroid_geom is not null
             and st_covers(geom, geojson_centroid_geom) then 'geojson'
            else 'calculado_shapefile'
        end as centroid_origem
    from source_geom_base
)
insert into geo.ra_geometria (
    ra_id,
    geom_utm,
    geom,
    centroid_geom,
    centroid_lon,
    centroid_lat,
    centroid_origem
)
select
    ra_id,
    geom_utm,
    geom,
    centroid_geom,
    st_x(centroid_geom)::numeric(11, 8),
    st_y(centroid_geom)::numeric(11, 8),
    centroid_origem
from source_geom
on conflict (ra_id) do update
set geom_utm = excluded.geom_utm,
    geom = excluded.geom,
    centroid_geom = excluded.centroid_geom,
    centroid_lon = excluded.centroid_lon,
    centroid_lat = excluded.centroid_lat,
    centroid_origem = excluded.centroid_origem;

update dim.regiao_administrativa ra
set fonte_centroide = geo.centroid_origem
from geo.ra_geometria geo
where geo.ra_id = ra.ra_id;
