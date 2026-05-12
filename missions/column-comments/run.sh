#!/bin/bash
# Launch the Column Comments Enrichment mission
#
# Usage:
#   ./run.sh <db_name> <table_name>   # Uses config/<db_name>/<table_name>.yaml
#   ./run.sh customer360 customer-lifecycle-vw
#
# Prerequisites:
#   - mu CLI installed
#   - Docker running (colima start)
#   - AWS_PROFILE set to a non-PCI account
#   - ~/.config/mu/mu.env configured
#
# Architecture:
#   1. Reads config/<db>/<table>.yaml and generates .manifest.generated.yaml
#   2. Launches mu with --mount-workspace pointing at a hidden host directory.
#      The container's /tmp/moonunit-workspace is bind-mounted to the host, so
#      every file the agent writes (research.md, *-table.ddl, cloned repos)
#      appears on the host filesystem as it happens — no docker cp needed.
#   3. Tails the log, snapshots the original DDL from the cloned repo once it
#      appears, polls for state=SUCCEEDED or FAILED.
#   4. On success: copies artifacts out of the workspace, generates
#      ddl-comparison.md, kills mu (skips the 10-min post-manifest wait),
#      sends a macOS notification, and cleans up the workspace.
#      On failure: reports the error and leaves the workspace for debugging.
#      On Ctrl+C: kills mu, cleans up, exits.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_TEMPLATE="$SCRIPT_DIR/manifest.yaml"
MANIFEST_FILE="$SCRIPT_DIR/.manifest.generated.yaml"
OUTPUT_BASE="$SCRIPT_DIR/output"

# Resolve config file from arguments
if [[ $# -ge 2 ]]; then
  CONFIG_FILE="$SCRIPT_DIR/config/$1/$2.yaml"
elif [[ $# -eq 1 ]]; then
  # Allow passing a direct path to a config file
  CONFIG_FILE="$1"
else
  echo "Usage: ./run.sh <db_name> <table_name>" >&2
  echo "       ./run.sh path/to/config.yaml" >&2
  echo "" >&2
  echo "Available configs:" >&2
  find "$SCRIPT_DIR/config" -name "*.yaml" -type f 2>/dev/null | sort | while read -r f; do
    rel="${f#$SCRIPT_DIR/config/}"
    db=$(dirname "$rel")
    tbl=$(basename "$rel" .yaml)
    echo "  $db $tbl" >&2
  done
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE" >&2
  echo "" >&2
  echo "Available configs:" >&2
  find "$SCRIPT_DIR/config" -name "*.yaml" -type f 2>/dev/null | sort | while read -r f; do
    rel="${f#$SCRIPT_DIR/config/}"
    db=$(dirname "$rel")
    tbl=$(basename "$rel" .yaml)
    echo "  $db $tbl" >&2
  done
  exit 1
fi

# Validate prerequisites
if ! command -v mu &>/dev/null; then
  echo "Error: mu CLI not found. Install it first." >&2
  exit 1
fi

if ! docker info &>/dev/null 2>&1; then
  echo "Error: Docker is not running. Start it with 'colima start'." >&2
  exit 1
fi

# Load environment variables from .env.local file
ENV_FILE="$SCRIPT_DIR/.env.local"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "Error: .env.local not found at $ENV_FILE" >&2
  exit 1
fi

if [[ -z "${AWS_PROFILE:-}" ]]; then
  export AWS_PROFILE=claude-p1
fi

export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-west-2}"
export AWS_REGION="${AWS_REGION:-us-west-2}"

# --- Parse config.yaml and generate manifest input.content ---

parse_config() {
  # Extract values from config.yaml using simple grep/sed (no yq dependency)
  DB_NAME=$(grep 'db_name:' "$CONFIG_FILE" | head -1 | sed 's/.*db_name: *"\([^"]*\)".*/\1/')
  TABLE_NAME=$(grep 'table_name:' "$CONFIG_FILE" | head -1 | sed 's/.*table_name: *"\([^"]*\)".*/\1/')
  REGISTRY_PATH=$(grep 'registry_path:' "$CONFIG_FILE" | head -1 | sed 's/.*registry_path: *"\([^"]*\)".*/\1/')
  ALATION_ENABLED=$(grep 'enabled:' "$CONFIG_FILE" | head -1 | sed 's/.*enabled: *//')

  # Determine DDL/YAML paths based on registry_path variant
  if [[ "$REGISTRY_PATH" == "dlms-api" ]]; then
    TABLE_REPO_PATH="catalog/config/prod/dlms-api/us-west-2/${DB_NAME}/${TABLE_NAME}"
  else
    TABLE_REPO_PATH="catalog/config/prod/us-west-2/${DB_NAME}/${TABLE_NAME}"
  fi

  DDL_PATH="${TABLE_REPO_PATH}/table.ddl"
  YAML_PATH="${TABLE_REPO_PATH}/table.yaml"
}

generate_confluence_section() {
  # Extract confluence pages from config.yaml
  local in_confluence=false
  while IFS= read -r line; do
    if echo "$line" | grep -q "^confluence_pages:"; then
      in_confluence=true
      continue
    fi
    if $in_confluence; then
      if echo "$line" | grep -qE "^[a-z]"; then
        break
      fi
      if echo "$line" | grep -q '  - url:'; then
        local url=$(echo "$line" | sed 's/.*url: *"\([^"]*\)".*/\1/')
        echo "    - ${url}"
      elif echo "$line" | grep -q 'description:'; then
        local desc=$(echo "$line" | sed 's/.*description: *"\([^"]*\)".*/\1/')
        echo "      (${desc})"
      fi
    fi
  done < "$CONFIG_FILE"
}

generate_reference_section() {
  # Extract reference tables from config.yaml
  local in_ref=false
  local has_entries=false
  local name="" schema="" tid=""
  while IFS= read -r line; do
    if echo "$line" | grep -q "^reference_tables:"; then
      in_ref=true
      if echo "$line" | grep -q "\[\]"; then
        echo "    - None configured"
        return
      fi
      continue
    fi
    if $in_ref; then
      if echo "$line" | grep -qE "^[a-z]"; then
        break
      fi
      if echo "$line" | grep -q '  - name:'; then
        name=$(echo "$line" | sed 's/.*name: *"\([^"]*\)".*/\1/')
        has_entries=true
      elif echo "$line" | grep -q 'schema:'; then
        schema=$(echo "$line" | sed 's/.*schema: *"\([^"]*\)".*/\1/')
      elif echo "$line" | grep -q 'alation_table_id:'; then
        tid=$(echo "$line" | sed 's/.*alation_table_id: *//')
      elif echo "$line" | grep -q 'description:'; then
        local desc=$(echo "$line" | sed 's/.*description: *"\([^"]*\)".*/\1/')
        if [[ -n "$tid" ]]; then
          echo "    - ${schema}.${name} (Alation table_id: ${tid})"
        else
          echo "    - ${schema}.${name} (look up in Alation by name)"
        fi
        echo "      ${desc}"
        tid=""  # reset so the next reference table doesn't inherit
      fi
    fi
  done < "$CONFIG_FILE"
  if ! $has_entries; then
    echo "    - None configured"
  fi
}

generate_input_content() {
  parse_config

  local confluence_section
  confluence_section=$(generate_confluence_section)

  local reference_section
  reference_section=$(generate_reference_section)

  cat <<EOF
    Enrich column descriptions in a Data Lake table DDL file following the
    Data Governance Council's Column Description Standard for Data Lake Assets.

    ## TARGET TABLE
    - Database: ${DB_NAME}
    - Table: ${TABLE_NAME}
    - DDL path: ${DDL_PATH}
    - YAML path: ${YAML_PATH}

    ## CONFLUENCE PAGES
${confluence_section}
    ## REFERENCE TABLES
${reference_section}
    ## ALATION
    - Enabled: ${ALATION_ENABLED}
    - User ID: 213
    - Refresh token: use \$ALATION_REFRESH_TOKEN env var
    - Certified Data Dictionary: Document Folder ID 6
EOF
}

# Parse config first (sets DB_NAME, TABLE_NAME, REGISTRY_PATH, etc.)
parse_config

# Set output directory based on target table
OUTPUT_DIR="$OUTPUT_BASE/${DB_NAME}/${TABLE_NAME}"
mkdir -p "$OUTPUT_DIR"

# Generate the input content and inject into manifest template
INPUT_CONTENT=$(generate_input_content)

# Assemble the generated manifest from template + dynamic content
while IFS= read -r line; do
  if echo "$line" | grep -q '^  content:'; then
    echo "  content: |"
    echo "$INPUT_CONTENT"
  else
    echo "$line"
  fi
done < "$MANIFEST_TEMPLATE" > "$MANIFEST_FILE"

echo "=== Column Comments Enrichment Mission ==="
echo "Target:   ${DB_NAME}.${TABLE_NAME}"
echo "Manifest: $MANIFEST_FILE"
echo "Output:   $OUTPUT_DIR"
echo "AWS:      $AWS_PROFILE"
echo ""

# --- Pre-flight: validate manifest ---

if ! mu lint "$MANIFEST_FILE" >/dev/null 2>&1; then
  echo "Error: manifest failed mu lint:" >&2
  mu lint "$MANIFEST_FILE" >&2
  exit 1
fi

# --- Launch mu with host-mounted workspace ---
#
# mu launch --mount-workspace <path> bind-mounts <path> into the container at
# /tmp/moonunit-workspace. Everything the agent writes — research.md, DDL
# outputs, cloned repos — appears on the host filesystem in real time, so the
# launcher never needs docker cp or to race the container's lifecycle.

MU_LOG="$SCRIPT_DIR/.mu-run.log"
WORKSPACE_DIR="$OUTPUT_DIR/.workspace"
rm -f "$MU_LOG"
rm -rf "$WORKSPACE_DIR"
# Wipe prior-run artifacts so the mid-pipeline snapshot guards (`[[ ! -f ]]`)
# actually trigger on fresh files instead of keeping stale ones.
rm -f "$OUTPUT_DIR"/{original,enriched,validated}-table.ddl \
      "$OUTPUT_DIR"/{research.md,INPUT.md,ddl-comparison.md}
mkdir -p "$WORKSPACE_DIR"

cleanup() {
  local sig="${1:-}"
  if [[ -n "${MU_PID:-}" ]] && kill -0 "$MU_PID" 2>/dev/null; then
    kill "$MU_PID" 2>/dev/null || true
  fi
  if [[ -n "${TAIL_PID:-}" ]] && kill -0 "$TAIL_PID" 2>/dev/null; then
    kill "$TAIL_PID" 2>/dev/null || true
    wait "$TAIL_PID" 2>/dev/null || true
  fi
  if [[ "$sig" == "INT" || "$sig" == "TERM" ]]; then
    echo ""
    echo "[!] Interrupted — workspace left at $WORKSPACE_DIR for inspection."
    exit 130
  fi
}
trap 'cleanup INT'  INT
trap 'cleanup TERM' TERM

mu launch "$MANIFEST_FILE" \
  --mount-workspace "$WORKSPACE_DIR" \
  --keep-container \
  --env-file "$HOME/.config/mu/mu.env" \
  > "$MU_LOG" 2>&1 &
MU_PID=$!
echo "[*] mu launched (PID: $MU_PID)"
echo "[*] Workspace mounted at: $WORKSPACE_DIR"
echo ""
echo "─────────────────────────────────────────────────────────────────"
echo "[*] Tailing log (Ctrl+C to cancel mission)"
echo "─────────────────────────────────────────────────────────────────"
echo ""

tail -f "$MU_LOG" 2>/dev/null &
TAIL_PID=$!

# --- Track the in-repo DDL at key stage boundaries ---
# The enrich stage modifies table.ddl in-place in the cloned repo. The validate
# stage may or may not further modify it. We snapshot at three points:
#   1. original-table.ddl — after bootstrap, before the enrich stage begins.
#   2. enriched-table.ddl — after enrich finishes, before validate begins.
#   3. validated-table.ddl — after validate finishes (final repo state).
# All three paths point to the same in-repo file at different moments in time.
REPO_DDL="$WORKSPACE_DIR/repos/lake/$TABLE_REPO_PATH/table.ddl"

# --- Wait for a terminal state or mu exit, snapshotting at stage boundaries ---

TERMINAL=""  # SUCCEEDED | FAILED | EXITED
while true; do
  # Snapshot original DDL as soon as the clone finishes and the file appears,
  # before the enrich stage modifies it.
  if [[ ! -f "$OUTPUT_DIR/original-table.ddl" && -f "$REPO_DDL" ]]; then
    cp "$REPO_DDL" "$OUTPUT_DIR/original-table.ddl"
  fi
  # Snapshot post-enrich DDL when the log reports the enrich stage finished.
  if [[ ! -f "$OUTPUT_DIR/enriched-table.ddl" ]] \
      && grep -q "Finished stage: enrich" "$MU_LOG" 2>/dev/null \
      && [[ -f "$REPO_DDL" ]]; then
    cp "$REPO_DDL" "$OUTPUT_DIR/enriched-table.ddl"
  fi

  if grep -q "state=SUCCEEDED" "$MU_LOG" 2>/dev/null; then
    TERMINAL="SUCCEEDED"
    break
  fi
  if grep -q "state=FAILED\|mu fatal error" "$MU_LOG" 2>/dev/null; then
    TERMINAL="FAILED"
    break
  fi
  if ! kill -0 "$MU_PID" 2>/dev/null; then
    TERMINAL="EXITED"
    break
  fi
  sleep 1
done

# Stop tail before printing our own banner.
kill "$TAIL_PID" 2>/dev/null || true
wait "$TAIL_PID" 2>/dev/null || true

# --- Collect artifacts (SUCCEEDED only) ---

collect_artifact() {
  local src="$1" dst="$2" require_create="${3:-false}"
  [[ -f "$src" ]] || return 1
  if $require_create && ! head -1 "$src" | grep -q "^CREATE"; then
    return 1
  fi
  cp "$src" "$dst"
}

generate_comparison_report() {
  # Defensive: `set -x` / `set -v` inherited from the invoking shell leaks
  # xtrace output into the `{ ... } > "$report"` block below, corrupting the
  # markdown table. Turn both off for the duration of this function.
  set +xv
  local report="$OUTPUT_DIR/ddl-comparison.md"
  local orig="$OUTPUT_DIR/original-table.ddl"
  local enriched="$OUTPUT_DIR/enriched-table.ddl"
  local validated="$OUTPUT_DIR/validated-table.ddl"
  [[ -f "$validated" ]] || return 0

  extract_comment_for() {
    local file="$1" col="$2"
    [[ -f "$file" ]] || { echo "—"; return; }
    local line
    line=$(grep -E "^[, ]*${col}[[:space:]]" "$file" 2>/dev/null | head -1)
    if echo "$line" | grep -q "COMMENT"; then
      echo "$line" | sed "s/.*COMMENT .//;s/.[,)]*$//"
    else
      echo "—"
    fi
  }

  {
    echo "# Column Comments Comparison: ${DB_NAME}.${TABLE_NAME}"
    echo ""
    echo "Generated: $(date +%Y-%m-%dT%H:%M)"
    echo ""
    echo "| # | Column | Original | Enriched | Validated | Len |"
    echo "|---|--------|----------|----------|-----------|-----|"
    local col_num=0
    while IFS= read -r validated_line; do
      echo "$validated_line" | grep -q "COMMENT" || continue
      col_num=$((col_num + 1))
      local col_name orig_c enr_c val_c val_len
      col_name=$(echo "$validated_line" | awk '{print $1}' | sed 's/^,//')
      orig_c=$(extract_comment_for "$orig" "$col_name")
      enr_c=$(extract_comment_for "$enriched" "$col_name")
      val_c=$(echo "$validated_line" | sed "s/.*COMMENT .//;s/.[,)]*$//")
      val_len=${#val_c}
      orig_c=$(echo "$orig_c" | sed 's/|/\\|/g')
      enr_c=$(echo "$enr_c" | sed 's/|/\\|/g')
      val_c=$(echo "$val_c" | sed 's/|/\\|/g')
      echo "| $col_num | \`$col_name\` | $orig_c | $enr_c | $val_c | $val_len |"
    done < "$validated"
  } > "$report"
}

if [[ "$TERMINAL" == "SUCCEEDED" ]]; then
  collect_artifact "$WORKSPACE_DIR/research.md" "$OUTPUT_DIR/research.md" || true
  collect_artifact "$WORKSPACE_DIR/INPUT.md"    "$OUTPUT_DIR/INPUT.md"    || true

  # Snapshot the final validated DDL from the cloned repo.
  if [[ -f "$REPO_DDL" ]]; then
    cp "$REPO_DDL" "$OUTPUT_DIR/validated-table.ddl"
  fi
  # If the mid-pipeline enrich snapshot never captured (stage finished between
  # loop iterations), fall back to treating the final DDL as enriched too.
  if [[ ! -f "$OUTPUT_DIR/enriched-table.ddl" && -f "$OUTPUT_DIR/validated-table.ddl" ]]; then
    cp "$OUTPUT_DIR/validated-table.ddl" "$OUTPUT_DIR/enriched-table.ddl"
  fi

  # 255-char compliance check on the validated DDL (authoritative output).
  FINAL_DDL="$OUTPUT_DIR/validated-table.ddl"
  [[ -f "$FINAL_DDL" ]] || FINAL_DDL="$OUTPUT_DIR/enriched-table.ddl"
  if [[ -f "$FINAL_DDL" ]]; then
    OVER_LIMIT=$(grep "COMMENT" "$FINAL_DDL" | while IFS= read -r l; do
      c=$(echo "$l" | sed "s/.*COMMENT .//;s/.[,)]*$//")
      [[ ${#c} -gt 255 ]] && echo "1" || true
    done | wc -l | tr -d " ")
    if [[ "$OVER_LIMIT" -gt 0 ]]; then
      echo " [!] WARNING: $OVER_LIMIT comments still exceed 255 chars"
    fi
  fi

  generate_comparison_report

  # Stop the container; we already have everything we need.
  kill "$MU_PID" 2>/dev/null || true

  # Workspace is no longer needed. Keep .workspace out of the way.
  rm -rf "$WORKSPACE_DIR"

  osascript -e "display notification \"Output ready in output/\" with title \"Moon Unit Complete ✓\"" 2>/dev/null
  printf "\a"
  MISSION_ID=$(grep -o "lmsn_[A-Z0-9]*" "$MU_LOG" | head -1)
  echo ""
  echo "═══════════════════════════════════════════════════"
  echo " ✓ MISSION SUCCEEDED ($MISSION_ID)"
  echo " Target: ${DB_NAME}.${TABLE_NAME}"
  echo " Output: $OUTPUT_DIR/"
  if [[ -f "$FINAL_DDL" ]]; then
    COL_COUNT=$(grep -c "COMMENT" "$FINAL_DDL" 2>/dev/null || echo "?")
    echo " Columns enriched: $COL_COUNT"
  fi
  echo "═══════════════════════════════════════════════════"
  exit 0
fi

if [[ "$TERMINAL" == "FAILED" ]]; then
  ERROR=$(grep "fatal error\|state=FAILED" "$MU_LOG" | tail -1 | sed "s/.*fatal error: //" | cut -c1-120)
  kill "$MU_PID" 2>/dev/null || true
  osascript -e "display notification \"$ERROR\" with title \"Moon Unit Failed ✗\"" 2>/dev/null
  printf "\a"
  echo ""
  echo "═══════════════════════════════════════════════════"
  echo " ✗ MISSION FAILED"
  echo " Target: ${DB_NAME}.${TABLE_NAME}"
  echo " Error: $ERROR"
  echo " Workspace: $WORKSPACE_DIR (left for debugging)"
  echo " Log: $MU_LOG"
  echo "═══════════════════════════════════════════════════"
  exit 1
fi

# TERMINAL == "EXITED" — mu exited on its own without reaching SUCCEEDED/FAILED.
echo ""
echo "═══════════════════════════════════════════════════"
echo " ! mu exited without a terminal state"
echo " Workspace: $WORKSPACE_DIR (left for debugging)"
echo " Log: $MU_LOG"
echo "═══════════════════════════════════════════════════"
exit 1
