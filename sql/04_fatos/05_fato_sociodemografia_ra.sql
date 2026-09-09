create table if not exists dim.indicador_sociodemografico (
    indicador_id bigint generated always as identity primary key,
    codigo text not null unique,
    grupo text not null,
    subgrupo text,
    metrica text not null,
    descricao text not null,
    unidade text not null
);

create table if not exists fato.sociodemografia_ra (
    ra_id bigint not null references dim.regiao_administrativa (ra_id),
    indicador_id bigint not null references dim.indicador_sociodemografico (indicador_id),
    ano_referencia integer not null,
    valor_num numeric(18, 4),
    percentual numeric(9, 4),
    fonte text,
    metodo text,
    source_file text,
    loaded_at timestamptz not null default now(),
    primary key (ra_id, indicador_id, ano_referencia)
);

create table if not exists fato.sociodemografia_ra_resumo (
    ra_id bigint not null references dim.regiao_administrativa (ra_id),
    ano_referencia integer not null,
    perfil_resumido text not null,
    source_file text,
    loaded_at timestamptz not null default now(),
    primary key (ra_id, ano_referencia)
);

create index if not exists sociodemografia_ra_indicador_idx
    on fato.sociodemografia_ra (indicador_id);
create index if not exists sociodemografia_ra_ano_idx
    on fato.sociodemografia_ra (ano_referencia);

delete from aux.qualidade_dado
where entidade in ('sociodemografia_ra', 'perfil_sociodemografico_ra_df_json')
  and regra in (
      'ra_sociodemografia_sem_dim_ra',
      'total_global_diverge_soma_ra'
  );

with source_json as (
    select payload, source_file
    from stg.perfil_sociodemografico_ra_df_json
    order by loaded_at desc
    limit 1
),
source_indicador as (
    select *
    from (
        values
            ('populacao_total', 'populacao', null, 'total_geral', 'Populacao total estimada', 'pessoas'),
            ('populacao_negra_total', 'raca_cor', 'negra', 'total', 'Populacao negra estimada', 'pessoas'),
            ('populacao_negra_feminino', 'raca_cor', 'negra', 'feminino_qtd', 'Populacao negra feminina estimada', 'pessoas'),
            ('populacao_negra_masculino', 'raca_cor', 'negra', 'masculino_qtd', 'Populacao negra masculina estimada', 'pessoas'),
            ('populacao_nao_negra_total', 'raca_cor', 'nao_negra', 'total', 'Populacao nao negra estimada', 'pessoas'),
            ('populacao_nao_negra_feminino', 'raca_cor', 'nao_negra', 'feminino_qtd', 'Populacao nao negra feminina estimada', 'pessoas'),
            ('populacao_nao_negra_masculino', 'raca_cor', 'nao_negra', 'masculino_qtd', 'Populacao nao negra masculina estimada', 'pessoas'),
            ('religiao_catolicos_pct', 'religiao', 'catolicos', 'percentual', 'Percentual de catolicos', 'percentual'),
            ('religiao_evangelicos_pct', 'religiao', 'evangelicos', 'percentual', 'Percentual de evangelicos', 'percentual'),
            ('religiao_espiritas_pct', 'religiao', 'espiritas', 'percentual', 'Percentual de espiritas', 'percentual'),
            ('religiao_sem_religiao_pct', 'religiao', 'sem_religiao', 'percentual', 'Percentual sem religiao', 'percentual'),
            ('religiao_outras_crencas_pct', 'religiao', 'outras_crencas', 'percentual', 'Percentual de outras crencas', 'percentual'),
            ('renda_domiciliar_per_capita_media', 'renda', null, 'media_per_capita', 'Renda domiciliar per capita media', 'BRL'),
            ('renda_domiciliar_media', 'renda', null, 'media_domiciliar', 'Renda domiciliar media', 'BRL'),
            ('domicilios_com_pets_pct', 'animais_estimacao', 'domicilios', 'percentual', 'Percentual de domicilios com pets', 'percentual'),
            ('domicilios_com_pets_qtd', 'animais_estimacao', 'domicilios', 'quantidade', 'Quantidade estimada de domicilios com pets', 'domicilios')
    ) as indicador(codigo, grupo, subgrupo, metrica, descricao, unidade)
)
insert into dim.indicador_sociodemografico (codigo, grupo, subgrupo, metrica, descricao, unidade)
select codigo, grupo, subgrupo, metrica, descricao, unidade
from source_indicador
on conflict (codigo) do update
set grupo = excluded.grupo,
    subgrupo = excluded.subgrupo,
    metrica = excluded.metrica,
    descricao = excluded.descricao,
    unidade = excluded.unidade;

with source_json as (
    select payload, source_file
    from stg.perfil_sociodemografico_ra_df_json
    order by loaded_at desc
    limit 1
),
source_ra as (
    select
        (source_json.payload #>> '{metadata,ano_referencia_demografica}')::integer as ano_referencia,
        source_json.source_file,
        ra_payload,
        ra_payload ->> 'ra_codigo' as ra_codigo,
        ra_payload ->> 'ra_nome' as ra_nome,
        coalesce(ra_payload #>> '{derivacao,tipo}', 'fonte_original') as metodo
    from source_json
    cross join lateral jsonb_array_elements(source_json.payload -> 'regioes_administrativas') as ra_payload
),
source_medida as (
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'populacao_total' as codigo, (ra_payload #>> '{populacao_raca_cor,total_geral}')::numeric as valor_num, null::numeric as percentual from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'populacao_negra_total', (ra_payload #>> '{populacao_raca_cor,negra,total}')::numeric, null::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'populacao_negra_feminino', (ra_payload #>> '{populacao_raca_cor,negra,feminino,qtd}')::numeric, (ra_payload #>> '{populacao_raca_cor,negra,feminino,pct}')::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'populacao_negra_masculino', (ra_payload #>> '{populacao_raca_cor,negra,masculino,qtd}')::numeric, (ra_payload #>> '{populacao_raca_cor,negra,masculino,pct}')::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'populacao_nao_negra_total', (ra_payload #>> '{populacao_raca_cor,nao_negra,total}')::numeric, null::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'populacao_nao_negra_feminino', (ra_payload #>> '{populacao_raca_cor,nao_negra,feminino,qtd}')::numeric, (ra_payload #>> '{populacao_raca_cor,nao_negra,feminino,pct}')::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'populacao_nao_negra_masculino', (ra_payload #>> '{populacao_raca_cor,nao_negra,masculino,qtd}')::numeric, (ra_payload #>> '{populacao_raca_cor,nao_negra,masculino,pct}')::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'religiao_catolicos_pct', null::numeric, (ra_payload #>> '{religiao,distribuicao_percentual,catolicos,pct}')::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'religiao_evangelicos_pct', null::numeric, (ra_payload #>> '{religiao,distribuicao_percentual,evangelicos,pct}')::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'religiao_espiritas_pct', null::numeric, (ra_payload #>> '{religiao,distribuicao_percentual,espiritas,pct}')::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'religiao_sem_religiao_pct', null::numeric, (ra_payload #>> '{religiao,distribuicao_percentual,sem_religiao,pct}')::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'religiao_outras_crencas_pct', null::numeric, (ra_payload #>> '{religiao,distribuicao_percentual,outras_crencas,pct}')::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'renda_domiciliar_per_capita_media', (ra_payload #>> '{renda,renda_domiciliar_per_capita_media}')::numeric, null::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'renda_domiciliar_media', (ra_payload #>> '{renda,renda_domiciliar_media}')::numeric, null::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'domicilios_com_pets_pct', null::numeric, (ra_payload #>> '{animais_estimacao,pct_domicilios_com_pets}')::numeric from source_ra
    union all
    select ano_referencia, source_file, ra_codigo, ra_nome, metodo, 'domicilios_com_pets_qtd', (ra_payload #>> '{animais_estimacao,qtd_domicilios_com_pets}')::numeric, null::numeric from source_ra
),
source_fato as (
    select
        ra.ra_id,
        indicador.indicador_id,
        source_medida.ano_referencia,
        source_medida.valor_num,
        source_medida.percentual,
        null::text as fonte,
        source_medida.metodo,
        source_medida.source_file
    from source_medida
    join dim.uf uf
      on uf.sigla = 'DF'
    join dim.regiao_administrativa ra
      on ra.uf_id = uf.uf_id
     and (
         ra.ra_codigo = source_medida.ra_codigo
         or ra.ra_nome_normalizado = upper(unaccent(replace(source_medida.ra_nome, '/', ' ')))
     )
    join dim.indicador_sociodemografico indicador
      on indicador.codigo = source_medida.codigo
)
insert into fato.sociodemografia_ra (
    ra_id,
    indicador_id,
    ano_referencia,
    valor_num,
    percentual,
    fonte,
    metodo,
    source_file
)
select
    ra_id,
    indicador_id,
    ano_referencia,
    valor_num,
    percentual,
    fonte,
    metodo,
    source_file
from source_fato
where valor_num is not null
   or percentual is not null
on conflict (ra_id, indicador_id, ano_referencia) do update
set valor_num = excluded.valor_num,
    percentual = excluded.percentual,
    fonte = excluded.fonte,
    metodo = excluded.metodo,
    source_file = excluded.source_file,
    loaded_at = now();

with source_json as (
    select payload, source_file
    from stg.perfil_sociodemografico_ra_df_json
    order by loaded_at desc
    limit 1
),
source_ra as (
    select
        (source_json.payload #>> '{metadata,ano_referencia_demografica}')::integer as ano_referencia,
        source_json.source_file,
        ra_payload ->> 'ra_codigo' as ra_codigo,
        ra_payload ->> 'ra_nome' as ra_nome,
        ra_payload ->> 'perfil_resumido' as perfil_resumido
    from source_json
    cross join lateral jsonb_array_elements(source_json.payload -> 'regioes_administrativas') as ra_payload
),
source_resumo as (
    select
        ra.ra_id,
        source_ra.ano_referencia,
        source_ra.perfil_resumido,
        source_ra.source_file
    from source_ra
    join dim.uf uf
      on uf.sigla = 'DF'
    join dim.regiao_administrativa ra
      on ra.uf_id = uf.uf_id
     and (
         ra.ra_codigo = source_ra.ra_codigo
         or ra.ra_nome_normalizado = upper(unaccent(replace(source_ra.ra_nome, '/', ' ')))
     )
    where nullif(source_ra.perfil_resumido, '') is not null
)
insert into fato.sociodemografia_ra_resumo (
    ra_id,
    ano_referencia,
    perfil_resumido,
    source_file
)
select ra_id, ano_referencia, perfil_resumido, source_file
from source_resumo
on conflict (ra_id, ano_referencia) do update
set perfil_resumido = excluded.perfil_resumido,
    source_file = excluded.source_file,
    loaded_at = now();

with source_json as (
    select payload, source_file
    from stg.perfil_sociodemografico_ra_df_json
    order by loaded_at desc
    limit 1
),
source_ra as (
    select
        ra_payload ->> 'ra_codigo' as ra_codigo,
        ra_payload ->> 'ra_nome' as ra_nome,
        source_file
    from source_json
    cross join lateral jsonb_array_elements(source_json.payload -> 'regioes_administrativas') as ra_payload
),
ra_sem_dim as (
    select source_ra.*
    from source_ra
    join dim.uf uf
      on uf.sigla = 'DF'
    left join dim.regiao_administrativa ra
      on ra.uf_id = uf.uf_id
     and (
         ra.ra_codigo = source_ra.ra_codigo
         or ra.ra_nome_normalizado = upper(unaccent(replace(source_ra.ra_nome, '/', ' ')))
     )
    where ra.ra_id is null
),
total_global_diverge_soma_ra as (
    select
        (source_json.payload #>> '{sociodemografia_geral_df,demografia_raca_cor_geral,total_geral}')::integer as total_global,
        (
            select sum((ra_payload #>> '{populacao_raca_cor,total_geral}')::integer)
            from jsonb_array_elements(source_json.payload -> 'regioes_administrativas') as ra_payload
        )::integer as soma_ra,
        source_json.source_file
    from source_json
)
insert into aux.qualidade_dado (
    entidade,
    chave_natural,
    severidade,
    regra,
    detalhe,
    source_file
)
select
    'sociodemografia_ra',
    concat('DF|', ra_codigo, '|', ra_nome),
    'erro',
    'ra_sociodemografia_sem_dim_ra',
    'RA sociodemografica sem correspondencia em dim.regiao_administrativa.',
    source_file
from ra_sem_dim
union all
select
    'perfil_sociodemografico_ra_df_json',
    'DF|sociodemografia_geral_df.demografia_raca_cor_geral.total_geral',
    'aviso',
    'total_global_diverge_soma_ra',
    concat('Total global=', total_global, '; soma das RAs=', soma_ra),
    source_file
from total_global_diverge_soma_ra
where total_global <> soma_ra;
