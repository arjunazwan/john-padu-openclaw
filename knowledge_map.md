# 🗺️ Knowledge Map (Obsidian Context)

Canonical vault path: `/Users/family/Library/CloudStorage/GoogleDrive-azwan@tv3.com.my/My Drive/_Obsidian Vault Sync/My_Obsidian_Vault`  
Generated from `/Users/family/Library/CloudStorage/GoogleDrive-azwan@tv3.com.my/My Drive/_Obsidian Vault Sync/My_Obsidian_Vault`

## Metadata policy
- agent_metadata.json (workspace) will store enforcement settings (agent_write thresholds, duplication thresholds, archive policy).
- Agent WILL consult this knowledge_map before any write. Fields below control behavior.

## 🛠️ Files & Agent Permissions
- path: System/JohnPADU/John PADU — Log Master.md
  canonical: true
  agent_write: append-only
  priority: high
  notes: "Project status & pointers only. No raw session backups. Agent must only write 1-line pointers when duplication detected."

- path: System/JohnPADU/Daily_Log/
  canonical: true
  agent_write: create-new-files (append-only per-file)
  priority: high
  notes: "Per-session full backups go here. Versioned by YYYY-MM/YYYY-MM-DD-Session-NN.md"

- path: System/JohnPADU/projek 2026 AI Padu.md
  canonical: true
  agent_write: read-only
  priority: high
  notes: "Installation guide / reference. Agent may index headings only."

- path: System/JohnPADU/test dr openclaw.md
  canonical: true
  agent_write: read-only
  priority: medium
  notes: "Connection test notes."

- path: System/JohnPADU/test dr openclaw - diagram.md
  canonical: true
  agent_write: read-only
  priority: medium
  notes: "Diagrams/prereqs."

- path: Openclaw installation in win ONLY.md
  canonical: true
  agent_write: read-only
  priority: medium
  notes: "Windows-specific notes."

- path: System/JohnPADU/media/
  canonical: true
  agent_write: none
  priority: low
  notes: "Media assets (images). Agent should not write here."

- path: (workspace) ./knowledge_map.md
  canonical: true
  agent_write: edit (agent will update this file per Boss approval rules)
  priority: high
  notes: "Master index kept in workspace. Agent will update and show diffs before writes."

- path: (workspace) ./agent_metadata.json
  canonical: true
  agent_write: edit
  priority: high
  notes: "Machine-readable enforcement/policy config."

- path: System/JohnPADU/Daily_Log/ (existing backups)
  canonical: true
  agent_write: append-only
  priority: high
  notes: "Do not duplicate content into Log Master; Log Master only gets pointers."

---
*Last updated: 2026-05-01 20:48 (Asia/Kuala_Lumpur)*
