#!/usr/bin/env python3
"""Discover Confluence URLs in an Alation Catalog Set's shared Description.

A Catalog Set groups multiple physical tables (across schemas / data sources)
that share the same logical definition. The shared Description rich-text field
is rendered on every member table's Overview page as "Shared from ⚙ <Title>".

Where the data actually lives (empirically verified 2026-05-13):
  NOT at /integration/v2/custom_field_value/?otype=dynamic_set_property&oid=<id>&field_id=4
  (that endpoint returns only the Title and ignores the shared Description).

  INSTEAD at /api/v1/table/<any_member_table_id>/ under the key
  `shared_catalog_sets[].description` — the rich-text HTML the UI renders.

For each target table, this script:
  1. Looks up the table in Alation (/integration/v2/table/?name=<t>&limit=50),
     picking any member (they all share the same description).
  2. Fetches /api/v1/table/<id>/, grabs `shared_catalog_sets[].description`,
     and scans for Confluence URLs. Also pulls `description` (table-level,
     separate field that may contain URLs too).
  3. Resolves tiny /wiki/x/<code> links via the Atlassian API (--resolve-tiny-links).

Required env (from missions/column-comments/.env.local):
  ALATION_URL, ALATION_REFRESH_TOKEN, ALATION_USER_ID
  ATLASSIAN_EMAIL, ATLASSIAN_API_TOKEN  (only for --resolve-tiny-links)

Verified: bill_line_traffic_ext → 5 Confluence URLs including the
`https://godaddy-corp.atlassian.net/wiki/x/dwQ5yg` "Data Design" link that was
previously only visible via the Alation web UI.

Usage:
  set -a; source missions/column-comments/.env.local; set +a
  python3 scripts/fetch_alation_catalog_set_design.py                    # all 15 targets
  python3 scripts/fetch_alation_catalog_set_design.py --table bill_line_traffic_ext
  python3 scripts/fetch_alation_catalog_set_design.py --resolve-tiny-links
"""
import argparse
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

ALATION_URL = os.environ["ALATION_URL"].rstrip("/")
REFRESH = os.environ["ALATION_REFRESH_TOKEN"]
USER_ID = int(os.environ["ALATION_USER_ID"])

DEFAULT_TABLES = [
    "ads_bill_line",
    "customer_type",
    "ads_entitlement_bill",
    "dim_bill_vw",
    "fact_bill_line_vw",
    "bill_line_traffic_ext",
    "renewal_360",
    "dim_entitlement",
    "dim_entitlement_history",
    "dim_subscription",
    "dim_subscription_history",
    "fact_entitlement_bill",
    "free_entitlement",
    "analytic_traffic_agg",
    "analytic_traffic_detail",
]

CONFLUENCE_RE = re.compile(
    r"https?://[a-z0-9\-.]+(?:atlassian\.net|godaddy\.com)[^\s<>\"')]+",
    re.IGNORECASE,
)


def get_token() -> str:
    req = urllib.request.Request(
        f"{ALATION_URL}/integration/v1/createAPIAccessToken/",
        data=json.dumps({"refresh_token": REFRESH, "user_id": USER_ID}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())["api_access_token"]


def api_get(path: str, token: str, params: dict | None = None) -> object:
    qs = "?" + urllib.parse.urlencode(params) if params else ""
    req = urllib.request.Request(
        f"{ALATION_URL}{path}{qs}",
        headers={"Token": token, "Accept": "application/json"},
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


def find_any_table(token: str, name: str) -> dict | None:
    """Return any table row for this name; all members of a catalog set share Description."""
    rows = api_get("/integration/v2/table/", token, {"name": name, "limit": 50})
    for row in rows or []:
        if row.get("name") == name:
            return row
    return None


def fetch_table_details(token: str, table_id: int) -> dict:
    """Return the full /api/v1/table/<id>/ payload, which includes shared_catalog_sets."""
    return api_get(f"/api/v1/table/{table_id}/", token)


def resolve_tiny_link(url: str) -> str:
    if "/wiki/x/" not in url:
        return url
    email = os.environ.get("ATLASSIAN_EMAIL")
    tok = os.environ.get("ATLASSIAN_API_TOKEN")
    if not email or not tok:
        return url
    auth = base64.b64encode(f"{email}:{tok}".encode()).decode()
    req = urllib.request.Request(url, headers={"Authorization": f"Basic {auth}"})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            final = r.geturl()
            if final and final != url:
                return final
    except Exception:
        pass
    return url


def extract_confluence(text: str) -> list[str]:
    if not text:
        return []
    raw = [u.rstrip(".,;)\"'&") for u in CONFLUENCE_RE.findall(text)]
    filt = [u for u in raw if any(k in u for k in ("/wiki/", "/display/", "/pages/", "/x/"))]
    # Dedupe on base URL (strip #fragment).
    seen, out = set(), []
    for u in filt:
        base = u.split("#", 1)[0]
        if base in seen:
            continue
        seen.add(base)
        out.append(base)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--table", action="append",
                    help="Table name to check (default: all 15 targets). Can be repeated.")
    ap.add_argument("--resolve-tiny-links", action="store_true",
                    help="Follow /wiki/x/<code> redirects to full page URLs (needs ATLASSIAN_* env).")
    args = ap.parse_args()
    targets = args.table or DEFAULT_TABLES

    token = get_token()
    result: dict[str, dict] = {}
    for name in targets:
        try:
            row = find_any_table(token, name)
        except Exception as e:
            result[name] = {"error": f"table lookup failed: {e}"}
            continue
        if not row:
            result[name] = {"error": "no Alation table found by that name"}
            continue
        try:
            detail = fetch_table_details(token, row["id"])
        except Exception as e:
            result[name] = {"alation_table_id": row["id"], "error": f"detail fetch failed: {e}"}
            continue

        scs = detail.get("shared_catalog_sets") or []
        urls_by_source: list[dict] = []
        for s in scs:
            body = s.get("description") or ""
            urls = extract_confluence(body)
            if args.resolve_tiny_links:
                urls = [resolve_tiny_link(u) for u in urls]
            if urls:
                urls_by_source.append({
                    "source": "shared_catalog_sets",
                    "catalog_set_id": s.get("id"),
                    "descriptor": s.get("descriptor"),
                    "urls": urls,
                })

        tbl_desc = detail.get("description") or ""
        tbl_urls = extract_confluence(tbl_desc)
        if args.resolve_tiny_links:
            tbl_urls = [resolve_tiny_link(u) for u in tbl_urls]
        if tbl_urls:
            urls_by_source.append({
                "source": "table.description",
                "urls": tbl_urls,
            })

        result[name] = {
            "alation_table_id": row["id"],
            "shared_catalog_sets": [
                {"id": s.get("id"), "descriptor": s.get("descriptor")}
                for s in scs
            ],
            "hits": urls_by_source,
        }

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
