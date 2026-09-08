create table if not exists dim.votavel (
    votavel_id bigint generated always as identity primary key,
    eleicao_id bigint not null references dim.eleicao (eleicao_id),
    cargo_id smallint not null references dim.cargo_eleitoral (cargo_id),
    partido_id bigint references dim.partido_politico (partido_id),
    candidato_id bigint references dim.candidato (candidato_id),
    nr_votavel integer not null,
    nm_votavel text not null,
    sq_candidato bigint,
    tipo_votavel text not null check (
        tipo_votavel in ('nominal', 'legenda', 'branco', 'nulo')
    ),
    source_file text,
    loaded_at timestamptz not null default now()
);

create unique index if not exists votavel_uk
on dim.votavel (
    eleicao_id,
    cargo_id,
    nr_votavel,
    (coalesce(sq_candidato, -999999999999))
);

create index if not exists votavel_cargo_idx on dim.votavel (cargo_id);
create index if not exists votavel_partido_idx on dim.votavel (partido_id);
create index if not exists votavel_candidato_idx on dim.votavel (candidato_id);
create index if not exists votavel_tipo_idx on dim.votavel (tipo_votavel);

create table if not exists fato.votacao_candidato_secao (
    eleicao_id bigint not null references dim.eleicao (eleicao_id),
    uf_id smallint not null references dim.uf (uf_id),
    ra_id bigint references dim.regiao_administrativa (ra_id),
    local_id bigint not null references dim.local_votacao (local_id),
    secao_id bigint not null references dim.secao_eleitoral (secao_id),
    cargo_id smallint not null references dim.cargo_eleitoral (cargo_id),
    votavel_id bigint not null references dim.votavel (votavel_id),
    candidato_id bigint references dim.candidato (candidato_id),
    partido_id bigint references dim.partido_politico (partido_id),
    nr_zona integer not null,
    nr_secao integer not null,
    nr_local_votacao integer not null,
    nr_votavel integer not null,
    sq_candidato bigint,
    nm_votavel text not null,
    tipo_votavel text not null check (
        tipo_votavel in ('nominal', 'legenda', 'branco', 'nulo')
    ),
    qt_votos integer not null,
    source_file text,
    loaded_at timestamptz not null default now(),
    primary key (eleicao_id, secao_id, cargo_id, votavel_id)
);

create index if not exists votacao_ra_cargo_idx on fato.votacao_candidato_secao (ra_id, cargo_id);
create index if not exists votacao_uf_ra_local_secao_idx on fato.votacao_candidato_secao (uf_id, ra_id, local_id, secao_id);
create index if not exists votacao_local_candidato_idx on fato.votacao_candidato_secao (local_id, candidato_id);
create index if not exists votacao_partido_idx on fato.votacao_candidato_secao (partido_id);
create index if not exists votacao_votavel_idx on fato.votacao_candidato_secao (votavel_id);

create table if not exists fato.apuracao_secao (
    eleicao_id bigint not null references dim.eleicao (eleicao_id),
    uf_id smallint not null references dim.uf (uf_id),
    ra_id bigint references dim.regiao_administrativa (ra_id),
    local_id bigint not null references dim.local_votacao (local_id),
    secao_id bigint not null references dim.secao_eleitoral (secao_id),
    cargo_id smallint not null references dim.cargo_eleitoral (cargo_id),
    qt_aptos integer,
    qt_comparecimento integer,
    qt_abstencoes integer,
    qt_votos_nominais integer,
    qt_votos_legenda integer,
    qt_votos_brancos integer,
    qt_votos_nulos integer,
    source_file text,
    loaded_at timestamptz not null default now(),
    primary key (eleicao_id, secao_id, cargo_id)
);

create index if not exists apuracao_secao_ra_cargo_idx on fato.apuracao_secao (ra_id, cargo_id);
create index if not exists apuracao_secao_local_idx on fato.apuracao_secao (local_id);

create or replace view fato.vw_votacao_drilldown as
select
    e.ano,
    e.turno,
    e.cd_eleicao,
    e.ds_eleicao,
    uf.sigla as uf,
    ra.ra_codigo,
    ra.ra_nome,
    lv.nr_local_votacao,
    lv.nome as local_votacao,
    se.nr_zona,
    se.nr_secao,
    ce.cd_cargo,
    ce.ds_cargo,
    vc.tipo_votavel,
    vc.nr_votavel,
    vc.nm_votavel,
    pp.sigla as partido,
    c.sq_candidato,
    c.nm_urna_candidato,
    vc.qt_votos
from fato.votacao_candidato_secao vc
join dim.eleicao e on e.eleicao_id = vc.eleicao_id
join dim.uf uf on uf.uf_id = vc.uf_id
left join dim.regiao_administrativa ra on ra.ra_id = vc.ra_id
join dim.local_votacao lv on lv.local_id = vc.local_id
join dim.secao_eleitoral se on se.secao_id = vc.secao_id
join dim.cargo_eleitoral ce on ce.cargo_id = vc.cargo_id
join dim.votavel v on v.votavel_id = vc.votavel_id
left join dim.partido_politico pp on pp.partido_id = vc.partido_id
left join dim.candidato c on c.candidato_id = vc.candidato_id;
