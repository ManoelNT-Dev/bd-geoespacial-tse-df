with expected_extensions(extname) as (
    values
        ('postgis'),
        ('unaccent')
),
missing_extensions as (
    select expected_extensions.extname
    from expected_extensions
    left join pg_extension using (extname)
    where pg_extension.extname is null
),
expected_schemas(schema_name) as (
    values
        ('stg'),
        ('dim'),
        ('fato'),
        ('geo'),
        ('aux')
),
missing_schemas as (
    select expected_schemas.schema_name
    from expected_schemas
    left join information_schema.schemata using (schema_name)
    where schemata.schema_name is null
)
select 'missing_extension' as issue_type, extname as object_name
from missing_extensions
union all
select 'missing_schema' as issue_type, schema_name as object_name
from missing_schemas
order by issue_type, object_name;
