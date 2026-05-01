#!/usr/bin/env python3
"""
john_discovery.py

Discovery helper for John (agent). Scans common mount points to locate the user's
Obsidian vault (My_Obsidian_Vault) and verifies presence of System/JohnPADU/JOHN_CORE_VISION.md.
If found, prompts the operator (Boss) to update workspace env_config (writes env_config.json).

Design goals:
- Use only stdlib (os, json, sys). Portable, no extra deps.
- Conservative: do not delete or move files. Show what will change and ask for approval.
- Clear comments and simple flow (Senior Developer style).

Usage: run from workspace (where env_config_template.json lives) or any directory. The script
writes env_config.json next to env_config_template.json when updating.
"""

import os
import json
import sys
from pathlib import Path

SEARCH_ROOTS = ["/Volumes", os.path.expanduser("~/Library/CloudStorage")]
TARGET_DIR_NAME = "My_Obsidian_Vault"
CHECK_RELATIVE = os.path.join("System", "JohnPADU", "JOHN_CORE_VISION.md")
TEMPLATE_NAME = "env_config_template.json"
OUTPUT_NAME = "env_config.json"


def find_candidates():
    """Search SEARCH_ROOTS for directories named TARGET_DIR_NAME.

    Returns list of absolute paths to matching directories.
    """
    results = []
    for root in SEARCH_ROOTS:
        if not os.path.exists(root):
            continue
        try:
            # iterate only top-level entries under root to keep scan fast and safe
            for entry in os.listdir(root):
                candidate = os.path.join(root, entry)
                # check immediate children and deeper: candidate could itself be the target
                # e.g., ~/Library/CloudStorage/GoogleDrive-.../My Drive/_Obsidian Vault Sync/My_Obsidian_Vault
                # We'll walk up to depth 3 under candidate to find the named dir
                for dirpath, dirnames, _ in os.walk(candidate):
                    # limit walk depth to avoid long scans
                    depth = dirpath[len(candidate):].count(os.sep)
                    if depth > 4:
                        # skip deeper
                        dirnames[:] = []
                        continue
                    for d in list(dirnames):
                        if d == TARGET_DIR_NAME:
                            results.append(os.path.join(dirpath, d))
                    # also check if current dirpath itself is the target
                    if os.path.basename(dirpath) == TARGET_DIR_NAME:
                        results.append(dirpath)
        except PermissionError:
            # skip unreadable roots
            continue
    # de-duplicate and normalize
    unique = []
    seen = set()
    for p in results:
        norm = os.path.normpath(p)
        if norm not in seen:
            seen.add(norm)
            unique.append(norm)
    return unique


def verify_candidate(path):
    """Return True if candidate contains the required JOHN_CORE_VISION.md file."""
    check_path = os.path.join(path, CHECK_RELATIVE)
    return os.path.isfile(check_path)


def load_template(path):
    """Load env_config_template.json if present; otherwise return a minimal base dict."""
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            print("Warning: failed to parse template; using minimal default.")
    # minimal default template
    return {
        "agent_identity": {"name": "John Padu", "version": "johnpadu_v1"},
        "path_manifest": {"home": "{{HOME}}", "gdrive_root": "{{GD_PATH}}"},
    }


def build_config_from_template(template, gdrive_root):
    """Fill placeholders in a shallow manner and produce a concrete config dict."""
    cfg = template.copy()
    # ensure path_manifest exists
    pm = cfg.get("path_manifest", {})
    home = os.path.expanduser("~")
    pm["home"] = home
    pm["gdrive_root"] = gdrive_root
    # If template expects obsidian_vault_root as {{GD_PATH}}/My_Obsidian_Vault, keep that pattern
    # but concrete it to actual path if needed
    if "obsidian_vault_root" in pm and "{{GD_PATH}}" in pm["obsidian_vault_root"]:
        pm["obsidian_vault_root"] = pm["obsidian_vault_root"].replace("{{GD_PATH}}", gdrive_root)
    cfg["path_manifest"] = pm
    return cfg


def write_config(path, cfg):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)


def prompt_yes_no(prompt):
    try:
        ans = input(prompt + " [y/N]: ").strip().lower()
    except EOFError:
        return False
    return ans in ("y", "yes")


def main():
    cwd = os.getcwd()
    print("john_discovery: scanning common locations for My_Obsidian_Vault...")
    candidates = find_candidates()
    if not candidates:
        print("No candidate vaults named '{0}' found under: {1}".format(TARGET_DIR_NAME, ", ".join(SEARCH_ROOTS)))
        sys.exit(0)

    # verify candidates
    valid = []
    for c in candidates:
        ok = verify_candidate(c)
        print(" - found:", c, "=>", "OK" if ok else "MISSING JOHN_CORE_VISION")
        if ok:
            valid.append(c)

    if not valid:
        print("No valid vaults verified (JOHN_CORE_VISION.md missing).")
        sys.exit(0)

    # If multiple, present choices
    chosen = None
    if len(valid) == 1:
        chosen = valid[0]
    else:
        print("Multiple verified vaults found:")
        for i, p in enumerate(valid, start=1):
            print(f"  {i}. {p}")
        try:
            sel = int(input("Choose number to use (or 0 to cancel): ").strip())
            if sel <= 0 or sel > len(valid):
                print("Cancelled.")
                sys.exit(0)
            chosen = valid[sel - 1]
        except Exception:
            print("Invalid selection, aborting.")
            sys.exit(1)

    # propose gdrive_root as parent directory of My_Obsidian_Vault
    gdrive_root = os.path.dirname(chosen)
    print(f"Boss, I found your soul at: {chosen}")
    if not prompt_yes_no(f"Boss, update env_config with GD_PATH={gdrive_root}?"):
        print("No changes made.")
        sys.exit(0)

    # load template
    template_path = os.path.join(cwd, TEMPLATE_NAME)
    template = load_template(template_path)
    config = build_config_from_template(template, gdrive_root)

    # write output file
    out_path = os.path.join(cwd, OUTPUT_NAME)
    write_config(out_path, config)
    print(f"Wrote config to: {out_path}")
    print("Done. You may review the file and remove/add secrets as needed.")


if __name__ == "__main__":
    main()
