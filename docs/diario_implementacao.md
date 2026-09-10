# Diario de implementacao

Este arquivo registra a execucao de cada etapa do planejamento.

## Etapa 0 - Preparacao do workspace

- Data: 2026-09-07
- Scripts executados: nenhum script de banco; criacao da estrutura de diretorios e arquivos base.
- Resultado: estrutura inicial criada para SQL, scripts, testes e documentacao.
- Consultas manuais: nao aplicavel nesta etapa.
- Divergencias encontradas: nenhuma.
- Decisao: avancar para a Etapa 1, conteineres e persistencia.

## Etapa 1 - Conteineres e persistencia

- Data: 2026-09-07
- Scripts executados: `docker compose config`, `docker compose up -d`, `docker compose ps`, `pg_isready`, teste SQL de persistencia, `docker compose down`, `docker compose up -d`.
- Resultado: conteiner `eleitoral_postgis` criado com imagem `postgis/postgis:16-3.5`, porta `5432`, volume nomeado `code_teste_r2_postgres_data` e montagem readonly de `fontes/`.
- Consultas manuais: criada tabela `aux_teste_persistencia`, inserido `id = 1`, confirmado o registro antes e depois do reinicio do conteiner.
- Divergencias encontradas: o Docker no Windows exigiu acesso elevado ao daemon; tambem emitiu aviso de permissao ao ler `C:\Users\mnt50\.docker\config.json`, mas os comandos executaram com sucesso.
- Decisao: Etapa 1 validada; avancar para a Etapa 2, extensoes e schemas.

## Etapa 2 - Extensoes e schemas

- Data: 2026-09-07
- Scripts executados: `docker compose config`, `docker compose up -d`, `docker compose ps`, `pg_isready`, `sql/00_extensions_schemas.sql` e `tests/sql/00_extensions_schemas_test.sql`.
- Resultado: `docker-compose.yml` atualizado para montar `./sql` em `/sql` e `./tests` em `/tests`, ambos somente leitura; extensao `unaccent` criada; extensao `postgis` confirmada; schemas `stg`, `dim`, `fato`, `geo` e `aux` criados.
- Consultas manuais: `postgis_full_version()` retornou PostGIS `3.5.2`; consulta em `information_schema.schemata` retornou `aux`, `dim`, `fato`, `geo` e `stg`; teste SQL retornou zero linhas.
- Divergencias encontradas: `postgis` ja existia no banco e foi mantida por `create extension if not exists`; Docker continuou exigindo acesso elevado ao daemon no Windows.
- Decisao: Etapa 2 validada; avancar para a Etapa 3, staging dos arquivos pequenos e medios.

## Etapa 3 - Staging dos arquivos pequenos e medios

- Data: 2026-09-07
- Scripts executados: `sql/01_staging/01_staging_small_medium.sql`, `scripts/load_staging.py` e `tests/sql/01_staging_small_medium_test.sql`.
- Resultado: criadas e carregadas nove tabelas de staging em `stg`: candidatos 2026, candidatos complementar 2026, eleitorado por local/secao 2026, quatro planilhas TRE, centroides GeoJSON e shapefile de RAs.
- Consultas manuais: teste de contagens retornou zero linhas; `stg.ra_shapefile` ficou com 37 registros, 37 geometrias preenchidas e zero geometrias invalidas; `stg.tre_secoes_2026_df` ficou com 1 linha de totais e 6.961 linhas uteis.
- Divergencias encontradas: os XLSX e o GeoJSON contem caracteres de substituicao em algumas strings acentuadas; o shapefile tambem tem inconsistencias de encoding e foi lido com `utf-8` e `encodingErrors="replace"` para preservar a carga completa. Correcao fina de nomes deve ocorrer na etapa geoespacial/dimensao RA.
- Decisao: Etapa 3 validada; avancar para a Etapa 4, staging dos arquivos grandes, mantendo `votacao_secao_2022_DF.csv` apenas como base de modelagem/piloto.

## Etapa 4 - Staging dos arquivos grandes

- Data: 2026-09-07
- Scripts executados: `sql/01_staging/02_staging_large.sql`, `scripts/load_large_staging.py` e `tests/sql/02_staging_large_test.sql`.
- Resultado: criadas as tabelas `stg.perfil_eleitor_secao_2026_df` e `stg.votacao_secao_2022_df`; carregado somente `perfil_eleitor_secao_2026_DF.csv`; a tabela de votacao foi criada, mas permaneceu vazia.
- Consultas manuais: teste de contagens retornou zero linhas; perfil carregou 1.233.369 linhas, 7.042 secoes distintas e soma de `qt_eleitores` igual a 2.253.132; `stg.votacao_secao_2022_df` retornou zero linhas.
- Divergencias encontradas: nenhuma na carga do perfil; a carga completa de `votacao_secao_2022_DF.csv` nao sera executada, ficando 2022 apenas como base de modelagem/piloto.
- Decisao: Etapa 4 validada; avancar para a Etapa 5, dimensao UF.

## Etapa 5 - Dimensao UF

- Data: 2026-09-07
- Scripts executados: `sql/02_dimensoes/01_dim_uf.sql` e `tests/sql/03_dim_uf_test.sql`.
- Resultado: tabela `dim.uf` criada e populada de forma idempotente com `DF / Distrito Federal / 53`.
- Consultas manuais: teste SQL retornou zero linhas; consulta em `dim.uf` retornou uma linha com `uf_id = 1`, `sigla = DF`, `nome = Distrito Federal`, `codigo_ibge = 53`.
- Divergencias encontradas: nenhuma.
- Decisao: Etapa 5 validada; avancar para a Etapa 6, dimensao eleicao.

## Etapa 6 - Dimensao eleicao

- Data: 2026-09-07
- Scripts executados: `sql/02_dimensoes/02_dim_eleicao.sql` e `tests/sql/04_dim_eleicao_test.sql`.
- Resultado: tabela `dim.eleicao` criada e populada de forma idempotente com a eleicao 2026 derivada de `stg.consulta_cand_2026_df`.
- Consultas manuais: teste SQL retornou zero linhas; consulta em `dim.eleicao` retornou `ano = 2026`, `turno = 1`, `cd_eleicao = 6259`, `ds_eleicao = Eleições Gerais Estaduais 2026`, `cd_tipo_eleicao = 2`, `nm_tipo_eleicao = ELEIÇÃO ORDINÁRIA`, `dt_eleicao = 2026-10-04`, `tp_abrangencia = ESTADUAL`.
- Divergencias encontradas: `stg.eleitorado_local_votacao_2026_df.ds_eleicao` traz `1º Turno`, por isso a dimensao usou `stg.consulta_cand_2026_df` como fonte principal para preservar a descricao oficial completa da eleicao.
- Decisao: Etapa 6 validada; avancar para a Etapa 7, geoespacial de RAs.

## Etapa 7 - Geoespacial de RAs

- Data: 2026-09-07
- Scripts executados: `sql/03_geoespacial/01_ra_geometria.sql` e `tests/sql/05_ra_geometria_test.sql`.
- Resultado: criadas e populadas `dim.regiao_administrativa` e `geo.ra_geometria`; 37 RAs carregadas com geometria UTM 31983 e geometria 4326.
- Consultas manuais: teste SQL retornou zero linhas; origens de centroide ficaram em 34 `geojson` e 3 `calculado_shapefile`; centroides calculados para `RA-XXIII / VARJÃO`, `RA-XXXVI / 26 DE SETEMBRO` e `XXXVII / PONTE ALTA`.
- Divergencias encontradas: o centroide do GeoJSON para `RA-XXIII / VARJÃO` ficou fora do poligono; a regra foi ajustada para usar ponto do GeoJSON somente quando `st_covers(geom, centroid_geom)` for verdadeiro, calculando `st_pointonsurface` nos demais casos.
- Decisao: Etapa 7 validada; avancar para a Etapa 8, dimensoes eleitorais basicas.

## Etapa 8 - Dimensoes eleitorais basicas

- Data: 2026-09-07
- Scripts executados: `sql/02_dimensoes/03_dimensoes_eleitorais_basicas.sql` e `tests/sql/06_dimensoes_eleitorais_basicas_test.sql`.
- Resultado: criadas e populadas `dim.zona_eleitoral`, `dim.cargo_eleitoral`, `dim.partido_politico`, `dim.federacao` e `dim.coligacao`.
- Consultas manuais: teste SQL retornou zero linhas; foram carregadas 19 zonas, 7 cargos, 29 partidos, 5 federacoes reais e 62 coligacoes.
- Divergencias encontradas: `NR_FEDERACAO = -1 / #NULO` aparece na staging, mas foi excluido de `dim.federacao` por representar ausencia de federacao, nao uma federacao real.
- Decisao: Etapa 8 validada; avancar para a Etapa 9, dimensao local de votacao.

## Etapa 9 - Dimensao local de votacao

- Data: 2026-09-08
- Scripts executados: `sql/02_dimensoes/04_dim_local_votacao.sql` e `tests/sql/07_dim_local_votacao_test.sql`.
- Resultado: criada e populada `dim.local_votacao`; criadas tambem `aux.qualidade_dado` e `aux.local_votacao_alias` para registrar pendencias e nomes/enderecos vindos das fontes.
- Consultas manuais: teste SQL retornou zero linhas; `dim.local_votacao` ficou com 622 pares `zona + local`, sendo 614 principais confirmados pela planilha oficial do TRE e 8 adicionais preservados com `is_principal = false` para checagem futura. Ha 108 numeros de local distintos, 3 locais sem geometria por coordenada sentinela `-1/-1` e 0 locais com geometria valida sem RA. A tabela `aux.qualidade_dado` registrou 8 pares presentes no CSV oficial e ausentes na planilha TRE, 3 locais sem coordenada valida e 90 numeros de local reutilizados em mais de uma zona.
- Divergencias encontradas: a premissa inicial de chave natural `eleicao_id + uf_id + nr_local_votacao` nao representa local fisico de votacao no DF, porque o mesmo `NR_LOCAL_VOTACAO` aparece em zonas distintas com nomes, enderecos e coordenadas diferentes. A chave natural foi ajustada para `eleicao_id + uf_id + nr_zona + nr_local_votacao`.
- Decisao: Etapa 9 validada; avancar para a Etapa 10, dimensao secao eleitoral, usando `zona + local` para relacionar secoes aos locais fisicos.

## Etapa 10 - Dimensao secao eleitoral

- Data: 2026-09-08
- Scripts executados: `sql/02_dimensoes/05_dim_secao_eleitoral.sql` e `tests/sql/08_dim_secao_eleitoral_test.sql`.
- Resultado: criada e populada `dim.secao_eleitoral` com 7.050 secoes do CSV oficial, preservando 6.961 secoes principais oficiais do TRE, 81 secoes agregadas e 8 secoes adicionais para checagem futura.
- Consultas manuais: teste SQL retornou zero linhas; a planilha TRE tem 6.961 linhas oficiais, das quais 78 trazem secoes agregadas entre parenteses. Ao expandir os parenteses, a planilha representa 7.042 secoes, exatamente o conjunto de secoes existente no perfil do eleitorado. As 8 secoes restantes existem apenas no CSV `eleitorado_local_votacao_2026_DF.csv`.
- Divergencias encontradas: 81 secoes do CSV possuem `DS_TIPO_SECAO_AGREGADA = Agregada`; todas apontam para uma secao principal existente e todas usam o local da secao principal. Foram registradas 106 divergencias de aptos entre a planilha TRE e a soma do CSV para secao principal mais agregadas.
- Decisao: Etapa 10 validada; avancar para a Etapa 11, dimensao candidato.

## Etapa 11 - Dimensao candidato

- Data: 2026-09-08
- Scripts executados: `sql/02_dimensoes/06_dim_candidato.sql` e `tests/sql/09_dim_candidato_test.sql`.
- Resultado: criada e populada `dim.candidato` com 661 candidatos de 2026, unindo `consulta_cand_2026_DF.csv` e `consulta_cand_complementar_2026_DF.csv` por `SQ_CANDIDATO`.
- Consultas manuais: teste SQL retornou zero linhas; foram carregados 431 candidatos a deputado distrital, 168 a deputado federal, 14 segundos suplentes, 13 primeiros suplentes, 13 senadores, 11 governadores e 11 vice-governadores. Todos os candidatos possuem cargo, partido, coligacao e hash de CPF; 184 possuem federacao real, 2 sao quilombolas e 458 declararam bens.
- Divergencias encontradas: nenhuma nas chaves de integridade da etapa; `st_reeleicao = #NE` foi convertido para `null` por nao expressar booleano.
- Decisao: Etapa 11 validada; avancar para a Etapa 12, perfil do eleitor e fato de eleitorado por perfil/secao.

## Etapa 12 - Perfil do eleitor e fato eleitorado por perfil/secao

- Data: 2026-09-08
- Scripts executados: `sql/02_dimensoes/07_dim_perfil_eleitor.sql`, `sql/04_fatos/01_fato_eleitorado_perfil_secao.sql` e `tests/sql/10_perfil_eleitor_test.sql`.
- Resultado: criada e populada `dim.perfil_eleitor` com 8.468 combinacoes demograficas; criada e populada `fato.eleitorado_perfil_secao` com 1.219.951 linhas analiticas agregadas por secao/perfil.
- Consultas manuais: teste SQL retornou zero linhas; a fato preserva 1.233.369 linhas de origem em `source_row_count`, cobre 7.042 secoes, soma 2.253.132 eleitores, 2.126.894 eleitores com biometria, 24.832 com deficiencia e 723 com nome social.
- Divergencias encontradas: a fonte possui 13.418 linhas excedentes quando agregada por `secao + perfil`; a fato consolida essas duplicidades somando medidas e preservando a contagem de linhas brutas em `source_row_count`. Nao houve perfil sem secao nem divergencia entre soma de perfil e `QT_ELEITOR_SECAO`.
- Decisao: Etapa 12 validada; avancar para a Etapa 13, estrutura de votacao de 2022 sem carga completa.

## Etapa 13 - Estrutura de votacao de 2022

- Data: 2026-09-08
- Scripts executados: `sql/04_fatos/02_estrutura_votacao_2022.sql` e `tests/sql/11_estrutura_votacao_2022_test.sql`.
- Resultado: criadas as estruturas `dim.votavel`, `fato.votacao_candidato_secao`, `fato.apuracao_secao` e `fato.vw_votacao_drilldown`.
- Consultas manuais: teste SQL retornou zero linhas; `stg.votacao_secao_2022_df`, `dim.votavel`, `fato.votacao_candidato_secao`, `fato.apuracao_secao` e `fato.vw_votacao_drilldown` ficaram com zero linhas, conforme escopo da etapa.
- Divergencias encontradas: nenhuma; a carga completa de `votacao_secao_2022_DF.csv` nao foi executada e nao ocorrera no plano atual.
- Decisao: Etapa 13 validada; avancar para a Etapa 14, carga piloto de votacao, somente com subconjunto controlado.

## Etapa 14 - Carga piloto de votacao 2022

- Data: 2026-09-08
- Scripts executados: `scripts/load_votacao_piloto.py`, `sql/04_fatos/03_carga_piloto_votacao_2022.sql` e `tests/sql/12_carga_piloto_votacao_2022_test.sql`.
- Resultado: carregada amostra deterministica da ZE 20 em `stg.votacao_secao_2022_df` com 44.464 linhas; populadas a eleicao 2022, 18 locais, 219 secoes, 838 votaveis, 44.464 linhas em `fato.votacao_candidato_secao` e 876 linhas em `fato.apuracao_secao`.
- Consultas manuais: teste SQL da Etapa 14 retornou zero linhas; suite SQL completa das Etapas 2 a 14 retornou zero divergencias. A classificacao de votaveis ficou com 39.844 linhas nominais, 2.869 de legenda, 876 brancos e 875 nulos.
- Divergencias encontradas: nenhuma na carga piloto; a carga completa de `votacao_secao_2022_DF.csv` nao ocorrera. A estrutura validada com 2022 sera reaproveitada para a carga completa futura dos dados de votacao 2026.
- Decisao: Etapa 14 validada; carga completa futura sera de votacao 2026, quando a fonte estiver disponivel na mesma estrutura. Proximo desenvolvimento imediato: views/indices e consultas sobre a amostra piloto 2022 e fatos de eleitorado 2026.

## Etapa 15 - Recorte PMB

- Data: 2026-09-09
- Scripts executados: `scripts/build_pmb_eleitorado_json.py`; validacoes locais com `python -m json.tool`, `python -m py_compile` e somas por municipio/perfil.
- Resultado: `fontes/eleitorado_PMB_2026.json` foi regenerado com estrutura `pmb.municipios`, preservando `municipio_codigo` como codigo TSE, adicionando `municipio_codigo_tse`, `municipio_codigo_ibge`, fonte de populacao IBGE/SIDRA e perfis agregados por municipio a partir de `perfil_eleitor_secao_2026_GO.csv`.
- Consultas manuais: validado total de 12 municipios, 759.538 eleitores, soma municipal de 759.538 e populacao IBGE/SIDRA 2025 de 1.362.821.
- Divergencias encontradas: `fontes/` e ignorado pelo Git; o JSON gerado nao aparece em `git status`. O PDF de dicionario GO nao foi extraido localmente por falta de biblioteca/ferramenta PDF, mas o CSV tem a mesma estrutura operacional do staging de perfil ja modelado.
- Decisao: PMB deve ser recorte de municipios goianos, nao RA. Foram criados `dim.municipio`, `dim.recorte_geografico`, `dim.recorte_municipio` e `fato.eleitorado_perfil_municipio`. Carga no Postgres e testes SQL ficaram como proximo passo.

## Etapa 16 - Sociodemografia por RA

- Data: 2026-09-09
- Scripts executados: `scripts/build_ra_sociodemografia_json.py`; validacoes locais com `python -m json.tool`, `python -m py_compile` e checagens de fechamento.
- Resultado: criado `fontes/perfil_sociodemografico_ra_df_2025_estruturado.json` com 37 RAs e apenas indicadores sociodemograficos: populacao/raca-cor, religiao, renda, animais de estimacao e perfil resumido. Campos eleitorais do arquivo original foram removidos do estruturado porque o banco ja totaliza eleitorado pela modelagem existente.
- Consultas manuais: validado que nenhuma RA do JSON estruturado contem `totais` ou `perfil`; populacao das 37 RAs fecha no total oficial de 2.982.816.
- Divergencias encontradas: o arquivo original traz 35 registros de RA somando 2.861.057, mas o cadastro oficial considerado no projeto tem 37 RAs e o proprio arquivo informa total oficial global de 2.982.816. A decisao revisada foi usar 2.982.816 como total oficial e ratear a diferenca proporcionalmente nas RAs sem populacao fixada por desdobramento.
- Decisao: `26 DE SETEMBRO` herdou perfil proporcional de `VICENTE PIRES` com populacao 29.394; `PONTE ALTA` herdou perfil proporcional de `GAMA` com populacao 45.452. `VICENTE PIRES` foi ajustada para 75.668 e `GAMA` para 88.496. A diferenca remanescente foi rateada nas outras 33 RAs para fechar o total oficial. Foram criadas `dim.indicador_sociodemografico`, `fato.sociodemografia_ra` e `fato.sociodemografia_ra_resumo`. Carga no Postgres e testes SQL ficaram como proximo passo.

## Encerramento da sessao - PMB e sociodemografia

- Data: 2026-09-09
- Scripts executados: `python scripts\build_ra_sociodemografia_json.py`, `python -m py_compile scripts\build_ra_sociodemografia_json.py` e checagem local com `python -X utf8`.
- Resultado: documentacao de retomada atualizada em `docs/resumo_contexto_proxima_sessao.md`; planejamento, diario e validacoes manuais alinhados com a regra oficial de 37 RAs.
- Consultas manuais: validado localmente que o JSON estruturado tem 37 RAs, total global 2.982.816, soma das RAs 2.982.816, `adjusted_count = 33` e populacoes fixas `GAMA = 88496`, `VICENTE PIRES = 75668`, `26 DE SETEMBRO = 29394`, `PONTE ALTA = 45452`.
- Divergencias encontradas: nenhuma nova; permanece documentado que o arquivo original tinha 35 registros de RA, mas o projeto considera 37 RAs oficiais.
- Decisao: encerrar a sessao com Etapas 15 e 16 implementadas em arquivos e validadas localmente; na proxima sessao, executar carga no PostgreSQL, criar testes SQL especificos e validar `aux.qualidade_dado`.

## Testes de carga no conteiner - PMB e sociodemografia

- Data: 2026-09-09
- Scripts executados: `docker compose up -d`, `pg_isready`, DDLs de staging, `scripts/load_staging.py`, `scripts/load_large_staging.py --include-pmb-go`, `sql/02_dimensoes/01_dim_uf.sql`, `sql/02_dimensoes/07_dim_perfil_eleitor.sql`, `sql/02_dimensoes/08_dim_municipio_recorte_pmb.sql`, `sql/04_fatos/04_fato_eleitorado_perfil_municipio_pmb.sql`, `sql/04_fatos/05_fato_sociodemografia_ra.sql`, `scripts/load_votacao_piloto.py`, `sql/04_fatos/03_carga_piloto_votacao_2022.sql` e suite `tests/sql/*.sql`.
- Resultado: cargas PMB e sociodemografia executadas no PostgreSQL; suite SQL `00` a `14` retornou zero divergencias.
- Consultas manuais: PMB ficou com 12 municipios, recorte `PMB` com 12 municipios, `fato.eleitorado_perfil_municipio` com 34.927 linhas e 759.538 eleitores. Sociodemografia ficou com 37 RAs, 592 indicadores, 37 resumos e populacoes fixas conferidas.
- Divergencias encontradas: a primeira execucao da fato PMB falhou porque o CTE de qualidade agrupava pelo alias `perfil_hash`; corrigido para agrupar explicitamente pelos campos de perfil. A primeira carga de sociodemografia casou apenas 26 RAs por acentuacao corrompida nos nomes; corrigido para priorizar `ra_codigo` e usar nome normalizado como fallback. `load_large_staging.py --include-pmb-go` truncava a staging de votacao quando `--include-votacao` nao era informado; corrigido para nao tocar em `stg.votacao_secao_2022_df` sem autorizacao explicita.
- Decisao: Etapas 15 e 16 passam a estar validadas no banco. Foram criados `tests/sql/13_pmb_test.sql` e `tests/sql/14_sociodemografia_ra_test.sql`; `tests/sql/10_perfil_eleitor_test.sql` foi atualizado para `dim.perfil_eleitor = 13628` apos incorporar GO.

## Planejamento da Etapa 18 - Views, materializacoes e indices

- Data: 2026-09-09
- Scripts executados: leitura da especificacao `fontes/especificacao-tecnica-painel-eleitoral.md`, inventario de tabelas/views/indices no PostgreSQL e suite `tests/sql/*.sql`.
- Resultado: criado `docs/views_materializacoes_indices.md` com contratos de consumo para resultados eleitorais, eleitorado DF, sociodemografia por RA e PMB; tambem foram documentadas materialized views, views simples, indices recomendados, ordem de implementacao e testes minimos.
- Consultas manuais: `pg_isready` retornou banco disponivel; suite SQL `00` a `14` retornou zero divergencias; inventario confirmou `fato.vw_votacao_drilldown` como unica view atual e fatos principais com `1.219.951` linhas de eleitorado por secao, `34.927` de eleitorado PMB, `592` indicadores sociodemograficos e `44.464` linhas da votacao piloto.
- Divergencias encontradas: a especificacao do painel e baseada em 35 RAs e JSONs estaticos legados; a documentacao da Etapa 18 foi ajustada para 37 RAs oficiais, PMB como recorte de municipios e votacao 2022 apenas como piloto tecnico.
- Decisao: implementar a Etapa 18 em arquivos `sql/05_views/`, comecando por indices de consulta e materializacoes de votacao/eleitorado, e criar `tests/sql/15_views_indices_test.sql`.

## Expansoes futuras de views/materializacoes

- Data: 2026-09-09
- Scripts executados: inventario da estrutura do projeto, fontes disponiveis, contagens reais no PostgreSQL e revisao de `docs/views_materializacoes_indices.md`.
- Resultado: `docs/views_materializacoes_indices.md` foi ampliado com inventario estrutural, propostas alem da especificacao original e indices futuros.
- Consultas manuais: confirmados 37 RAs, 640 locais totais, 7.269 secoes totais, 13.628 perfis, 1.219.951 linhas de eleitorado DF, 34.927 linhas de eleitorado PMB, 592 indicadores sociodemograficos e 44.464 linhas da votacao piloto.
- Divergencias encontradas: consultas globais de locais/secoes misturam 2026 DF com piloto 2022 se nao filtrarem `eleicao_id`; soma de populacao PMB duplica quando `dim.municipio` e juntada diretamente a fato de perfil sem pre-agregacao; `pg_stat_user_tables` pode exibir estimativas zeradas antes de `analyze`.
- Decisao: propor views de catalogo/cobertura, territorio unificado, recortes expandidos, vizinhanca espacial, segmentacao DF/PMB, percentis sociodemograficos, resultado por partido/coligacao, comparativos historicos, candidato enriquecido, busca global, payload JSON opcional e views operacionais de tamanho/uso de indices.

## Consistencia TRE/TSE e encerramento da sessao

- Data: 2026-09-09
- Scripts executados: consultas diretas nas tabelas `stg.tre_locais_2026_df`, `stg.tre_secoes_2026_df`, `stg.eleitorado_local_votacao_2026_df`, `dim.local_votacao`, `dim.secao_eleitoral` e `aux.qualidade_dado`; suite `tests/sql/*.sql`.
- Resultado: atualizado `docs/resumo_contexto_proxima_sessao.md` com contexto denso para retomada, comandos de reinicio de conteineres, estado da arquitetura, contagens validadas, lacunas e proximos passos exatos.
- Consultas manuais: `Locais_TRE_DF_2026.xlsx` fecha em 614 locais oficiais, 6.961 secoes, 2.253.238 aptos, 308.799 nao aptos e 2.562.037 eleitores totais; CSV TSE fecha em 622 pares `zona + local`, 7.050 secoes e 2.253.132 aptos; `dim.local_votacao` tem 640 locais no total por incluir 18 locais do piloto 2022; `dim.secao_eleitoral` tem 7.269 secoes no total por incluir 219 secoes do piloto 2022.
- Divergencias encontradas: o numero `641` nao fecha como total de locais nas bases carregadas; aparece como numero de secao em registros de fonte. A diferenca de 106 aptos entre TRE e CSV/perfil segue documentada em `aux.qualidade_dado` como `divergencia_aptos_tre_csv`.
- Decisao: usar como referencia oficial TRE 2026 `614 locais`, `6.961 secoes`, `2.253.238 aptos`, `308.799 nao aptos` e `2.562.037 total`; usar `622` como cobertura ampliada do CSV TSE 2026; filtrar sempre por `eleicao_id`/ano ao contar locais e secoes.

## Etapa 18.1 - Indices de consulta

- Data: 2026-09-09
- Scripts executados: `sql/05_views/01_indices_consulta.sql`, `tests/sql/15_views_indices_test.sql` e suite completa `tests/sql/*.sql`.
- Resultado: criada a extensao `pg_trgm` e aplicados indices de consulta para votacao, eleitorado DF, sociodemografia por RA, geografia, PMB, candidaturas, busca textual e staging grande. O script tambem executa `analyze` nas tabelas fato/dim mais consultadas.
- Consultas manuais: `tests/sql/15_views_indices_test.sql` validou `pg_trgm` e os 30 indices esperados com zero divergencias. A suite SQL `00` a `15` retornou zero divergencias.
- Divergencias encontradas: nenhuma.
- Decisao: Etapa 18.1 concluida. Proximo passo operacional: implementar `sql/05_views/02_votacao_materializacoes.sql` e testes de agregacao de votacao.

## Etapa 18.2 - Materializacoes de votacao

- Data: 2026-09-09
- Scripts executados: `sql/05_views/02_votacao_materializacoes.sql`, `tests/sql/16_votacao_materializacoes_test.sql` e suite completa `tests/sql/*.sql`.
- Resultado: criadas `fato.mv_votacao_nivel` e, posteriormente, ajustada a materializacao derivada para `fato.mv_votacao_top5`. A primeira agrega votos por `geral`, `ra`, `local` e `secao` em formato longo por votavel; a segunda expoe os 5 primeiros colocados por nivel/territorio.
- Consultas manuais: `fato.mv_votacao_nivel` ficou com 55.219 linhas e preservou 261.004 votos em cada nivel do piloto 2022; `fato.mv_votacao_top5` ficou com 4.779 linhas, sendo 20 gerais, 20 por RA nula do piloto, 360 por local e 4.379 por secao. Validacao especifica retornou zero divergencias; suite SQL `00` a `16` retornou zero divergencias.
- Divergencias encontradas: nenhuma. A agregacao por RA do piloto 2022 fica em `ra_id` nulo, comportamento esperado porque a fonte piloto nao contem georreferenciamento/RA.
- Decisao: Etapa 18.2 concluida. O contrato SQL deve manter apenas `TOP 5`; comparacoes de primeiro/segundo, margem e apresentacao `TOP 2` ficam a cargo do front-end. Proximo passo operacional: implementar `sql/05_views/03_votacao_views.sql` com views de resultado, top5, ranking/Pareto e consultas auxiliares de painel.

## Etapa 18.3 - Views de votacao

- Data: 2026-09-09
- Scripts executados: `sql/05_views/03_votacao_views.sql`, `tests/sql/17_votacao_views_test.sql` e suite completa `tests/sql/*.sql`.
- Resultado: criadas `fato.vw_votacao_resultado_nivel`, `fato.vw_votacao_top5`, `fato.vw_votacao_rank_pareto`, `fato.vw_vitorias_zeros_votavel`, `fato.vw_votacao_heatmap_top5` e `fato.vw_votacao_stacked_ra_top5`.
- Consultas manuais: views retornaram 55.219 linhas em resultado por nivel, 4.779 em top5, 53.308 em ranking/Pareto, 53.308 em vitorias/zeros e 20 linhas nos top5 por RA. Validacao especifica retornou zero divergencias; suite SQL `00` a `17` retornou zero divergencias.
- Divergencias encontradas: nenhuma. As views de Pareto e vitorias/zeros consideram apenas votos nominais e de legenda; brancos e nulos permanecem disponiveis em `vw_votacao_resultado_nivel`.
- Decisao: Etapa 18.3 concluida. Proximo passo operacional: implementar `sql/05_views/04_eleitorado_views.sql` com agregacoes de perfil do eleitorado DF por RA, local e secao.

## Etapa 18.4 - Views de eleitorado DF

- Data: 2026-09-09
- Scripts executados: `sql/05_views/04_eleitorado_views.sql`, `tests/sql/18_eleitorado_views_test.sql` e suite completa `tests/sql/*.sql`.
- Resultado: criada `fato.mv_eleitorado_perfil_nivel` em formato longo por `ra`, `local`, `secao` e dimensao demografica; criadas `fato.vw_eleitorado_perfil_ra`, `fato.vw_eleitorado_perfil_local`, `fato.vw_eleitorado_perfil_secao` e `fato.vw_eleitorado_dominante_nivel`.
- Consultas manuais: materializacao ficou com 346.143 linhas; views por nivel ficaram com 1.951 linhas em RA, 31.168 em local e 313.024 em secao; dominantes ficaram com 61.544 linhas. A soma da dimensao `genero` fecha 2.253.132 eleitores nos tres niveis. Validacao especifica retornou zero divergencias; suite SQL `00` a `18` retornou zero divergencias.
- Divergencias encontradas: a primeira execucao encontrou erro interno do planner PostgreSQL `could not find memoization table entry`; o script foi ajustado para `set enable_memoize = off` somente durante a criacao da materializacao. No nivel RA, a fonte de perfil possui 36 RAs identificadas e 603 eleitores em RA nula; a RA oficial sem eleitorado perfil associado e `26 DE SETEMBRO`.
- Decisao: Etapa 18.4 concluida. Proximo passo operacional: implementar `sql/05_views/05_sociodemografia_views.sql` com pivot de indicadores e RA analitica.

## Ajuste de contrato - TOP 5 em votacao

- Data: 2026-09-10
- Scripts executados: `sql/05_views/02_votacao_materializacoes.sql`, `sql/05_views/03_votacao_views.sql`, `tests/sql/16_votacao_materializacoes_test.sql`, `tests/sql/17_votacao_views_test.sql` e suite completa `tests/sql/*.sql`.
- Resultado: removido o contrato SQL de `TOP 2`/margem e substituido por `fato.mv_votacao_top5` e `fato.vw_votacao_top5`. Os scripts ainda removem objetos antigos `top2` quando existirem, para manter reprocessamento idempotente.
- Consultas manuais: `fato.mv_votacao_top5` ficou com 4.779 linhas no piloto 2022: 20 em `geral`, 20 em `ra`, 360 em `local` e 4.379 em `secao`; ranking maximo 5 em todos os niveis. Suite SQL `00` a `18` retornou zero divergencias.
- Divergencias encontradas: nenhuma apos ajuste. Os testes 16 e 17 validam explicitamente que nao existem materialized views, views ou indices `top2` no schema `fato`.
- Decisao: manter apenas `TOP 5` em views, materializacoes e indices de consulta. Visualizacoes `TOP 2`, margem, lider/segundo e competitividade serao calculadas no front-end a partir de `ranking_top5`.

## Encerramento da sessao - Etapa 18 parcial

- Data: 2026-09-10
- Scripts executados: atualizacao documental de `docs/resumo_contexto_proxima_sessao.md`, `docs/planejamento_implementacao_banco_eleitoral.md`, `docs/diario_implementacao.md` e `docs/validacoes_manuais.md`; suite SQL `tests/sql/00` a `18` executada antes do encerramento.
- Resultado: resumo de retomada recriado com arquitetura, estado atual, comandos de reinicio dos conteineres, reprocessamento completo ate `sql/05_views/04_eleitorado_views.sql` e proximos passos exatos.
- Consultas manuais: suite SQL `00` a `18` retornou zero divergencias; banco possui `fato.mv_votacao_top5` e `fato.vw_votacao_top5`; nao existem objetos ou indices `top2` no schema `fato`.
- Divergencias encontradas: nenhuma nova.
- Decisao: proxima sessao deve iniciar por `sql/05_views/05_sociodemografia_views.sql` e `tests/sql/19_sociodemografia_views_test.sql`, mantendo a regra oficial de 37 RAs e o contrato SQL apenas `TOP 5`.

## Modelo de registro para proximas etapas

```md
## Etapa X - Nome

- Data:
- Scripts executados:
- Resultado:
- Consultas manuais:
- Divergencias encontradas:
- Decisao:
```
