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
ARCHIVE_DIR="$WORKSPACE_DIR/_archive"
ARCHIVE_ENTRY="_archive/"
ENV_ENTRY="env_config.json"
ENV_FILE="$WORKSPACE_DIR/$ENV_ENTRY"
DISCOVERY_SCRIPT="$WORKSPACE_DIR/john_discovery.py"

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
  [ -f "$GITIGNORE_FILE" ] && info ".gitignore: OK" || warn ".gitignore: MISSING"
  [ -f "$ENV_FILE" ] && info "Config: env_config.json exists" || warn "Config: env_config.json NOT FOUND"
  echo
}

# Create backup of workspace and vault (System/JohnPADU only)
create_snapshot() {
  info "Safety First: Creating snapshot..."
  mkdir -p "$ARCHIVE_DIR"
  local ts=$(date +%Y%m%d_%H%M%S)
  local snap_name="john_snap_${ts}.tar.gz"
  local snap_path="$ARCHIVE_DIR/$snap_name"

  # Find vault path from config if it exists
  local vault_root=""
  if [ -f "$ENV_FILE" ]; then
    vault_root=$(python3 -c "import json; print(json.load(open('$ENV_FILE'))['path_manifest'].get('obsidian_vault_root', ''))" 2>/dev/null || echo "")
  fi

  info "Archiving workspace..."
  # Archive workspace (exclude _archive and large node_modules if any)
  tar -czf "$snap_path" --exclude="./_archive" --exclude="./node_modules" -C "$WORKSPACE_DIR" .

  if [ -n "$vault_root" ] && [ -d "$vault_root/System/JohnPADU" ]; then
    info "Archiving Vault System (JohnPADU)..."
    # Append vault system to same archive (using --append requires uncompressed first, so we just make a separate one for simplicity or use a temp folder)
    # To keep it clean: we make one archive containing both
    local temp_dir=$(mktemp -d)
    cp -R "$WORKSPACE_DIR" "$temp_dir/workspace"
    rm -rf "$temp_dir/workspace/_archive"
    mkdir -p "$temp_dir/vault_system"
    cp -R "$vault_root/System/JohnPADU" "$temp_dir/vault_system/"
    tar -czf "$snap_path" -C "$temp_dir" .
    rm -rf "$temp_dir"
  fi

  info "Snapshot saved: $snap_path"
}

ensure_folders() {
  info "Checking folder structure..."
  local dirs=("_archive" "logs" "temp")
  for d in "${dirs[@]}"; do
    if [ ! -d "$WORKSPACE_DIR/$d" ]; then
      mkdir -p "$WORKSPACE_DIR/$d"
      info "Created folder: $d"
    fi
  done
}

run_discovery() {
  if [ -f "$ENV_FILE" ]; then
    info "Idempotency Check: env_config.json already exists. Skipping discovery."
    info "Run with 'discovery' command if you want to re-scan."
    return 0
  fi

  if [ ! -f "$DISCOVERY_SCRIPT" ]; then
    err "Discovery script missing: $DISCOVERY_SCRIPT"
    return 1
  fi

  info "Checking permissions for discovery script..."
  chmod +x "$DISCOVERY_SCRIPT"
  
  info "Starting live discovery..."
  python3 "$DISCOVERY_SCRIPT"
  # If discovery wrote env_config.json, restrict permissions to user only
  if [ -f "$ENV_FILE" ]; then
    chmod 600 "$ENV_FILE" || true
    info "Applied permissions: env_config.json -> 600 (user read/write)"
  fi
}

# Main install module (Module 2)
module_install() {
  info "Running Module 2: Installation & Config..."
  
  # 1. Folders
  ensure_folders

  # 2. Safety
  create_snapshot

  # 3. Discovery/Config
  run_discovery

  info "Module 2 complete."
}

# --- Module 3: Smart Integration (Core detection, linkage, cleanup) ---
find_core_root() {
  # Look for an existing OpenClaw core (agents, plugins)
  local candidates=("$HOME/.openclaw" "$WORKSPACE_DIR/.openclaw" "/etc/.openclaw")
  for c in "${candidates[@]}"; do
    if [ -d "$c" ] && [ -d "$c/agents" ] && [ -d "$c/plugins" ]; then
      echo "$c"
      return 0
    fi
  done
  # quick scan under HOME for any .openclaw directories
  for d in "$HOME"/*; do
    if [ -d "$d/.openclaw" ] && [ -d "$d/.openclaw/agents" ] && [ -d "$d/.openclaw/plugins" ]; then
      echo "$d/.openclaw"
      return 0
    fi
  done
  return 1
}

# Remove any previous broad 'core' symlink to avoid inception loops
remove_old_core_link() {
  if [ -L "$WORKSPACE_DIR/core" ]; then
    info "Removing old symlink: $WORKSPACE_DIR/core"
    rm -f "$WORKSPACE_DIR/core"
  elif [ -e "$WORKSPACE_DIR/core" ]; then
    warn "$WORKSPACE_DIR/core exists and is not a symlink; leaving it alone to avoid data loss"
  else
    info "No old core symlink to remove."
  fi
}

# Create multiple specific links: agents, plugins, tools -> point to parent core (../agents etc) when appropriate
create_specific_links() {
  local core_root
  core_root=$(find_core_root 2>/dev/null || true)
  local names=("agents" "plugins" "tools" "memory")

  for name in "${names[@]}"; do
    local link_path="$WORKSPACE_DIR/$name"
    local parent_dir
    parent_dir=$(dirname "$WORKSPACE_DIR")
    local rel_target="../$name"
    local abs_target=""

    # If detected core root is actually the parent dir of the workspace, prefer relative ../name
    if [ -n "$core_root" ] && [ "$core_root" = "$parent_dir" ]; then
      abs_target="$core_root/$name"
      # prefer relative target when possible
      if [ -L "$link_path" ]; then
        cur=$(readlink "$link_path") || cur=""
        if [ "$cur" = "$rel_target" ] || [ "$cur" = "$abs_target" ]; then
          info "$name symlink already correct: $link_path -> $cur"
          continue
        else
          info "Removing stale symlink: $link_path -> $cur"
          rm -f "$link_path"
        fi
      elif [ -e "$link_path" ]; then
        warn "$link_path exists and is not a symlink; leaving alone"
        continue
      fi

      if [ -e "$abs_target" ]; then
        ln -s "$rel_target" "$link_path"
        info "Linked: $link_path -> $rel_target"
      else
        # create dangling relative link (explicit request from Boss)
        ln -s "$rel_target" "$link_path"
        info "Created dangling link: $link_path -> $rel_target (target missing)"
      fi
    else
      # core_root not parent of workspace: use absolute symlink to the detected core if available
      if [ -n "$core_root" ] && [ -e "$core_root/$name" ]; then
        abs_target="$core_root/$name"
      fi

      if [ -L "$link_path" ]; then
        cur=$(readlink "$link_path") || cur=""
        if [ "$cur" = "$abs_target" ]; then
          info "$name symlink already correct: $link_path -> $cur"
          continue
        else
          info "Removing stale symlink: $link_path -> $cur"
          rm -f "$link_path"
        fi
      elif [ -e "$link_path" ]; then
        warn "$link_path exists and is not a symlink; leaving alone"
        continue
      fi

      if [ -n "$abs_target" ]; then
        ln -s "$abs_target" "$link_path"
        info "Linked: $link_path -> $abs_target"
      else
        info "No core target found for $name; creating dangling relative link ../$name"
        ln -s "../$name" "$link_path"
        info "Created dangling link: $link_path -> ../$name"
      fi
    fi
  done
}

archive_legacy_baks() {
  info "Archiving .bak legacy config files older than 30 days..."
  local legacy_dir="$ARCHIVE_DIR/legacy_configs"
  mkdir -p "$legacy_dir"
  local count=0

  # find .bak files under workspace and under the detected core root (if any)
  local core_root
  core_root=$(find_core_root 2>/dev/null || true)

  # Build list of roots to scan (deduplicated)
  local -a scan_roots=("$WORKSPACE_DIR")
  if [ -n "$core_root" ] && [ "$core_root" != "$WORKSPACE_DIR" ]; then
    scan_roots+=("$core_root")
  fi

  # Use find; for missing roots find will error so suppress stderr
  for root in "${scan_roots[@]}"; do
    [ -d "$root" ] || continue
    while IFS= read -r -d '' f; do
      # Skip files already under _archive
      case "$f" in
        "$ARCHIVE_DIR"*) continue ;;
      esac
      # Build destination path preserving relative structure
      if [[ "$f" == "$WORKSPACE_DIR"/* ]]; then
        rel_path="${f#$WORKSPACE_DIR/}"
        dest="$legacy_dir/workspace/$rel_path"
      else
        # for core_root or others, prefix with core_ and use basename to avoid collisions
        rel_path="${f#$core_root/}"
        dest="$legacy_dir/core/$rel_path"
      fi
      mkdir -p "$(dirname "$dest")"
      mv "$f" "$dest"
      ((count++))
    done < <(find "$root" -type f -name "*.bak" -mtime +30 -print0 2>/dev/null || true)
  done

  info "Archived $count .bak files into: $legacy_dir"
}

module_integrate() {
  info "Running Module 3: Smart Integration (Core detection + cleanup)"
  # 1. Detect core
  local core_root
  core_root=$(find_core_root 2>/dev/null || true)
  if [ -n "$core_root" ]; then
    info "Core detected at $core_root (no clone will be performed)."
  else
    info "No core detected. If you want to clone a remote core, run the appropriate command manually."
  fi

  # 2. Link workspace to core (idempotent)
  remove_old_core_link
  create_specific_links

  # 3. Clean up legacy .bak files
  archive_legacy_baks

  info "Module 3 complete."
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
  preflight   Run Module 1 pre-flight checks
  install     Run Module 2 installation (snapshot, folders, config)
  integrate   Run Module 3 smart integration (core link, cleanup)
  all         Run all modules (preflight -> install -> integrate)
  snapshot    Create a manual backup
  discovery   Force run john_discovery.py
  help        Show this help

Behavior:
  - Idempotent: won't overwrite existing env_config.json, duplicate folders, or re-link core.
  - Smart: automatically detects existing OpenClaw core folders.
  - Keep Clean: archives .bak files older than 30 days to _archive/legacy_configs.
USAGE
    ;;
  preflight)
    module_preflight
    ;;
  install)
    module_preflight && module_install
    ;;
  integrate)
    module_integrate
    ;;
  all|"")
    module_preflight && module_install && module_integrate
    ;;
  snapshot)
    create_snapshot
    ;;
  discovery)
    run_discovery
    ;;
  *)
    err "Unknown command: $1"
    exit 1
    ;;
esac
