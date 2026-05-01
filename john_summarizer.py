#!/usr/bin/env python3
"""
john_summarizer.py

Memory management tool for John (agent). 
1. Reads the latest session daily log.
2. Generates a "Shadow Memory" summary (overwrite-style).
3. Updates SHADOW_MEMORY_LATEST.md in Obsidian as the latest 'working context'.

Design: Pure Python, Senior Dev style, focused on preserving 'Latest State'.
"""

import os
import json
import sys
from datetime import datetime

CONFIG_NAME = "env_config.json"

def get_config():
    if not os.path.exists(CONFIG_NAME):
        print(f"Error: {CONFIG_NAME} not found. Run john_discovery.py first.")
        sys.exit(1)
    with open(CONFIG_NAME, "r") as f:
        return json.load(f)

def run_reasoning():
    """High-Level Reasoning for Memory Update Strategy."""
    print("Alignment: Vision ensures John remains efficient and avoids 'junk' files.")
    print("Architectural Plan: Overwrite SHADOW_MEMORY_LATEST.md to provide a 'Hot Context' for the next session start.")
    print("Risk: Single-file overwrite loses historical context if not backed up elsewhere.")
    print("Mitigation: We keep full history in Daily_Log; SHADOW_MEMORY is purely for speed/token-efficiency.")

def summarize_log(log_path):
    """
    Extremely simple parser for the demo. In live use, this would 
    extract key headers and code.
    """
    if not os.path.exists(log_path):
        return "No log found for today's session."
    
    with open(log_path, "r") as f:
        lines = f.readlines()
    
    # Identify key sections (simple search for our established headers)
    summary = {
        "Actions": [],
        "Decisions": [],
        "Issues": []
    }
    
    # Heuristics based on our log structure
    for line in lines:
        if "- " in line:
            summary["Actions"].append(line.strip())
            
    return summary

def main():
    run_reasoning()
    cfg = get_config()
    pm = cfg.get("path_manifest", {})
    
    # Define paths
    today = datetime.now().strftime("%Y-%m-%d")
    # Resolution of {{GD_PATH}}
    gdrive_root = pm["gdrive_root"]
    daily_log_dir = pm["daily_log_dir"].replace("{{GD_PATH}}", gdrive_root)
    log_master = pm["log_master"].replace("{{GD_PATH}}", gdrive_root)
    
    log_file = os.path.join(daily_log_dir, datetime.now().strftime("%Y-%m"), f"{today}-Session-01.md")
    shadow_path = os.path.join(os.path.dirname(log_master), "SHADOW_MEMORY_LATEST.md")
    
    print(f"Reading session log: {log_file}")
    data = summarize_log(log_file)
    
    if isinstance(data, str):
        print(f"Error summarized data: {data}")
        sys.exit(1)
    
    # Build Content
    content = f"--- \ntype: shadow_memory\nupdated: {datetime.now().isoformat()}\n---\n\n"
    content += "# 🧠 SHADOW_MEMORY_LATEST\n\n"
    content += "## 🚀 What we did\n" + "\n".join(data["Actions"][:10]) + "\n\n"
    content += "## 🎯 Key Decisions\n- Workflow confirmed: Discovery -> Config -> Summarizer (Shadow Memory).\n- Policy: Overwrite Latest, Keep Full History in Daily_Log.\n\n"
    content += "## 🔧 Next Context\n- Ready for automated memory cycles.\n"
    
    with open(shadow_path, "w") as f:
        f.write(content)
    
    print(f"Shadow Memory Updated at: {shadow_path}")

if __name__ == "__main__":
    main()
