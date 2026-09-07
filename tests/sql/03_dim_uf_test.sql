with checks(check_name, expected_value, actual_value) as (
    values
        (
            'dim_uf_df_count',
            1,
            (
                select count(*)::integer
                from dim.uf
                where sigla = 'DF'
                  and nome = 'Distrito Federal'
                  and codigo_ibge = 53
            )
        ),
        (
            'dim_uf_sigla_duplicada',
            0,
            (
                select count(*)::integer
                from (
                    select sigla
                    from dim.uf
                    group by sigla
                    having count(*) > 1
                ) duplicadas
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
