# Resumo de contexto para proxima sessao

Data de encerramento: 2026-09-07

## Objetivo do projeto

Implementar um banco de dados relacional e geoespacial em PostgreSQL/PostGIS para servir como fonte de dados de um futuro sistema de inteligencia eleitoral. O banco deve permitir consultas, filtros, comparativos e cruzamentos de votacao e eleitorado por UF, regiao administrativa, local de votacao, zona eleitoral e secao eleitoral.

## Fontes de dados

Diretorio de fontes: `fontes/`

Arquivos analisados:

- `consulta_cand_2026_DF.csv`
- `consulta_cand_complementar_2026_DF.csv`
- `eleitorado_local_votacao_2026_DF.csv`
- `perfil_eleitor_secao_2026_DF.csv`
- `votacao_secao_2022_DF.csv`
- planilhas TRE de locais e secoes em `.xlsx`
- `geo_ra_centroid_atualizado.json`
- shapefile `fontes/shapefile_ras/regioes_administrativas.*`
- PDFs de dicionario de dados associados

Pontos relevantes ja identificados:

- CSVs principais usam `;` e encoding Latin-1.
- Shapefile de RAs possui 37 poligonos em SIRGAS 2000 / UTM Zone 23S.
- GeoJSON de centroides possui 35 centroides em EPSG:4326.
- Faltam centroides no GeoJSON para `RA-XXXVI / 26 DE SETEMBRO` e `XXXVII / PONTE ALTA`; esses devem ser calculados a partir dos poligonos do shapefile usando `st_pointonsurface`.
- `votacao_secao_2022_DF.csv` possui 1.238.611 linhas e 26 colunas.
- A votacao de 2022 permite granularidade `UF -> RA -> Local -> Secao -> Cargo -> Votavel`.
- Na votacao, `SQ_CANDIDATO = -1` representa branco/nulo e `SQ_CANDIDATO = -3` representa voto de legenda.

## Documentos criados

- `docs/modelagem_banco_eleitoral_postgis.md`
  - Modelagem relacional e geoespacial.
  - Schemas previstos: `stg`, `dim`, `fato`, `geo`, `aux`.
  - Dimensoes: eleicao, UF, RA, local, zona, secao, partido, cargo, federacao, coligacao, candidato, perfil eleitor, votavel.
  - Fatos: perfil do eleitorado por secao, votacao por candidato/votavel/secao, apuracao por secao.
  - View recomendada: `fato.vw_votacao_drilldown`.

- `docs/planejamento_implementacao_banco_eleitoral.md`
  - Plano incremental de implementacao em 18 etapas.
  - Cada etapa tem objetivo, entregaveis, validacoes manuais e criterio de aceite.
  - Proximas etapas imediatas: Etapa 2, depois Etapa 3.

- `docs/diario_implementacao.md`
  - Registro das etapas executadas.
  - Etapa 0 concluida.
  - Etapa 1 concluida.
  - Etapa 2 concluida.
  - Etapa 3 concluida.

- `docs/validacoes_manuais.md`
  - Comandos e consultas usados para validar Etapas 0 e 1.

## Estado atual da implementacao

Etapa 0 - concluida:

- Estrutura inicial de diretorios criada:
  - `sql/`
  - `sql/01_staging/`
  - `sql/02_dimensoes/`
  - `sql/03_geoespacial/`
  - `sql/04_fatos/`
  - `sql/05_views/`
  - `sql/99_qualidade/`
  - `scripts/`
  - `tests/`
  - `tests/sql/`
  - `tests/expected/`
  - `docs/`
- Arquivos README criados nas pastas de apoio.
- `.env.example` criado.

Etapa 1 - concluida:

- `docker-compose.yml` criado.
- Servico `db` configurado com:
  - imagem `postgis/postgis:16-3.5`
  - container `eleitoral_postgis`
  - porta `5432`
  - volume persistente `postgres_data`
  - montagem readonly de `./fontes` em `/fontes`
  - healthcheck com `pg_isready`
- Conteiner subiu com sucesso.
- Banco respondeu a `pg_isready`.
- Persistencia validada:
  - tabela `aux_teste_persistencia` criada;
  - registro `id = 1` inserido;
  - executado `docker compose down`;
  - executado `docker compose up -d`;
  - registro continuou existindo.

Estado atual do conteiner ao final da Etapa 1:

- `eleitoral_postgis` estava rodando e `healthy`.
- O volume persistente criado foi `code_teste_r2_postgres_data`.

Etapa 2 - concluida:

- `docker-compose.yml` atualizado com montagens readonly:
  - `./sql:/sql:ro`
  - `./tests:/tests:ro`
- `sql/00_extensions_schemas.sql` criado e executado.
- `tests/sql/00_extensions_schemas_test.sql` criado e executado.
- Extensoes:
  - `postgis` confirmada; ja existia no banco.
  - `unaccent` criada.
- Schemas criados:
  - `stg`
  - `dim`
  - `fato`
  - `geo`
  - `aux`
- Validacoes:
  - `postgis_full_version()` retornou PostGIS `3.5.2`.
  - consulta dos schemas retornou `aux`, `dim`, `fato`, `geo`, `stg`.
  - teste SQL retornou zero linhas.

Etapa 3 - concluida:

- `sql/01_staging/01_staging_small_medium.sql` criado e executado.
- `scripts/load_staging.py` criado e executado.
- `tests/sql/01_staging_small_medium_test.sql` criado e executado.
- Tabelas criadas/carregadas em `stg`:
  - `consulta_cand_2026_df`: 661 linhas.
  - `consulta_cand_complementar_2026_df`: 661 linhas.
  - `eleitorado_local_votacao_2026_df`: 7.050 linhas.
  - `tre_locais_2026_df`: 615 linhas brutas, 614 uteis e 1 linha `Totais`.
  - `tre_locais_secao_2026_df`: 615 linhas brutas, 614 uteis e 1 linha `Totais`.
  - `tre_locais_secao_agrupadas_2026_df`: 615 linhas brutas, 614 uteis e 1 linha `Totais`.
  - `tre_secoes_2026_df`: 6.962 linhas brutas, 6.961 uteis e 1 linha `Totais`.
  - `geo_ra_centroid_atualizado`: 35 linhas.
  - `ra_shapefile`: 37 linhas.
- Validacoes:
  - teste SQL de contagens retornou zero linhas.
  - shapefile carregou 37 geometrias, todas validas por `st_isvalid`.
- Observacao de qualidade:
  - alguns XLSX, o GeoJSON e registros do shapefile possuem caracteres de substituicao em textos acentuados.
  - a carga preserva os dados recebidos; normalizacao/correcao de nomes deve ocorrer na etapa geoespacial/dimensao RA.

## Arquivos de implementacao existentes

Raiz do projeto:

- `.env.example`
- `docker-compose.yml`
- `sql/00_extensions_schemas.sql`
- `sql/01_staging/01_staging_small_medium.sql`
- `scripts/load_staging.py`

Documentacao:

- `docs/diario_implementacao.md`
- `docs/modelagem_banco_eleitoral_postgis.md`
- `docs/planejamento_implementacao_banco_eleitoral.md`
- `docs/validacoes_manuais.md`
- `docs/resumo_contexto_proxima_sessao.md`

Pastas preparadas, ainda sem scripts finais:

- `sql/01_staging/`
- `sql/02_dimensoes/`
- `sql/03_geoespacial/`
- `sql/04_fatos/`
- `sql/05_views/`
- `sql/99_qualidade/`
- `scripts/`
- `tests/sql/`
- `tests/expected/`

Testes existentes:

- `tests/sql/00_extensions_schemas_test.sql`
- `tests/sql/01_staging_small_medium_test.sql`

## O que ainda esta incompleto

- Etapa 4 ainda nao foi implementada.
- Nenhuma tabela da modelagem foi criada, exceto a tabela temporaria/de validacao `aux_teste_persistencia`.
- Nenhuma carga de dados grandes foi implementada.
- Nenhuma regra de qualidade foi implementada.
- Nenhuma view final foi criada.
- A carga completa de `votacao_secao_2022_DF.csv` continua explicitamente fora do escopo ate autorizacao futura.

## Como retomar a proxima sessao

1. Abrir o workspace:

```powershell
cd C:\Users\mnt50\DEV\code_teste_r2
```

2. Conferir arquivos principais:

```powershell
Get-ChildItem -Force
Get-ChildItem .\docs
```

3. Ler rapidamente:

- `docs/resumo_contexto_proxima_sessao.md`
- `docs/diario_implementacao.md`
- `docs/planejamento_implementacao_banco_eleitoral.md`
- `docs/modelagem_banco_eleitoral_postgis.md`

4. Verificar Docker:

```powershell
docker --version
docker compose version
```

5. Reiniciar/subir conteineres:

```powershell
docker compose up -d
```

Observacao: no Windows, este comando pode exigir acesso elevado ao Docker Engine. Na sessao anterior, foi necessario executar comandos Docker com permissao elevada.

6. Conferir status:

```powershell
docker compose ps
```

Resultado esperado:

```text
eleitoral_postgis   postgis/postgis:16-3.5   db   Up ... (healthy)   0.0.0.0:5432->5432/tcp
```

7. Conferir disponibilidade do PostgreSQL:

```powershell
docker compose exec -T db pg_isready -U eleitoral_app -d eleitoral
```

Resultado esperado:

```text
/var/run/postgresql:5432 - accepting connections
```

8. Conferir persistencia ja validada:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select * from aux_teste_persistencia;"
```

Resultado esperado:

```text
 id
----
  1
```

## Proximo passo exato

Implementar a Etapa 4 - Staging dos arquivos grandes.

Escopo:

- Criar staging para `perfil_eleitor_secao_2026_DF.csv`.
- Preparar staging para `votacao_secao_2022_DF.csv`, sem executar a carga completa ate autorizacao explicita.

Observacao:

- A proxima carga grande autorizada no planejamento e `perfil_eleitor_secao_2026_DF.csv`.
- `votacao_secao_2022_DF.csv` deve permanecer fora de carga completa ate decisao futura.

## Comandos uteis de operacao

Subir conteineres:

```powershell
docker compose up -d
```

Parar e remover conteineres sem apagar volume:

```powershell
docker compose down
```

Ver logs do banco:

```powershell
docker compose logs db
```

Abrir shell SQL:

```powershell
docker compose exec db psql -U eleitoral_app -d eleitoral
```

Executar SQL inline:

```powershell
docker compose exec -T db psql -U eleitoral_app -d eleitoral -c "select current_database(), current_user;"
```

Listar volumes Docker do projeto:

```powershell
docker volume ls
```

Nao usar salvo decisao explicita de reset total:

```powershell
docker compose down -v
```

Esse comando apaga o volume persistente e destruiria os dados do banco.
