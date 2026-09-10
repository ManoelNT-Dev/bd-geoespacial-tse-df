create extension if not exists pg_trgm;

-- Votacao: filtros principais de painel por eleicao, cargo, territorio e votavel.
create index if not exists votacao_eleicao_cargo_votavel_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, votavel_id);

create index if not exists votacao_eleicao_cargo_ra_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, ra_id);

create index if not exists votacao_eleicao_cargo_local_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, local_id);

create index if not exists votacao_eleicao_cargo_secao_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, secao_id);

create index if not exists votacao_eleicao_cargo_tipo_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, tipo_votavel);

create index if not exists votacao_eleicao_cargo_nr_votavel_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, nr_votavel);

create index if not exists votacao_eleicao_cargo_partido_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, partido_id);

create index if not exists votacao_eleicao_cargo_candidato_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, candidato_id);

create index if not exists votacao_eleicao_cargo_zona_idx
on fato.votacao_candidato_secao (eleicao_id, cargo_id, nr_zona);

create index if not exists votavel_eleicao_cargo_nr_votavel_idx
on dim.votavel (eleicao_id, cargo_id, nr_votavel);

-- Eleitorado DF: agregacoes por RA, local, secao e perfil.
create index if not exists eleitorado_perfil_eleicao_ra_idx
on fato.eleitorado_perfil_secao (eleicao_id, ra_id);

create index if not exists eleitorado_perfil_eleicao_local_idx
on fato.eleitorado_perfil_secao (eleicao_id, local_id);

create index if not exists eleitorado_perfil_eleicao_secao_idx
on fato.eleitorado_perfil_secao (eleicao_id, secao_id);

create index if not exists eleitorado_perfil_eleicao_perfil_idx
on fato.eleitorado_perfil_secao (eleicao_id, perfil_id);

-- Sociodemografia: filtros por ano, indicador e catalogo.
create index if not exists sociodemografia_ra_ano_indicador_idx
on fato.sociodemografia_ra (ano_referencia, indicador_id);

create index if not exists indicador_sociodemografico_grupo_idx
on dim.indicador_sociodemografico (grupo, subgrupo, metrica);

-- Geografia: filtros comuns de mapa e drill-down.
create index if not exists local_votacao_eleicao_ra_idx
on dim.local_votacao (eleicao_id, ra_id, nr_zona, nr_local_votacao);

create index if not exists secao_eleitoral_eleicao_local_idx
on dim.secao_eleitoral (eleicao_id, local_id, nr_zona, nr_secao);

create index if not exists secao_eleitoral_eleicao_ra_idx
on dim.secao_eleitoral (eleicao_id, ra_id, nr_zona, nr_secao);

-- PMB: consultas por recorte e municipio.
create index if not exists eleitorado_perfil_municipio_eleicao_recorte_idx
on fato.eleitorado_perfil_municipio (eleicao_id, recorte_id);

create index if not exists eleitorado_perfil_municipio_eleicao_municipio_idx
on fato.eleitorado_perfil_municipio (eleicao_id, municipio_id);

-- Candidaturas: filtros por partido, cargo e numero de urna.
create index if not exists candidato_eleicao_cargo_partido_idx
on dim.candidato (eleicao_id, cargo_id, partido_id);

create index if not exists candidato_eleicao_nr_candidato_idx
on dim.candidato (eleicao_id, nr_candidato);

-- Busca textual para API/admin. Manter colunas normalizadas como alvo principal.
create index if not exists ra_nome_normalizado_trgm_idx
on dim.regiao_administrativa using gin (ra_nome_normalizado gin_trgm_ops);

create index if not exists local_votacao_nome_normalizado_trgm_idx
on dim.local_votacao using gin (nome_normalizado gin_trgm_ops);

create index if not exists municipio_nome_normalizado_trgm_idx
on dim.municipio using gin (municipio_nome_normalizado gin_trgm_ops);

create index if not exists candidato_nm_urna_trgm_idx
on dim.candidato using gin (nm_urna_candidato gin_trgm_ops);

-- Staging grande: acelerar auditoria e reprocessamento. Criar apos carga.
create index if not exists stg_perfil_df_zona_secao_idx
on stg.perfil_eleitor_secao_2026_df (sg_uf, nr_zona, nr_secao);

create index if not exists stg_perfil_go_municipio_zona_secao_idx
on stg.perfil_eleitor_secao_2026_go (cd_municipio, nr_zona, nr_secao);

create index if not exists stg_votacao_2022_zona_secao_cargo_idx
on stg.votacao_secao_2022_df (nr_zona, nr_secao, cd_cargo);

analyze fato.votacao_candidato_secao;
analyze fato.eleitorado_perfil_secao;
analyze fato.eleitorado_perfil_municipio;
analyze fato.sociodemografia_ra;
analyze dim.local_votacao;
analyze dim.secao_eleitoral;
analyze dim.candidato;
analyze dim.votavel;
