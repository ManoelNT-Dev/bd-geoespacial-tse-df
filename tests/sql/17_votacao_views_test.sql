with checks(check_name, expected_value, actual_value) as (
    values
        (
            'votacao_views_count',
            6,
            (
                select count(*)::integer
                from information_schema.views
                where table_schema = 'fato'
                  and table_name in (
                      'vw_votacao_resultado_nivel',
                      'vw_votacao_top5',
                      'vw_votacao_rank_pareto',
                      'vw_vitorias_zeros_votavel',
                      'vw_votacao_heatmap_top5',
                      'vw_votacao_stacked_ra_top5'
                  )
            )
        ),
        (
            'votacao_top2_views_absent',
            0,
            (
                select count(*)::integer
                from information_schema.views
                where table_schema = 'fato'
                  and table_name ilike '%top2%'
            )
        ),
        (
            'vw_votacao_resultado_nivel_count',
            55219,
            (select count(*)::integer from fato.vw_votacao_resultado_nivel)
        ),
        (
            'vw_votacao_top5_count',
            4779,
            (select count(*)::integer from fato.vw_votacao_top5)
        ),
        (
            'vw_votacao_rank_pareto_count',
            53308,
            (select count(*)::integer from fato.vw_votacao_rank_pareto)
        ),
        (
            'vw_vitorias_zeros_votavel_count',
            53308,
            (select count(*)::integer from fato.vw_vitorias_zeros_votavel)
        ),
        (
            'vw_votacao_heatmap_top5_count',
            20,
            (select count(*)::integer from fato.vw_votacao_heatmap_top5)
        ),
        (
            'vw_votacao_stacked_ra_top5_count',
            20,
            (select count(*)::integer from fato.vw_votacao_stacked_ra_top5)
        ),
        (
            'vw_resultado_geral_votos_piloto',
            261004,
            (
                select sum(qt_votos)::integer
                from fato.vw_votacao_resultado_nivel
                where ano = 2022
                  and cd_eleicao = 546
                  and nivel = 'geral'
            )
        ),
        (
            'vw_resultado_secao_votos_piloto',
            261004,
            (
                select sum(qt_votos)::integer
                from fato.vw_votacao_resultado_nivel
                where ano = 2022
                  and cd_eleicao = 546
                  and nivel = 'secao'
            )
        ),
        (
            'vw_top5_max_rank_piloto',
            5,
            (
                select max(ranking_top5)::integer
                from fato.vw_votacao_top5
                where ano = 2022
                  and cd_eleicao = 546
            )
        ),
        (
            'vw_secao_vitorias_piloto',
            876,
            (
                select count(*)::integer
                from fato.vw_vitorias_zeros_votavel
                where ano = 2022
                  and cd_eleicao = 546
                  and nivel = 'secao'
                  and venceu_nivel
            )
        ),
        (
            'vw_pareto_geral_max_pct_piloto',
            100,
            (
                select round(max(cum_pct))::integer
                from fato.vw_votacao_rank_pareto
                where ano = 2022
                  and cd_eleicao = 546
                  and nivel = 'geral'
            )
        ),
        (
            'vw_heatmap_top5_max_ranking_geral',
            5,
            (select max(ranking_geral)::integer from fato.vw_votacao_heatmap_top5)
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
