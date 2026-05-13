#!/usr/bin/env python3
"""Fetch `table.yaml` for a table from the gdcorp-dna/lake registry, parse
`lineage.upstream_table_dependencies`, filter to curated schemas, and resolve each
upstream to an Alation table id.

Useful for populating `reference_tables` blocks in column-comments mission configs.

Required env:
  ALATION_URL, ALATION_REFRESH_TOKEN, ALATION_USER_ID
  GITHUB_PAT   (with read access to gdcorp-dna/lake)

Usage:
  # standard registry path (catalog/config/prod/us-west-2/<db>/<table>):
  python3 scripts/lake_lineage_fetch.py enterprise/dim-entitlement

  # dlms-api variant (catalog/config/prod/dlms-api/us-west-2/<db>/<table>):
  python3 scripts/lake_lineage_fetch.py --registry dlms-api ecomm360/dim-bill-vw

  # multiple tables:
  python3 scripts/lake_lineage_fetch.py enterprise/dim-entitlement enterprise/dim-subscription

Output: JSON keyed by "<db>/<table>" with total upstream count, curated (filtered)
subset, and per-dependency Alation metadata (id, title, Data Lake description).

Curated schemas are controlled by `CURATED_SCHEMAS` — edit to add/remove.
"""
import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request

ALATION_URL = os.environ["ALATION_URL"].rstrip("/")
REFRESH = os.environ["ALATION_REFRESH_TOKEN"]
USER_ID = int(os.environ["ALATION_USER_ID"])
GH_PAT = os.environ.get("GITHUB_PAT", "")

LAKE_RAW = "https://raw.githubusercontent.com/gdcorp-dna/lake/main"

# Upstream deps in these (enriched / curated) schemas are kept; raw tx-log / snap
# sources in schemas like godaddybilling, godaddy, merchantaccounts, etc., are
# dropped because their Alation descriptions don't help column-level enrichment.
CURATED_SCHEMAS = {
    "customer360",
    "enterprise",
    "ecomm360", "ecomm_mart", "ecomm_cln",
    "analytic", "analytic_feature",
    "bi_reports",
    "finance360",
    "partner360",
    "gd_traffic_mart",
    "pricing_mart",
    "advertising_mart",
    "activity_log",
    "data_quality_mart",
    "signals_platform_cln",
}


def lake_table_yaml_url(registry: str, db: str, table: str) -> str:
    if registry == "dlms-api":
        return f"{LAKE_RAW}/catalog/config/prod/dlms-api/us-west-2/{db}/{table}/table.yaml"
    return f"{LAKE_RAW}/catalog/config/prod/us-west-2/{db}/{table}/table.yaml"


def fetch_lake_yaml(url: str) -> str:
    headers = {"Accept": "text/plain"}
    if GH_PAT:
        headers["Authorization"] = f"token {GH_PAT}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as r:
        return r.read().decode()


def extract_upstream(yaml_text: str) -> list[str]:
    m = re.search(r"^\s*upstream_table_dependencies:\s*$", yaml_text, re.M)
    if not m:
        return []
    deps: list[str] = []
    for line in yaml_text[m.end():].split("\n"):
        s = line.strip()
        if not s:
            continue
        if s.startswith("#"):
            continue
        if s.startswith("- "):
            dep = s[2:].strip().strip('"').strip("'")
            if "." in dep:
                deps.append(dep)
            continue
        # Sibling top-level-ish key ends the block
        if re.match(r"^\s{0,10}[a-zA-Z_]", line):
            break
    return deps


def get_alation_token() -> str:
    req = urllib.request.Request(
        f"{ALATION_URL}/integration/v1/createAPIAccessToken/",
        data=json.dumps({"refresh_token": REFRESH, "user_id": USER_ID}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())["api_access_token"]


def alation_lookup(token: str, schema: str, name: str) -> dict | None:
    url = f"{ALATION_URL}/integration/v2/table/?name={urllib.parse.quote(name)}&limit=50"
    req = urllib.request.Request(url, headers={"Token": token, "Accept": "application/json"})
    with urllib.request.urlopen(req) as r:
        rows = json.loads(r.read())
    for row in rows:
        parts = (row.get("key") or "").split(".")
        if len(parts) >= 2 and parts[-2] == schema and parts[-1] == name:
            return row
    for row in rows:
        if row.get("name") == name:
            return row
    return None


def strip_html(s: str | None) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", s or "")).strip()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0] if __doc__ else None)
    ap.add_argument("tables", nargs="+", help='"<db>/<table>" — use the hyphenated lake registry form, e.g. enterprise/dim-entitlement.')
    ap.add_argument("--registry", choices=["standard", "dlms-api"], default="standard",
                    help="Registry variant (default: standard).")
    ap.add_argument("--all", action="store_true",
                    help="Return all upstream deps, not just curated schemas.")
    args = ap.parse_args()

    token = get_alation_token()
    result: dict[str, dict] = {}
    for spec in args.tables:
        if "/" not in spec:
            result[spec] = {"error": "expected '<db>/<table>' format"}
            continue
        db, table = spec.split("/", 1)
        try:
            yaml_text = fetch_lake_yaml(lake_table_yaml_url(args.registry, db, table))
        except Exception as e:
            result[spec] = {"error": f"fetch failed: {e}"}
            continue
        all_upstream = extract_upstream(yaml_text)
        kept = all_upstream if args.all else [
            d for d in all_upstream if d.split(".", 1)[0] in CURATED_SCHEMAS
        ]
        # dedupe, preserve order
        seen, kept_dedup = set(), []
        for d in kept:
            if d not in seen:
                seen.add(d)
                kept_dedup.append(d)

        refs = []
        for dep in kept_dedup:
            schema, name = dep.split(".", 1)
            try:
                row = alation_lookup(token, schema, name)
            except Exception as e:
                refs.append({"schema": schema, "name": name, "error": str(e)})
                continue
            if row is None:
                refs.append({"schema": schema, "name": name, "alation_id": None})
                continue
            dl_desc = ""
            for cf in row.get("custom_fields", []) or []:
                if cf.get("field_name") == "Data Lake Table Description":
                    dl_desc = strip_html(cf.get("value"))
                    break
            refs.append({
                "schema": schema,
                "name": name,
                "alation_id": row.get("id"),
                "title": row.get("title") or "",
                "dl_desc": dl_desc,
            })
        result[spec] = {
            "upstream_total": len(all_upstream),
            "upstream_curated_count": len(kept_dedup),
            "references": refs,
        }

    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
