with checks(check_name, expected_value, actual_value) as (
    values
        (
            'stg_votacao_piloto_ze20_count',
            44464,
            (select count(*)::integer from stg.votacao_secao_2022_df)
        ),
        (
            'stg_votacao_piloto_uma_zona',
            1,
            (select count(distinct nr_zona)::integer from stg.votacao_secao_2022_df)
        ),
        (
            'stg_votacao_piloto_zona_20',
            20,
            (select min(nr_zona::integer) from stg.votacao_secao_2022_df)
        ),
        (
            'dim_eleicao_2022_criada',
            1,
            (
                select count(*)::integer
                from dim.eleicao
                where ano = 2022
                  and turno = 1
                  and cd_eleicao = 546
            )
        ),
        (
            'fato_votacao_piloto_count',
            (select count(*)::integer from stg.votacao_secao_2022_df),
            (select count(*)::integer from fato.votacao_candidato_secao vc join dim.eleicao e on e.eleicao_id = vc.eleicao_id where e.ano = 2022 and e.cd_eleicao = 546)
        ),
        (
            'fato_votacao_piloto_soma_votos',
            (select sum(qt_votos::integer)::integer from stg.votacao_secao_2022_df),
            (select sum(vc.qt_votos)::integer from fato.votacao_candidato_secao vc join dim.eleicao e on e.eleicao_id = vc.eleicao_id where e.ano = 2022 and e.cd_eleicao = 546)
        ),
        (
            'fato_votacao_tipos_distintos',
            4,
            (select count(distinct tipo_votavel)::integer from fato.votacao_candidato_secao vc join dim.eleicao e on e.eleicao_id = vc.eleicao_id where e.ano = 2022 and e.cd_eleicao = 546)
        ),
        (
            'dim_votavel_tipos_distintos',
            4,
            (select count(distinct tipo_votavel)::integer from dim.votavel v join dim.eleicao e on e.eleicao_id = v.eleicao_id where e.ano = 2022 and e.cd_eleicao = 546)
        ),
        (
            'fato_votacao_sem_secao',
            0,
            (
                select count(*)::integer
                from fato.votacao_candidato_secao vc
                left join dim.secao_eleitoral se on se.secao_id = vc.secao_id
                where se.secao_id is null
            )
        ),
        (
            'view_drilldown_piloto_count',
            (select count(*)::integer from fato.votacao_candidato_secao vc join dim.eleicao e on e.eleicao_id = vc.eleicao_id where e.ano = 2022 and e.cd_eleicao = 546),
            (select count(*)::integer from fato.vw_votacao_drilldown where ano = 2022 and cd_eleicao = 546)
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
