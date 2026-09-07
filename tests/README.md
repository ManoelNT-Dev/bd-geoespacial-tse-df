# Testes

Diretorio reservado para testes SQL e resultados esperados.

Padrao recomendado:

- `tests/sql/`: consultas de validacao.
- `tests/expected/`: resultados esperados ou notas de conferencia.

Cada teste SQL deve retornar zero linhas quando representar uma regra de erro, ou uma contagem explicitamente documentada quando validar cardinalidade.

