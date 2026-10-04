# WSO2 APIM Migration Script Generator

A toolkit for generating WSO2 API Manager data migration bash scripts using Claude Code.

When upgrading WSO2 APIM, WSO2 Support provides a migration documentation file and migration client ZIPs specific to your version pair. This toolkit uses that documentation to automatically generate the bash scripts needed to run the data migration.

## What It Generates

Seven bash scripts covering the complete data migration workflow:

```
1_db_dump.sh                → Snapshot databases (source backup + post-IS checkpoint)
2_db_restore.sh             → Restore any snapshot onto the target (re-runnable)
3_prepare_target_pack.sh    → Unzip, update, and configure target APIM pack
4_prep_is_migration.sh      → Prepare IS component migration
5_cleanup_is_artifacts.sh   → Clean up after IS migration run + take post-IS checkpoint
6_prep_apim_migration.sh    → Prepare APIM component migration + pre-validation
7_cleanup_apim_artifacts.sh → Clean up + post-migration guidance
```

Plus a `migration.config.sh` — a single file with all your environment variables.

## Prerequisites

- [Claude Code](https://claude.ai/code) installed (`npm install -g @anthropic-ai/claude-code`)
- WSO2 migration documentation (provided by WSO2 Support for your version pair)
- WSO2 migration client ZIPs (`wso2is-migration-x.x.x.zip`, `wso2am-migration-x.x.x.zip`)
- Your migrated `deployment.toml` for the target APIM version
- The target APIM pack ZIP

## Quick Start

**1. Clone this repo**
```bash
git clone https://github.com/ramiiyan/agent-guider.git
cd agent-guider/wso2/wso2-migration
```

**2. Drop your files in `workspace/`**

```
workspace/
├── migration-docs/          ← Your WSO2 migration documentation
├── apim_packs/              ← Target APIM pack ZIP (e.g. wso2am-4.5.0.5.zip)
├── migration-artifacts/
│   ├── is/                  ← wso2is-migration-x.x.x.zip
│   ├── apim/                ← wso2am-migration-x.x.x.zip
│   └── db-scripts/          ← MySQL.sql / PostgreSQL.sql etc.
├── configurations/          ← Your deployment.toml + JDBC driver JAR
│   └── security/            ← Your JKS keystore files (not committed to Git)
├── customizations/          ← Optional: UI builds/themes
│   └── custom_handlers/     ← Optional: custom handler JARs
└── generated-scripts/       ← Scripts will be generated here
```

**3. Open in Claude Code and run the generation command**
```bash
claude
```

Then run:
```
/generate-migration-scripts
```

Claude will:
1. Read your migration documentation from `workspace/migration-docs/`
2. Ask clarifying questions about your environment
3. Generate all scripts in `workspace/generated-scripts/`

**4. Review and run**

Review the generated scripts before running. Copy the whole `workspace/` folder to your VM, set `MOUNT_DIR` in `migration.config.sh`, then follow `workspace/generated-scripts/README.md` — it has the execution order and the rollback guide.

## Repo Structure

```
.
├── CLAUDE.md                          # Claude Code guide — drives script generation
├── README.md                          # This file
├── lib/                               # Reusable bash library
│   ├── logging.sh                     # log_info, log_warn, log_error, log_section
│   ├── db_utils.sh                    # DB connection test, script execution
│   ├── file_utils.sh                  # File/directory backup and replace helpers
│   └── prereqs.sh                     # jq, yq, rsync, Java install/check
├── templates/                         # Generic blueprint scripts
│   ├── migration.config.sh.template   # Config template with all variables
│   └── 1_db_dump.sh.template ... 7_*  # Per-script blueprints
├── examples/                          # Reference implementation
│   └── apim-410-to-450/               # Complete 4.1.0 → 4.5.0 example
│       ├── migration.config.sh
│       ├── scripts/
│       └── README.md
└── workspace/                         # Your working area (files gitignored)
    ├── migration-docs/
    ├── apim_packs/
    ├── migration-artifacts/
    ├── configurations/
    ├── customizations/
    └── generated-scripts/             # Generated scripts + their own lib/ copy
```

## Key Design Decisions

**jq for JSON, yq for YAML** — migration scripts edit `migration-config.yaml` and `config.json`. Using `jq`/`yq` instead of `sed`/`awk` ensures reliable edits across operating systems and handles edge cases that regex-based tools miss on structured data.

**Manual server runs, guided next steps** — migration server runs (`api-manager.sh -Dmigrate ...`) are never automated. Each script that precedes a server run ends with printed next-step instructions. This is intentional: migrations can take a long time, produce errors requiring human review, and must not be chained.

**Checkpoints built in** — Script 1 labels each snapshot (`source`, `post-is`), Script 5 offers to take the post-IS checkpoint, Script 2 lists snapshots to restore, and Script 6 warns if there's no checkpoint to fall back to. If the APIM migration fails, you restore the post-IS snapshot and retry from Script 6 instead of starting over. The generated `README.md` includes a rollback guide.

**Feature flags for optional sections** — `ENABLE_UI_CUSTOMIZATIONS`, `ENABLE_CUSTOM_HANDLERS`, `ENABLE_JKS_MIGRATION`, etc. in `migration.config.sh` control which sections run. Set to `false` to skip sections not applicable to your setup.

**Reusable `lib/`** — all scripts share the same logging, DB helper, file helper, and prereqs library. During generation, Claude copies it into `workspace/generated-scripts/lib/`, so the generated scripts are self-contained — copy `workspace/` to your VM and they run without the rest of this repo.

## Example Reference

See `examples/apim-410-to-450/` for a complete working example of the 4.1.0 → 4.5.0 migration path, including all 7 scripts and a filled-in `migration.config.sh`.
