create or replace view fato.vw_votacao_resultado_nivel as
select
    m.*,
    rank() over (
        partition by m.eleicao_id, m.cargo_id, m.nivel,
                     m.ra_id, m.local_id, m.secao_id
        order by m.qt_votos desc, m.nr_votavel, m.votavel_id
    ) as ranking_no_nivel,
    dense_rank() over (
        partition by m.eleicao_id, m.cargo_id, m.nivel,
                     m.ra_id, m.local_id, m.secao_id
        order by m.qt_votos desc
    ) as ranking_votos_no_nivel
from fato.mv_votacao_nivel m;

drop view if exists fato.vw_votacao_top2_margem;

create or replace view fato.vw_votacao_top5 as
select *
from fato.mv_votacao_top5;

create or replace view fato.vw_votacao_rank_pareto as
with ranked as (
    select
        m.*,
        concat_ws(' - ', m.nr_votavel::text, m.nm_votavel) as label,
        row_number() over (
            partition by m.eleicao_id, m.cargo_id, m.nivel,
                         m.ra_id, m.local_id, m.secao_id
            order by m.qt_votos desc, m.nr_votavel, m.votavel_id
        ) as ranking,
        sum(m.qt_votos) over (
            partition by m.eleicao_id, m.cargo_id, m.nivel,
                         m.ra_id, m.local_id, m.secao_id
            order by m.qt_votos desc, m.nr_votavel, m.votavel_id
            rows between unbounded preceding and current row
        ) as votos_acumulados
    from fato.mv_votacao_nivel m
    where m.tipo_votavel in ('nominal', 'legenda')
)
select
    r.*,
    round((100.0 * r.votos_acumulados / nullif(r.votos_validos_nivel, 0))::numeric, 6) as cum_pct,
    (
        coalesce(
            lag(round((100.0 * r.votos_acumulados / nullif(r.votos_validos_nivel, 0))::numeric, 6)) over (
                partition by r.eleicao_id, r.cargo_id, r.nivel,
                             r.ra_id, r.local_id, r.secao_id
                order by r.ranking
            ),
            0
        ) < 80
    ) as dentro_pareto80
from ranked r;

create or replace view fato.vw_vitorias_zeros_votavel as
with ranked as (
    select
        m.*,
        row_number() over (
            partition by m.eleicao_id, m.cargo_id, m.nivel,
                         m.ra_id, m.local_id, m.secao_id
            order by m.qt_votos desc, m.nr_votavel, m.votavel_id
        ) as ranking_no_nivel,
        lead(m.votavel_id, 1) over (
            partition by m.eleicao_id, m.cargo_id, m.nivel,
                         m.ra_id, m.local_id, m.secao_id
            order by m.qt_votos desc, m.nr_votavel, m.votavel_id
        ) as segundo_votavel_id,
        lead(m.nr_votavel, 1) over (
            partition by m.eleicao_id, m.cargo_id, m.nivel,
                         m.ra_id, m.local_id, m.secao_id
            order by m.qt_votos desc, m.nr_votavel, m.votavel_id
        ) as segundo_nr_votavel,
        lead(m.nm_votavel, 1) over (
            partition by m.eleicao_id, m.cargo_id, m.nivel,
                         m.ra_id, m.local_id, m.secao_id
            order by m.qt_votos desc, m.nr_votavel, m.votavel_id
        ) as segundo_nm_votavel,
        lead(m.qt_votos, 1) over (
            partition by m.eleicao_id, m.cargo_id, m.nivel,
                         m.ra_id, m.local_id, m.secao_id
            order by m.qt_votos desc, m.nr_votavel, m.votavel_id
        ) as segundo_votos,
        lead(m.votavel_id, 2) over (
            partition by m.eleicao_id, m.cargo_id, m.nivel,
                         m.ra_id, m.local_id, m.secao_id
            order by m.qt_votos desc, m.nr_votavel, m.votavel_id
        ) as terceiro_votavel_id,
        lead(m.nr_votavel, 2) over (
            partition by m.eleicao_id, m.cargo_id, m.nivel,
                         m.ra_id, m.local_id, m.secao_id
            order by m.qt_votos desc, m.nr_votavel, m.votavel_id
        ) as terceiro_nr_votavel,
        lead(m.nm_votavel, 2) over (
            partition by m.eleicao_id, m.cargo_id, m.nivel,
                         m.ra_id, m.local_id, m.secao_id
            order by m.qt_votos desc, m.nr_votavel, m.votavel_id
        ) as terceiro_nm_votavel,
        lead(m.qt_votos, 2) over (
            partition by m.eleicao_id, m.cargo_id, m.nivel,
                         m.ra_id, m.local_id, m.secao_id
            order by m.qt_votos desc, m.nr_votavel, m.votavel_id
        ) as terceiro_votos
    from fato.mv_votacao_nivel m
    where m.tipo_votavel in ('nominal', 'legenda')
)
select
    r.*,
    (r.ranking_no_nivel = 1) as venceu_nivel,
    (r.qt_votos = 0 and r.votos_validos_nivel > 0) as zerou_nivel
from ranked r;

create or replace view fato.vw_votacao_heatmap_top5 as
with ra_rank as (
    select
        m.*,
        tg.ranking_top5 as ranking_geral,
        row_number() over (
            partition by m.eleicao_id, m.cargo_id, m.ra_id
            order by m.qt_votos desc, m.nr_votavel, m.votavel_id
        ) as ranking_ra
    from fato.mv_votacao_nivel m
    join fato.mv_votacao_top5 tg
      on tg.eleicao_id = m.eleicao_id
     and tg.cargo_id = m.cargo_id
     and tg.votavel_id = m.votavel_id
     and tg.nivel = 'geral'
    where m.nivel = 'ra'
      and m.tipo_votavel in ('nominal', 'legenda')
)
select
    eleicao_id,
    ano,
    turno,
    cd_eleicao,
    cargo_id,
    cd_cargo,
    ds_cargo,
    ra_id,
    ra_codigo,
    ra_nome,
    votavel_id,
    nr_votavel,
    nm_votavel,
    partido_id,
    sg_partido,
    qt_votos,
    percentual_no_nivel as percentual_na_ra,
    ranking_geral,
    ranking_ra,
    latitude,
    longitude
from ra_rank;

create or replace view fato.vw_votacao_stacked_ra_top5 as
select
    eleicao_id,
    ano,
    turno,
    cd_eleicao,
    cargo_id,
    cd_cargo,
    ds_cargo,
    ra_id,
    ra_codigo,
    ra_nome,
    votavel_id,
    nr_votavel,
    nm_votavel,
    partido_id,
    sg_partido,
    qt_votos,
    percentual_na_ra,
    ranking_geral,
    latitude,
    longitude
from fato.vw_votacao_heatmap_top5;
