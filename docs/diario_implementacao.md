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
