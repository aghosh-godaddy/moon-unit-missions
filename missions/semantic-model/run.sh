#!/bin/bash
# Launch the OSI Semantic Model Generation mission
#
# Usage:
#   ./run.sh <identifier> <name>   # Uses config/<identifier>/<name>.yaml
#   ./run.sh path/to/config.yaml   # Direct config file path
#
# Output:
#   output/<identifier>/<name>/
#     INPUT.md
#     gather.md
#     analyze.md
#     generate.md
#     validate.md
#     RESOLVED_TARGET.json
#     <schema>.<table>-osi-model.yaml
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_TEMPLATE="$SCRIPT_DIR/manifest.yaml"
MANIFEST_FILE="$SCRIPT_DIR/.manifest.generated.yaml"
OUTPUT_BASE="$SCRIPT_DIR/output"

usage() {
  echo "Usage: ./run.sh <identifier> <name>" >&2
  echo "       ./run.sh path/to/config.yaml" >&2
  echo "" >&2
  echo "Available configs:" >&2
  find "$SCRIPT_DIR/config" -name "*.yaml" -type f 2>/dev/null | sort | while read -r f; do
    rel="${f#$SCRIPT_DIR/config/}"
    ident=$(dirname "$rel")
    name=$(basename "$rel" .yaml)
    echo "  $ident $name" >&2
  done
}

# Resolve config file from arguments
if [[ $# -ge 2 ]]; then
  IDENTIFIER="$1"
  NAME="$2"
  CONFIG_FILE="$SCRIPT_DIR/config/$IDENTIFIER/$NAME.yaml"
elif [[ $# -eq 1 ]]; then
  CONFIG_FILE="$1"
  IDENTIFIER="$(basename "$(dirname "$CONFIG_FILE")")"
  NAME="$(basename "$CONFIG_FILE" .yaml)"
else
  usage
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE" >&2
  echo "" >&2
  usage
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

read_yaml_string() {
  local key="$1"
  local line
  line=$(grep -E "^[[:space:]]*${key}:" "$CONFIG_FILE" | head -1 || true)
  if [[ -z "$line" ]]; then
    echo ""
    return
  fi
  if echo "$line" | grep -qE ": *null( |$|#)"; then
    echo ""
    return
  fi
  echo "$line" | sed -E 's/.*: *"([^"]*)".*/\1/'
}

parse_github_blob_url() {
  local url="$1"
  local rest
  rest="${url#https://github.com/}"
  if [[ "$rest" == "$url" ]]; then
    echo "Error: pyspark_url must start with https://github.com/" >&2
    exit 1
  fi
  local org repo blob ref path
  org=$(echo "$rest" | awk -F'/' '{print $1}')
  repo=$(echo "$rest" | awk -F'/' '{print $2}')
  blob=$(echo "$rest" | awk -F'/' '{print $3}')
  ref=$(echo "$rest" | awk -F'/' '{print $4}')
  path=$(echo "$rest" | cut -d'/' -f5-)

  if [[ -z "$org" || -z "$repo" || "$blob" != "blob" || -z "$ref" || -z "$path" ]]; then
    echo "Error: unsupported pyspark_url format: $url" >&2
    exit 1
  fi

  SOURCE_ORG="$org"
  SOURCE_REPO="$repo"
  SOURCE_REF="$ref"
  SOURCE_PATH="$path"
  SOURCE_REPO_URL="https://github.com/${SOURCE_ORG}/${SOURCE_REPO}.git"
}

read_yaml_notes() {
  local in_notes=false
  local line
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^notes:[[:space:]]*\|'; then
      in_notes=true
      continue
    fi
    if $in_notes; then
      if echo "$line" | grep -qE '^[a-zA-Z0-9_]+:'; then
        break
      fi
      printf '%s\n' "$line"
    fi
  done < "$CONFIG_FILE"
}

read_yaml_max_queries() {
  local val
  val=$(grep -E '^[[:space:]]*max_queries:' "$CONFIG_FILE" | head -1 | sed -E 's/.*max_queries: *//;s/ *#.*//' || true)
  if [[ -z "$val" ]]; then
    echo "5"
  else
    echo "$val"
  fi
}

generate_confluence_section() {
  local in_block=false
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^[[:space:]]*confluence_pages:'; then
      in_block=true
      continue
    fi
    if $in_block; then
      if echo "$line" | grep -qE '^[[:space:]]*[a-zA-Z0-9_]+:'; then
        break
      fi
      if echo "$line" | grep -qE '^[[:space:]]*-[[:space:]]*url:'; then
        local url
        url=$(echo "$line" | sed -E 's/.*url: *"([^"]*)".*/\1/')
        echo "    - ${url}"
      elif echo "$line" | grep -qE '^[[:space:]]*description:'; then
        local desc
        desc=$(echo "$line" | sed -E 's/.*description: *"([^"]*)".*/\1/')
        echo "      (${desc})"
      fi
    fi
  done < "$CONFIG_FILE"
}

generate_input_content() {
  local lake_override semantic_model_name alation_enabled alation_search_query alation_max_queries
  local notes_content notes_section
  lake_override=$(read_yaml_string "lake_table_override")
  semantic_model_name=$(read_yaml_string "semantic_model_name")

  alation_enabled=$(grep -E '^[[:space:]]*enabled:' "$CONFIG_FILE" | head -1 | sed -E 's/.*enabled: *//;s/ *#.*//')
  alation_search_query=$(read_yaml_string "search_query")
  alation_max_queries=$(read_yaml_max_queries)

  notes_content=$(read_yaml_notes)
  if [[ -n "$(echo "$notes_content" | tr -d '[:space:]')" ]]; then
    local indented_notes
    indented_notes=$(echo "$notes_content" | sed 's/^  /    /')
    notes_section=$(printf '    ## USER NOTES (HIGHEST PRIORITY)\n    These notes come directly from the table owner/expert. They take priority over\n    Confluence, Alation, and other secondary sources — but NOT over PySpark/DAG code.\n    Incorporate them into OSI descriptions, ai_context, and metrics.\n\n%s' "$indented_notes")
  else
    notes_section=""
  fi

  local confluence_section
  confluence_section=$(generate_confluence_section)
  if [[ -z "$confluence_section" ]]; then
    confluence_section="    - None provided"
  fi

  cat <<EOF
    Generate an OSI-compliant semantic model (YAML) for a Data Lake table.
    The PySpark script and its calling DAG are the source of truth.
    Output must conform to OSI Core Spec v0.2.0.dev0 (see docs/osi-spec-reference.md).
${notes_section:+
${notes_section}
}
    ## TARGET (INPUT)
    - Identifier: ${IDENTIFIER}
    - Name: ${NAME}
    - PySpark GitHub URL: ${PYSPARK_URL}
    - Source repo URL: ${SOURCE_REPO_URL}
    - Source git ref: ${SOURCE_REF}
    - Source file path: ${SOURCE_PATH}
    - Lake table override (optional): ${lake_override:-}
    - Semantic model name (optional): ${semantic_model_name:-}

    ## WORKSPACE REPOS (container)
    - Source repo folder: repos/${SOURCE_REPO}/
    - Lake repo folder: repos/lake/

    ## CONFLUENCE PAGES
${confluence_section}

    ## ALATION
    - Enabled: ${alation_enabled:-false}
    - Search query override: ${alation_search_query:-}
    - Max queries (for metric/usage context): ${alation_max_queries}
EOF
}

# Parse the PySpark URL early so SOURCE_* vars are available
PYSPARK_URL=$(read_yaml_string "pyspark_url")
if [[ -z "$PYSPARK_URL" ]]; then
  echo "Error: target.pyspark_url is required in $CONFIG_FILE" >&2
  exit 1
fi
parse_github_blob_url "$PYSPARK_URL"

# Set output directory
OUTPUT_DIR="$OUTPUT_BASE/${IDENTIFIER}/${NAME}"
mkdir -p "$OUTPUT_DIR"

# Assemble generated manifest with dynamic input content + source repo URL
INPUT_CONTENT=$(generate_input_content)

while IFS= read -r line; do
  if echo "$line" | grep -q '^  url:' && echo "$line" | grep -q '__GENERATED_BY_RUN_SH__'; then
    echo "  url: ${SOURCE_REPO_URL}"
  elif echo "$line" | grep -q '^  content:' && echo "$line" | grep -q '__GENERATED_BY_RUN_SH__'; then
    echo "  content: |"
    echo "$INPUT_CONTENT"
  elif echo "$line" | grep -q '^    - url: "__GENERATED_BY_RUN_SH__SOURCE_REPO_URL__"'; then
    echo "    - url: ${SOURCE_REPO_URL}"
  else
    echo "$line"
  fi
done < "$MANIFEST_TEMPLATE" > "$MANIFEST_FILE"

echo "=== OSI Semantic Model Generation Mission ==="
echo "Config:    $CONFIG_FILE"
echo "Target:    ${IDENTIFIER}/${NAME}"
echo "PySpark:   ${SOURCE_ORG}/${SOURCE_REPO}@${SOURCE_REF}:${SOURCE_PATH}"
echo "Manifest:  $MANIFEST_FILE"
echo "Output:    $OUTPUT_DIR"
echo "AWS:       $AWS_PROFILE"
echo ""

if ! mu lint "$MANIFEST_FILE" >/dev/null 2>&1; then
  echo "Error: manifest failed mu lint:" >&2
  mu lint "$MANIFEST_FILE" >&2
  exit 1
fi

MU_LOG="$SCRIPT_DIR/.mu-run.log"
WORKSPACE_DIR="$OUTPUT_DIR/.workspace"
rm -f "$MU_LOG"
rm -rf "$WORKSPACE_DIR"
rm -f "$OUTPUT_DIR"/{INPUT,gather,analyze,generate,validate}.md \
      "$OUTPUT_DIR"/RESOLVED_TARGET.json \
      "$OUTPUT_DIR"/*-osi-model.yaml
mkdir -p "$WORKSPACE_DIR/docs"
cp "$SCRIPT_DIR/docs/osi-spec-reference.md" "$WORKSPACE_DIR/docs/osi-spec-reference.md"

cleanup() {
  local sig="${1:-}"
  if [[ -n "${MU_PID:-}" ]] && kill -0 "$MU_PID" 2>/dev/null; then
    kill "$MU_PID" 2>/dev/null || true
  fi
  if [[ -n "${TAIL_PID:-}" ]] && kill -0 "$TAIL_PID" 2>/dev/null; then
    kill "$TAIL_PID" 2>/dev/null || true
    wait "$TAIL_PID" 2>/dev/null || true
  fi
  if [[ -f "${MU_LOG:-/dev/null}" ]]; then
    local cn
    cn=$(grep -oE 'mu-[0-9]+' "$MU_LOG" 2>/dev/null | head -1 || true)
    if [[ -n "$cn" ]]; then
      docker stop --time 5 "$cn" >/dev/null 2>&1 || true
      docker rm   --force  "$cn" >/dev/null 2>&1 || true
    fi
  fi
  if [[ "$sig" == "INT" || "$sig" == "TERM" ]]; then
    echo ""
    echo "[!] Interrupted — workspace left at $WORKSPACE_DIR for inspection."
    exit 130
  fi
}
trap 'cleanup INT'  INT
trap 'cleanup TERM' TERM

# Merge mu.env with mission .env.local
MU_ENV_FILE="$SCRIPT_DIR/.mu-env.merged"
{
  if [[ -f "$HOME/.config/mu/mu.env" ]]; then
    cat "$HOME/.config/mu/mu.env"
  fi
  echo ""
  grep -E '^(MOONUNIT_|ALATION_)' "$ENV_FILE" 2>/dev/null || true
} > "$MU_ENV_FILE"

mu launch "$MANIFEST_FILE" \
  --mount-workspace "$WORKSPACE_DIR" \
  --keep-container \
  --env-file "$MU_ENV_FILE" \
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

TERMINAL=""
while true; do
  if grep -q "state=SUCCEEDED" "$MU_LOG" 2>/dev/null; then
    TERMINAL="SUCCEEDED"
    break
  fi
  if grep -q "state=FAILED\\|mu fatal error" "$MU_LOG" 2>/dev/null; then
    TERMINAL="FAILED"
    break
  fi
  if ! kill -0 "$MU_PID" 2>/dev/null; then
    TERMINAL="EXITED"
    break
  fi
  sleep 1
done

kill "$TAIL_PID" 2>/dev/null || true
wait "$TAIL_PID" 2>/dev/null || true

collect_artifact() {
  local src="$1" dst="$2"
  [[ -f "$src" ]] || return 1
  cp "$src" "$dst"
}

copy_stage_outputs() {
  collect_artifact "$WORKSPACE_DIR/INPUT.md"    "$OUTPUT_DIR/INPUT.md"    || true
  collect_artifact "$WORKSPACE_DIR/gather.md"   "$OUTPUT_DIR/gather.md"   || true
  collect_artifact "$WORKSPACE_DIR/analyze.md"  "$OUTPUT_DIR/analyze.md"  || true
  collect_artifact "$WORKSPACE_DIR/generate.md" "$OUTPUT_DIR/generate.md" || true
  collect_artifact "$WORKSPACE_DIR/validate.md" "$OUTPUT_DIR/validate.md" || true
  collect_artifact "$WORKSPACE_DIR/RESOLVED_TARGET.json" "$OUTPUT_DIR/RESOLVED_TARGET.json" || true
}

resolve_output_filename() {
  local resolved="$OUTPUT_DIR/RESOLVED_TARGET.json"
  if [[ -f "$resolved" ]]; then
    local schema table_u
    schema=$(node -e "const j=require('$resolved'); console.log(j.schema||'');" 2>/dev/null || true)
    table_u=$(node -e "const j=require('$resolved'); console.log(j.table_underscore||'');" 2>/dev/null || true)
    if [[ -n "$schema" && -n "$table_u" ]]; then
      echo "${schema}.${table_u}-osi-model.yaml"
      return
    fi
  fi
  echo "unknown.unknown-osi-model.yaml"
}

if [[ "$TERMINAL" == "SUCCEEDED" ]]; then
  copy_stage_outputs

  if [[ -f "$WORKSPACE_DIR/SEMANTIC_MODEL.yaml" ]]; then
    OUT_NAME=$(resolve_output_filename)
    cp "$WORKSPACE_DIR/SEMANTIC_MODEL.yaml" "$OUTPUT_DIR/$OUT_NAME"
  fi

  kill "$MU_PID" 2>/dev/null || true
  CONTAINER_NAME=$(grep -oE 'mu-[0-9]+' "$MU_LOG" 2>/dev/null | head -1 || true)
  if [[ -n "$CONTAINER_NAME" ]]; then
    docker stop --time 5 "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm   --force  "$CONTAINER_NAME" >/dev/null 2>&1 || true
  fi
  wait "$MU_PID" 2>/dev/null || true

  rm -rf "$WORKSPACE_DIR" 2>/dev/null || true
  if [[ -d "$WORKSPACE_DIR" ]]; then
    sleep 2
    rm -rf "$WORKSPACE_DIR" 2>/dev/null || true
  fi

  osascript -e "display notification \"Output ready in output/\" with title \"Moon Unit Complete ✓\"" 2>/dev/null || true
  printf "\a"
  MISSION_ID=$(grep -o "lmsn_[A-Z0-9]*" "$MU_LOG" | head -1 || true)
  echo ""
  echo "═══════════════════════════════════════════════════"
  echo " ✓ MISSION SUCCEEDED ${MISSION_ID:+($MISSION_ID)}"
  echo " Target: ${IDENTIFIER}/${NAME}"
  echo " Output: $OUTPUT_DIR/"
  echo "═══════════════════════════════════════════════════"
  exit 0
fi

if [[ "$TERMINAL" == "FAILED" ]]; then
  copy_stage_outputs
  ERROR=$(grep "fatal error\\|state=FAILED" "$MU_LOG" | tail -1 | sed "s/.*fatal error: //" | cut -c1-160)
  kill "$MU_PID" 2>/dev/null || true
  osascript -e "display notification \"$ERROR\" with title \"Moon Unit Failed ✗\"" 2>/dev/null || true
  printf "\a"
  echo ""
  echo "═══════════════════════════════════════════════════"
  echo " ✗ MISSION FAILED"
  echo " Target: ${IDENTIFIER}/${NAME}"
  echo " Error: $ERROR"
  echo " Workspace: $WORKSPACE_DIR (left for debugging)"
  echo " Log: $MU_LOG"
  echo " Partial outputs: $OUTPUT_DIR/ (stage outputs if reached)"
  echo "═══════════════════════════════════════════════════"
  exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo " ! mu exited without a terminal state"
echo " Workspace: $WORKSPACE_DIR (left for debugging)"
echo " Log: $MU_LOG"
echo "═══════════════════════════════════════════════════"
exit 1
