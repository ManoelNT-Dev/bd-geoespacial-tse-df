from __future__ import annotations

import argparse
import csv
import json
import os
import re
import unicodedata
from pathlib import Path
from typing import Iterable

import openpyxl
import psycopg
import shapefile


ROOT_DIR = Path(__file__).resolve().parents[1]
FONTES_DIR = ROOT_DIR / "fontes"

DB_CONFIG = {
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": os.getenv("POSTGRES_PORT", "5432"),
    "dbname": os.getenv("POSTGRES_DB", "eleitoral"),
    "user": os.getenv("POSTGRES_USER", "eleitoral_app"),
    "password": os.getenv("POSTGRES_PASSWORD", "trocar_senha"),
}


CSV_LOADS = [
    {
        "table": "stg.consulta_cand_2026_df",
        "file": "consulta_cand_2026_DF.csv",
        "encoding": "latin-1",
    },
    {
        "table": "stg.consulta_cand_complementar_2026_df",
        "file": "consulta_cand_complementar_2026_DF.csv",
        "encoding": "latin-1",
    },
    {
        "table": "stg.eleitorado_local_votacao_2026_df",
        "file": "eleitorado_local_votacao_2026_DF.csv",
        "encoding": "latin-1",
    },
]

XLSX_LOADS = [
    {"table": "stg.tre_locais_2026_df", "file": "Locais_TRE_DF_2026.xlsx"},
    {"table": "stg.tre_locais_secao_2026_df", "file": "Locais_Seção_TRE_DF_2026.xlsx"},
    {
        "table": "stg.tre_locais_secao_agrupadas_2026_df",
        "file": "Locais_Seção_Agrupadas por local_TRE_DF_2026.xlsx",
    },
    {"table": "stg.tre_secoes_2026_df", "file": "Secoes_TRE-DF_2026.xlsx"},
]


def normalize_identifier(value: object) -> str:
    text = str(value).strip().lower()
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    text = re.sub(r"[^a-z0-9]+", "_", text).strip("_")
    return text


def quote_identifier(identifier: str) -> str:
    return '"' + identifier.replace('"', '""') + '"'


def copy_rows(conn: psycopg.Connection, table: str, columns: list[str], rows: Iterable[list[object]]) -> int:
    qualified_table = ".".join(quote_identifier(part) for part in table.split("."))
    column_sql = ", ".join(quote_identifier(column) for column in columns)
    count = 0

    with conn.cursor() as cur:
        with cur.copy(f"copy {qualified_table} ({column_sql}) from stdin") as copy:
            for row in rows:
                copy.write_row(row)
                count += 1

    return count


def truncate_tables(conn: psycopg.Connection, tables: Iterable[str]) -> None:
    table_sql = ", ".join(".".join(quote_identifier(part) for part in table.split(".")) for table in tables)
    with conn.cursor() as cur:
        cur.execute(f"truncate table {table_sql};")


def load_csv(conn: psycopg.Connection, config: dict[str, str]) -> int:
    path = FONTES_DIR / config["file"]
    with path.open(encoding=config["encoding"], newline="") as file_obj:
        reader = csv.reader(file_obj, delimiter=";")
        source_columns = [normalize_identifier(column) for column in next(reader)]
        columns = source_columns + ["source_file", "row_number"]

        def rows() -> Iterable[list[object]]:
            for row_number, row in enumerate(reader, start=1):
                yield row + [config["file"], row_number]

        return copy_rows(conn, config["table"], columns, rows())


def load_xlsx(conn: psycopg.Connection, config: dict[str, str]) -> int:
    path = FONTES_DIR / config["file"]
    workbook = openpyxl.load_workbook(path, read_only=True, data_only=True)
    worksheet = workbook.active
    row_iter = worksheet.iter_rows(values_only=True)
    source_columns = [normalize_identifier(column) for column in next(row_iter)]
    columns = source_columns + ["is_total", "source_file", "row_number"]

    def rows() -> Iterable[list[object]]:
        for row_number, row in enumerate(row_iter, start=1):
            is_total = str(row[0]).strip().lower() == "totais" if row and row[0] is not None else False
            yield list(row) + [is_total, config["file"], row_number]

    return copy_rows(conn, config["table"], columns, rows())


def load_geojson(conn: psycopg.Connection) -> int:
    source_file = "geo_ra_centroid_atualizado.json"
    path = FONTES_DIR / source_file
    data = json.loads(path.read_text(encoding="utf-8"))
    columns = [
        "ra_nome",
        "ra_codigo",
        "ra_areakm2",
        "longitude",
        "latitude",
        "geometry_type",
        "geometry_json",
        "source_file",
        "row_number",
    ]

    def rows() -> Iterable[list[object]]:
        for row_number, feature in enumerate(data["features"], start=1):
            properties = feature.get("properties", {})
            geometry = feature.get("geometry", {})
            coordinates = geometry.get("coordinates") or [None, None]
            yield [
                properties.get("ra_nome"),
                properties.get("ra_codigo"),
                properties.get("ra_areakm2"),
                coordinates[0],
                coordinates[1],
                geometry.get("type"),
                json.dumps(geometry, ensure_ascii=False),
                source_file,
                row_number,
            ]

    return copy_rows(conn, "stg.geo_ra_centroid_atualizado", columns, rows())


def load_shapefile(conn: psycopg.Connection) -> int:
    source_file = "shapefile_ras/regioes_administrativas.shp"
    path = FONTES_DIR / source_file
    reader = shapefile.Reader(str(path), encoding="utf-8", encodingErrors="replace")
    fields = [field[0] for field in reader.fields if field[0] != "DeletionFlag"]
    source_columns = [normalize_identifier(field) for field in fields]
    columns = source_columns + ["geometry_type", "geometry_json", "source_file", "row_number"]

    def rows() -> Iterable[list[object]]:
        for row_number, shape_record in enumerate(reader.iterShapeRecords(), start=1):
            geometry = shape_record.shape.__geo_interface__
            yield [
                *list(shape_record.record),
                geometry.get("type"),
                json.dumps(geometry, ensure_ascii=False),
                source_file,
                row_number,
            ]

    count = copy_rows(conn, "stg.ra_shapefile", columns, rows())

    with conn.cursor() as cur:
        cur.execute(
            """
            update stg.ra_shapefile
            set geom = st_setsrid(st_geomfromgeojson(geometry_json), 31983)
            where geometry_json is not null;
            """
        )

    return count


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Carrega staging dos arquivos pequenos e medios.")
    parser.add_argument(
        "--no-truncate",
        action="store_true",
        help="Nao truncar tabelas antes da carga.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    tables = [
        *(config["table"] for config in CSV_LOADS),
        *(config["table"] for config in XLSX_LOADS),
        "stg.geo_ra_centroid_atualizado",
        "stg.ra_shapefile",
    ]

    with psycopg.connect(**DB_CONFIG) as conn:
        if not args.no_truncate:
            truncate_tables(conn, tables)

        loaded_counts = []
        for config in CSV_LOADS:
            loaded_counts.append((config["table"], load_csv(conn, config)))

        for config in XLSX_LOADS:
            loaded_counts.append((config["table"], load_xlsx(conn, config)))

        loaded_counts.append(("stg.geo_ra_centroid_atualizado", load_geojson(conn)))
        loaded_counts.append(("stg.ra_shapefile", load_shapefile(conn)))

    for table, count in loaded_counts:
        print(f"{table}: {count} linhas carregadas")


if __name__ == "__main__":
    main()
