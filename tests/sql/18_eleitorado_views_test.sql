with checks(check_name, expected_value, actual_value) as (
    values
        (
            'mv_eleitorado_perfil_nivel_exists',
            1,
            (
                select count(*)::integer
                from pg_matviews
                where schemaname = 'fato'
                  and matviewname = 'mv_eleitorado_perfil_nivel'
            )
        ),
        (
            'eleitorado_views_count',
            4,
            (
                select count(*)::integer
                from information_schema.views
                where table_schema = 'fato'
                  and table_name in (
                      'vw_eleitorado_perfil_ra',
                      'vw_eleitorado_perfil_local',
                      'vw_eleitorado_perfil_secao',
                      'vw_eleitorado_dominante_nivel'
                  )
            )
        ),
        (
            'mv_eleitorado_indexes_count',
            3,
            (
                select count(*)::integer
                from pg_indexes
                where schemaname = 'fato'
                  and indexname in (
                      'mv_eleitorado_perfil_nivel_uk',
                      'mv_eleitorado_perfil_nivel_filtro_idx',
                      'mv_eleitorado_perfil_nivel_territorio_idx'
                  )
            )
        ),
        (
            'mv_eleitorado_total_linhas',
            346143,
            (select count(*)::integer from fato.mv_eleitorado_perfil_nivel)
        ),
        (
            'vw_eleitorado_perfil_ra_count',
            1951,
            (select count(*)::integer from fato.vw_eleitorado_perfil_ra)
        ),
        (
            'vw_eleitorado_perfil_local_count',
            31168,
            (select count(*)::integer from fato.vw_eleitorado_perfil_local)
        ),
        (
            'vw_eleitorado_perfil_secao_count',
            313024,
            (select count(*)::integer from fato.vw_eleitorado_perfil_secao)
        ),
        (
            'vw_eleitorado_dominante_count',
            61544,
            (select count(*)::integer from fato.vw_eleitorado_dominante_nivel)
        ),
        (
            'vw_eleitorado_ra_distinct_count',
            36,
            (select count(distinct ra_id)::integer from fato.vw_eleitorado_perfil_ra)
        ),
        (
            'vw_eleitorado_ra_nula_eleitores',
            603,
            (
                select sum(qt_eleitores)::integer
                from fato.vw_eleitorado_perfil_ra
                where ra_id is null
                  and dimensao = 'genero'
            )
        ),
        (
            'vw_eleitorado_local_distinct_count',
            614,
            (select count(distinct local_id)::integer from fato.vw_eleitorado_perfil_local)
        ),
        (
            'vw_eleitorado_secao_distinct_count',
            7042,
            (select count(distinct secao_id)::integer from fato.vw_eleitorado_perfil_secao)
        ),
        (
            'mv_eleitorado_ra_genero_total',
            2253132,
            (
                select sum(qt_eleitores)::integer
                from fato.mv_eleitorado_perfil_nivel
                where ano = 2026
                  and nivel = 'ra'
                  and dimensao = 'genero'
            )
        ),
        (
            'mv_eleitorado_local_genero_total',
            2253132,
            (
                select sum(qt_eleitores)::integer
                from fato.mv_eleitorado_perfil_nivel
                where ano = 2026
                  and nivel = 'local'
                  and dimensao = 'genero'
            )
        ),
        (
            'mv_eleitorado_secao_genero_total',
            2253132,
            (
                select sum(qt_eleitores)::integer
                from fato.mv_eleitorado_perfil_nivel
                where ano = 2026
                  and nivel = 'secao'
                  and dimensao = 'genero'
            )
        ),
        (
            'vw_eleitorado_dominante_ra_count',
            296,
            (
                select count(*)::integer
                from fato.vw_eleitorado_dominante_nivel
                where nivel = 'ra'
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
