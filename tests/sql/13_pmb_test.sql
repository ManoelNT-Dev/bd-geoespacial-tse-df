with checks(check_name, expected_value, actual_value) as (
    values
        (
            'dim_municipio_pmb_count',
            12,
            (select count(*)::integer from dim.municipio)
        ),
        (
            'recorte_pmb_municipios_count',
            12,
            (
                select count(*)::integer
                from dim.recorte_geografico rg
                join dim.recorte_municipio rm on rm.recorte_id = rg.recorte_id
                where rg.codigo = 'PMB'
            )
        ),
        (
            'fato_eleitorado_perfil_municipio_count',
            34927,
            (select count(*)::integer from fato.eleitorado_perfil_municipio)
        ),
        (
            'fato_eleitorado_perfil_municipio_eleitores',
            759538,
            (select sum(qt_eleitores)::integer from fato.eleitorado_perfil_municipio)
        ),
        (
            'qualidade_pmb_erros',
            0,
            (
                select count(*)::integer
                from aux.qualidade_dado
                where entidade = 'eleitorado_perfil_municipio'
                  and severidade = 'erro'
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
