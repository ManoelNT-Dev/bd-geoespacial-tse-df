with checks(check_name, expected_value, actual_value) as (
    values
        (
            'dim_candidato_count',
            661,
            (select count(*)::integer from dim.candidato)
        ),
        (
            'dim_candidato_sq_distintos',
            661,
            (select count(distinct sq_candidato)::integer from dim.candidato)
        ),
        (
            'dim_candidato_chave_duplicada',
            0,
            (
                select count(*)::integer
                from (
                    select eleicao_id, sq_candidato
                    from dim.candidato
                    group by eleicao_id, sq_candidato
                    having count(*) > 1
                ) duplicadas
            )
        ),
        (
            'dim_candidato_sem_cargo',
            0,
            (select count(*)::integer from dim.candidato where cargo_id is null)
        ),
        (
            'dim_candidato_sem_partido',
            0,
            (select count(*)::integer from dim.candidato where partido_id is null)
        ),
        (
            'dim_candidato_sem_hash_cpf',
            0,
            (select count(*)::integer from dim.candidato where cpf_hash is null)
        ),
        (
            'dim_candidato_hash_cpf_md5',
            0,
            (
                select count(*)::integer
                from dim.candidato
                where cpf_hash !~ '^[0-9a-f]{32}$'
            )
        ),
        (
            'dim_candidato_federacao_real_sem_fk',
            0,
            (
                select count(*)::integer
                from dim.candidato c
                join stg.consulta_cand_2026_df stg
                  on stg.sq_candidato::bigint = c.sq_candidato
                where stg.nr_federacao::integer > 0
                  and c.federacao_id is null
            )
        ),
        (
            'dim_candidato_coligacao_real_sem_fk',
            0,
            (
                select count(*)::integer
                from dim.candidato c
                join stg.consulta_cand_2026_df stg
                  on stg.sq_candidato::bigint = c.sq_candidato
                where stg.sq_coligacao::bigint > 0
                  and c.coligacao_id is null
            )
        ),
        (
            'qualidade_candidato_erros',
            0,
            (
                select count(*)::integer
                from aux.qualidade_dado
                where entidade = 'candidato'
                  and severidade = 'erro'
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
