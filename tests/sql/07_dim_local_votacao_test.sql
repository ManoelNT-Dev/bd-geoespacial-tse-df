with checks(check_name, expected_value, actual_value) as (
    values
        (
            'dim_local_votacao_count_zona_local_csv',
            622,
            (
                select count(*)::integer
                from dim.local_votacao lv
                join dim.eleicao e on e.eleicao_id = lv.eleicao_id
                where e.ano = 2026
            )
        ),
        (
            'dim_local_votacao_distinct_nr_local',
            108,
            (
                select count(distinct lv.nr_local_votacao)::integer
                from dim.local_votacao lv
                join dim.eleicao e on e.eleicao_id = lv.eleicao_id
                where e.ano = 2026
            )
        ),
        (
            'dim_local_votacao_principais_tre',
            614,
            (
                select count(*)::integer
                from dim.local_votacao lv
                join dim.eleicao e on e.eleicao_id = lv.eleicao_id
                where e.ano = 2026
                  and lv.is_principal
            )
        ),
        (
            'dim_local_votacao_adicionais_checar',
            8,
            (
                select count(*)::integer
                from dim.local_votacao lv
                join dim.eleicao e on e.eleicao_id = lv.eleicao_id
                where e.ano = 2026
                  and not lv.is_principal
            )
        ),
        (
            'dim_local_votacao_fonte_tre_confirmada',
            614,
            (
                select count(*)::integer
                from dim.local_votacao lv
                join dim.eleicao e on e.eleicao_id = lv.eleicao_id
                where e.ano = 2026
                  and lv.fonte_tre_confirmada
            )
        ),
        (
            'dim_local_votacao_chave_duplicada',
            0,
            (
                select count(*)::integer
                from (
                    select eleicao_id, uf_id, nr_zona, nr_local_votacao
                    from dim.local_votacao
                    group by eleicao_id, uf_id, nr_zona, nr_local_votacao
                    having count(*) > 1
                ) duplicadas
            )
        ),
        (
            'dim_local_votacao_sem_zona_id',
            0,
            (
                select count(*)::integer
                from dim.local_votacao lv
                join dim.eleicao e on e.eleicao_id = lv.eleicao_id
                where e.ano = 2026
                  and lv.zona_id is null
            )
        ),
        (
            'dim_local_votacao_sem_geom',
            3,
            (
                select count(*)::integer
                from dim.local_votacao lv
                join dim.eleicao e on e.eleicao_id = lv.eleicao_id
                where e.ano = 2026
                  and lv.geom is null
            )
        ),
        (
            'dim_local_votacao_geom_sem_ra',
            0,
            (
                select count(*)::integer
                from dim.local_votacao lv
                join dim.eleicao e on e.eleicao_id = lv.eleicao_id
                where e.ano = 2026
                  and lv.geom is not null
                  and lv.ra_id is null
            )
        ),
        (
            'dim_local_votacao_geom_srid',
            0,
            (
                select count(*)::integer
                from dim.local_votacao lv
                join dim.eleicao e on e.eleicao_id = lv.eleicao_id
                where e.ano = 2026
                  and lv.geom is not null
                  and st_srid(lv.geom) <> 4326
            )
        ),
        (
            'dim_local_votacao_tre_pairs_nao_representados',
            0,
            (
                select count(*)::integer
                from (
                    select distinct ze::integer as nr_zona, num_local::integer as nr_local_votacao
                    from stg.tre_locais_2026_df
                    where not is_total
                      and nullif(ze, '') is not null
                      and nullif(num_local, '') is not null
                ) tre
                where not exists (
                    select 1
                    from dim.local_votacao lv
                    join dim.eleicao e on e.eleicao_id = lv.eleicao_id
                    where e.ano = 2026
                      and lv.nr_zona = tre.nr_zona
                      and lv.nr_local_votacao = tre.nr_local_votacao
                )
            )
        ),
        (
            'qualidade_local_csv_sem_tre',
            8,
            (
                select count(*)::integer
                from aux.qualidade_dado
                where entidade = 'local_votacao'
                  and regra = 'local_csv_sem_tre'
            )
        ),
        (
            'qualidade_local_sem_coordenada',
            3,
            (
                select count(*)::integer
                from aux.qualidade_dado
                where entidade = 'local_votacao'
                  and regra = 'local_sem_coordenada'
            )
        ),
        (
            'qualidade_local_sem_ra',
            0,
            (
                select count(*)::integer
                from aux.qualidade_dado
                where entidade = 'local_votacao'
                  and regra = 'local_sem_ra'
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
