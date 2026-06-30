#!/usr/bin/env python3
"""
Deterministic validator for Snowflake Semantic View YAML.

Validates structure, semantics, and referential integrity against the
Snowflake semantic view YAML spec. Outputs VALIDATION_REPORT.json and
prints a human-readable summary.

Usage:
    python validate_snowflake_yaml.py <path_to_yaml> [--report <path_to_json>]

Exit codes:
    0  All checks passed (may include warnings)
    1  At least one check failed
    2  Input error (file not found, invalid YAML, etc.)
"""

import argparse
import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

AGGREGATE_PATTERN = re.compile(
    r"\b(SUM|COUNT|AVG|MIN|MAX|MEDIAN|STDDEV|VARIANCE|"
    r"COUNT_IF|SUM_IF|AVG_IF|LISTAGG|ARRAY_AGG|"
    r"APPROX_COUNT_DISTINCT|HLL|ANY_VALUE|"
    r"PERCENTILE_CONT|PERCENTILE_DISC|MODE|CORR|"
    r"COVAR_POP|COVAR_SAMP|REGR_SLOPE|REGR_INTERCEPT)\s*\(",
    re.IGNORECASE,
)

VALID_SNOWFLAKE_TYPES = {
    "VARCHAR", "STRING", "TEXT", "CHAR", "CHARACTER",
    "NUMBER", "NUMERIC", "DECIMAL", "INT", "INTEGER",
    "BIGINT", "SMALLINT", "TINYINT", "BYTEINT",
    "FLOAT", "FLOAT4", "FLOAT8", "DOUBLE", "DOUBLE PRECISION", "REAL",
    "BOOLEAN",
    "DATE", "TIME", "TIMESTAMP", "TIMESTAMP_LTZ", "TIMESTAMP_NTZ", "TIMESTAMP_TZ",
    "DATETIME",
    "VARIANT", "OBJECT", "ARRAY",
    "BINARY", "VARBINARY",
    "GEOGRAPHY", "GEOMETRY",
}

VALID_ACCESS_MODIFIERS = {"public_access", "private_access"}


class ValidationResult:
    def __init__(self, check_id, category, description):
        self.check_id = check_id
        self.category = category
        self.description = description
        self.status = "PASS"
        self.details = []

    def fail(self, msg):
        self.status = "FAIL"
        self.details.append(msg)

    def warn(self, msg):
        if self.status == "PASS":
            self.status = "WARN"
        self.details.append(f"[WARN] {msg}")

    def to_dict(self):
        return {
            "check_id": self.check_id,
            "category": self.category,
            "description": self.description,
            "status": self.status,
            "details": self.details,
        }


def load_yaml(path):
    with open(path, "r") as f:
        return yaml.safe_load(f)


def check_root_structure(data, results):
    r = ValidationResult("S01", "structural", "Root has 'name' (non-empty string)")
    name = data.get("name")
    if not isinstance(name, str) or not name.strip():
        r.fail("'name' is missing or not a non-empty string")
    results.append(r)

    r = ValidationResult("S02", "structural", "Root has 'tables' (non-empty list)")
    tables = data.get("tables")
    if not isinstance(tables, list) or len(tables) == 0:
        r.fail("'tables' is missing or empty")
    results.append(r)


def check_tables(data, results):
    tables = data.get("tables", [])
    if not isinstance(tables, list):
        return

    table_names = []
    for i, tbl in enumerate(tables):
        prefix = f"tables[{i}]"
        if not isinstance(tbl, dict):
            r = ValidationResult(f"S03_{i}", "structural", f"{prefix} is a mapping")
            r.fail(f"{prefix} is not a mapping/dict")
            results.append(r)
            continue

        tname = tbl.get("name", "")
        r = ValidationResult(f"S03_{i}", "structural", f"{prefix} has 'name'")
        if not isinstance(tname, str) or not tname.strip():
            r.fail(f"{prefix}.name is missing or empty")
        else:
            table_names.append(tname)
        results.append(r)

        r = ValidationResult(f"S04_{i}", "structural", f"{prefix} has valid 'base_table'")
        bt = tbl.get("base_table")
        if not isinstance(bt, dict):
            r.fail(f"{prefix}.base_table is missing or not a mapping")
        else:
            for key in ("database", "schema", "table"):
                val = bt.get(key)
                if not isinstance(val, str) or not val.strip():
                    r.fail(f"{prefix}.base_table.{key} is missing or empty")
        results.append(r)

        _check_entities(tbl, "dimensions", prefix, results, is_metric=False)
        _check_entities(tbl, "time_dimensions", prefix, results, is_metric=False)
        _check_entities(tbl, "facts", prefix, results, is_metric=False)
        _check_entities(tbl, "metrics", prefix, results, is_metric=True)
        _check_unique_names_within_table(tbl, prefix, results)

    r = ValidationResult("S10", "structural", "Table names are unique")
    seen = set()
    for tn in table_names:
        if tn in seen:
            r.fail(f"Duplicate table name: '{tn}'")
        seen.add(tn)
    results.append(r)


def _check_entities(tbl, key, prefix, results, is_metric):
    entities = tbl.get(key)
    if entities is None:
        return
    if not isinstance(entities, list):
        r = ValidationResult(f"S05_{prefix}_{key}", "structural", f"{prefix}.{key} is a list")
        r.fail(f"{prefix}.{key} is not a list")
        results.append(r)
        return

    for j, ent in enumerate(entities):
        epath = f"{prefix}.{key}[{j}]"
        if not isinstance(ent, dict):
            r = ValidationResult(f"S06_{epath}", "structural", f"{epath} is a mapping")
            r.fail(f"{epath} is not a mapping")
            results.append(r)
            continue

        r = ValidationResult(f"S06_{epath}", "structural", f"{epath} has 'name' and 'expr'")
        ename = ent.get("name")
        if not isinstance(ename, str) or not ename.strip():
            r.fail(f"{epath}.name is missing or empty")
        expr = ent.get("expr")
        if expr is None:
            r.fail(f"{epath}.expr is missing")
        elif not isinstance(expr, str):
            r.fail(f"{epath}.expr is not a string")
        results.append(r)

        if isinstance(expr, str):
            _check_expr_aggregates(expr, epath, is_metric, results)

        _check_access_modifier(ent, epath, results)
        _check_data_type(ent, epath, results)


def _check_expr_aggregates(expr, epath, is_metric, results):
    has_agg = bool(AGGREGATE_PATTERN.search(expr))
    if is_metric:
        r = ValidationResult(f"M01_{epath}", "semantic", f"{epath} metric expr contains aggregate")
        if not has_agg:
            r.fail(f"Metric expr has no aggregate function: '{expr}'")
        results.append(r)
    else:
        r = ValidationResult(f"M02_{epath}", "semantic", f"{epath} non-metric expr is scalar")
        if has_agg:
            r.warn(f"Non-metric expr contains aggregate function: '{expr}'")
        results.append(r)


def _check_access_modifier(ent, epath, results):
    am = ent.get("access_modifier")
    if am is None:
        return
    r = ValidationResult(f"M03_{epath}", "semantic", f"{epath} access_modifier is valid")
    if am not in VALID_ACCESS_MODIFIERS:
        r.fail(f"Invalid access_modifier '{am}'; must be one of {VALID_ACCESS_MODIFIERS}")
    results.append(r)


def _check_data_type(ent, epath, results):
    dt = ent.get("data_type")
    if dt is None:
        return
    r = ValidationResult(f"M04_{epath}", "semantic", f"{epath} data_type is valid Snowflake type")
    dt_upper = str(dt).upper().strip()
    base_type = re.split(r"[\s(]", dt_upper, maxsplit=1)[0]
    if base_type not in VALID_SNOWFLAKE_TYPES:
        r.warn(f"Unrecognized data_type '{dt}'; expected a Snowflake type")
    results.append(r)


def _check_unique_names_within_table(tbl, prefix, results):
    all_names = []
    for key in ("dimensions", "time_dimensions", "facts", "metrics", "filters"):
        for ent in tbl.get(key, []) or []:
            if isinstance(ent, dict) and isinstance(ent.get("name"), str):
                all_names.append((key, ent["name"]))

    r = ValidationResult(f"S11_{prefix}", "structural", f"{prefix} entity names unique within table")
    seen = {}
    for section, name in all_names:
        if name in seen:
            r.fail(f"Duplicate name '{name}' in {section} (also in {seen[name]})")
        seen[name] = section
    results.append(r)


def check_relationships(data, results):
    rels = data.get("relationships")
    if rels is None:
        return
    if not isinstance(rels, list):
        r = ValidationResult("R01", "referential", "'relationships' is a list")
        r.fail("'relationships' is not a list")
        results.append(r)
        return

    table_names = {t.get("name") for t in data.get("tables", []) if isinstance(t, dict)}

    rel_names = []
    for i, rel in enumerate(rels):
        rpath = f"relationships[{i}]"
        if not isinstance(rel, dict):
            r = ValidationResult(f"R02_{i}", "referential", f"{rpath} is a mapping")
            r.fail(f"{rpath} is not a mapping")
            results.append(r)
            continue

        r = ValidationResult(f"R02_{i}", "referential", f"{rpath} has required fields")
        rname = rel.get("name")
        if not isinstance(rname, str) or not rname.strip():
            r.fail(f"{rpath}.name is missing or empty")
        else:
            rel_names.append(rname)

        lt = rel.get("left_table")
        rt = rel.get("right_table")
        if not isinstance(lt, str) or not lt.strip():
            r.fail(f"{rpath}.left_table is missing or empty")
        elif lt not in table_names:
            r.fail(f"{rpath}.left_table '{lt}' does not match any defined table")

        if not isinstance(rt, str) or not rt.strip():
            r.fail(f"{rpath}.right_table is missing or empty")
        elif rt not in table_names:
            r.fail(f"{rpath}.right_table '{rt}' does not match any defined table")

        cols = rel.get("relationship_columns")
        if not isinstance(cols, list) or len(cols) == 0:
            r.fail(f"{rpath}.relationship_columns is missing or empty")
        else:
            for k, pair in enumerate(cols):
                if not isinstance(pair, dict):
                    r.fail(f"{rpath}.relationship_columns[{k}] is not a mapping")
                else:
                    if not pair.get("left_column"):
                        r.fail(f"{rpath}.relationship_columns[{k}].left_column is missing")
                    if not pair.get("right_column"):
                        r.fail(f"{rpath}.relationship_columns[{k}].right_column is missing")
        results.append(r)

    r = ValidationResult("R03", "referential", "Relationship names are unique")
    seen = set()
    for rn in rel_names:
        if rn in seen:
            r.fail(f"Duplicate relationship name: '{rn}'")
        seen.add(rn)
    results.append(r)


def check_verified_queries(data, results):
    vqs = data.get("verified_queries")
    if vqs is None:
        return
    if not isinstance(vqs, list):
        r = ValidationResult("V01", "structural", "'verified_queries' is a list")
        r.fail("'verified_queries' is not a list")
        results.append(r)
        return

    for i, vq in enumerate(vqs):
        vpath = f"verified_queries[{i}]"
        r = ValidationResult(f"V02_{i}", "structural", f"{vpath} has required fields")
        if not isinstance(vq, dict):
            r.fail(f"{vpath} is not a mapping")
            results.append(r)
            continue
        for field in ("name", "question", "sql"):
            val = vq.get(field)
            if not isinstance(val, str) or not val.strip():
                r.fail(f"{vpath}.{field} is missing or empty")
        results.append(r)


def check_view_level_metrics(data, results):
    metrics = data.get("metrics")
    if metrics is None:
        return
    if not isinstance(metrics, list):
        r = ValidationResult("D01", "structural", "View-level 'metrics' is a list")
        r.fail("View-level 'metrics' is not a list")
        results.append(r)
        return

    for i, m in enumerate(metrics):
        mpath = f"metrics[{i}] (view-level)"
        if not isinstance(m, dict):
            r = ValidationResult(f"D02_{i}", "structural", f"{mpath} is a mapping")
            r.fail(f"{mpath} is not a mapping")
            results.append(r)
            continue

        r = ValidationResult(f"D02_{i}", "structural", f"{mpath} has 'name' and 'expr'")
        mname = m.get("name")
        if not isinstance(mname, str) or not mname.strip():
            r.fail(f"{mpath}.name is missing or empty")
        expr = m.get("expr")
        if not isinstance(expr, str) or not expr.strip():
            r.fail(f"{mpath}.expr is missing or empty")
        results.append(r)

        _check_access_modifier(m, mpath, results)


def check_custom_instructions(data, results):
    ci = data.get("custom_instructions")
    mci = data.get("module_custom_instructions")
    if ci is not None:
        r = ValidationResult("C01", "structural", "'custom_instructions' is a string")
        if not isinstance(ci, str):
            r.fail("'custom_instructions' is not a string")
        results.append(r)

    if mci is not None:
        r = ValidationResult("C02", "structural", "'module_custom_instructions' is a mapping")
        if not isinstance(mci, dict):
            r.fail("'module_custom_instructions' is not a mapping")
        else:
            for key in ("sql_generation", "question_categorization"):
                val = mci.get(key)
                if val is not None and not isinstance(val, str):
                    r.fail(f"'module_custom_instructions.{key}' is not a string")
        results.append(r)


def validate(data):
    results = []
    check_root_structure(data, results)
    check_tables(data, results)
    check_relationships(data, results)
    check_verified_queries(data, results)
    check_view_level_metrics(data, results)
    check_custom_instructions(data, results)
    return results


def summarize(results):
    total = len(results)
    passed = sum(1 for r in results if r.status == "PASS")
    warned = sum(1 for r in results if r.status == "WARN")
    failed = sum(1 for r in results if r.status == "FAIL")
    return {
        "total_checks": total,
        "passed": passed,
        "warnings": warned,
        "failed": failed,
        "overall": "PASS" if failed == 0 else "FAIL",
    }


def main():
    parser = argparse.ArgumentParser(description="Validate Snowflake Semantic View YAML")
    parser.add_argument("yaml_file", help="Path to the YAML file to validate")
    parser.add_argument("--report", default="VALIDATION_REPORT.json",
                        help="Path for JSON report output (default: VALIDATION_REPORT.json)")
    args = parser.parse_args()

    yaml_path = Path(args.yaml_file)
    if not yaml_path.exists():
        print(f"ERROR: File not found: {yaml_path}", file=sys.stderr)
        sys.exit(2)

    try:
        data = load_yaml(yaml_path)
    except yaml.YAMLError as e:
        print(f"ERROR: Invalid YAML: {e}", file=sys.stderr)
        sys.exit(2)

    if not isinstance(data, dict):
        print("ERROR: YAML root is not a mapping", file=sys.stderr)
        sys.exit(2)

    results = validate(data)
    summary = summarize(results)

    report = {
        "file": str(yaml_path),
        "summary": summary,
        "checks": [r.to_dict() for r in results],
    }

    report_path = Path(args.report)
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)

    print(f"\n{'='*60}")
    print(f"  Snowflake Semantic View YAML Validation")
    print(f"  File: {yaml_path}")
    print(f"{'='*60}")
    print(f"  Total checks: {summary['total_checks']}")
    print(f"  Passed:       {summary['passed']}")
    print(f"  Warnings:     {summary['warnings']}")
    print(f"  Failed:       {summary['failed']}")
    print(f"  Overall:      {summary['overall']}")
    print(f"{'='*60}\n")

    if summary["failed"] > 0:
        print("FAILURES:")
        for r in results:
            if r.status == "FAIL":
                print(f"  [{r.check_id}] {r.description}")
                for d in r.details:
                    print(f"    - {d}")
        print()

    if summary["warnings"] > 0:
        print("WARNINGS:")
        for r in results:
            if r.status == "WARN":
                print(f"  [{r.check_id}] {r.description}")
                for d in r.details:
                    print(f"    - {d}")
        print()

    print(f"Report written to: {report_path}")
    sys.exit(0 if summary["failed"] == 0 else 1)


if __name__ == "__main__":
    main()
