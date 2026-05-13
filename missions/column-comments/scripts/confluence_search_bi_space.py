#!/usr/bin/env python3
"""Search the Confluence BI space for candidate design-doc pages for a table.

Useful when Alation metadata has no Confluence link. Runs one or more CQL text searches,
filters out known noise (JIRA reports, bi-weekly updates, dashboards, etc.), and fetches
a short body excerpt so you can judge relevance.

Required env:
  ATLASSIAN_EMAIL, ATLASSIAN_API_TOKEN

Usage:
  python3 scripts/confluence_search_bi_space.py "dim_entitlement" "Entitlement Dimension"
  python3 scripts/confluence_search_bi_space.py --space BI "fact_entitlement_bill"
  python3 scripts/confluence_search_bi_space.py --no-excerpts "free_entitlement"

The first positional arg is usually the table name (with underscores); subsequent args
are alternate search terms (e.g., the Alation display title). Each term is quoted into
its own CQL `text ~` clause.
"""
import argparse
import base64
import html
import json
import os
import re
import sys
import urllib.parse
import urllib.request

BASE = "https://godaddy-corp.atlassian.net/wiki"

# Titles matching this pattern are hidden by default — they're rarely design docs.
DEFAULT_NOISE = re.compile(
    r"JIRA Report|Bi-Weekly|Executive Update|MBR|Digest|OKRs|Cost Savings|"
    r"Meeting Summaries|Weekly Ops|On Call Rotation|SLA Miss|"
    r"Operations excellence|Dashboard|Gap Analysis|DIFY|"
    r"QuickSight|Redshift COPY|Airo|Offer Pulse|Pricing Experiment|"
    r"Vibe-Code|Knowledge Graph|Vector Store|"
    r"Helix Disambiguation|^20\d\d-\d\d-\d\d",
    re.IGNORECASE,
)


def auth_header() -> str:
    email = os.environ["ATLASSIAN_EMAIL"]
    token = os.environ["ATLASSIAN_API_TOKEN"]
    return "Basic " + base64.b64encode(f"{email}:{token}".encode()).decode()


def api_get(path: str) -> dict:
    req = urllib.request.Request(
        f"{BASE}{path}",
        headers={"Authorization": auth_header(), "Accept": "application/json"},
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


def search(cql: str, limit: int = 15) -> list[dict]:
    data = api_get(f"/rest/api/content/search?cql={urllib.parse.quote(cql)}&limit={limit}")
    return data.get("results", [])


def excerpt(page_id: str, max_len: int = 350) -> str:
    try:
        d = api_get(f"/rest/api/content/{page_id}?expand=body.view")
    except Exception as e:
        return f"(excerpt error: {e})"
    body = d.get("body", {}).get("view", {}).get("value", "")
    txt = html.unescape(re.sub(r"<[^>]+>", " ", body))
    return re.sub(r"\s+", " ", txt).strip()[:max_len]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0] if __doc__ else None)
    ap.add_argument("terms", nargs="+", help="Search terms (will be quoted into CQL).")
    ap.add_argument("--space", default="BI", help='Confluence space key (default "BI").')
    ap.add_argument("--limit", type=int, default=15, help="Max hits per term (default 15).")
    ap.add_argument("--no-noise-filter", action="store_true",
                    help="Don't filter out JIRA/weekly/dashboard-style titles.")
    ap.add_argument("--no-excerpts", action="store_true",
                    help="Skip body-excerpt fetch (faster, no relevance hints).")
    args = ap.parse_args()

    all_hits: dict[str, dict] = {}
    for term in args.terms:
        cql = f'space = {args.space} AND type = page AND text ~ "{term}"'
        try:
            rows = search(cql, args.limit)
        except Exception as e:
            print(f"skip {term!r}: {e}", file=sys.stderr)
            continue
        for r in rows:
            pid = r.get("id")
            if not pid or pid in all_hits:
                continue
            title = r.get("title") or ""
            if not args.no_noise_filter and DEFAULT_NOISE.search(title):
                continue
            all_hits[pid] = {
                "term": term,
                "title": title,
                "id": pid,
                "url": f"{BASE}{r.get('_links', {}).get('webui', '')}",
            }

    results = list(all_hits.values())
    if not args.no_excerpts:
        for h in results:
            h["excerpt"] = excerpt(h["id"])

    json.dump(results, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
