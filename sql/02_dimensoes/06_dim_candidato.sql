create table if not exists dim.candidato (
    candidato_id bigint generated always as identity primary key,
    eleicao_id bigint not null references dim.eleicao (eleicao_id),
    uf_id smallint not null references dim.uf (uf_id),
    cargo_id smallint not null references dim.cargo_eleitoral (cargo_id),
    partido_id bigint references dim.partido_politico (partido_id),
    federacao_id bigint references dim.federacao (federacao_id),
    coligacao_id bigint references dim.coligacao (coligacao_id),
    sq_candidato bigint not null,
    nr_candidato integer not null,
    nm_candidato text not null,
    nm_urna_candidato text,
    nm_social_candidato text,
    cpf_hash text,
    email_divulgavel text,
    tp_agremiacao text,
    cd_situacao_candidatura integer,
    ds_situacao_candidatura text,
    cd_detalhe_situacao_cand integer,
    ds_detalhe_situacao_cand text,
    cd_genero integer,
    ds_genero text,
    cd_grau_instrucao integer,
    ds_grau_instrucao text,
    cd_estado_civil integer,
    ds_estado_civil text,
    cd_cor_raca text,
    ds_cor_raca text,
    cd_ocupacao integer,
    ds_ocupacao text,
    sg_uf_nascimento char(2),
    cd_municipio_nascimento integer,
    nm_municipio_nascimento text,
    dt_nascimento date,
    cd_nacionalidade integer,
    ds_nacionalidade text,
    nr_idade_data_posse integer,
    st_quilombola boolean,
    cd_etnia_indigena integer,
    ds_etnia_indigena text,
    st_reeleicao boolean,
    st_declarar_bens boolean,
    vr_despesa_max_campanha numeric(16, 2),
    cd_situacao_julgamento integer,
    ds_situacao_julgamento text,
    cd_situacao_candidato_urna integer,
    ds_situacao_candidato_urna text,
    cd_sit_tot_turno integer,
    ds_sit_tot_turno text,
    source_file text,
    source_file_complementar text,
    loaded_at timestamptz not null default now(),
    unique (eleicao_id, sq_candidato)
);

create index if not exists candidato_partido_idx on dim.candidato (partido_id);
create index if not exists candidato_cargo_idx on dim.candidato (cargo_id);
create index if not exists candidato_federacao_idx on dim.candidato (federacao_id);
create index if not exists candidato_coligacao_idx on dim.candidato (coligacao_id);

delete from aux.qualidade_dado
where entidade = 'candidato'
  and regra in (
      'candidato_sem_complementar',
      'candidato_sem_cargo',
      'candidato_sem_partido',
      'candidato_sem_federacao',
      'candidato_sem_coligacao'
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
source_candidato as (
    select
        eleicao_2026.eleicao_id,
        uf_df.uf_id,
        cargo.cargo_id,
        partido.partido_id,
        federacao.federacao_id,
        coligacao.coligacao_id,
        cand.sq_candidato::bigint as sq_candidato,
        cand.nr_candidato::integer as nr_candidato,
        nullif(cand.nm_candidato, '') as nm_candidato,
        nullif(cand.nm_urna_candidato, '') as nm_urna_candidato,
        nullif(cand.nm_social_candidato, '') as nm_social_candidato,
        case
            when nullif(cand.nr_cpf_candidato, '') is not null then
                md5(cand.nr_cpf_candidato)
            else null
        end as cpf_hash,
        nullif(cand.ds_email, '') as email_divulgavel,
        nullif(cand.tp_agremiacao, '') as tp_agremiacao,
        nullif(cand.cd_situacao_candidatura, '')::integer as cd_situacao_candidatura,
        nullif(cand.ds_situacao_candidatura, '') as ds_situacao_candidatura,
        nullif(comp.cd_detalhe_situacao_cand, '')::integer as cd_detalhe_situacao_cand,
        nullif(comp.ds_detalhe_situacao_cand, '') as ds_detalhe_situacao_cand,
        nullif(cand.cd_genero, '')::integer as cd_genero,
        nullif(cand.ds_genero, '') as ds_genero,
        nullif(cand.cd_grau_instrucao, '')::integer as cd_grau_instrucao,
        nullif(cand.ds_grau_instrucao, '') as ds_grau_instrucao,
        nullif(cand.cd_estado_civil, '')::integer as cd_estado_civil,
        nullif(cand.ds_estado_civil, '') as ds_estado_civil,
        nullif(cand.cd_cor_raca, '') as cd_cor_raca,
        nullif(cand.ds_cor_raca, '') as ds_cor_raca,
        nullif(cand.cd_ocupacao, '')::integer as cd_ocupacao,
        nullif(cand.ds_ocupacao, '') as ds_ocupacao,
        nullif(cand.sg_uf_nascimento, '')::char(2) as sg_uf_nascimento,
        nullif(comp.cd_municipio_nascimento, '')::integer as cd_municipio_nascimento,
        nullif(comp.nm_municipio_nascimento, '') as nm_municipio_nascimento,
        to_date(cand.dt_nascimento, 'DD/MM/YYYY') as dt_nascimento,
        nullif(comp.cd_nacionalidade, '')::integer as cd_nacionalidade,
        nullif(comp.ds_nacionalidade, '') as ds_nacionalidade,
        nullif(comp.nr_idade_data_posse, '')::integer as nr_idade_data_posse,
        case comp.st_quilombola
            when 'S' then true
            when 'N' then false
            else null
        end as st_quilombola,
        case
            when nullif(comp.cd_etnia_indigena, '') is not null
             and comp.cd_etnia_indigena::integer > 0 then
                comp.cd_etnia_indigena::integer
            else null
        end as cd_etnia_indigena,
        case
            when nullif(comp.ds_etnia_indigena, '') is not null
             and comp.ds_etnia_indigena <> '#NULO' then
                comp.ds_etnia_indigena
            else null
        end as ds_etnia_indigena,
        case comp.st_reeleicao
            when 'S' then true
            when 'N' then false
            else null
        end as st_reeleicao,
        case comp.st_declarar_bens
            when 'S' then true
            when 'N' then false
            else null
        end as st_declarar_bens,
        case
            when nullif(comp.vr_despesa_max_campanha, '') is not null
             and comp.vr_despesa_max_campanha::numeric >= 0 then
                comp.vr_despesa_max_campanha::numeric(16, 2)
            else null
        end as vr_despesa_max_campanha,
        nullif(comp.cd_situacao_julgamento, '')::integer as cd_situacao_julgamento,
        nullif(comp.ds_situacao_julgamento, '') as ds_situacao_julgamento,
        nullif(comp.cd_situacao_candidato_urna, '')::integer as cd_situacao_candidato_urna,
        nullif(comp.ds_situacao_candidato_urna, '') as ds_situacao_candidato_urna,
        nullif(cand.cd_sit_tot_turno, '')::integer as cd_sit_tot_turno,
        nullif(cand.ds_sit_tot_turno, '') as ds_sit_tot_turno,
        cand.source_file,
        comp.source_file as source_file_complementar
    from stg.consulta_cand_2026_df cand
    cross join eleicao_2026
    cross join uf_df
    join dim.cargo_eleitoral cargo
      on cargo.cd_cargo = cand.cd_cargo::integer
    join dim.partido_politico partido
      on partido.nr_partido = cand.nr_partido::integer
    left join dim.federacao federacao
      on nullif(cand.nr_federacao, '') is not null
     and cand.nr_federacao::integer > 0
     and federacao.nr_federacao = cand.nr_federacao::integer
     and federacao.sg_federacao = cand.sg_federacao
    left join dim.coligacao coligacao
      on coligacao.eleicao_id = eleicao_2026.eleicao_id
     and coligacao.sq_coligacao = cand.sq_coligacao::bigint
    left join stg.consulta_cand_complementar_2026_df comp
      on comp.sq_candidato = cand.sq_candidato
    where nullif(cand.sq_candidato, '') is not null
)
insert into dim.candidato (
    eleicao_id,
    uf_id,
    cargo_id,
    partido_id,
    federacao_id,
    coligacao_id,
    sq_candidato,
    nr_candidato,
    nm_candidato,
    nm_urna_candidato,
    nm_social_candidato,
    cpf_hash,
    email_divulgavel,
    tp_agremiacao,
    cd_situacao_candidatura,
    ds_situacao_candidatura,
    cd_detalhe_situacao_cand,
    ds_detalhe_situacao_cand,
    cd_genero,
    ds_genero,
    cd_grau_instrucao,
    ds_grau_instrucao,
    cd_estado_civil,
    ds_estado_civil,
    cd_cor_raca,
    ds_cor_raca,
    cd_ocupacao,
    ds_ocupacao,
    sg_uf_nascimento,
    cd_municipio_nascimento,
    nm_municipio_nascimento,
    dt_nascimento,
    cd_nacionalidade,
    ds_nacionalidade,
    nr_idade_data_posse,
    st_quilombola,
    cd_etnia_indigena,
    ds_etnia_indigena,
    st_reeleicao,
    st_declarar_bens,
    vr_despesa_max_campanha,
    cd_situacao_julgamento,
    ds_situacao_julgamento,
    cd_situacao_candidato_urna,
    ds_situacao_candidato_urna,
    cd_sit_tot_turno,
    ds_sit_tot_turno,
    source_file,
    source_file_complementar
)
select
    eleicao_id,
    uf_id,
    cargo_id,
    partido_id,
    federacao_id,
    coligacao_id,
    sq_candidato,
    nr_candidato,
    nm_candidato,
    nm_urna_candidato,
    nm_social_candidato,
    cpf_hash,
    email_divulgavel,
    tp_agremiacao,
    cd_situacao_candidatura,
    ds_situacao_candidatura,
    cd_detalhe_situacao_cand,
    ds_detalhe_situacao_cand,
    cd_genero,
    ds_genero,
    cd_grau_instrucao,
    ds_grau_instrucao,
    cd_estado_civil,
    ds_estado_civil,
    cd_cor_raca,
    ds_cor_raca,
    cd_ocupacao,
    ds_ocupacao,
    sg_uf_nascimento,
    cd_municipio_nascimento,
    nm_municipio_nascimento,
    dt_nascimento,
    cd_nacionalidade,
    ds_nacionalidade,
    nr_idade_data_posse,
    st_quilombola,
    cd_etnia_indigena,
    ds_etnia_indigena,
    st_reeleicao,
    st_declarar_bens,
    vr_despesa_max_campanha,
    cd_situacao_julgamento,
    ds_situacao_julgamento,
    cd_situacao_candidato_urna,
    ds_situacao_candidato_urna,
    cd_sit_tot_turno,
    ds_sit_tot_turno,
    source_file,
    source_file_complementar
from source_candidato
on conflict (eleicao_id, sq_candidato) do update
set uf_id = excluded.uf_id,
    cargo_id = excluded.cargo_id,
    partido_id = excluded.partido_id,
    federacao_id = excluded.federacao_id,
    coligacao_id = excluded.coligacao_id,
    nr_candidato = excluded.nr_candidato,
    nm_candidato = excluded.nm_candidato,
    nm_urna_candidato = excluded.nm_urna_candidato,
    nm_social_candidato = excluded.nm_social_candidato,
    cpf_hash = excluded.cpf_hash,
    email_divulgavel = excluded.email_divulgavel,
    tp_agremiacao = excluded.tp_agremiacao,
    cd_situacao_candidatura = excluded.cd_situacao_candidatura,
    ds_situacao_candidatura = excluded.ds_situacao_candidatura,
    cd_detalhe_situacao_cand = excluded.cd_detalhe_situacao_cand,
    ds_detalhe_situacao_cand = excluded.ds_detalhe_situacao_cand,
    cd_genero = excluded.cd_genero,
    ds_genero = excluded.ds_genero,
    cd_grau_instrucao = excluded.cd_grau_instrucao,
    ds_grau_instrucao = excluded.ds_grau_instrucao,
    cd_estado_civil = excluded.cd_estado_civil,
    ds_estado_civil = excluded.ds_estado_civil,
    cd_cor_raca = excluded.cd_cor_raca,
    ds_cor_raca = excluded.ds_cor_raca,
    cd_ocupacao = excluded.cd_ocupacao,
    ds_ocupacao = excluded.ds_ocupacao,
    sg_uf_nascimento = excluded.sg_uf_nascimento,
    cd_municipio_nascimento = excluded.cd_municipio_nascimento,
    nm_municipio_nascimento = excluded.nm_municipio_nascimento,
    dt_nascimento = excluded.dt_nascimento,
    cd_nacionalidade = excluded.cd_nacionalidade,
    ds_nacionalidade = excluded.ds_nacionalidade,
    nr_idade_data_posse = excluded.nr_idade_data_posse,
    st_quilombola = excluded.st_quilombola,
    cd_etnia_indigena = excluded.cd_etnia_indigena,
    ds_etnia_indigena = excluded.ds_etnia_indigena,
    st_reeleicao = excluded.st_reeleicao,
    st_declarar_bens = excluded.st_declarar_bens,
    vr_despesa_max_campanha = excluded.vr_despesa_max_campanha,
    cd_situacao_julgamento = excluded.cd_situacao_julgamento,
    ds_situacao_julgamento = excluded.ds_situacao_julgamento,
    cd_situacao_candidato_urna = excluded.cd_situacao_candidato_urna,
    ds_situacao_candidato_urna = excluded.ds_situacao_candidato_urna,
    cd_sit_tot_turno = excluded.cd_sit_tot_turno,
    ds_sit_tot_turno = excluded.ds_sit_tot_turno,
    source_file = excluded.source_file,
    source_file_complementar = excluded.source_file_complementar,
    loaded_at = now();

with base as (
    select
        cand.*,
        comp.sq_candidato as sq_candidato_complementar,
        cargo.cargo_id,
        partido.partido_id,
        federacao.federacao_id,
        coligacao.coligacao_id,
        e.eleicao_id
    from stg.consulta_cand_2026_df cand
    left join stg.consulta_cand_complementar_2026_df comp
      on comp.sq_candidato = cand.sq_candidato
    left join dim.cargo_eleitoral cargo
      on cargo.cd_cargo = cand.cd_cargo::integer
    left join dim.partido_politico partido
      on partido.nr_partido = cand.nr_partido::integer
    left join dim.federacao federacao
      on nullif(cand.nr_federacao, '') is not null
     and cand.nr_federacao::integer > 0
     and federacao.nr_federacao = cand.nr_federacao::integer
     and federacao.sg_federacao = cand.sg_federacao
    left join dim.eleicao e
      on e.ano = cand.ano_eleicao::smallint
     and e.turno = cand.nr_turno::smallint
     and e.cd_eleicao = cand.cd_eleicao::integer
    left join dim.coligacao coligacao
      on coligacao.eleicao_id = e.eleicao_id
     and coligacao.sq_coligacao = cand.sq_coligacao::bigint
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
    'candidato',
    concat('2026|DF|SQ_CANDIDATO=', sq_candidato),
    'erro',
    'candidato_sem_complementar',
    'Candidato sem registro correspondente em consulta_cand_complementar_2026_DF.csv.',
    source_file
from base
where sq_candidato_complementar is null
union all
select
    'candidato',
    concat('2026|DF|SQ_CANDIDATO=', sq_candidato),
    'erro',
    'candidato_sem_cargo',
    'Candidato sem cargo correspondente em dim.cargo_eleitoral.',
    source_file
from base
where cargo_id is null
union all
select
    'candidato',
    concat('2026|DF|SQ_CANDIDATO=', sq_candidato),
    'erro',
    'candidato_sem_partido',
    'Candidato sem partido correspondente em dim.partido_politico.',
    source_file
from base
where partido_id is null
union all
select
    'candidato',
    concat('2026|DF|SQ_CANDIDATO=', sq_candidato),
    'erro',
    'candidato_sem_federacao',
    'Candidato possui federacao informada na fonte, mas ela nao foi encontrada em dim.federacao.',
    source_file
from base
where nullif(nr_federacao, '') is not null
  and nr_federacao::integer > 0
  and federacao_id is null
union all
select
    'candidato',
    concat('2026|DF|SQ_CANDIDATO=', sq_candidato),
    'erro',
    'candidato_sem_coligacao',
    'Candidato possui coligacao informada na fonte, mas ela nao foi encontrada em dim.coligacao.',
    source_file
from base
where nullif(sq_coligacao, '') is not null
  and sq_coligacao::bigint > 0
  and coligacao_id is null;
