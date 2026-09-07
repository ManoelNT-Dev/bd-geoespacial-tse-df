with checks(check_name, expected_value, actual_value) as (
    values
        (
            'dim_regiao_administrativa_count',
            37,
            (select count(*)::integer from dim.regiao_administrativa)
        ),
        (
            'geo_ra_geometria_count',
            37,
            (select count(*)::integer from geo.ra_geometria)
        ),
        (
            'geo_ra_centroid_geojson_count',
            34,
            (
                select count(*)::integer
                from geo.ra_geometria
                where centroid_origem = 'geojson'
            )
        ),
        (
            'geo_ra_centroid_calculado_count',
            3,
            (
                select count(*)::integer
                from geo.ra_geometria
                where centroid_origem = 'calculado_shapefile'
            )
        ),
        (
            'geo_ra_sem_geometria_ou_centroide',
            0,
            (
                select count(*)::integer
                from geo.ra_geometria
                where geom is null
                   or geom_utm is null
                   or centroid_geom is null
            )
        ),
        (
            'geo_ra_geometria_invalida',
            0,
            (
                select count(*)::integer
                from geo.ra_geometria
                where not st_isvalid(geom)
                   or not st_isvalid(geom_utm)
            )
        ),
        (
            'geo_ra_centroide_fora_poligono',
            0,
            (
                select count(*)::integer
                from geo.ra_geometria
                where not st_covers(geom, centroid_geom)
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
