create table if not exists fato.eleitorado_perfil_municipio (
    eleicao_id bigint not null references dim.eleicao (eleicao_id),
    uf_id smallint not null references dim.uf (uf_id),
    recorte_id bigint references dim.recorte_geografico (recorte_id),
    municipio_id bigint not null references dim.municipio (municipio_id),
    perfil_id bigint not null references dim.perfil_eleitor (perfil_id),
    qt_eleitores integer not null,
    qt_eleitores_biometria integer not null,
    qt_eleitores_deficiencia integer not null,
    qt_eleitores_nome_social integer not null,
    source_row_count integer not null,
    source_file text,
    loaded_at timestamptz not null default now(),
    primary key (eleicao_id, municipio_id, perfil_id)
);

create index if not exists eleitorado_perfil_municipio_recorte_idx
    on fato.eleitorado_perfil_municipio (recorte_id);
create index if not exists eleitorado_perfil_municipio_municipio_idx
    on fato.eleitorado_perfil_municipio (municipio_id);
create index if not exists eleitorado_perfil_municipio_perfil_idx
    on fato.eleitorado_perfil_municipio (perfil_id);

delete from aux.qualidade_dado
where entidade = 'eleitorado_perfil_municipio'
  and regra in (
      'perfil_municipio_sem_dim_municipio',
      'perfil_municipio_sem_dim_perfil'
  );

with eleicao_2026 as (
    select eleicao_id
    from dim.eleicao
    where ano = 2026
      and turno = 1
      and cd_eleicao = 6259
),
uf_go as (
    select uf_id
    from dim.uf
    where sigla = 'GO'
),
recorte_pmb as (
    select recorte_id
    from dim.recorte_geografico
    where codigo = 'PMB'
),
source_perfil as (
    select
        src.cd_municipio::integer as municipio_codigo_tse,
        md5(concat_ws(
            '|',
            src.cd_genero,
            src.cd_estado_civil,
            src.cd_faixa_etaria,
            src.cd_grau_escolaridade,
            src.cd_raca_cor,
            src.cd_identidade_genero,
            src.cd_quilombola,
            src.cd_interprete_libras
        )) as perfil_hash,
        sum(src.qt_eleitores::integer) as qt_eleitores,
        sum(src.qt_eleitores_biometria::integer) as qt_eleitores_biometria,
        sum(src.qt_eleitores_deficiencia::integer) as qt_eleitores_deficiencia,
        sum(src.qt_eleitores_nome_social::integer) as qt_eleitores_nome_social,
        count(*)::integer as source_row_count,
        min(src.source_file) as source_file
    from stg.perfil_eleitor_secao_2026_go src
    join dim.municipio municipio
      on municipio.municipio_codigo_tse = src.cd_municipio::integer
    join dim.recorte_municipio recorte_municipio
      on recorte_municipio.municipio_id = municipio.municipio_id
    join recorte_pmb
      on recorte_pmb.recorte_id = recorte_municipio.recorte_id
    where nullif(src.cd_municipio, '') is not null
    group by
        src.cd_municipio::integer,
        src.cd_genero,
        src.cd_estado_civil,
        src.cd_faixa_etaria,
        src.cd_grau_escolaridade,
        src.cd_raca_cor,
        src.cd_identidade_genero,
        src.cd_quilombola,
        src.cd_interprete_libras
),
source_fato as (
    select
        eleicao_2026.eleicao_id,
        uf_go.uf_id,
        recorte_pmb.recorte_id,
        municipio.municipio_id,
        perfil.perfil_id,
        src.qt_eleitores,
        src.qt_eleitores_biometria,
        src.qt_eleitores_deficiencia,
        src.qt_eleitores_nome_social,
        src.source_row_count,
        src.source_file
    from source_perfil src
    cross join eleicao_2026
    cross join uf_go
    cross join recorte_pmb
    join dim.municipio municipio
      on municipio.uf_id = uf_go.uf_id
     and municipio.municipio_codigo_tse = src.municipio_codigo_tse
    join dim.perfil_eleitor perfil
      on perfil.perfil_hash = src.perfil_hash
)
insert into fato.eleitorado_perfil_municipio (
    eleicao_id,
    uf_id,
    recorte_id,
    municipio_id,
    perfil_id,
    qt_eleitores,
    qt_eleitores_biometria,
    qt_eleitores_deficiencia,
    qt_eleitores_nome_social,
    source_row_count,
    source_file
)
select
    eleicao_id,
    uf_id,
    recorte_id,
    municipio_id,
    perfil_id,
    qt_eleitores,
    qt_eleitores_biometria,
    qt_eleitores_deficiencia,
    qt_eleitores_nome_social,
    source_row_count,
    source_file
from source_fato
on conflict (eleicao_id, municipio_id, perfil_id) do update
set uf_id = excluded.uf_id,
    recorte_id = excluded.recorte_id,
    qt_eleitores = excluded.qt_eleitores,
    qt_eleitores_biometria = excluded.qt_eleitores_biometria,
    qt_eleitores_deficiencia = excluded.qt_eleitores_deficiencia,
    qt_eleitores_nome_social = excluded.qt_eleitores_nome_social,
    source_row_count = excluded.source_row_count,
    source_file = excluded.source_file,
    loaded_at = now();

with perfil_municipio_sem_dim_municipio as (
    select distinct
        src.cd_municipio::integer as municipio_codigo_tse,
        min(src.nm_municipio) as nm_municipio,
        min(src.source_file) as source_file
    from stg.perfil_eleitor_secao_2026_go src
    left join dim.municipio municipio
      on municipio.municipio_codigo_tse = src.cd_municipio::integer
    where municipio.municipio_id is null
      and src.cd_municipio::integer in (
          select (municipio_json ->> 'municipio_codigo_tse')::integer
          from stg.eleitorado_pmb_2026_json json_source
          cross join lateral jsonb_array_elements(json_source.payload #> '{pmb,municipios}') as municipio_json
          where json_source.source_file = 'eleitorado_PMB_2026.json'
      )
    group by src.cd_municipio::integer
),
perfil_municipio_sem_dim_perfil as (
    select distinct
        src.cd_municipio::integer as municipio_codigo_tse,
        md5(concat_ws(
            '|',
            src.cd_genero,
            src.cd_estado_civil,
            src.cd_faixa_etaria,
            src.cd_grau_escolaridade,
            src.cd_raca_cor,
            src.cd_identidade_genero,
            src.cd_quilombola,
            src.cd_interprete_libras
        )) as perfil_hash,
        min(src.source_file) as source_file
    from stg.perfil_eleitor_secao_2026_go src
    join dim.municipio municipio
      on municipio.municipio_codigo_tse = src.cd_municipio::integer
    join dim.recorte_municipio recorte_municipio
      on recorte_municipio.municipio_id = municipio.municipio_id
    join dim.recorte_geografico recorte
      on recorte.recorte_id = recorte_municipio.recorte_id
     and recorte.codigo = 'PMB'
    left join dim.perfil_eleitor perfil
      on perfil.perfil_hash = md5(concat_ws(
          '|',
          src.cd_genero,
          src.cd_estado_civil,
          src.cd_faixa_etaria,
          src.cd_grau_escolaridade,
          src.cd_raca_cor,
          src.cd_identidade_genero,
          src.cd_quilombola,
          src.cd_interprete_libras
      ))
    where perfil.perfil_id is null
    group by
        src.cd_municipio::integer,
        src.cd_genero,
        src.cd_estado_civil,
        src.cd_faixa_etaria,
        src.cd_grau_escolaridade,
        src.cd_raca_cor,
        src.cd_identidade_genero,
        src.cd_quilombola,
        src.cd_interprete_libras
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
    'eleitorado_perfil_municipio',
    concat('2026|GO|CD_MUNICIPIO=', municipio_codigo_tse),
    'erro',
    'perfil_municipio_sem_dim_municipio',
    concat('Perfil PMB sem municipio correspondente em dim.municipio: ', nm_municipio),
    source_file
from perfil_municipio_sem_dim_municipio
union all
select
    'eleitorado_perfil_municipio',
    concat('2026|GO|CD_MUNICIPIO=', municipio_codigo_tse, '|PERFIL_HASH=', perfil_hash),
    'erro',
    'perfil_municipio_sem_dim_perfil',
    'Perfil PMB sem combinacao correspondente em dim.perfil_eleitor.',
    source_file
from perfil_municipio_sem_dim_perfil;
