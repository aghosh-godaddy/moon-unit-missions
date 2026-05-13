#!/usr/bin/env python3
"""Fetch Alation metadata (description + custom_fields) for a list of tables and extract
any Confluence URLs referenced inline.

This covers URLs stored in the table's own description or any of its `custom_fields`
(Data Lake Table Description, Data Lake Owner Info, etc.). It does NOT reach Catalog
Set–level fields like "Data Design" — for those, see
`fetch_alation_catalog_set_design.py`.

Required env (typically `source .env.local`):
  ALATION_URL, ALATION_REFRESH_TOKEN, ALATION_USER_ID

Usage:
  # From stdin, one "schema.table" per line:
  printf 'enterprise.dim_entitlement\\necomm360.fact_bill_line_vw\\n' | \\
    python3 scripts/alation_fetch_table_metadata.py

  # Or from args:
  python3 scripts/alation_fetch_table_metadata.py \\
    enterprise.dim_entitlement ecomm360.fact_bill_line_vw

Output: JSON on stdout keyed by "schema.table", each entry containing the Alation
table id, title, Data Lake Table Description, and a list of Confluence URLs found.

Legacy confluence.godaddy.com hosts are normalized to godaddy-corp.atlassian.net.
Fragment-only duplicates (same page with different #anchors) are de-duped.
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

CONFLUENCE_RE = re.compile(
    r"https?://[a-z0-9\-.]+(?:atlassian\.net|godaddy\.com)[^\s<>\"')]+",
    re.IGNORECASE,
)
LEGACY_HOSTS = ("confluence.godaddy.com", "confluence.int.godaddy.com")


def get_token() -> str:
    req = urllib.request.Request(
        f"{ALATION_URL}/integration/v1/createAPIAccessToken/",
        data=json.dumps({"refresh_token": REFRESH, "user_id": USER_ID}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())["api_access_token"]


def find_table(token: str, schema: str, name: str) -> dict | None:
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


def normalize(url: str) -> str:
    for h in LEGACY_HOSTS:
        if h in url:
            url = url.replace(h, "godaddy-corp.atlassian.net")
    return url


def extract_confluence(text: str) -> list[str]:
    if not text:
        return []
    raw = [u.rstrip(".,;)\"'&") for u in CONFLUENCE_RE.findall(text)]
    filt = [normalize(u) for u in raw
            if any(k in u for k in ("/wiki/", "/display/", "/pages/", "/x/"))]
    # Dedupe: collapse fragment-only variants to their base page.
    seen, out = set(), []
    for u in filt:
        base = u.split("#", 1)[0]
        if base in seen:
            continue
        seen.add(base)
        out.append(base)
    return out


def collect_text(table: dict) -> str:
    chunks = [table.get("description") or ""]
    for cf in table.get("custom_fields", []) or []:
        v = cf.get("value")
        if isinstance(v, str):
            chunks.append(v)
        elif isinstance(v, list):
            for item in v:
                chunks.append(json.dumps(item) if isinstance(item, dict) else str(item))
    return "\n".join(chunks)


def strip_html(s: str | None) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", s or "")).strip()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0] if __doc__ else None)
    ap.add_argument("tables", nargs="*", help='"schema.table" pairs (else read from stdin)')
    args = ap.parse_args()

    targets: list[str] = args.tables or [ln.strip() for ln in sys.stdin if ln.strip()]
    if not targets:
        ap.error("provide tables on the command line or via stdin")

    token = get_token()
    out: dict[str, dict] = {}
    for t in targets:
        if "." not in t:
            out[t] = {"error": "expected 'schema.table' format"}
            continue
        schema, name = t.split(".", 1)
        try:
            row = find_table(token, schema, name)
        except Exception as e:
            out[t] = {"error": f"lookup failed: {e}"}
            continue
        if not row:
            out[t] = {"error": "not found in Alation"}
            continue
        urls = extract_confluence(collect_text(row))
        dl_desc = ""
        for cf in row.get("custom_fields", []) or []:
            if cf.get("field_name") == "Data Lake Table Description":
                dl_desc = strip_html(cf.get("value"))
                break
        out[t] = {
            "alation_id": row.get("id"),
            "title": row.get("title") or "",
            "dl_desc": dl_desc,
            "confluence_urls": urls,
        }

    json.dump(out, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
