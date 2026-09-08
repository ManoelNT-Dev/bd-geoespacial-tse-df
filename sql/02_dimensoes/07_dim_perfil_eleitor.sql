create table if not exists dim.perfil_eleitor (
    perfil_id bigint generated always as identity primary key,
    perfil_hash text not null unique,
    cd_genero integer not null,
    ds_genero text not null,
    cd_estado_civil integer not null,
    ds_estado_civil text not null,
    cd_faixa_etaria integer not null,
    ds_faixa_etaria text not null,
    cd_grau_escolaridade integer not null,
    ds_grau_escolaridade text not null,
    cd_raca_cor integer not null,
    ds_raca_cor text not null,
    cd_identidade_genero integer not null,
    ds_identidade_genero text not null,
    cd_quilombola integer not null,
    ds_quilombola text not null,
    cd_interprete_libras integer not null,
    ds_interprete_libras text not null
);

create index if not exists perfil_eleitor_genero_idx on dim.perfil_eleitor (cd_genero);
create index if not exists perfil_eleitor_faixa_etaria_idx on dim.perfil_eleitor (cd_faixa_etaria);
create index if not exists perfil_eleitor_escolaridade_idx on dim.perfil_eleitor (cd_grau_escolaridade);
create index if not exists perfil_eleitor_raca_cor_idx on dim.perfil_eleitor (cd_raca_cor);

with source_perfil as (
    select distinct
        md5(concat_ws(
            '|',
            cd_genero,
            cd_estado_civil,
            cd_faixa_etaria,
            cd_grau_escolaridade,
            cd_raca_cor,
            cd_identidade_genero,
            cd_quilombola,
            cd_interprete_libras
        )) as perfil_hash,
        cd_genero::integer as cd_genero,
        ds_genero,
        cd_estado_civil::integer as cd_estado_civil,
        ds_estado_civil,
        cd_faixa_etaria::integer as cd_faixa_etaria,
        ds_faixa_etaria,
        cd_grau_escolaridade::integer as cd_grau_escolaridade,
        ds_grau_escolaridade,
        cd_raca_cor::integer as cd_raca_cor,
        ds_raca_cor,
        cd_identidade_genero::integer as cd_identidade_genero,
        ds_identidade_genero,
        cd_quilombola::integer as cd_quilombola,
        ds_quilombola,
        cd_interprete_libras::integer as cd_interprete_libras,
        ds_interprete_libras
    from stg.perfil_eleitor_secao_2026_df
)
insert into dim.perfil_eleitor (
    perfil_hash,
    cd_genero,
    ds_genero,
    cd_estado_civil,
    ds_estado_civil,
    cd_faixa_etaria,
    ds_faixa_etaria,
    cd_grau_escolaridade,
    ds_grau_escolaridade,
    cd_raca_cor,
    ds_raca_cor,
    cd_identidade_genero,
    ds_identidade_genero,
    cd_quilombola,
    ds_quilombola,
    cd_interprete_libras,
    ds_interprete_libras
)
select
    perfil_hash,
    cd_genero,
    ds_genero,
    cd_estado_civil,
    ds_estado_civil,
    cd_faixa_etaria,
    ds_faixa_etaria,
    cd_grau_escolaridade,
    ds_grau_escolaridade,
    cd_raca_cor,
    ds_raca_cor,
    cd_identidade_genero,
    ds_identidade_genero,
    cd_quilombola,
    ds_quilombola,
    cd_interprete_libras,
    ds_interprete_libras
from source_perfil
on conflict (perfil_hash) do update
set cd_genero = excluded.cd_genero,
    ds_genero = excluded.ds_genero,
    cd_estado_civil = excluded.cd_estado_civil,
    ds_estado_civil = excluded.ds_estado_civil,
    cd_faixa_etaria = excluded.cd_faixa_etaria,
    ds_faixa_etaria = excluded.ds_faixa_etaria,
    cd_grau_escolaridade = excluded.cd_grau_escolaridade,
    ds_grau_escolaridade = excluded.ds_grau_escolaridade,
    cd_raca_cor = excluded.cd_raca_cor,
    ds_raca_cor = excluded.ds_raca_cor,
    cd_identidade_genero = excluded.cd_identidade_genero,
    ds_identidade_genero = excluded.ds_identidade_genero,
    cd_quilombola = excluded.cd_quilombola,
    ds_quilombola = excluded.ds_quilombola,
    cd_interprete_libras = excluded.cd_interprete_libras,
    ds_interprete_libras = excluded.ds_interprete_libras;
