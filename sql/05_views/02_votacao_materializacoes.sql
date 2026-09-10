drop view if exists fato.vw_votacao_stacked_ra_top5;
drop view if exists fato.vw_votacao_heatmap_top5;
drop view if exists fato.vw_vitorias_zeros_votavel;
drop view if exists fato.vw_votacao_rank_pareto;
drop view if exists fato.vw_votacao_top5;
drop view if exists fato.vw_votacao_top2_margem;
drop view if exists fato.vw_votacao_resultado_nivel;
drop materialized view if exists fato.mv_votacao_top5;
drop materialized view if exists fato.mv_votacao_top2_margem;
drop materialized view if exists fato.mv_votacao_nivel;

create materialized view fato.mv_votacao_nivel as
with base as (
    select
        vc.eleicao_id,
        e.ano,
        e.turno,
        e.cd_eleicao,
        vc.cargo_id,
        ce.cd_cargo,
        ce.ds_cargo,
        vc.uf_id,
        uf.sigla::text as uf,
        vc.ra_id,
        ra.ra_codigo,
        ra.ra_nome,
        vc.local_id,
        vc.nr_zona,
        vc.nr_local_votacao,
        lv.nome as local_votacao,
        vc.secao_id,
        vc.nr_secao,
        coalesce(se.latitude, lv.latitude) as secao_latitude,
        coalesce(se.longitude, lv.longitude) as secao_longitude,
        coalesce(se.geom, lv.geom)::geometry as secao_geom,
        lv.latitude as local_latitude,
        lv.longitude as local_longitude,
        lv.geom::geometry as local_geom,
        rg.centroid_lat as ra_latitude,
        rg.centroid_lon as ra_longitude,
        rg.geom::geometry as ra_geom,
        vc.votavel_id,
        vc.nr_votavel,
        vc.nm_votavel,
        vc.tipo_votavel,
        vc.partido_id,
        pp.sigla as sg_partido,
        vc.qt_votos
    from fato.votacao_candidato_secao vc
    join dim.eleicao e on e.eleicao_id = vc.eleicao_id
    join dim.cargo_eleitoral ce on ce.cargo_id = vc.cargo_id
    join dim.uf uf on uf.uf_id = vc.uf_id
    join dim.local_votacao lv on lv.local_id = vc.local_id
    join dim.secao_eleitoral se on se.secao_id = vc.secao_id
    left join dim.regiao_administrativa ra on ra.ra_id = vc.ra_id
    left join geo.ra_geometria rg on rg.ra_id = vc.ra_id
    left join dim.partido_politico pp on pp.partido_id = vc.partido_id
),
nivel_agregado as (
    select
        eleicao_id,
        ano,
        turno,
        cd_eleicao,
        cargo_id,
        cd_cargo,
        ds_cargo,
        'geral'::text as nivel,
        min(uf_id) as uf_id,
        min(uf) as uf,
        null::bigint as ra_id,
        null::text as ra_codigo,
        null::text as ra_nome,
        null::bigint as local_id,
        null::integer as nr_zona,
        null::integer as nr_local_votacao,
        null::text as local_votacao,
        null::bigint as secao_id,
        null::integer as nr_secao,
        null::numeric(11,8) as latitude,
        null::numeric(11,8) as longitude,
        null::geometry as geom,
        votavel_id,
        nr_votavel,
        nm_votavel,
        tipo_votavel,
        partido_id,
        sg_partido,
        sum(qt_votos)::bigint as qt_votos
    from base
    group by eleicao_id, ano, turno, cd_eleicao, cargo_id, cd_cargo, ds_cargo,
             votavel_id, nr_votavel, nm_votavel, tipo_votavel, partido_id, sg_partido

    union all

    select
        eleicao_id,
        ano,
        turno,
        cd_eleicao,
        cargo_id,
        cd_cargo,
        ds_cargo,
        'ra'::text as nivel,
        min(uf_id) as uf_id,
        min(uf) as uf,
        ra_id,
        ra_codigo,
        ra_nome,
        null::bigint as local_id,
        null::integer as nr_zona,
        null::integer as nr_local_votacao,
        null::text as local_votacao,
        null::bigint as secao_id,
        null::integer as nr_secao,
        ra_latitude as latitude,
        ra_longitude as longitude,
        ra_geom as geom,
        votavel_id,
        nr_votavel,
        nm_votavel,
        tipo_votavel,
        partido_id,
        sg_partido,
        sum(qt_votos)::bigint as qt_votos
    from base
    group by eleicao_id, ano, turno, cd_eleicao, cargo_id, cd_cargo, ds_cargo,
             ra_id, ra_codigo, ra_nome, ra_latitude, ra_longitude, ra_geom,
             votavel_id, nr_votavel, nm_votavel, tipo_votavel, partido_id, sg_partido

    union all

    select
        eleicao_id,
        ano,
        turno,
        cd_eleicao,
        cargo_id,
        cd_cargo,
        ds_cargo,
        'local'::text as nivel,
        min(uf_id) as uf_id,
        min(uf) as uf,
        ra_id,
        ra_codigo,
        ra_nome,
        local_id,
        nr_zona,
        nr_local_votacao,
        local_votacao,
        null::bigint as secao_id,
        null::integer as nr_secao,
        local_latitude as latitude,
        local_longitude as longitude,
        local_geom as geom,
        votavel_id,
        nr_votavel,
        nm_votavel,
        tipo_votavel,
        partido_id,
        sg_partido,
        sum(qt_votos)::bigint as qt_votos
    from base
    group by eleicao_id, ano, turno, cd_eleicao, cargo_id, cd_cargo, ds_cargo,
             ra_id, ra_codigo, ra_nome, local_id, nr_zona, nr_local_votacao,
             local_votacao, local_latitude, local_longitude, local_geom,
             votavel_id, nr_votavel, nm_votavel, tipo_votavel, partido_id, sg_partido

    union all

    select
        eleicao_id,
        ano,
        turno,
        cd_eleicao,
        cargo_id,
        cd_cargo,
        ds_cargo,
        'secao'::text as nivel,
        min(uf_id) as uf_id,
        min(uf) as uf,
        ra_id,
        ra_codigo,
        ra_nome,
        local_id,
        nr_zona,
        nr_local_votacao,
        local_votacao,
        secao_id,
        nr_secao,
        secao_latitude as latitude,
        secao_longitude as longitude,
        secao_geom as geom,
        votavel_id,
        nr_votavel,
        nm_votavel,
        tipo_votavel,
        partido_id,
        sg_partido,
        sum(qt_votos)::bigint as qt_votos
    from base
    group by eleicao_id, ano, turno, cd_eleicao, cargo_id, cd_cargo, ds_cargo,
             ra_id, ra_codigo, ra_nome, local_id, nr_zona, nr_local_votacao,
             local_votacao, secao_id, nr_secao, secao_latitude, secao_longitude,
             secao_geom, votavel_id, nr_votavel, nm_votavel, tipo_votavel,
             partido_id, sg_partido
),
com_totais as (
    select
        n.*,
        sum(n.qt_votos) over (
            partition by n.eleicao_id, n.cargo_id, n.nivel,
                         n.ra_id, n.local_id, n.secao_id
        ) as votos_brutos_nivel,
        sum(n.qt_votos) filter (where n.tipo_votavel in ('nominal', 'legenda')) over (
            partition by n.eleicao_id, n.cargo_id, n.nivel,
                         n.ra_id, n.local_id, n.secao_id
        ) as votos_validos_nivel,
        sum(n.qt_votos) filter (where n.tipo_votavel = 'branco') over (
            partition by n.eleicao_id, n.cargo_id, n.nivel,
                         n.ra_id, n.local_id, n.secao_id
        ) as votos_brancos_nivel,
        sum(n.qt_votos) filter (where n.tipo_votavel = 'nulo') over (
            partition by n.eleicao_id, n.cargo_id, n.nivel,
                         n.ra_id, n.local_id, n.secao_id
        ) as votos_nulos_nivel,
        sum(n.qt_votos) over (
            partition by n.eleicao_id, n.cargo_id
        ) as votos_brutos_total
    from nivel_agregado n
)
select
    eleicao_id,
    ano,
    turno,
    cd_eleicao,
    cargo_id,
    cd_cargo,
    ds_cargo,
    nivel,
    uf_id,
    uf,
    ra_id,
    ra_codigo,
    ra_nome,
    local_id,
    nr_zona,
    nr_local_votacao,
    local_votacao,
    secao_id,
    nr_secao,
    latitude,
    longitude,
    geom,
    votavel_id,
    nr_votavel,
    nm_votavel,
    tipo_votavel,
    partido_id,
    sg_partido,
    qt_votos,
    coalesce(votos_validos_nivel, 0)::bigint as votos_validos_nivel,
    coalesce(votos_brutos_nivel, 0)::bigint as votos_brutos_nivel,
    coalesce(votos_brancos_nivel, 0)::bigint as votos_brancos_nivel,
    coalesce(votos_nulos_nivel, 0)::bigint as votos_nulos_nivel,
    round((100.0 * qt_votos / nullif(votos_brutos_nivel, 0))::numeric, 6) as percentual_no_nivel,
    round((100.0 * qt_votos / nullif(votos_brutos_total, 0))::numeric, 6) as percentual_no_total
from com_totais;

create unique index mv_votacao_nivel_uk
on fato.mv_votacao_nivel (
    eleicao_id,
    cargo_id,
    nivel,
    coalesce(ra_id, -1),
    coalesce(local_id, -1),
    coalesce(secao_id, -1),
    votavel_id
);

create index mv_votacao_nivel_filtro_idx
on fato.mv_votacao_nivel (eleicao_id, cargo_id, nivel, tipo_votavel);

create index mv_votacao_nivel_territorio_idx
on fato.mv_votacao_nivel (nivel, ra_id, local_id, secao_id);

create materialized view fato.mv_votacao_top5 as
with territorios as (
    select
        eleicao_id,
        cargo_id,
        nivel,
        uf_id,
        uf,
        ra_id,
        ra_codigo,
        ra_nome,
        local_id,
        nr_zona,
        nr_local_votacao,
        local_votacao,
        secao_id,
        nr_secao,
        max(votos_validos_nivel) as votos_validos_nivel,
        max(votos_brutos_nivel) as votos_brutos_nivel,
        max(votos_brancos_nivel) as votos_brancos_nivel,
        max(votos_nulos_nivel) as votos_nulos_nivel
    from fato.mv_votacao_nivel
    group by eleicao_id, cargo_id, nivel, uf_id, uf, ra_id, ra_codigo, ra_nome,
             local_id, nr_zona, nr_local_votacao, local_votacao, secao_id, nr_secao
),
territorio_stats as (
    select
        eleicao_id,
        cargo_id,
        'geral'::text as nivel,
        null::bigint as ra_id,
        null::bigint as local_id,
        null::bigint as secao_id,
        count(distinct local_id)::integer as total_locais,
        count(distinct secao_id)::integer as total_secoes,
        count(distinct nr_zona)::integer as total_zonas
    from fato.votacao_candidato_secao
    group by eleicao_id, cargo_id

    union all

    select
        eleicao_id,
        cargo_id,
        'ra'::text as nivel,
        ra_id,
        null::bigint as local_id,
        null::bigint as secao_id,
        count(distinct local_id)::integer as total_locais,
        count(distinct secao_id)::integer as total_secoes,
        count(distinct nr_zona)::integer as total_zonas
    from fato.votacao_candidato_secao
    group by eleicao_id, cargo_id, ra_id

    union all

    select
        eleicao_id,
        cargo_id,
        'local'::text as nivel,
        ra_id,
        local_id,
        null::bigint as secao_id,
        count(distinct local_id)::integer as total_locais,
        count(distinct secao_id)::integer as total_secoes,
        count(distinct nr_zona)::integer as total_zonas
    from fato.votacao_candidato_secao
    group by eleicao_id, cargo_id, ra_id, local_id

    union all

    select
        eleicao_id,
        cargo_id,
        'secao'::text as nivel,
        ra_id,
        local_id,
        secao_id,
        count(distinct local_id)::integer as total_locais,
        count(distinct secao_id)::integer as total_secoes,
        count(distinct nr_zona)::integer as total_zonas
    from fato.votacao_candidato_secao
    group by eleicao_id, cargo_id, ra_id, local_id, secao_id
),
top5_ranked as (
    select
        m.*,
        row_number() over (
            partition by m.eleicao_id, m.cargo_id, m.nivel,
                         m.ra_id, m.local_id, m.secao_id
            order by m.qt_votos desc, m.nr_votavel, m.votavel_id
        ) as posicao
    from fato.mv_votacao_nivel m
    where m.tipo_votavel in ('nominal', 'legenda')
)
select
    r.eleicao_id,
    r.ano,
    r.turno,
    r.cd_eleicao,
    r.cargo_id,
    r.cd_cargo,
    r.ds_cargo,
    r.nivel,
    r.uf_id,
    r.uf,
    r.ra_id,
    r.ra_codigo,
    r.ra_nome,
    r.local_id,
    r.nr_zona,
    r.nr_local_votacao,
    r.local_votacao,
    r.secao_id,
    r.nr_secao,
    r.votavel_id,
    r.nr_votavel,
    r.nm_votavel,
    r.partido_id,
    r.sg_partido,
    r.qt_votos,
    r.votos_validos_nivel,
    r.votos_brutos_nivel,
    r.votos_brancos_nivel,
    r.votos_nulos_nivel,
    round((100.0 * r.qt_votos / nullif(r.votos_validos_nivel, 0))::numeric, 6) as percentual_validos_nivel,
    r.percentual_no_nivel,
    r.percentual_no_total,
    r.posicao as ranking_top5,
    ts.total_locais,
    ts.total_secoes,
    ts.total_zonas
from top5_ranked r
join territorios t
  on t.eleicao_id = r.eleicao_id
 and t.cargo_id = r.cargo_id
 and t.nivel = r.nivel
 and t.ra_id is not distinct from r.ra_id
 and t.local_id is not distinct from r.local_id
 and t.secao_id is not distinct from r.secao_id
left join territorio_stats ts
  on ts.eleicao_id = r.eleicao_id
 and ts.cargo_id = r.cargo_id
 and ts.nivel = r.nivel
 and ts.ra_id is not distinct from r.ra_id
 and ts.local_id is not distinct from r.local_id
 and ts.secao_id is not distinct from r.secao_id
where r.posicao <= 5;

create unique index mv_votacao_top5_uk
on fato.mv_votacao_top5 (
    eleicao_id,
    cargo_id,
    nivel,
    coalesce(ra_id, -1),
    coalesce(local_id, -1),
    coalesce(secao_id, -1),
    ranking_top5
);

create index mv_votacao_top5_votavel_idx
on fato.mv_votacao_top5 (eleicao_id, cargo_id, nivel, votavel_id);

create index mv_votacao_top5_territorio_idx
on fato.mv_votacao_top5 (nivel, ra_id, local_id, secao_id);

analyze fato.mv_votacao_nivel;
analyze fato.mv_votacao_top5;
