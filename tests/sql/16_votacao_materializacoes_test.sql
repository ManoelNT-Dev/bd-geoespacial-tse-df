with checks(check_name, expected_value, actual_value) as (
    values
        (
            'mv_votacao_nivel_exists',
            1,
            (
                select count(*)::integer
                from pg_matviews
                where schemaname = 'fato'
                  and matviewname = 'mv_votacao_nivel'
            )
        ),
        (
            'mv_votacao_top5_exists',
            1,
            (
                select count(*)::integer
                from pg_matviews
                where schemaname = 'fato'
                  and matviewname = 'mv_votacao_top5'
            )
        ),
        (
            'mv_votacao_top2_absent',
            0,
            (
                select count(*)::integer
                from pg_matviews
                where schemaname = 'fato'
                  and matviewname ilike '%top2%'
            )
        ),
        (
            'mv_votacao_indexes_count',
            6,
            (
                select count(*)::integer
                from pg_indexes
                where schemaname = 'fato'
                  and indexname in (
                      'mv_votacao_nivel_uk',
                      'mv_votacao_nivel_filtro_idx',
                      'mv_votacao_nivel_territorio_idx',
                      'mv_votacao_top5_uk',
                      'mv_votacao_top5_votavel_idx',
                      'mv_votacao_top5_territorio_idx'
                  )
            )
        ),
        (
            'mv_votacao_top2_indexes_absent',
            0,
            (
                select count(*)::integer
                from pg_indexes
                where schemaname = 'fato'
                  and indexname ilike '%top2%'
            )
        ),
        (
            'mv_votacao_nivel_total_linhas',
            55219,
            (select count(*)::integer from fato.mv_votacao_nivel)
        ),
        (
            'mv_votacao_top5_total_linhas',
            4779,
            (select count(*)::integer from fato.mv_votacao_top5)
        ),
        (
            'mv_votacao_nivel_niveis',
            4,
            (select count(distinct nivel)::integer from fato.mv_votacao_nivel)
        ),
        (
            'mv_votacao_top5_niveis',
            4,
            (select count(distinct nivel)::integer from fato.mv_votacao_top5)
        ),
        (
            'mv_votacao_top5_max_rank',
            5,
            (select max(ranking_top5)::integer from fato.mv_votacao_top5)
        ),
        (
            'mv_votacao_nivel_geral_votos_piloto',
            261004,
            (
                select sum(qt_votos)::integer
                from fato.mv_votacao_nivel
                where ano = 2022
                  and cd_eleicao = 546
                  and nivel = 'geral'
            )
        ),
        (
            'mv_votacao_nivel_secao_votos_piloto',
            261004,
            (
                select sum(qt_votos)::integer
                from fato.mv_votacao_nivel
                where ano = 2022
                  and cd_eleicao = 546
                  and nivel = 'secao'
            )
        ),
        (
            'mv_votacao_nivel_geral_validos_piloto',
            233040,
            (
                select sum(qt_votos)::integer
                from fato.mv_votacao_nivel
                where ano = 2022
                  and cd_eleicao = 546
                  and nivel = 'geral'
                  and tipo_votavel in ('nominal', 'legenda')
            )
        ),
        (
            'mv_votacao_top5_geral_count_piloto',
            20,
            (
                select count(*)::integer
                from fato.mv_votacao_top5
                where ano = 2022
                  and cd_eleicao = 546
                  and nivel = 'geral'
            )
        ),
        (
            'mv_votacao_top5_secao_count_piloto',
            4379,
            (
                select count(*)::integer
                from fato.mv_votacao_top5
                where ano = 2022
                  and cd_eleicao = 546
                  and nivel = 'secao'
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
