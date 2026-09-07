from __future__ import annotations

import argparse
import csv
import os
import re
import unicodedata
from pathlib import Path
from typing import Iterable

import psycopg


ROOT_DIR = Path(__file__).resolve().parents[1]
FONTES_DIR = ROOT_DIR / "fontes"

DB_CONFIG = {
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": os.getenv("POSTGRES_PORT", "5432"),
    "dbname": os.getenv("POSTGRES_DB", "eleitoral"),
    "user": os.getenv("POSTGRES_USER", "eleitoral_app"),
    "password": os.getenv("POSTGRES_PASSWORD", "trocar_senha"),
}

PROFILE_LOAD = {
    "table": "stg.perfil_eleitor_secao_2026_df",
    "file": "perfil_eleitor_secao_2026_DF.csv",
    "encoding": "latin-1",
}

VOTACAO_LOAD = {
    "table": "stg.votacao_secao_2022_df",
    "file": "votacao_secao_2022_DF.csv",
    "encoding": "latin-1",
}


def normalize_identifier(value: object) -> str:
    text = str(value).strip().lower()
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    text = re.sub(r"[^a-z0-9]+", "_", text).strip("_")
    return text


def quote_identifier(identifier: str) -> str:
    return '"' + identifier.replace('"', '""') + '"'


def qualified_table_name(table: str) -> str:
    return ".".join(quote_identifier(part) for part in table.split("."))


def truncate_tables(conn: psycopg.Connection, tables: Iterable[str]) -> None:
    table_sql = ", ".join(qualified_table_name(table) for table in tables)
    with conn.cursor() as cur:
        cur.execute(f"truncate table {table_sql};")


def copy_csv(conn: psycopg.Connection, config: dict[str, str]) -> int:
    path = FONTES_DIR / config["file"]
    with path.open(encoding=config["encoding"], newline="") as file_obj:
        reader = csv.reader(file_obj, delimiter=";")
        columns = [normalize_identifier(column) for column in next(reader)]
        columns.extend(["source_file", "row_number"])

        column_sql = ", ".join(quote_identifier(column) for column in columns)
        copy_sql = f"copy {qualified_table_name(config['table'])} ({column_sql}) from stdin"
        count = 0

        with conn.cursor() as cur:
            with cur.copy(copy_sql) as copy:
                for row_number, row in enumerate(reader, start=1):
                    copy.write_row(row + [config["file"], row_number])
                    count += 1

    return count


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Carrega staging dos arquivos grandes.")
    parser.add_argument(
        "--include-votacao",
        action="store_true",
        help="Carrega votacao_secao_2022_DF.csv. Usar somente com autorizacao explicita.",
    )
    parser.add_argument(
        "--no-truncate",
        action="store_true",
        help="Nao truncar tabelas antes da carga.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    loads = [PROFILE_LOAD]
    truncate_targets = [PROFILE_LOAD["table"]]

    if args.include_votacao:
        loads.append(VOTACAO_LOAD)
        truncate_targets.append(VOTACAO_LOAD["table"])
    elif not args.no_truncate:
        truncate_targets.append(VOTACAO_LOAD["table"])

    loaded_counts = []
    with psycopg.connect(**DB_CONFIG) as conn:
        if not args.no_truncate:
            truncate_tables(conn, truncate_targets)

        for config in loads:
            loaded_counts.append((config["table"], copy_csv(conn, config)))

    for table, count in loaded_counts:
        print(f"{table}: {count} linhas carregadas")

    if not args.include_votacao:
        print("stg.votacao_secao_2022_df: carga nao executada por falta de autorizacao explicita")


if __name__ == "__main__":
    main()
