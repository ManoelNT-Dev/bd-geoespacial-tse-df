with indicador_populacao as (
    select indicador_id
    from dim.indicador_sociodemografico
    where codigo = 'populacao_total'
),
checks(check_name, expected_value, actual_value) as (
    values
        (
            'sociodemografia_ra_distinct_ra_count',
            37,
            (select count(distinct ra_id)::integer from fato.sociodemografia_ra)
        ),
        (
            'sociodemografia_ra_indicadores_count',
            592,
            (select count(*)::integer from fato.sociodemografia_ra)
        ),
        (
            'sociodemografia_ra_resumo_count',
            37,
            (select count(*)::integer from fato.sociodemografia_ra_resumo)
        ),
        (
            'sociodemografia_ra_populacao_total',
            2982816,
            (
                select sum(f.valor_num)::integer
                from fato.sociodemografia_ra f
                join indicador_populacao i on i.indicador_id = f.indicador_id
            )
        ),
        (
            'pop_26_de_setembro',
            29394,
            (
                select f.valor_num::integer
                from fato.sociodemografia_ra f
                join indicador_populacao i on i.indicador_id = f.indicador_id
                join dim.regiao_administrativa ra on ra.ra_id = f.ra_id
                where ra.ra_nome_normalizado = '26 DE SETEMBRO'
            )
        ),
        (
            'pop_ponte_alta',
            45452,
            (
                select f.valor_num::integer
                from fato.sociodemografia_ra f
                join indicador_populacao i on i.indicador_id = f.indicador_id
                join dim.regiao_administrativa ra on ra.ra_id = f.ra_id
                where ra.ra_nome_normalizado = 'PONTE ALTA'
            )
        ),
        (
            'pop_vicente_pires',
            75668,
            (
                select f.valor_num::integer
                from fato.sociodemografia_ra f
                join indicador_populacao i on i.indicador_id = f.indicador_id
                join dim.regiao_administrativa ra on ra.ra_id = f.ra_id
                where ra.ra_nome_normalizado = 'VICENTE PIRES'
            )
        ),
        (
            'pop_gama',
            88496,
            (
                select f.valor_num::integer
                from fato.sociodemografia_ra f
                join indicador_populacao i on i.indicador_id = f.indicador_id
                join dim.regiao_administrativa ra on ra.ra_id = f.ra_id
                where ra.ra_nome_normalizado = 'GAMA'
            )
        ),
        (
            'qualidade_sociodemografia_erros',
            0,
            (
                select count(*)::integer
                from aux.qualidade_dado
                where entidade in ('sociodemografia_ra', 'perfil_sociodemografico_ra_df_json')
                  and severidade = 'erro'
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
