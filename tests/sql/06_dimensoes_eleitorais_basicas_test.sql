with checks(check_name, expected_value, actual_value) as (
    values
        (
            'dim_zona_eleitoral_count',
            19,
            (select count(*)::integer from dim.zona_eleitoral)
        ),
        (
            'dim_cargo_eleitoral_count',
            7,
            (select count(*)::integer from dim.cargo_eleitoral)
        ),
        (
            'dim_partido_politico_count',
            29,
            (select count(*)::integer from dim.partido_politico)
        ),
        (
            'dim_federacao_count_real',
            5,
            (select count(*)::integer from dim.federacao)
        ),
        (
            'dim_coligacao_count',
            62,
            (select count(*)::integer from dim.coligacao)
        ),
        (
            'dim_zona_eleitoral_chave_duplicada',
            0,
            (
                select count(*)::integer
                from (
                    select uf_id, nr_zona
                    from dim.zona_eleitoral
                    group by uf_id, nr_zona
                    having count(*) > 1
                ) duplicadas
            )
        ),
        (
            'dim_cargo_eleitoral_chave_duplicada',
            0,
            (
                select count(*)::integer
                from (
                    select cd_cargo
                    from dim.cargo_eleitoral
                    group by cd_cargo
                    having count(*) > 1
                ) duplicadas
            )
        ),
        (
            'dim_partido_politico_nr_duplicado',
            0,
            (
                select count(*)::integer
                from (
                    select nr_partido
                    from dim.partido_politico
                    group by nr_partido
                    having count(*) > 1
                ) duplicadas
            )
        ),
        (
            'dim_partido_politico_sigla_duplicada',
            0,
            (
                select count(*)::integer
                from (
                    select sigla
                    from dim.partido_politico
                    group by sigla
                    having count(*) > 1
                ) duplicadas
            )
        ),
        (
            'dim_federacao_sem_codigo_especial',
            0,
            (
                select count(*)::integer
                from dim.federacao
                where nr_federacao <= 0
                   or sg_federacao = '#NULO'
            )
        ),
        (
            'dim_coligacao_chave_duplicada',
            0,
            (
                select count(*)::integer
                from (
                    select eleicao_id, sq_coligacao
                    from dim.coligacao
                    group by eleicao_id, sq_coligacao
                    having count(*) > 1
                ) duplicadas
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
