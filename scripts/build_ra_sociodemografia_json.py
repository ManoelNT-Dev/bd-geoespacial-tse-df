import copy
import json
import unicodedata
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_JSON = ROOT / "fontes" / "perfil_eleitorado_df_2025_consolidado_12jan2026.json"
OUTPUT_JSON = ROOT / "fontes" / "perfil_sociodemografico_ra_df_2025_estruturado.json"

TEXT_REPLACEMENTS = {
    "\u0081": "Á",
    "\u0082": "Â",
    "\u0083": "Ã",
    "\u0089": "É",
    "\u008a": "Ê",
}

DERIVED_RAS = [
    {
        "ra_codigo": "RA-XXXVI",
        "ra_cira": 36,
        "ra_nome": "26 DE SETEMBRO",
        "origem_ra_codigo": "RA-XXX",
        "origem_ra_nome": "VICENTE PIRES",
        "populacao_estimada": 29394,
    },
    {
        "ra_codigo": "XXXVII",
        "ra_cira": 37,
        "ra_nome": "PONTE ALTA",
        "origem_ra_codigo": "RA-II",
        "origem_ra_nome": "GAMA",
        "populacao_estimada": 45452,
    },
]

FIXED_POPULATION_RA_CODES = {
    item["ra_codigo"] for item in DERIVED_RAS
} | {
    item["origem_ra_codigo"] for item in DERIVED_RAS
}

ROMAN_VALUES = {
    "I": 1,
    "V": 5,
    "X": 10,
    "L": 50,
}


def fix_text(value):
    if isinstance(value, str):
        for source, target in TEXT_REPLACEMENTS.items():
            value = value.replace(source, target)
        return value
    if isinstance(value, list):
        return [fix_text(item) for item in value]
    if isinstance(value, dict):
        return {key: fix_text(item) for key, item in value.items()}
    return value


def normalize_name(value):
    decomposed = unicodedata.normalize("NFKD", value)
    ascii_name = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    return " ".join(ascii_name.upper().replace("/", " ").split())


def roman_to_int(value):
    total = 0
    previous = 0
    for char in reversed(value):
        current = ROMAN_VALUES[char]
        if current < previous:
            total -= current
        else:
            total += current
            previous = current
    return total


def ra_cira_from_code(ra_codigo):
    roman = ra_codigo.removeprefix("RA-")
    return roman_to_int(roman) if roman and all(char in ROMAN_VALUES for char in roman) else None


def round_split(items, total, value_key):
    raw_values = [item[value_key] for item in items]
    raw_sum = sum(raw_values)
    if raw_sum == 0:
        return

    scaled = []
    for item in items:
        exact = item[value_key] * total / raw_sum
        base = int(exact)
        scaled.append((item, base, exact - base))

    remainder = total - sum(base for _, base, _ in scaled)
    for item, base, _ in scaled:
        item[value_key] = base
    for item, _, _ in sorted(scaled, key=lambda row: row[2], reverse=True)[:remainder]:
        item[value_key] += 1


def scale_nested(value, factor):
    if isinstance(value, list):
        for item in value:
            scale_nested(item, factor)
        if all(isinstance(item, dict) and "quantidade" in item for item in value):
            total = round(sum(item["quantidade"] for item in value))
            round_split(value, total, "quantidade")
        return value

    if isinstance(value, dict):
        for key, item in value.items():
            if key in {"qtd", "total", "quantidade", "qtd_domicilios_com_pets"} and isinstance(item, int):
                value[key] = round(item * factor)
            elif key.startswith("eleitores_") and isinstance(item, int):
                value[key] = round(item * factor)
            else:
                scale_nested(item, factor)
        return value

    return value


def set_population(ra, population):
    race = ra["populacao_raca_cor"]
    race["total_geral"] = population
    groups = [race["negra"], race["nao_negra"]]
    round_split(groups, population, "total")

    for group in groups:
        round_split([group["feminino"], group["masculino"]], group["total"], "qtd")
        for sex in ("feminino", "masculino"):
            group[sex]["pct"] = round(group[sex]["qtd"] * 100 / group["total"], 1) if group["total"] else 0


def rescale_ra_population(ra, new_population, derivation):
    current_population = ra["populacao_raca_cor"]["total_geral"]
    factor = new_population / current_population
    scale_nested(ra, factor)
    set_population(ra, new_population)
    ra["derivacao"] = {
        **ra.get("derivacao", {}),
        **derivation,
        "populacao_antes_ajuste_total_df": current_population,
        "populacao_apos_ajuste_total_df": new_population,
        "fator_ajuste_total_df": factor,
    }


def scale_ra(source_ra, new_population, extra):
    source_population = source_ra["populacao_raca_cor"]["total_geral"]
    factor = new_population / source_population
    ra = extract_sociodemographic_ra(source_ra)
    ra["ra_codigo"] = extra["ra_codigo"]
    ra["ra_cira"] = extra["ra_cira"]
    ra["ra_nome"] = extra["ra_nome"]
    ra["derivacao"] = {
        "tipo": "desdobramento_proporcional",
        "origem_ra_codigo": extra["origem_ra_codigo"],
        "origem_ra_nome": extra["origem_ra_nome"],
        "populacao_origem_original": source_population,
        "fator_proporcional": factor,
    }
    scale_nested(ra, factor)
    set_population(ra, new_population)
    ra["perfil_resumido"] = (
        f"Perfil herdado proporcionalmente de {extra['origem_ra_nome']} "
        f"com populacao estimada de {new_population} habitantes."
    )
    return ra


def adjust_origin_ra(source_ra, derived_population):
    original_population = source_ra["populacao_raca_cor"]["total_geral"]
    adjusted_population = original_population - derived_population
    if adjusted_population <= 0:
        raise ValueError(f"Populacao derivada maior que a origem em {source_ra['ra_nome']}")

    factor = adjusted_population / original_population
    ra = extract_sociodemographic_ra(source_ra)
    ra["derivacao"] = {
        "tipo": "origem_ajustada_por_desdobramento",
        "populacao_original": original_population,
        "populacao_desdobrada": derived_population,
        "populacao_ajustada": adjusted_population,
        "fator_proporcional": factor,
    }
    scale_nested(ra, factor)
    set_population(ra, adjusted_population)
    return ra


def extract_sociodemographic_ra(ra):
    keys = [
        "ra_codigo",
        "ra_cira",
        "ra_nome",
        "centroid",
        "area_km2",
        "populacao_raca_cor",
        "religiao",
        "renda",
        "animais_estimacao",
        "perfil_resumido",
    ]
    output = {key: copy.deepcopy(ra[key]) for key in keys if key in ra}
    output["ra_cira"] = output.get("ra_cira") or ra_cira_from_code(output["ra_codigo"])
    return output


def rebuild_sociodemographic_totals(regioes):
    race = {
        "ra": "Distrito Federal",
        "total_geral": 0,
        "negra": {"total": 0, "feminino": {"qtd": 0}, "masculino": {"qtd": 0}},
        "nao_negra": {"total": 0, "feminino": {"qtd": 0}, "masculino": {"qtd": 0}},
    }

    for ra in regioes:
        src_race = ra["populacao_raca_cor"]
        race["total_geral"] += src_race["total_geral"]
        for group in ("negra", "nao_negra"):
            race[group]["total"] += src_race[group]["total"]
            for sex in ("feminino", "masculino"):
                race[group][sex]["qtd"] += src_race[group][sex]["qtd"]

    for group in ("negra", "nao_negra"):
        for sex in ("feminino", "masculino"):
            total = race[group]["total"]
            qtd = race[group][sex]["qtd"]
            race[group][sex]["pct"] = round(qtd * 100 / total, 1) if total else 0

    return race


def reconcile_official_df_population(regioes, official_total):
    current_total = sum(ra["populacao_raca_cor"]["total_geral"] for ra in regioes)
    difference = official_total - current_total
    if difference == 0:
        return

    adjustable = [
        ra
        for ra in regioes
        if ra["ra_codigo"] not in FIXED_POPULATION_RA_CODES
    ]
    adjustable_current_total = sum(ra["populacao_raca_cor"]["total_geral"] for ra in adjustable)
    adjustable_target_total = adjustable_current_total + difference
    if adjustable_target_total <= 0:
        raise ValueError("Ajuste para total oficial deixaria populacao ajustavel menor ou igual a zero")

    population_refs = [
        {"ra": ra, "populacao": ra["populacao_raca_cor"]["total_geral"]}
        for ra in adjustable
    ]
    round_split(population_refs, adjustable_target_total, "populacao")

    for item in population_refs:
        rescale_ra_population(
            item["ra"],
            item["populacao"],
            {
                "tipo_ajuste_total_df": "rateio_proporcional_total_oficial",
                "populacao_total_df_oficial": official_total,
                "diferenca_rateada": difference,
            },
        )


def validate(regioes):
    for ra in regioes:
        population = ra["populacao_raca_cor"]["total_geral"]
        race_total = ra["populacao_raca_cor"]["negra"]["total"] + ra["populacao_raca_cor"]["nao_negra"]["total"]
        if population != race_total:
            raise AssertionError(f"Raca/cor nao fecha em {ra['ra_nome']}: {population} != {race_total}")


def main():
    with SOURCE_JSON.open("r", encoding="utf-8-sig") as fp:
        source = fix_text(json.load(fp))

    by_code = {ra["ra_codigo"]: ra for ra in source["regioes_administrativas"]}
    derived_by_origin = {item["origem_ra_codigo"]: item for item in DERIVED_RAS}

    regioes = []
    for ra in source["regioes_administrativas"]:
        if ra["ra_codigo"] in derived_by_origin:
            regioes.append(adjust_origin_ra(ra, derived_by_origin[ra["ra_codigo"]]["populacao_estimada"]))
        else:
            sociodemographic_ra = extract_sociodemographic_ra(ra)
            set_population(sociodemographic_ra, sociodemographic_ra["populacao_raca_cor"]["total_geral"])
            regioes.append(sociodemographic_ra)

    for item in DERIVED_RAS:
        regioes.append(scale_ra(by_code[item["origem_ra_codigo"]], item["populacao_estimada"], item))

    official_total = source["perfil_geral_df"]["demografia_raca_cor_geral"]["total_geral"]
    reconcile_official_df_population(regioes, official_total)

    regioes = sorted(regioes, key=lambda item: item.get("ra_cira") or 999)
    validate(regioes)
    race = rebuild_sociodemographic_totals(regioes)

    output = {
        "schema_version": "1.0.0",
        "metadata": {
            "titulo": "Indicadores Sociodemograficos por Regiao Administrativa - Distrito Federal",
            "ano_referencia_demografica": source["metadata"]["ano_referencia_demografica"],
            "fontes": [
                fonte
                for fonte in source["metadata"]["fontes"]
                if fonte.startswith("IPEDF/")
            ],
            "data_consolidacao": source["metadata"]["data_consolidacao"],
            "data_ultima_atualizacao": source["metadata"]["data_ultima_atualizacao"],
            "data_normalizacao": date.today().isoformat(),
            "fonte_arquivo_original": str(SOURCE_JSON.relative_to(ROOT)).replace("\\", "/"),
            "estrutura": "DF > Regiao Administrativa > Indicadores sociodemograficos",
        },
        "regras_transformacao": {
            "encoding": "Arquivo original lido como utf-8-sig; caracteres de controle conhecidos foram normalizados.",
            "desdobramentos": DERIVED_RAS,
            "proporcionalidade": (
                "Quantidades foram ajustadas pelo fator populacao_nova/populacao_original. "
                "Percentuais e medias herdadas foram mantidos quando nao ha microdados."
            ),
            "consistencia_total_df": (
                "O total oficial do DF vem de perfil_geral_df.demografia_raca_cor_geral.total_geral. "
                "As populacoes das RAs derivadas e de origem ajustada ficam fixas; a diferenca remanescente "
                "e rateada proporcionalmente nas demais RAs."
            ),
        },
        "sociodemografia_geral_df": {
            "demografia_raca_cor_geral": race,
            "religiao": source["perfil_geral_df"].get("religiao"),
            "renda": source["perfil_geral_df"].get("renda"),
            "animais_estimacao": source["perfil_geral_df"].get("animais_estimacao"),
            "perfil_resumido": source["perfil_geral_df"].get("perfil_resumido"),
        },
        "regioes_administrativas": regioes,
    }

    with OUTPUT_JSON.open("w", encoding="utf-8", newline="\n") as fp:
        json.dump(output, fp, ensure_ascii=False, indent=2)
        fp.write("\n")

    print(f"RAs estruturadas: {len(regioes)}")
    print(f"Populacao DF: {race['total_geral']}")


if __name__ == "__main__":
    main()
