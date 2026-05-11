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
#   2. Launches mu in background
#   3. Spawns a DETACHED watcher daemon (nohup + disown) that:
#      - Polls the log for state=SUCCEEDED or FAILED
#      - Immediately pulls output via docker cp
#      - Kills mu (skips 10-min post-manifest wait)
#      - Sends macOS notification
#   4. Main script tails the log for live visibility, then exits
#      (the watcher daemon survives independently)

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
    BASE_PATH="catalog/config/prod/dlms-api/us-west-2/${DB_NAME}/${TABLE_NAME}"
  else
    BASE_PATH="catalog/config/prod/us-west-2/${DB_NAME}/${TABLE_NAME}"
  fi

  DDL_PATH="${BASE_PATH}/table.ddl"
  YAML_PATH="${BASE_PATH}/table.yaml"
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
        echo "    - ${schema}.${name} (Alation table_id: ${tid})"
        echo "      ${desc}"
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

# --- Launch mu ---

MU_LOG="$SCRIPT_DIR/.mu-run.log"
rm -f "$MU_LOG"

mu launch "$MANIFEST_FILE" --keep-container --env-file "$HOME/.config/mu/mu.env" > "$MU_LOG" 2>&1 &
MU_PID=$!
echo "[*] mu launched (PID: $MU_PID)"

# --- Spawn detached watcher daemon ---
# This process is fully independent — it survives even if the parent shell is killed.
# It watches the log, pulls output on success, kills mu, and notifies.

nohup bash -c '
MU_LOG="'"$MU_LOG"'"
MU_PID='"$MU_PID"'
OUTPUT_DIR="'"$OUTPUT_DIR"'"
DB_NAME="'"$DB_NAME"'"
TABLE_NAME="'"$TABLE_NAME"'"
REGISTRY_PATH="'"$REGISTRY_PATH"'"
WORKSPACE="/tmp/moonunit-workspace"

if [[ "$REGISTRY_PATH" == "dlms-api" ]]; then
  TABLE_PATH="catalog/config/prod/dlms-api/us-west-2/${DB_NAME}/${TABLE_NAME}"
else
  TABLE_PATH="catalog/config/prod/us-west-2/${DB_NAME}/${TABLE_NAME}"
fi

while true; do
  # Detect success
  if grep -q "state=SUCCEEDED" "$MU_LOG" 2>/dev/null; then
    sleep 2
    CONTAINER=$(docker ps -a --filter "name=mu-" --format "{{.Names}}" --latest 2>/dev/null | head -1)
    if [[ -n "$CONTAINER" ]]; then
      mkdir -p "$OUTPUT_DIR"
      # Try candidate paths in priority order — validate each with CREATE TABLE check
      DDL_FOUND=false
      for CANDIDATE in \
        "$WORKSPACE/repos/lake/${TABLE_PATH}/table.ddl" \
        "$WORKSPACE/table.ddl" \
        "$WORKSPACE/enriched-table.ddl"; do
        docker cp "$CONTAINER:$CANDIDATE" "$OUTPUT_DIR/enriched-table.ddl" 2>/dev/null || continue
        # Valid DDL must contain CREATE TABLE (not just a stage summary)
        if grep -q "CREATE" "$OUTPUT_DIR/enriched-table.ddl" 2>/dev/null; then
          DDL_FOUND=true
          break
        fi
      done
      if ! $DDL_FOUND; then
        # Last resort: try .md variant
        docker cp "$CONTAINER:$WORKSPACE/enriched-table.md" "$OUTPUT_DIR/enriched-table.md" 2>/dev/null || true
      fi
      docker cp "$CONTAINER:$WORKSPACE/research.md" "$OUTPUT_DIR/research.md" 2>/dev/null || true
      docker cp "$CONTAINER:$WORKSPACE/INPUT.md" "$OUTPUT_DIR/INPUT.md" 2>/dev/null || true
    fi
    kill "$MU_PID" 2>/dev/null
    osascript -e "display notification \"Output ready in output/\" with title \"Moon Unit Complete ✓\"" 2>/dev/null
    printf "\a"
    MISSION_ID=$(grep -o "lmsn_[A-Z0-9]*" "$MU_LOG" | head -1)
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo " ✓ MISSION SUCCEEDED ($MISSION_ID)"
    echo " Target: ${DB_NAME}.${TABLE_NAME}"
    echo " Output: $OUTPUT_DIR/"
    if [[ -f "$OUTPUT_DIR/enriched-table.ddl" ]]; then
      COL_COUNT=$(grep -c "COMMENT" "$OUTPUT_DIR/enriched-table.ddl" 2>/dev/null || echo "?")
      echo " Columns enriched: $COL_COUNT"
    fi
    echo "═══════════════════════════════════════════════════"
    exit 0
  fi

  # Detect failure
  if grep -q "mu fatal error" "$MU_LOG" 2>/dev/null; then
    ERROR=$(grep "fatal error" "$MU_LOG" | tail -1 | sed "s/.*fatal error: //" | cut -c1-80)
    osascript -e "display notification \"$ERROR\" with title \"Moon Unit Failed ✗\"" 2>/dev/null
    printf "\a"
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo " ✗ MISSION FAILED"
    echo " Target: ${DB_NAME}.${TABLE_NAME}"
    echo " Error: $ERROR"
    echo " Log: $MU_LOG"
    echo "═══════════════════════════════════════════════════"
    exit 1
  fi

  # If mu exited and we missed the state, check one more time
  if ! kill -0 "$MU_PID" 2>/dev/null; then
    if grep -q "state=SUCCEEDED" "$MU_LOG" 2>/dev/null; then
      continue  # loop back to the success handler
    fi
    echo "[!] mu exited without reaching terminal state"
    exit 1
  fi

  sleep 1
done
' > "$SCRIPT_DIR/.watcher.log" 2>&1 &
disown

WATCHER_PID=$!
echo "[*] Watcher daemon spawned (PID: $WATCHER_PID)"
echo "[*] Output will be pulled automatically on completion."
echo "[*] You'll get a macOS notification when done."
echo ""
echo "─────────────────────────────────────────────────────────────────"
echo "[*] Tailing live log (Ctrl+C to detach — mission continues)..."
echo "─────────────────────────────────────────────────────────────────"
echo ""

# Tail the log for live visibility until mu exits.
# User can Ctrl+C safely — watcher daemon still pulls output and notifies.
tail -f "$MU_LOG" 2>/dev/null &
TAIL_PID=$!

# Wait for mu to exit (watcher kills it on success/failure)
while kill -0 "$MU_PID" 2>/dev/null; do
  sleep 1
done

# mu is dead — stop tail and exit
kill $TAIL_PID 2>/dev/null
wait $TAIL_PID 2>/dev/null

echo ""
echo "[*] Mission complete. Check output/ for results."
