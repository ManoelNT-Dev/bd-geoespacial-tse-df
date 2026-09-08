create table if not exists dim.secao_eleitoral (
    secao_id bigint generated always as identity primary key,
    eleicao_id bigint not null references dim.eleicao (eleicao_id),
    uf_id smallint not null references dim.uf (uf_id),
    ra_id bigint references dim.regiao_administrativa (ra_id),
    zona_id bigint not null references dim.zona_eleitoral (zona_id),
    local_id bigint not null references dim.local_votacao (local_id),
    nr_zona integer not null,
    nr_secao integer not null,
    cd_tipo_secao_agregada integer,
    ds_tipo_secao_agregada text,
    nr_secao_principal integer,
    secao_principal_id bigint references dim.secao_eleitoral (secao_id),
    local_principal_id bigint references dim.local_votacao (local_id),
    cd_situ_secao integer,
    ds_situ_secao text,
    cd_situ_secao_acessibilidade integer,
    ds_situ_secao_acessibilidade text,
    tem_acessibilidade boolean,
    qt_eleitores_aptos integer,
    qt_eleitores_aptos_tre integer,
    qt_eleitores_suspensos_tre integer,
    latitude numeric(11, 8),
    longitude numeric(11, 8),
    geom geometry(Point, 4326),
    is_secao_principal_tre boolean not null default false,
    fonte_tre_confirmada boolean not null default false,
    is_adicional_csv boolean not null default false,
    source_file text,
    loaded_at timestamptz not null default now(),
    unique (eleicao_id, uf_id, nr_zona, nr_secao)
);

create index if not exists secao_local_idx on dim.secao_eleitoral (local_id);
create index if not exists secao_ra_idx on dim.secao_eleitoral (ra_id);
create index if not exists secao_geom_gix on dim.secao_eleitoral using gist (geom);
create index if not exists secao_principal_tre_idx on dim.secao_eleitoral (is_secao_principal_tre);
create index if not exists secao_fonte_tre_confirmada_idx on dim.secao_eleitoral (fonte_tre_confirmada);

delete from aux.qualidade_dado
where entidade = 'secao_eleitoral'
  and regra in (
      'secao_csv_sem_tre',
      'secao_csv_sem_perfil',
      'secao_sem_local',
      'secao_sem_ra',
      'secao_agregada_sem_principal',
      'secao_agregada_local_diferente_principal',
      'divergencia_aptos_tre_csv'
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
tre_secoes_raw as (
    select
        ze::integer as nr_zona,
        num_secao,
        substring(num_secao from '^[0-9]+')::integer as nr_secao_principal_tre,
        substring(num_secao from '\(([0-9, ]+)\)') as secoes_agregadas_tre,
        nullif(aptos, '')::integer as aptos,
        nullif(suspensos, '')::integer as suspensos
    from stg.tre_secoes_2026_df
    where not is_total
      and nullif(ze, '') is not null
      and nullif(num_secao, '') is not null
),
tre_secoes_expandidas as (
    select
        nr_zona,
        nr_secao_principal_tre as nr_secao,
        true as is_secao_principal_tre,
        aptos,
        suspensos
    from tre_secoes_raw
    union all
    select
        raw.nr_zona,
        trim(secao_agregada.nr_secao)::integer as nr_secao,
        false as is_secao_principal_tre,
        null::integer as aptos,
        null::integer as suspensos
    from tre_secoes_raw raw
    cross join lateral regexp_split_to_table(raw.secoes_agregadas_tre, ',') as secao_agregada(nr_secao)
    where raw.secoes_agregadas_tre is not null
),
perfil_secoes as (
    select distinct
        nr_zona::integer as nr_zona,
        nr_secao::integer as nr_secao
    from stg.perfil_eleitor_secao_2026_df
    where nullif(nr_zona, '') is not null
      and nullif(nr_secao, '') is not null
),
source_csv as (
    select
        eleicao_2026.eleicao_id,
        uf_df.uf_id,
        zona.zona_id,
        local.local_id,
        local.ra_id,
        local.latitude,
        local.longitude,
        local.geom,
        src.nr_zona::integer as nr_zona,
        src.nr_secao::integer as nr_secao,
        nullif(src.cd_tipo_secao_agregada, '')::integer as cd_tipo_secao_agregada,
        nullif(src.ds_tipo_secao_agregada, '') as ds_tipo_secao_agregada,
        case
            when nullif(src.nr_secao_principal, '') is not null
             and src.nr_secao_principal::integer > 0 then
                src.nr_secao_principal::integer
            else null
        end as nr_secao_principal,
        nullif(src.cd_situ_secao, '')::integer as cd_situ_secao,
        nullif(src.ds_situ_secao, '') as ds_situ_secao,
        nullif(src.cd_situ_secao_acessibilidade, '')::integer as cd_situ_secao_acessibilidade,
        nullif(src.ds_situ_secao_acessibilidade, '') as ds_situ_secao_acessibilidade,
        case
            when upper(unaccent(coalesce(src.ds_situ_secao_acessibilidade, ''))) like '%COM ACESSIBILIDADE%' then true
            when upper(unaccent(coalesce(src.ds_situ_secao_acessibilidade, ''))) like '%SEM ACESSIBILIDADE%' then false
            else null
        end as tem_acessibilidade,
        nullif(src.qt_eleitor_secao, '')::integer as qt_eleitores_aptos,
        tre.aptos as qt_eleitores_aptos_tre,
        tre.suspensos as qt_eleitores_suspensos_tre,
        coalesce(tre.is_secao_principal_tre, false) as is_secao_principal_tre,
        (tre.nr_secao is not null) as fonte_tre_confirmada,
        (tre.nr_secao is null) as is_adicional_csv,
        src.source_file
    from stg.eleitorado_local_votacao_2026_df src
    cross join eleicao_2026
    cross join uf_df
    join dim.zona_eleitoral zona
      on zona.uf_id = uf_df.uf_id
     and zona.nr_zona = src.nr_zona::integer
    join dim.local_votacao local
      on local.eleicao_id = eleicao_2026.eleicao_id
     and local.uf_id = uf_df.uf_id
     and local.nr_zona = src.nr_zona::integer
     and local.nr_local_votacao = src.nr_local_votacao::integer
    left join tre_secoes_expandidas tre
      on tre.nr_zona = src.nr_zona::integer
     and tre.nr_secao = src.nr_secao::integer
    where nullif(src.nr_zona, '') is not null
      and nullif(src.nr_secao, '') is not null
      and nullif(src.nr_local_votacao, '') is not null
)
insert into dim.secao_eleitoral (
    eleicao_id,
    uf_id,
    ra_id,
    zona_id,
    local_id,
    nr_zona,
    nr_secao,
    cd_tipo_secao_agregada,
    ds_tipo_secao_agregada,
    nr_secao_principal,
    local_principal_id,
    cd_situ_secao,
    ds_situ_secao,
    cd_situ_secao_acessibilidade,
    ds_situ_secao_acessibilidade,
    tem_acessibilidade,
    qt_eleitores_aptos,
    qt_eleitores_aptos_tre,
    qt_eleitores_suspensos_tre,
    latitude,
    longitude,
    geom,
    is_secao_principal_tre,
    fonte_tre_confirmada,
    is_adicional_csv,
    source_file
)
select
    eleicao_id,
    uf_id,
    ra_id,
    zona_id,
    local_id,
    nr_zona,
    nr_secao,
    cd_tipo_secao_agregada,
    ds_tipo_secao_agregada,
    nr_secao_principal,
    local_id as local_principal_id,
    cd_situ_secao,
    ds_situ_secao,
    cd_situ_secao_acessibilidade,
    ds_situ_secao_acessibilidade,
    tem_acessibilidade,
    qt_eleitores_aptos,
    qt_eleitores_aptos_tre,
    qt_eleitores_suspensos_tre,
    latitude,
    longitude,
    geom,
    is_secao_principal_tre,
    fonte_tre_confirmada,
    is_adicional_csv,
    source_file
from source_csv
on conflict (eleicao_id, uf_id, nr_zona, nr_secao) do update
set ra_id = excluded.ra_id,
    zona_id = excluded.zona_id,
    local_id = excluded.local_id,
    cd_tipo_secao_agregada = excluded.cd_tipo_secao_agregada,
    ds_tipo_secao_agregada = excluded.ds_tipo_secao_agregada,
    nr_secao_principal = excluded.nr_secao_principal,
    local_principal_id = excluded.local_principal_id,
    cd_situ_secao = excluded.cd_situ_secao,
    ds_situ_secao = excluded.ds_situ_secao,
    cd_situ_secao_acessibilidade = excluded.cd_situ_secao_acessibilidade,
    ds_situ_secao_acessibilidade = excluded.ds_situ_secao_acessibilidade,
    tem_acessibilidade = excluded.tem_acessibilidade,
    qt_eleitores_aptos = excluded.qt_eleitores_aptos,
    qt_eleitores_aptos_tre = excluded.qt_eleitores_aptos_tre,
    qt_eleitores_suspensos_tre = excluded.qt_eleitores_suspensos_tre,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    geom = excluded.geom,
    is_secao_principal_tre = excluded.is_secao_principal_tre,
    fonte_tre_confirmada = excluded.fonte_tre_confirmada,
    is_adicional_csv = excluded.is_adicional_csv,
    source_file = excluded.source_file,
    loaded_at = now();

update dim.secao_eleitoral secao
set secao_principal_id = principal.secao_id,
    local_principal_id = principal.local_id,
    local_id = principal.local_id,
    ra_id = principal.ra_id,
    latitude = principal.latitude,
    longitude = principal.longitude,
    geom = principal.geom
from dim.secao_eleitoral principal
where secao.eleicao_id = principal.eleicao_id
  and secao.uf_id = principal.uf_id
  and secao.nr_zona = principal.nr_zona
  and secao.nr_secao_principal = principal.nr_secao
  and secao.ds_tipo_secao_agregada = 'Agregada';

with perfil_secoes as (
    select distinct
        nr_zona::integer as nr_zona,
        nr_secao::integer as nr_secao
    from stg.perfil_eleitor_secao_2026_df
    where nullif(nr_zona, '') is not null
      and nullif(nr_secao, '') is not null
),
secao_csv_sem_tre as (
    select *
    from dim.secao_eleitoral
    where not fonte_tre_confirmada
),
secao_csv_sem_perfil as (
    select secao.*
    from dim.secao_eleitoral secao
    left join perfil_secoes perfil
      on perfil.nr_zona = secao.nr_zona
     and perfil.nr_secao = secao.nr_secao
    where perfil.nr_zona is null
),
secao_sem_ra as (
    select *
    from dim.secao_eleitoral
    where geom is not null
      and ra_id is null
),
secao_agregada_sem_principal as (
    select *
    from dim.secao_eleitoral
    where ds_tipo_secao_agregada = 'Agregada'
      and secao_principal_id is null
),
secao_agregada_local_diferente_principal as (
    select secao.*
    from dim.secao_eleitoral secao
    join dim.secao_eleitoral principal
      on principal.secao_id = secao.secao_principal_id
    where secao.ds_tipo_secao_agregada = 'Agregada'
      and secao.local_id <> principal.local_id
),
divergencia_aptos_tre_csv as (
    select
        secao.nr_zona,
        secao.nr_secao,
        secao.qt_eleitores_aptos_tre,
        (
            select sum(filha.qt_eleitores_aptos)
            from dim.secao_eleitoral filha
            where filha.eleicao_id = secao.eleicao_id
              and filha.uf_id = secao.uf_id
              and filha.nr_zona = secao.nr_zona
              and (
                  filha.nr_secao = secao.nr_secao
                  or filha.nr_secao_principal = secao.nr_secao
              )
        ) as soma_csv
    from dim.secao_eleitoral secao
    where secao.is_secao_principal_tre
      and secao.qt_eleitores_aptos_tre is not null
      and secao.qt_eleitores_aptos_tre <> (
          select sum(filha.qt_eleitores_aptos)
          from dim.secao_eleitoral filha
          where filha.eleicao_id = secao.eleicao_id
            and filha.uf_id = secao.uf_id
            and filha.nr_zona = secao.nr_zona
            and (
                filha.nr_secao = secao.nr_secao
                or filha.nr_secao_principal = secao.nr_secao
            )
      )
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
    'secao_eleitoral',
    concat('2026|DF|ZE=', nr_zona, '|SECAO=', nr_secao),
    'aviso',
    'secao_csv_sem_tre',
    'Secao presente no CSV oficial e ausente da planilha TRE, mesmo apos expandir secoes agregadas entre parenteses.',
    source_file
from secao_csv_sem_tre
union all
select
    'secao_eleitoral',
    concat('2026|DF|ZE=', nr_zona, '|SECAO=', nr_secao),
    'aviso',
    'secao_csv_sem_perfil',
    'Secao presente no CSV eleitorado/local e ausente no perfil do eleitorado por secao.',
    source_file
from secao_csv_sem_perfil
union all
select
    'secao_eleitoral',
    concat('2026|DF|ZE=', nr_zona, '|SECAO=', nr_secao),
    'erro',
    'secao_sem_ra',
    'Secao herdou local sem RA.',
    source_file
from secao_sem_ra
union all
select
    'secao_eleitoral',
    concat('2026|DF|ZE=', nr_zona, '|SECAO=', nr_secao),
    'erro',
    'secao_agregada_sem_principal',
    concat('Secao agregada referencia principal ', nr_secao_principal, ', mas a principal nao foi encontrada.'),
    source_file
from secao_agregada_sem_principal
union all
select
    'secao_eleitoral',
    concat('2026|DF|ZE=', nr_zona, '|SECAO=', nr_secao),
    'erro',
    'secao_agregada_local_diferente_principal',
    'Secao agregada nao herdou o local da secao principal.',
    source_file
from secao_agregada_local_diferente_principal
union all
select
    'secao_eleitoral',
    concat('2026|DF|ZE=', nr_zona, '|SECAO=', nr_secao),
    'aviso',
    'divergencia_aptos_tre_csv',
    concat('APTOS TRE=', qt_eleitores_aptos_tre, '; soma CSV principal/agregadas=', soma_csv),
    'Secoes_TRE-DF_2026.xlsx'
from divergencia_aptos_tre_csv;
