with checks(check_name, expected_value, actual_value) as (
    values
        (
            'dim_votavel_table_exists',
            1,
            (
                select count(*)::integer
                from information_schema.tables
                where table_schema = 'dim'
                  and table_name = 'votavel'
            )
        ),
        (
            'fato_votacao_candidato_secao_table_exists',
            1,
            (
                select count(*)::integer
                from information_schema.tables
                where table_schema = 'fato'
                  and table_name = 'votacao_candidato_secao'
            )
        ),
        (
            'fato_apuracao_secao_table_exists',
            1,
            (
                select count(*)::integer
                from information_schema.tables
                where table_schema = 'fato'
                  and table_name = 'apuracao_secao'
            )
        ),
        (
            'fato_vw_votacao_drilldown_exists',
            1,
            (
                select count(*)::integer
                from information_schema.views
                where table_schema = 'fato'
                  and table_name = 'vw_votacao_drilldown'
            )
        ),
        (
            'dim_votavel_tipo_check_exists',
            1,
            (
                select case when count(*) > 0 then 1 else 0 end
                from pg_constraint con
                join pg_class cls on cls.oid = con.conrelid
                join pg_namespace nsp on nsp.oid = cls.relnamespace
                where nsp.nspname = 'dim'
                  and cls.relname = 'votavel'
                  and con.contype = 'c'
                  and pg_get_constraintdef(con.oid) like '%tipo_votavel%'
            )
        ),
        (
            'fato_votacao_tipo_check_exists',
            1,
            (
                select case when count(*) > 0 then 1 else 0 end
                from pg_constraint con
                join pg_class cls on cls.oid = con.conrelid
                join pg_namespace nsp on nsp.oid = cls.relnamespace
                where nsp.nspname = 'fato'
                  and cls.relname = 'votacao_candidato_secao'
                  and con.contype = 'c'
                  and pg_get_constraintdef(con.oid) like '%tipo_votavel%'
            )
        )
)
select check_name, expected_value, actual_value
from checks
where expected_value <> actual_value
order by check_name;
