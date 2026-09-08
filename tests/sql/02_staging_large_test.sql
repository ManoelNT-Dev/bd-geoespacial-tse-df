with checks(check_name, expected_value, actual_value) as (
    values
        (
            'perfil_eleitor_secao_2026_df_count',
            1233369,
            (select count(*)::integer from stg.perfil_eleitor_secao_2026_df)
        ),
        (
            'perfil_eleitor_secao_2026_df_secoes_distintas',
            7042,
            (
                select count(distinct sg_uf || '-' || nr_zona || '-' || nr_secao)::integer
                from stg.perfil_eleitor_secao_2026_df
            )
        ),
        (
            'votacao_secao_2022_df_count_piloto_ze20',
            44464,
            (select count(*)::integer from stg.votacao_secao_2022_df)
        ),
        (
            'votacao_secao_2022_df_zona_piloto',
            20,
            (select min(nr_zona::integer) from stg.votacao_secao_2022_df)
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
