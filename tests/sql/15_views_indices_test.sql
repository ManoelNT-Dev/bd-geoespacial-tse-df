with expected_indexes(index_name) as (
    values
        ('votacao_eleicao_cargo_votavel_idx'),
        ('votacao_eleicao_cargo_ra_idx'),
        ('votacao_eleicao_cargo_local_idx'),
        ('votacao_eleicao_cargo_secao_idx'),
        ('votacao_eleicao_cargo_tipo_idx'),
        ('votacao_eleicao_cargo_nr_votavel_idx'),
        ('votacao_eleicao_cargo_partido_idx'),
        ('votacao_eleicao_cargo_candidato_idx'),
        ('votacao_eleicao_cargo_zona_idx'),
        ('votavel_eleicao_cargo_nr_votavel_idx'),
        ('eleitorado_perfil_eleicao_ra_idx'),
        ('eleitorado_perfil_eleicao_local_idx'),
        ('eleitorado_perfil_eleicao_secao_idx'),
        ('eleitorado_perfil_eleicao_perfil_idx'),
        ('sociodemografia_ra_ano_indicador_idx'),
        ('indicador_sociodemografico_grupo_idx'),
        ('local_votacao_eleicao_ra_idx'),
        ('secao_eleitoral_eleicao_local_idx'),
        ('secao_eleitoral_eleicao_ra_idx'),
        ('eleitorado_perfil_municipio_eleicao_recorte_idx'),
        ('eleitorado_perfil_municipio_eleicao_municipio_idx'),
        ('candidato_eleicao_cargo_partido_idx'),
        ('candidato_eleicao_nr_candidato_idx'),
        ('ra_nome_normalizado_trgm_idx'),
        ('local_votacao_nome_normalizado_trgm_idx'),
        ('municipio_nome_normalizado_trgm_idx'),
        ('candidato_nm_urna_trgm_idx'),
        ('stg_perfil_df_zona_secao_idx'),
        ('stg_perfil_go_municipio_zona_secao_idx'),
        ('stg_votacao_2022_zona_secao_cargo_idx')
),
checks(check_name, expected_value, actual_value) as (
    values
        (
            'pg_trgm_extension_installed',
            1,
            (select count(*)::integer from pg_extension where extname = 'pg_trgm')
        ),
        (
            'consulta_indexes_count',
            30,
            (
                select count(*)::integer
                from expected_indexes e
                join pg_indexes i on i.indexname = e.index_name
            )
        ),
        (
            'consulta_indexes_missing_count',
            0,
            (
                select count(*)::integer
                from expected_indexes e
                left join pg_indexes i on i.indexname = e.index_name
                where i.indexname is null
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
