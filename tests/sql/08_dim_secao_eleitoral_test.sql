with checks(check_name, expected_value, actual_value) as (
    values
        (
            'dim_secao_eleitoral_count_csv',
            7050,
            (
                select count(*)::integer
                from dim.secao_eleitoral se
                join dim.eleicao e on e.eleicao_id = se.eleicao_id
                where e.ano = 2026
            )
        ),
        (
            'dim_secao_eleitoral_principais_tre_oficiais',
            6961,
            (
                select count(*)::integer
                from dim.secao_eleitoral se
                join dim.eleicao e on e.eleicao_id = se.eleicao_id
                where e.ano = 2026
                  and se.is_secao_principal_tre
            )
        ),
        (
            'dim_secao_eleitoral_tre_expandida',
            7042,
            (
                select count(*)::integer
                from dim.secao_eleitoral se
                join dim.eleicao e on e.eleicao_id = se.eleicao_id
                where e.ano = 2026
                  and se.fonte_tre_confirmada
            )
        ),
        (
            'dim_secao_eleitoral_agregadas_csv',
            81,
            (
                select count(*)::integer
                from dim.secao_eleitoral se
                join dim.eleicao e on e.eleicao_id = se.eleicao_id
                where e.ano = 2026
                  and se.ds_tipo_secao_agregada = 'Agregada'
            )
        ),
        (
            'dim_secao_eleitoral_adicionais_csv',
            8,
            (
                select count(*)::integer
                from dim.secao_eleitoral se
                join dim.eleicao e on e.eleicao_id = se.eleicao_id
                where e.ano = 2026
                  and se.is_adicional_csv
            )
        ),
        (
            'dim_secao_eleitoral_chave_duplicada',
            0,
            (
                select count(*)::integer
                from (
                    select eleicao_id, uf_id, nr_zona, nr_secao
                    from dim.secao_eleitoral
                    group by eleicao_id, uf_id, nr_zona, nr_secao
                    having count(*) > 1
                ) duplicadas
            )
        ),
        (
            'dim_secao_eleitoral_sem_local',
            0,
            (
                select count(*)::integer
                from dim.secao_eleitoral se
                join dim.eleicao e on e.eleicao_id = se.eleicao_id
                where e.ano = 2026
                  and se.local_id is null
            )
        ),
        (
            'dim_secao_eleitoral_agregada_sem_principal',
            0,
            (
                select count(*)::integer
                from dim.secao_eleitoral se
                join dim.eleicao e on e.eleicao_id = se.eleicao_id
                where e.ano = 2026
                  and se.ds_tipo_secao_agregada = 'Agregada'
                  and se.secao_principal_id is null
            )
        ),
        (
            'dim_secao_eleitoral_agregada_local_diferente_principal',
            0,
            (
                select count(*)::integer
                from dim.secao_eleitoral secao
                join dim.eleicao e on e.eleicao_id = secao.eleicao_id
                join dim.secao_eleitoral principal
                  on principal.secao_id = secao.secao_principal_id
                where e.ano = 2026
                  and secao.ds_tipo_secao_agregada = 'Agregada'
                  and secao.local_id <> principal.local_id
            )
        ),
        (
            'dim_secao_eleitoral_geom_sem_ra',
            0,
            (
                select count(*)::integer
                from dim.secao_eleitoral se
                join dim.eleicao e on e.eleicao_id = se.eleicao_id
                where e.ano = 2026
                  and se.geom is not null
                  and se.ra_id is null
            )
        ),
        (
            'dim_secao_eleitoral_sem_geom',
            4,
            (
                select count(*)::integer
                from dim.secao_eleitoral se
                join dim.eleicao e on e.eleicao_id = se.eleicao_id
                where e.ano = 2026
                  and se.geom is null
            )
        ),
        (
            'qualidade_divergencia_aptos_tre_csv',
            106,
            (
                select count(*)::integer
                from aux.qualidade_dado
                where entidade = 'secao_eleitoral'
                  and regra = 'divergencia_aptos_tre_csv'
            )
        ),
        (
            'qualidade_secao_csv_sem_tre',
            8,
            (
                select count(*)::integer
                from aux.qualidade_dado
                where entidade = 'secao_eleitoral'
                  and regra = 'secao_csv_sem_tre'
            )
        ),
        (
            'qualidade_secao_csv_sem_perfil',
            8,
            (
                select count(*)::integer
                from aux.qualidade_dado
                where entidade = 'secao_eleitoral'
                  and regra = 'secao_csv_sem_perfil'
            )
        ),
        (
            'qualidade_secao_agregada_sem_principal',
            0,
            (
                select count(*)::integer
                from aux.qualidade_dado
                where entidade = 'secao_eleitoral'
                  and regra = 'secao_agregada_sem_principal'
            )
        ),
        (
            'qualidade_secao_agregada_local_diferente_principal',
            0,
            (
                select count(*)::integer
                from aux.qualidade_dado
                where entidade = 'secao_eleitoral'
                  and regra = 'secao_agregada_local_diferente_principal'
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
