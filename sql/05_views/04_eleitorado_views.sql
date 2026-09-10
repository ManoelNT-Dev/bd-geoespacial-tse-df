drop materialized view if exists fato.mv_eleitorado_perfil_nivel;

set enable_memoize = off;

create materialized view fato.mv_eleitorado_perfil_nivel as
with base as (
    select
        ep.eleicao_id,
        e.ano,
        e.turno,
        e.cd_eleicao,
        ep.uf_id,
        uf.sigla::text as uf,
        ep.ra_id,
        ra.ra_codigo,
        ra.ra_nome,
        ep.local_id,
        lv.nr_zona,
        lv.nr_local_votacao,
        lv.nome as local_votacao,
        ep.secao_id,
        se.nr_secao,
        ep.qt_eleitores,
        ep.qt_eleitores_biometria,
        ep.qt_eleitores_deficiencia,
        ep.qt_eleitores_nome_social,
        perfil.dimensao,
        perfil.codigo,
        perfil.descricao
    from fato.eleitorado_perfil_secao ep
    join dim.eleicao e on e.eleicao_id = ep.eleicao_id
    join dim.uf uf on uf.uf_id = ep.uf_id
    join dim.local_votacao lv on lv.local_id = ep.local_id
    join dim.secao_eleitoral se on se.secao_id = ep.secao_id
    join dim.perfil_eleitor pe on pe.perfil_id = ep.perfil_id
    left join dim.regiao_administrativa ra on ra.ra_id = ep.ra_id
    cross join lateral (
        values
            ('genero'::text, pe.cd_genero, pe.ds_genero),
            ('estado_civil'::text, pe.cd_estado_civil, pe.ds_estado_civil),
            ('faixa_etaria'::text, pe.cd_faixa_etaria, pe.ds_faixa_etaria),
            ('escolaridade'::text, pe.cd_grau_escolaridade, pe.ds_grau_escolaridade),
            ('raca_cor'::text, pe.cd_raca_cor, pe.ds_raca_cor),
            ('identidade_genero'::text, pe.cd_identidade_genero, pe.ds_identidade_genero),
            ('quilombola'::text, pe.cd_quilombola, pe.ds_quilombola),
            ('interprete_libras'::text, pe.cd_interprete_libras, pe.ds_interprete_libras)
    ) as perfil(dimensao, codigo, descricao)
),
nivel_agregado as (
    select
        eleicao_id,
        ano,
        turno,
        cd_eleicao,
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
        dimensao,
        codigo,
        descricao,
        sum(qt_eleitores)::bigint as qt_eleitores,
        sum(qt_eleitores_biometria)::bigint as qt_eleitores_biometria,
        sum(qt_eleitores_deficiencia)::bigint as qt_eleitores_deficiencia,
        sum(qt_eleitores_nome_social)::bigint as qt_eleitores_nome_social
    from base
    group by eleicao_id, ano, turno, cd_eleicao, ra_id, ra_codigo, ra_nome,
             dimensao, codigo, descricao

    union all

    select
        eleicao_id,
        ano,
        turno,
        cd_eleicao,
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
        dimensao,
        codigo,
        descricao,
        sum(qt_eleitores)::bigint as qt_eleitores,
        sum(qt_eleitores_biometria)::bigint as qt_eleitores_biometria,
        sum(qt_eleitores_deficiencia)::bigint as qt_eleitores_deficiencia,
        sum(qt_eleitores_nome_social)::bigint as qt_eleitores_nome_social
    from base
    group by eleicao_id, ano, turno, cd_eleicao, ra_id, ra_codigo, ra_nome,
             local_id, nr_zona, nr_local_votacao, local_votacao,
             dimensao, codigo, descricao

    union all

    select
        eleicao_id,
        ano,
        turno,
        cd_eleicao,
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
        dimensao,
        codigo,
        descricao,
        sum(qt_eleitores)::bigint as qt_eleitores,
        sum(qt_eleitores_biometria)::bigint as qt_eleitores_biometria,
        sum(qt_eleitores_deficiencia)::bigint as qt_eleitores_deficiencia,
        sum(qt_eleitores_nome_social)::bigint as qt_eleitores_nome_social
    from base
    group by eleicao_id, ano, turno, cd_eleicao, ra_id, ra_codigo, ra_nome,
             local_id, nr_zona, nr_local_votacao, local_votacao, secao_id, nr_secao,
             dimensao, codigo, descricao
),
com_totais as (
    select
        n.*,
        sum(n.qt_eleitores) over (
            partition by n.eleicao_id, n.nivel, n.ra_id, n.local_id, n.secao_id, n.dimensao
        ) as total_eleitores_nivel
    from nivel_agregado n
)
select
    eleicao_id,
    ano,
    turno,
    cd_eleicao,
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
    dimensao,
    codigo,
    descricao,
    qt_eleitores,
    qt_eleitores_biometria,
    qt_eleitores_deficiencia,
    qt_eleitores_nome_social,
    total_eleitores_nivel::bigint,
    round((100.0 * qt_eleitores / nullif(total_eleitores_nivel, 0))::numeric, 6) as percentual
from com_totais;

create unique index mv_eleitorado_perfil_nivel_uk
on fato.mv_eleitorado_perfil_nivel (
    eleicao_id,
    nivel,
    coalesce(ra_id, -1),
    coalesce(local_id, -1),
    coalesce(secao_id, -1),
    dimensao,
    codigo
);

create index mv_eleitorado_perfil_nivel_filtro_idx
on fato.mv_eleitorado_perfil_nivel (eleicao_id, nivel, dimensao);

create index mv_eleitorado_perfil_nivel_territorio_idx
on fato.mv_eleitorado_perfil_nivel (nivel, ra_id, local_id, secao_id);

create or replace view fato.vw_eleitorado_perfil_ra as
select *
from fato.mv_eleitorado_perfil_nivel
where nivel = 'ra';

create or replace view fato.vw_eleitorado_perfil_local as
select *
from fato.mv_eleitorado_perfil_nivel
where nivel = 'local';

create or replace view fato.vw_eleitorado_perfil_secao as
select *
from fato.mv_eleitorado_perfil_nivel
where nivel = 'secao';

create or replace view fato.vw_eleitorado_dominante_nivel as
with classificado as (
    select
        m.*,
        (
            upper(unaccent(trim(coalesce(m.descricao, '')))) in (
                '',
                'NAO INFORMADO',
                'NAO INFORMADA',
                'NAO SE APLICA',
                'INVALIDO',
                'INVALIDA'
            )
        ) as is_descricao_nao_informativa,
        bool_or(
            upper(unaccent(trim(coalesce(m.descricao, '')))) not in (
                '',
                'NAO INFORMADO',
                'NAO INFORMADA',
                'NAO SE APLICA',
                'INVALIDO',
                'INVALIDA'
            )
        ) over (
            partition by m.eleicao_id, m.nivel, m.ra_id, m.local_id, m.secao_id, m.dimensao
        ) as possui_descricao_informativa
    from fato.mv_eleitorado_perfil_nivel m
),
ranked as (
    select
        c.*,
        row_number() over (
            partition by c.eleicao_id, c.nivel, c.ra_id, c.local_id, c.secao_id, c.dimensao
            order by
                case
                    when c.possui_descricao_informativa and c.is_descricao_nao_informativa then 1
                    else 0
                end,
                c.qt_eleitores desc,
                c.codigo
        ) as ranking_dominante
    from classificado c
)
select
    eleicao_id,
    ano,
    turno,
    cd_eleicao,
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
    dimensao,
    codigo as codigo_dominante,
    descricao as descricao_dominante,
    qt_eleitores as qt_eleitores_dominante,
    percentual as percentual_dominante,
    total_eleitores_nivel
from ranked
where ranking_dominante = 1;

analyze fato.mv_eleitorado_perfil_nivel;

reset enable_memoize;
