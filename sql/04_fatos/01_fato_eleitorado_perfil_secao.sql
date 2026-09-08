create table if not exists fato.eleitorado_perfil_secao (
    eleicao_id bigint not null references dim.eleicao (eleicao_id),
    uf_id smallint not null references dim.uf (uf_id),
    ra_id bigint references dim.regiao_administrativa (ra_id),
    local_id bigint not null references dim.local_votacao (local_id),
    secao_id bigint not null references dim.secao_eleitoral (secao_id),
    perfil_id bigint not null references dim.perfil_eleitor (perfil_id),
    qt_eleitores integer not null,
    qt_eleitores_biometria integer not null,
    qt_eleitores_deficiencia integer not null,
    qt_eleitores_nome_social integer not null,
    source_row_count integer not null,
    source_file text,
    loaded_at timestamptz not null default now(),
    primary key (eleicao_id, secao_id, perfil_id)
);

create index if not exists eleitorado_perfil_ra_idx on fato.eleitorado_perfil_secao (ra_id);
create index if not exists eleitorado_perfil_local_idx on fato.eleitorado_perfil_secao (local_id);
create index if not exists eleitorado_perfil_perfil_idx on fato.eleitorado_perfil_secao (perfil_id);
create index if not exists eleitorado_perfil_secao_idx on fato.eleitorado_perfil_secao (secao_id);

delete from aux.qualidade_dado
where entidade = 'eleitorado_perfil_secao'
  and regra in (
      'perfil_sem_secao',
      'perfil_secao_diverge_aptos_csv'
  );

with eleicao_2026 as (
    select eleicao_id
    from dim.eleicao
    where ano = 2026
      and turno = 1
      and cd_eleicao = 6259
),
uf_df as (
    select uf_id
    from dim.uf
    where sigla = 'DF'
),
source_perfil as (
    select
        src.nr_zona::integer as nr_zona,
        src.nr_secao::integer as nr_secao,
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
    from stg.perfil_eleitor_secao_2026_df src
    where nullif(src.nr_zona, '') is not null
      and nullif(src.nr_secao, '') is not null
    group by
        src.nr_zona::integer,
        src.nr_secao::integer,
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
        uf_df.uf_id,
        secao.ra_id,
        secao.local_id,
        secao.secao_id,
        perfil.perfil_id,
        src.qt_eleitores::integer as qt_eleitores,
        src.qt_eleitores_biometria::integer as qt_eleitores_biometria,
        src.qt_eleitores_deficiencia::integer as qt_eleitores_deficiencia,
        src.qt_eleitores_nome_social::integer as qt_eleitores_nome_social,
        src.source_row_count,
        src.source_file
    from source_perfil src
    cross join eleicao_2026
    cross join uf_df
    join dim.secao_eleitoral secao
      on secao.eleicao_id = eleicao_2026.eleicao_id
     and secao.uf_id = uf_df.uf_id
     and secao.nr_zona = src.nr_zona
     and secao.nr_secao = src.nr_secao
    join dim.perfil_eleitor perfil
      on perfil.perfil_hash = src.perfil_hash
)
insert into fato.eleitorado_perfil_secao (
    eleicao_id,
    uf_id,
    ra_id,
    local_id,
    secao_id,
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
    ra_id,
    local_id,
    secao_id,
    perfil_id,
    qt_eleitores,
    qt_eleitores_biometria,
    qt_eleitores_deficiencia,
    qt_eleitores_nome_social,
    source_row_count,
    source_file
from source_fato
on conflict (eleicao_id, secao_id, perfil_id) do update
set uf_id = excluded.uf_id,
    ra_id = excluded.ra_id,
    local_id = excluded.local_id,
    qt_eleitores = excluded.qt_eleitores,
    qt_eleitores_biometria = excluded.qt_eleitores_biometria,
    qt_eleitores_deficiencia = excluded.qt_eleitores_deficiencia,
    qt_eleitores_nome_social = excluded.qt_eleitores_nome_social,
    source_row_count = excluded.source_row_count,
    source_file = excluded.source_file,
    loaded_at = now();

with perfil_sem_secao as (
    select distinct
        src.nr_zona::integer as nr_zona,
        src.nr_secao::integer as nr_secao,
        src.source_file
    from stg.perfil_eleitor_secao_2026_df src
    left join dim.secao_eleitoral secao
      on secao.nr_zona = src.nr_zona::integer
     and secao.nr_secao = src.nr_secao::integer
    where secao.secao_id is null
),
perfil_secao_diverge_aptos_csv as (
    select
        secao.nr_zona,
        secao.nr_secao,
        secao.qt_eleitores_aptos,
        sum(fato.qt_eleitores) as soma_perfil,
        min(fato.source_file) as source_file
    from dim.secao_eleitoral secao
    join fato.eleitorado_perfil_secao fato
      on fato.secao_id = secao.secao_id
    group by secao.nr_zona, secao.nr_secao, secao.qt_eleitores_aptos
    having secao.qt_eleitores_aptos is not null
       and secao.qt_eleitores_aptos <> sum(fato.qt_eleitores)
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
    'eleitorado_perfil_secao',
    concat('2026|DF|ZE=', nr_zona, '|SECAO=', nr_secao),
    'erro',
    'perfil_sem_secao',
    'Perfil do eleitorado sem secao correspondente em dim.secao_eleitoral.',
    source_file
from perfil_sem_secao
union all
select
    'eleitorado_perfil_secao',
    concat('2026|DF|ZE=', nr_zona, '|SECAO=', nr_secao),
    'aviso',
    'perfil_secao_diverge_aptos_csv',
    concat('QT_ELEITOR_SECAO=', qt_eleitores_aptos, '; soma perfil=', soma_perfil),
    source_file
from perfil_secao_diverge_aptos_csv;
