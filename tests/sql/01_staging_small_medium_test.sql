with expected_counts(table_name, expected_count) as (
    values
        ('consulta_cand_2026_df', 661),
        ('consulta_cand_complementar_2026_df', 661),
        ('eleitorado_local_votacao_2026_df', 7050),
        ('tre_locais_2026_df', 614),
        ('tre_locais_secao_2026_df', 614),
        ('tre_locais_secao_agrupadas_2026_df', 614),
        ('tre_secoes_2026_df', 6961),
        ('geo_ra_centroid_atualizado', 35),
        ('ra_shapefile', 37)
),
actual_counts(table_name, actual_count) as (
    values
        ('consulta_cand_2026_df', (select count(*)::integer from stg.consulta_cand_2026_df)),
        ('consulta_cand_complementar_2026_df', (select count(*)::integer from stg.consulta_cand_complementar_2026_df)),
        ('eleitorado_local_votacao_2026_df', (select count(*)::integer from stg.eleitorado_local_votacao_2026_df)),
        ('tre_locais_2026_df', (select count(*)::integer from stg.tre_locais_2026_df where not is_total)),
        ('tre_locais_secao_2026_df', (select count(*)::integer from stg.tre_locais_secao_2026_df where not is_total)),
        ('tre_locais_secao_agrupadas_2026_df', (select count(*)::integer from stg.tre_locais_secao_agrupadas_2026_df where not is_total)),
        ('tre_secoes_2026_df', (select count(*)::integer from stg.tre_secoes_2026_df where not is_total)),
        ('geo_ra_centroid_atualizado', (select count(*)::integer from stg.geo_ra_centroid_atualizado)),
        ('ra_shapefile', (select count(*)::integer from stg.ra_shapefile))
)
select expected_counts.table_name,
       expected_counts.expected_count,
       actual_counts.actual_count
from expected_counts
join actual_counts using (table_name)
where expected_counts.expected_count <> actual_counts.actual_count
order by expected_counts.table_name;
