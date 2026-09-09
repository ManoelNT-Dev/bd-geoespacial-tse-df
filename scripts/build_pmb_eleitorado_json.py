import csv
import gzip
import json
import unicodedata
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_JSON = ROOT / "fontes" / "eleitorado_PMB_2026.json"
SOURCE_CSV = ROOT / "fontes" / "perfil_eleitor_secao_2026_GO.csv"

IBGE_MUNICIPIOS_GO_URL = (
    "https://servicodados.ibge.gov.br/api/v1/localidades/estados/52/municipios"
)
SIDRA_POP_URL = (
    "https://apisidra.ibge.gov.br/values/t/6579/n6/in%20n3%2052/p/2025/v/9324"
    "?formato=json"
)


PROFILE_DIMENSIONS = {
    "genero": ("CD_GENERO", "DS_GENERO"),
    "estado_civil": ("CD_ESTADO_CIVIL", "DS_ESTADO_CIVIL"),
    "faixa_etaria": ("CD_FAIXA_ETARIA", "DS_FAIXA_ETARIA"),
    "escolaridade": ("CD_GRAU_ESCOLARIDADE", "DS_GRAU_ESCOLARIDADE"),
    "raca_cor": ("CD_RACA_COR", "DS_RACA_COR"),
    "identidade_genero": ("CD_IDENTIDADE_GENERO", "DS_IDENTIDADE_GENERO"),
    "quilombola": ("CD_QUILOMBOLA", "DS_QUILOMBOLA"),
    "interprete_libras": ("CD_INTERPRETE_LIBRAS", "DS_INTERPRETE_LIBRAS"),
}


def normalize_name(value):
    decomposed = unicodedata.normalize("NFKD", value)
    ascii_name = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    return " ".join(ascii_name.upper().split())


def as_int(value):
    return int(str(value).strip().strip('"'))


def sorted_profile(counter):
    rows = []
    for (code, description), amount in counter.items():
        rows.append(
            {
                "codigo": int(code),
                "descricao": description,
                "quantidade": amount,
            }
        )
    return sorted(rows, key=lambda item: item["codigo"])


def load_json_base():
    with SOURCE_JSON.open("r", encoding="utf-8") as fp:
        data = json.load(fp)

    municipios = data.get("pmb", {}).get("municipios") or data.get("regioes_administrativas", [])
    by_tse_code = {as_int(item["municipio_codigo"]): item for item in municipios}
    pmb_codes = set(by_tse_code)
    return data, by_tse_code, pmb_codes


def load_ibge_municipios():
    with urllib.request.urlopen(IBGE_MUNICIPIOS_GO_URL, timeout=30) as response:
        data = json.loads(decode_response(response))
    return {normalize_name(item["nome"]): item for item in data}


def load_ibge_population():
    with urllib.request.urlopen(SIDRA_POP_URL, timeout=30) as response:
        data = json.loads(decode_response(response))

    population = {}
    for row in data[1:]:
        code = row.get("D1C")
        value = row.get("V")
        if code and value not in (None, "-", "..."):
            population[int(code)] = int(str(value).replace(".", ""))
    return population


def decode_response(response):
    body = response.read()
    if body[:2] == b"\x1f\x8b":
        body = gzip.decompress(body)
    return body.decode("utf-8")


def aggregate_csv(pmb_codes):
    municipalities = {}
    global_totals = Counter()
    global_profile = {key: Counter() for key in PROFILE_DIMENSIONS}
    dt_geracao = None
    hh_geracao = None

    with SOURCE_CSV.open("r", encoding="latin-1", newline="") as fp:
        reader = csv.DictReader(fp, delimiter=";")
        for row in reader:
            tse_code = as_int(row["CD_MUNICIPIO"])
            if tse_code not in pmb_codes:
                continue

            if dt_geracao is None:
                dt_geracao = row["DT_GERACAO"]
                hh_geracao = row["HH_GERACAO"]

            municipio = municipalities.setdefault(
                tse_code,
                {
                    "municipio_codigo": tse_code,
                    "municipio_nome": row["NM_MUNICIPIO"],
                    "totais": Counter(),
                    "perfil": {key: Counter() for key in PROFILE_DIMENSIONS},
                    "secoes": set(),
                    "locais": set(),
                    "zonas": set(),
                },
            )

            qt_eleitores = as_int(row["QT_ELEITORES"])
            qt_biometria = as_int(row["QT_ELEITORES_BIOMETRIA"])
            qt_deficiencia = as_int(row["QT_ELEITORES_DEFICIENCIA"])
            qt_nome_social = as_int(row["QT_ELEITORES_NOME_SOCIAL"])

            for key, value in (
                ("eleitores_total", qt_eleitores),
                ("eleitores_biometria", qt_biometria),
                ("eleitores_deficiencia", qt_deficiencia),
                ("eleitores_nome_social", qt_nome_social),
            ):
                municipio["totais"][key] += value
                global_totals[key] += value

            municipio["secoes"].add((as_int(row["NR_ZONA"]), as_int(row["NR_SECAO"])))
            municipio["locais"].add((as_int(row["NR_ZONA"]), as_int(row["NR_LOCAL_VOTACAO"])))
            municipio["zonas"].add(as_int(row["NR_ZONA"]))

            for profile_key, (code_col, description_col) in PROFILE_DIMENSIONS.items():
                profile_id = (as_int(row[code_col]), row[description_col])
                municipio["perfil"][profile_key][profile_id] += qt_eleitores
                global_profile[profile_key][profile_id] += qt_eleitores

    return municipalities, global_totals, global_profile, dt_geracao, hh_geracao


def build_output(base_data, base_by_tse, aggregated, totals, global_profile, dt_geracao, hh_geracao):
    ibge_by_name = load_ibge_municipios()
    population_by_ibge = load_ibge_population()

    municipios = []
    for tse_code in sorted(aggregated):
        agg = aggregated[tse_code]
        previous = base_by_tse[tse_code]
        ibge = ibge_by_name[normalize_name(agg["municipio_nome"])]
        ibge_code = int(ibge["id"])

        item = {
            "municipio_codigo": tse_code,
            "municipio_codigo_tse": tse_code,
            "municipio_codigo_ibge": ibge_code,
            "municipio_nome": agg["municipio_nome"],
            "uf": "GO",
            "pop_municipio": population_by_ibge[ibge_code],
            "pop_municipio_fonte": {
                "orgao": "IBGE",
                "tabela": "SIDRA 6579",
                "variavel": "9324 - Populacao residente estimada",
                "periodo": 2025,
                "data_referencia": "2025-07-01",
                "url": SIDRA_POP_URL,
            },
            "area_km2": previous.get("area_km2"),
            "centroid": previous.get("centroid"),
            "totais": dict(agg["totais"]),
            "perfil": {
                profile_key: sorted_profile(counter)
                for profile_key, counter in agg["perfil"].items()
            },
            "zonas_eleitorais_unicas": len(agg["zonas"]),
            "locais_votacao_unicos": len(agg["locais"]),
            "secoes_eleitorais_unicas": len(agg["secoes"]),
        }
        municipios.append(item)

    output = {
        "metadata": {
            "titulo": "Perfil do Eleitorado - PMB",
            "ano_eleicao": 2026,
            "uf": "GO",
            "data_geracao": f"{dt_geracao} {hh_geracao}",
            "data_atualizacao_json": date.today().isoformat(),
            "fonte": "TSE - Tribunal Superior Eleitoral",
            "fonte_perfil": str(SOURCE_CSV.relative_to(ROOT)).replace("\\", "/"),
            "fonte_populacao": "IBGE/SIDRA - Tabela 6579, variavel 9324, periodo 2025",
            "estrutura": "PMB > Municipio > Perfil agregado de secoes eleitorais",
            "observacoes": [
                "municipio_codigo preserva o codigo TSE usado na fonte eleitoral.",
                "municipio_codigo_ibge foi acrescentado para compatibilizacao territorial e populacao oficial.",
                "Os perfis foram agregados por soma de QT_ELEITORES a partir do nivel de secao eleitoral.",
            ],
        },
        "pmb": {
            "codigo": "PMB",
            "nome": "Periferia Metropolitana de Brasilia",
            "descricao": "Municipios goianos vizinhos ao Distrito Federal selecionados no recorte PMB.",
            "uf": "GO",
            "total_municipios": len(municipios),
            "municipios": municipios,
        },
        "totais_gerais": dict(totals),
        "perfil_geral": {
            profile_key: sorted_profile(counter)
            for profile_key, counter in global_profile.items()
        },
    }

    return output


def main():
    base_data, base_by_tse, pmb_codes = load_json_base()
    aggregated, totals, global_profile, dt_geracao, hh_geracao = aggregate_csv(pmb_codes)

    missing = sorted(pmb_codes - set(aggregated))
    if missing:
        raise RuntimeError(f"Municipios PMB sem dados no CSV GO: {missing}")

    output = build_output(base_data, base_by_tse, aggregated, totals, global_profile, dt_geracao, hh_geracao)

    with SOURCE_JSON.open("w", encoding="utf-8", newline="\n") as fp:
        json.dump(output, fp, ensure_ascii=False, indent=2)
        fp.write("\n")

    print(f"Municipios PMB: {output['pmb']['total_municipios']}")
    print(f"Eleitores PMB: {output['totais_gerais']['eleitores_total']}")
    print(f"Populacao IBGE 2025 PMB: {sum(m['pop_municipio'] for m in output['pmb']['municipios'])}")


if __name__ == "__main__":
    main()
