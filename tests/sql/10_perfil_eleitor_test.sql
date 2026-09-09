with checks(check_name, expected_value, actual_value) as (
    values
        (
            'dim_perfil_eleitor_count',
            13628,
            (select count(*)::integer from dim.perfil_eleitor)
        ),
        (
            'dim_perfil_eleitor_hash_distintos',
            13628,
            (select count(distinct perfil_hash)::integer from dim.perfil_eleitor)
        ),
        (
            'fato_eleitorado_perfil_secao_count_agregada',
            1219951,
            (select count(*)::integer from fato.eleitorado_perfil_secao)
        ),
        (
            'fato_eleitorado_source_row_count',
            1233369,
            (select sum(source_row_count)::integer from fato.eleitorado_perfil_secao)
        ),
        (
            'fato_eleitorado_secoes_distintas',
            7042,
            (select count(distinct secao_id)::integer from fato.eleitorado_perfil_secao)
        ),
        (
            'fato_eleitorado_soma_eleitores',
            2253132,
            (select sum(qt_eleitores)::integer from fato.eleitorado_perfil_secao)
        ),
        (
            'fato_eleitorado_soma_biometria',
            2126894,
            (select sum(qt_eleitores_biometria)::integer from fato.eleitorado_perfil_secao)
        ),
        (
            'fato_eleitorado_pk_duplicada',
            0,
            (
                select count(*)::integer
                from (
                    select eleicao_id, secao_id, perfil_id
                    from fato.eleitorado_perfil_secao
                    group by eleicao_id, secao_id, perfil_id
                    having count(*) > 1
                ) duplicadas
            )
        ),
        (
            'fato_eleitorado_sem_ra_com_geom',
            0,
            (
                select count(*)::integer
                from fato.eleitorado_perfil_secao fato
                join dim.secao_eleitoral secao on secao.secao_id = fato.secao_id
                where secao.geom is not null
                  and fato.ra_id is null
            )
        ),
        (
            'qualidade_perfil_sem_secao',
            0,
            (
                select count(*)::integer
                from aux.qualidade_dado
                where entidade = 'eleitorado_perfil_secao'
                  and regra = 'perfil_sem_secao'
            )
        ),
        (
            'qualidade_perfil_diverge_aptos_csv',
            0,
            (
                select count(*)::integer
                from aux.qualidade_dado
                where entidade = 'eleitorado_perfil_secao'
                  and regra = 'perfil_secao_diverge_aptos_csv'
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
