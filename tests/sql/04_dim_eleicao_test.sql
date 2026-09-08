with checks(check_name, expected_value, actual_value) as (
    values
        (
            'dim_eleicao_2026_count',
            1,
            (
                select count(*)::integer
                from dim.eleicao
                where ano = 2026
                  and turno = 1
                  and cd_eleicao = 6259
                  and ds_eleicao = 'Eleições Gerais Estaduais 2026'
                  and cd_tipo_eleicao = 2
                  and nm_tipo_eleicao = 'ELEIÇÃO ORDINÁRIA'
                  and dt_eleicao = date '2026-10-04'
                  and tp_abrangencia = 'ESTADUAL'
            )
        ),
        (
            'dim_eleicao_chave_duplicada',
            0,
            (
                select count(*)::integer
                from (
                    select ano, turno, cd_eleicao
                    from dim.eleicao
                    group by ano, turno, cd_eleicao
                    having count(*) > 1
                ) duplicadas
            )
        ),
        (
            'dim_eleicao_2022_piloto_count',
            1,
            (
                select count(*)::integer
                from dim.eleicao
                where ano = 2022
                  and turno = 1
                  and cd_eleicao = 546
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
