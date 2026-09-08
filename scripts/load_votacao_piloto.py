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

VOTACAO_TABLE = "stg.votacao_secao_2022_df"
VOTACAO_FILE = "votacao_secao_2022_DF.csv"


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


def copy_votacao_piloto(conn: psycopg.Connection, zona: str) -> int:
    path = FONTES_DIR / VOTACAO_FILE
    with path.open(encoding="latin-1", newline="") as file_obj:
        reader = csv.reader(file_obj, delimiter=";")
        columns = [normalize_identifier(column) for column in next(reader)]
        columns.extend(["source_file", "row_number"])

        column_sql = ", ".join(quote_identifier(column) for column in columns)
        copy_sql = f"copy {qualified_table_name(VOTACAO_TABLE)} ({column_sql}) from stdin"
        count = 0

        with conn.cursor() as cur:
            with cur.copy(copy_sql) as copy:
                for row_number, row in enumerate(reader, start=1):
                    row_dict = dict(zip(columns[:-2], row))
                    if row_dict["nr_zona"] != zona:
                        continue

                    copy.write_row(row + [VOTACAO_FILE, row_number])
                    count += 1

    return count


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Carrega amostra piloto de votacao 2022.")
    parser.add_argument(
        "--zona",
        default="20",
        help="Zona eleitoral a carregar como piloto. Padrao: 20.",
    )
    parser.add_argument(
        "--no-truncate",
        action="store_true",
        help="Nao truncar stg.votacao_secao_2022_df antes da carga.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    with psycopg.connect(**DB_CONFIG) as conn:
        if not args.no_truncate:
            truncate_tables(conn, [VOTACAO_TABLE])

        count = copy_votacao_piloto(conn, args.zona)

    print(f"{VOTACAO_TABLE}: {count} linhas carregadas para NR_ZONA={args.zona}")


if __name__ == "__main__":
    main()
