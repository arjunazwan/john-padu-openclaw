#!/usr/bin/env bash
# install_john.sh — Module 1: Pre‑flight Check for John PADU Installer
# Senior‑Dev style: clear functions, version pinning, safe .gitignore logic
# Purpose: report system readiness (Node >=18, Python >=3.10) and create .gitignore

set -euo pipefail
IFS=$'\n\t'

REQUIRED_NODE_MAJOR=18
REQUIRED_PY_MAJOR=3
REQUIRED_PY_MINOR=10

WORKSPACE_DIR="$(pwd)"
GITIGNORE_FILE="$WORKSPACE_DIR/.gitignore"
ARCHIVE_ENTRY="_archive/"
ENV_ENTRY="env_config.json"

# Utility: print header
info() { printf "[INFO] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*"; }
err() { printf "[ERROR] %s\n" "$*"; }

# Version helpers
parse_node_major() {
  if ! command -v node >/dev/null 2>&1; then
    echo ""; return 1
  fi
  v=$(node --version 2>/dev/null || true) # e.g. v18.16.0
  v=${v#v}
  major=${v%%.*}
  echo "$major"
}

parse_python_major_minor() {
  # Favor newer homebrew versions explicitly
  local target_py=""
  if [ -x "/opt/homebrew/bin/python3.13" ]; then
    target_py="/opt/homebrew/bin/python3.13"
  elif [ -x "/opt/homebrew/bin/python3.12" ]; then
    target_py="/opt/homebrew/bin/python3.12"
  elif command -v python3 >/dev/null 2>&1; then
    target_py=$(command -v python3)
  else
    echo ""; return 1
  fi
  
  local v_str=$("$target_py" --version 2>&1 || true)
  # Extract "3.13" from "Python 3.13.13"
  local ver_part=$(echo "$v_str" | awk '{print $2}')
  local maj_v=$(echo "$ver_part" | cut -d. -f1)
  local min_v=$(echo "$ver_part" | cut -d. -f2)
  echo "$maj_v:$min_v"
}

check_node() {
  maj=$(parse_node_major 2>/dev/null || true)
  if [ -z "$maj" ]; then
    echo "missing"
    return 1
  fi
  if [ "$maj" -lt "$REQUIRED_NODE_MAJOR" ]; then
    echo "bad_version"
    return 2
  fi
  echo "ok"
  return 0
}

check_python() {
  pm=$(parse_python_major_minor 2>/dev/null || true)
  if [ -z "$pm" ]; then
    echo "missing"
    return 1
  fi
  IFS=: read -r maj min <<<"$pm"
  maj=${maj:-0}
  min=${min:-0}
  if [ "$maj" -gt "$REQUIRED_PY_MAJOR" ] || { [ "$maj" -eq "$REQUIRED_PY_MAJOR" ] && [ "$min" -ge "$REQUIRED_PY_MINOR" ]; }; then
    echo "ok"
    return 0
  else
    echo "bad_version"
    return 2
  fi
}

# Create or update .gitignore safely (idempotent)
ensure_gitignore() {
  info "Ensuring .gitignore has safe entries: $ARCHIVE_ENTRY and $ENV_ENTRY"
  touch "$GITIGNORE_FILE"
  # add entry if missing
  grep -Fxq "$ARCHIVE_ENTRY" "$GITIGNORE_FILE" || echo "$ARCHIVE_ENTRY" >> "$GITIGNORE_FILE"
  grep -Fxq "$ENV_ENTRY" "$GITIGNORE_FILE" || echo "$ENV_ENTRY" >> "$GITIGNORE_FILE"
  info ".gitignore updated at $GITIGNORE_FILE"
}

# Report summary
report() {
  echo
  info "Pre-flight Summary"
  echo "---------------------"
  # OS info
  uname_s=$(uname -s 2>/dev/null || true)
  uname_r=$(uname -r 2>/dev/null || true)
  info "OS: $uname_s $uname_r"

  # git
  if command -v git >/dev/null 2>&1; then
    git_ver=$(git --version 2>/dev/null || true)
    info "git: $git_ver"
  else
    warn "git: not installed"
  fi

  # gh
  if command -v gh >/dev/null 2>&1; then
    gh_ver=$(gh --version 2>/dev/null | head -n1 || true)
    info "gh: $gh_ver"
  else
    warn "gh: not installed"
  fi

  # Node
  node_status=$(check_node || true)
  case "$node_status" in
    ok)
      node_v=$(node --version 2>/dev/null || echo "")
      info "Node: $node_v (meets >= $REQUIRED_NODE_MAJOR)" ;;
    bad_version)
      node_v=$(node --version 2>/dev/null || echo "(version too old)")
      err "Node: $node_v (REQUIRE >= v$REQUIRED_NODE_MAJOR)" ;;
    missing)
      err "Node: not found (REQUIRE >= v$REQUIRED_NODE_MAJOR)" ;;
  esac

  # Python
  py_status=$(check_python || true)
  case "$py_status" in
    ok)
      local py_cmd="python3"
      if [ -x "/opt/homebrew/bin/python3.13" ]; then py_cmd="/opt/homebrew/bin/python3.13"; fi
      if [ -x "/opt/homebrew/bin/python3.12" ]; then py_cmd="/opt/homebrew/bin/python3.12"; fi
      py_v=$($py_cmd --version 2>&1 || echo "")
      info "Python: $py_v (meets >= $REQUIRED_PY_MAJOR.$REQUIRED_PY_MINOR)" ;;
    bad_version)
      py_v=$(python3 --version 2>&1 || echo "(version too old)")
      err "Python: $py_v (REQUIRE >= $REQUIRED_PY_MAJOR.$REQUIRED_PY_MINOR)" ;;
    missing)
      err "Python3: not found (REQUIRE >= $REQUIRED_PY_MAJOR.$REQUIRED_PY_MINOR)" ;;
  esac

  # node/npm path
  if command -v npm >/dev/null 2>&1; then
    npm_v=$(npm --version 2>/dev/null || true)
    info "npm: $npm_v"
  fi

  # Workspace info
  info "Workspace: $WORKSPACE_DIR"
  if [ -f "$GITIGNORE_FILE" ]; then
    info ".gitignore exists"
  else
    warn ".gitignore missing (will be created)"
  fi
  echo
}

# Main preflight module
module_preflight() {
  info "Running Module 1: Pre-flight checks..."
  report
  ensure_gitignore

  # Consolidate pass/fail
  fail_count=0
  check_node >/dev/null 2>&1 || { ((fail_count++)); }
  check_python >/dev/null 2>&1 || { ((fail_count++)); }

  if [ "$fail_count" -eq 0 ]; then
    info "Pre-flight checks PASSED. System ready for next modules."
    return 0
  else
    err "Pre-flight checks FAILED (see messages above). Fix missing/old dependencies and re-run."
    return 2
  fi
}

# Entry point
case "${1:-}" in
  --help|-h)
    cat <<'USAGE'
install_john.sh [command]

Commands:
  preflight   Run Module 1 pre-flight checks (default)
  help        Show this help

Behavior:
  - Checks Node >= 18 and Python >= 3.10
  - Reports system status and updates .gitignore to exclude _archive/ and env_config.json
USAGE
    ;;
  preflight|"")
    module_preflight
    ;;
  *)
    err "Unknown command: $1"
    exit 1
    ;;
esac
