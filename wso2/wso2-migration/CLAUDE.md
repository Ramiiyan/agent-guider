# WSO2 APIM Migration Script Generator — Claude Guide

This guide tells Claude Code how to generate data migration bash scripts for WSO2 API Manager upgrades.
A WSO2 user clones this repo, drops their migration documentation and artifacts into `workspace/`, then opens the project in Claude Code to generate their version-specific scripts.

---

## What This Toolkit Produces

Seven numbered bash scripts that cover the full data migration workflow:

| Script | Purpose |
|---|---|
| `1_db_dump.sh` | Snapshot both databases — on SOURCE (label `source`) and on TARGET as the post-IS checkpoint (label `post-is`) |
| `2_db_restore.sh` | Restore any snapshot onto the target DB — lists available snapshots (re-runnable) |
| `3_prepare_target_pack.sh` | Unzip target pack, apply U2 update, copy configs and customizations |
| `4_prep_is_migration.sh` | Run DB script, configure and place IS migration client |
| `5_cleanup_is_artifacts.sh` | Remove IS migration artifacts after server run, then offer to take the post-IS checkpoint |
| `6_prep_apim_migration.sh` | Check a post-IS checkpoint exists, configure and place APIM migration client, run pre-migration validation |
| `7_cleanup_apim_artifacts.sh` | Remove APIM artifacts and print post-migration guidance |

Scripts are generated into `workspace/generated-scripts/` alongside a `migration.config.sh` that holds all environment variables.

---

## How to Use This Guide (For the Human)

1. Get your migration documentation from WSO2 Support and drop it in `workspace/migration-docs/`
2. Place migration clients in `workspace/migration-artifacts/` (IS client in `is/`, APIM client in `apim/`, DB scripts in `db-scripts/`)
3. Place the target APIM pack ZIP in `workspace/apim_packs/`
4. Place your migrated `deployment.toml` and JDBC driver JAR in `workspace/configurations/`; optional UI builds and custom handler JARs go in `workspace/customizations/` (`custom_handlers/` for JARs)
5. Place your source-version JKS keystore files in `workspace/configurations/security/`
6. Open this project in Claude Code:
   ```bash
   claude
   ```
7. Run the generation command:
   ```
   /generate-migration-scripts
   ```
   Claude will ask questions first, then generate all scripts into `workspace/generated-scripts/`

---

## For Claude: How to Generate Migration Scripts

### Phase 1 — Scan the Workspace

Before asking any questions, scan the entire `workspace/` directory. Do two things in one pass:

**1. Read all files in `workspace/migration-docs/` for content.** Extract:
- **Source and target APIM versions** (e.g. 4.1.0 → 4.5.0)
- **Data migration phases** — how many phases, what order (usually: DB scripts → IS migration → APIM migration)
- **IS (Identity Server) versions** — current IS version embedded in source APIM, and target IS version
- **DB script instructions** — which database gets the script (usually `shared_db`), which SQL file to use
- **IS migration-config.yaml** instructions — what `currentVersion` and `migrateVersion` to set, which `SchemaMigrator` steps to remove
- **Pre-migration validation** flags (`-DrunPreMigration`, `-DmigrateFromVersion=x.x.x`)
- **APIM migration** flags (`-Dmigrate -DmigrateFromVersion=x.x.x`)
- **Post-migration** actions — re-indexing, governance feature notes, server restart steps
- **Any special warnings** — PostgreSQL JDBC URL params, governance exceptions, admin role customization

**2. Inventory everything else in `workspace/` for presence.** Note what exists and where:
- Target APIM pack ZIP (`wso2am-*.zip` in `apim_packs/`) — use its exact filename for `PACK_ZIP_NAME`, and don't ask for it in Group 2 if found
- Migration client ZIPs (`wso2is-migration-*.zip`, `wso2am-migration-*.zip`)
- JDBC driver JAR (e.g. `mysql-connector-*.jar`) — don't ask for its filename in Group 1 if found
- Custom handler JARs under `customizations/custom_handlers/`
- DB scripts (`MySQL.sql`, `PostgreSQL.sql`, etc.)
- JKS keystore files (`*.jks`)
- `deployment.toml`
- Built dist files or theme files under `customizations/` or similar

If files are in unexpected locations, note them. In Phase 2, tell the user what you found and confirm rather than ask blindly. If you can determine the correct destination, say so: *"I found `wso2is-migration-6.1.0.zip` under `workspace/configurations/` — I'll treat it as the IS migration client."*

### Phase 2 — Ask Questions Conversationally (One Group at a Time)

**After reading the migration doc**, ask questions in the following groups — wait for the user's answer before moving to the next group. Do not generate scripts until all groups are answered.

Summarise what you already know from the doc (versions, IS versions, DB script target, migration flags) at the start of Phase 2 so the user can verify. Only ask about things the doc did not answer.

---

**Group 1 — Database**

Ask these together and wait for the answer:
- What database type are you using? (MySQL / PostgreSQL / MSSQL / Oracle)
- What are your database **host** and **port**? Ask for them separately *(defaults: MySQL `3306`; a placeholder like `your-db-host` is fine)*
  - If the user gives `host:port` (e.g. `localhost:8806`), split it yourself: `DB_HOST="localhost"`, `DB_PORT="8806"`. Never put a port in `DB_HOST` — `mysql -h` doesn't accept it.
- What are your **APIM DB name** and **shared DB name**? *(defaults: `wso2am_db`, `wso2shared_db`)*
  - **Clarify if asked:** these names are the same for source and target — Script 1 dumps from these names on the source, Script 2 recreates databases with the same names on the target.
- The scripts use **two** DB users — ask for both:
  - **Root/admin DB user** (e.g. `root`) — used by the scripts to run `mysqldump`, drop/create databases, and execute the DB migration script. Needs full privileges.
  - **APIM application DB user + password** — the user APIM itself connects with (from `deployment.toml`). Script 2 creates this user and grants it privileges on the restored databases.
- What JDBC driver filename will you use? *(e.g. `mysql-connector-java-8.0.20.jar`)*

---

**Group 2 — Infrastructure**

Ask these together and wait for the answer:
- What Java version is required by the target APIM? *(usually 21 for 4.4.0+)*
- What is the filename of the target APIM pack ZIP? *(e.g. `wso2am-4.5.0.5.zip`)*
- Will you apply a U2 update level to the target pack? If yes, what level number?
- Will you run ciphertool after pack preparation? (yes/no)

---

**Group 3 — Customizations**

Ask these together and wait for the answer:
- Do you have **UI customizations**? If yes:
  - Which component(s)? (DevPortal / Publisher / Admin Portal — select all that apply)
  - Do you have **pre-built dist files** for any of those components? If yes, ask the user to build them and place the built output under `workspace/customizations/` (e.g. `workspace/customizations/devportal-dist/`, `workspace/customizations/publisher-dist/`). The script will copy them to the correct location in the target pack.
  - Do you have **theme files** (e.g. `userTheme.json`, Publisher theme overrides)? If yes, note the filenames — the script will copy them to the correct path in the target pack.
- Do you have **custom handler JARs**? (files going to `lib/` or `dropins/`)
  - If yes: list the JAR filenames and whether each goes to `lib/` or `dropins/`
- Do you have a **custom velocity_template.xml**? If yes, what is the filename?
- **JKS keystore files** — do NOT ask blindly. Report what your Phase 1 scan found:
  - If you found `.jks` files in the workspace, list them and confirm: *"I found `wso2carbon.jks`, `client-truststore.jks` in `workspace/configurations/security/` — I'll migrate these."*
  - If you found none, say so and ask whether they intend to migrate JKS files: *"I didn't find any `.jks` files in the workspace. If you have source-version keystores to migrate, place them in `workspace/configurations/security/`. Should I enable JKS migration?"* (the generated scripts search-before-fail at runtime, so the user can add them later)
- Do you have **secondary userstores** configured for any tenants in the source environment? (yes/no)
- Does your deployment use a **separate config DB** (`isSeparateRegistryDB: true`)? (yes/no)

---

**Group 4 — IS Migration**

Ask this and wait for the answer:
- Is IS embedded in APIM or running as a **separate IS server**?
  - If separate IS server: IS migration steps may not apply — confirm whether to include or skip them

### Phase 3 — Generate Scripts Following These Rules

After receiving answers, generate all files in `workspace/generated-scripts/`. Create these files:
- `README.md` *(execution guide — generated first, see spec below)*
- `migration.config.sh` *(central config — all variables in one place)*
- `1_db_dump.sh`
- `2_db_restore.sh`
- `3_prepare_target_pack.sh`
- `4_prep_is_migration.sh`
- `5_cleanup_is_artifacts.sh`
- `6_prep_apim_migration.sh`
- `7_cleanup_apim_artifacts.sh`
- `lib/` *(a copy of the repo's `lib/*.sh` helpers — see below)*

#### `lib/` — copy the helpers in yourself (never ask the user to)

The engineer will copy `workspace/` to a VM and run the scripts there, away from this repo. The scripts must not depend on anything outside `generated-scripts/`.

As part of generation, **you** copy the helper library into the output folder — this is not a step for the user:

```bash
mkdir -p workspace/generated-scripts/lib
cp lib/logging.sh lib/db_utils.sh lib/file_utils.sh lib/prereqs.sh workspace/generated-scripts/lib/
```

Copy all four files even if a script doesn't use them all, so any script can be extended later without missing helpers. Every generated script loads helpers from its own `lib/` folder (see Blueprint Rule #1).

#### `migration.config.sh` — MOUNT_DIR portability

The user will copy the `workspace/` directory to a VM or server to run the scripts. They will not be on the same machine where they cloned this repo. Therefore `migration.config.sh` must have `MOUNT_DIR` as the **first and most important variable**, with a clear comment explaining it must be set to wherever the workspace was copied on the target VM:

```bash
# =============================================================================
# IMPORTANT: Set MOUNT_DIR to the absolute path where you copied this
# workspace directory on your VM/server.
# Example: if you copied it to /opt/migration/workspace, set:
#   MOUNT_DIR="/opt/migration/workspace"
# =============================================================================
MOUNT_DIR="<SET_THIS_TO_YOUR_WORKSPACE_PATH_ON_THE_VM>"
```

All other paths in `migration.config.sh` must be derived from `MOUNT_DIR`:
```bash
ARTIFACTS_DIR="$MOUNT_DIR/configurations"
MIGRATION_ARTIFACTS_DIR="$MOUNT_DIR/migration-artifacts"
IS_MIGRATION_DIR="$MIGRATION_ARTIFACTS_DIR/is"
APIM_MIGRATION_DIR="$MIGRATION_ARTIFACTS_DIR/apim"
DB_SCRIPT_PATH="$MIGRATION_ARTIFACTS_DIR/db-scripts/<DB_TYPE>.sql"
JKS_SOURCE_DIR="$MOUNT_DIR/configurations/security"
```

This way the user only needs to change one variable (`MOUNT_DIR`) to make all paths work on their VM.

**Pack filename — never reconstruct it.** The target pack ZIP often has an update/build suffix (e.g. `wso2am-4.5.0.5.zip`) that does NOT match `wso2am-${TARGET_VERSION}.zip`. Store the exact filename the user gave you in its own variable; do not splice the suffix into a derived path:
```bash
# WRONG — breaks when the build suffix changes:
PACK_SOURCE="$MOUNT_DIR/apim_packs/wso2am-${TARGET_VERSION}.5.zip"

# RIGHT — store the exact filename the user provided:
PACK_ZIP_NAME="wso2am-4.5.0.5.zip"
PACK_SOURCE="$MOUNT_DIR/apim_packs/$PACK_ZIP_NAME"
```
The unzipped directory name (`APIM_HOME`) usually drops the build suffix, so `APIM_HOME="$UNZIP_DEST/wso2am-${TARGET_VERSION}"` is normally correct — but if the extracted folder differs, set it explicitly.

#### Generated `README.md` — what it must contain

The `README.md` generated in `workspace/generated-scripts/` is the user's operational guide on the VM. It must include:

1. **Generation summary** — source → target versions, DB type, which optional sections are enabled (UI customizations, custom handlers, JKS, etc.)

2. **Step 1 — Copy workspace to your VM**
   ```
   Copy this entire workspace/ directory to your VM/server.
   Then open migration.config.sh and set MOUNT_DIR to that path.
   ```

3. **Step 2 — Pre-flight checklist** — a clear checklist of files the user must place before running scripts. Example:
   ```
   workspace/
   ├── migration-artifacts/
   │   ├── is/         ← Place wso2is-migration-x.x.x.zip here
   │   ├── apim/       ← Place wso2am-migration-x.x.x.zip here
   │   └── db-scripts/ ← Place MySQL.sql (or your DB type) here
   ├── configurations/
   │   ├── deployment.toml          ← Your migrated deployment.toml
   │   └── security/                ← Your JKS keystore files
   │       ├── wso2carbon.jks
   │       └── client-truststore.jks
   ```
   List only the files relevant to the user's configuration (based on their answers).

4. **Step 3 — Script execution order** — numbered table with script name, purpose, and whether it's run on source or target:
   | Script | Run on | Purpose |
   |---|---|---|
   | `1_db_dump.sh` | SOURCE | Backup databases |
   | `2_db_restore.sh` | TARGET | Restore to target DB |
   | ... | ... | ... |

5. **Checkpoints and rollback** — explain the two snapshots and include this rollback guide (adapt script names only if they differ):
   ```
   Snapshots (in $DUMP_DIR):
     <db>_source_<time>.sql   ← taken by Script 1 on the SOURCE
     <db>_post-is_<time>.sql  ← taken at the end of Script 5 (the checkpoint)

   If something fails (fix the cause first — check wso2carbon.log):
     Failed in Script 3                → no restore needed  → rerun Script 3
     Failed in Script 4 or the IS run  → 2_db_restore.sh with the *_source_* dumps
                                         → rerun from Script 3 (fresh pack), then 4
     Failed in Script 6 or the APIM run → 2_db_restore.sh with the *_post-is_* dumps
                                         → rerun from Script 6
     Failed in Script 1, 2, 5 or 7     → fix it and rerun that script
   ```

6. **A note that scripts are generated, not locked:**
   > These scripts were generated based on your answers. Review them before running.
   > Feel free to modify them to fit your exact environment, or ask Claude to make changes:
   > ```
   > cd <path-to-repo>/wso2/wso2-migration
   > claude
   > > /generate-migration-scripts
   > ```

#### After generating all files — print a closing message

After writing all files, print this summary to the user (do not skip this):

```
✅ Migration scripts generated in workspace/generated-scripts/

Files created:
  - README.md               ← Start here — read this on your VM
  - migration.config.sh     ← Set MOUNT_DIR before running anything
  - 1_db_dump.sh ... 7_cleanup_apim_artifacts.sh
  - lib/                    ← Helper library, already copied in — keep it next to the scripts

Next steps:
  1. Review the generated scripts — they are based on your answers but may need adjustment
  2. Copy the entire workspace/ directory to your VM/server
  3. Open migration.config.sh and set MOUNT_DIR to where you copied it
  4. Place your migration artifacts (ZIPs, DB scripts) in the expected directories
  5. Follow workspace/generated-scripts/README.md for the full execution guide

Need to change something? Ask Claude:
  "Update the DB host in migration.config.sh"
  "Add a custom handler JAR to script 3"
  "Change the U2 update level to 30"
```

---

## Blueprint Rules — Non-Negotiable

These rules reflect hard-won lessons. Follow them exactly.

### 1. Always source `migration.config.sh` and `lib/`

Every script starts with:
```bash
set -e
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
[ -d "$LIB_DIR" ] || { echo "ERROR: $LIB_DIR not found. Copy the whole generated-scripts/ folder, including lib/."; exit 1; }

source "$LIB_DIR/logging.sh"
source "$LIB_DIR/file_utils.sh"   # only if file operations are used
source "$LIB_DIR/db_utils.sh"     # only if DB operations are used
source "$LIB_DIR/prereqs.sh"      # only if dependency checks are used
source "$SCRIPT_DIR/migration.config.sh"
```

Never reference the repo's top-level `lib/` (e.g. `../../lib` or a `REPO_ROOT` variable) — the scripts run on a VM where the repo doesn't exist. Always load helpers from `$SCRIPT_DIR/lib`, which you populate during generation.

Never hardcode any value that belongs in `migration.config.sh`.

### 2. Use `jq` for JSON, `yq` for YAML — never `sed`/`awk` for structured data

**Wrong:**
```bash
sed -i 's/currentVersion: .*/currentVersion: "5.11.0"/' migration-config.yaml
```

**Right:**
```bash
yq -i '.currentVersion = "5.11.0"' migration-config.yaml
```

**Wrong:**
```bash
sed -i 's/"username": ".*"/"username": ""/' config.json
```

**Right:**
```bash
jq '.username = ""' config.json > tmp.$$.json && mv tmp.$$.json config.json
```

`jq` and `yq` are reliable across operating systems and handle edge cases that `sed`/`awk` miss on structured data. `sed` is acceptable only for line-pattern operations on non-structured text (e.g. stripping DEFINER clauses from SQL dumps).

### 3. Never automate server startup for migration

The migration server runs (`api-manager.sh -Dmigrate ...`) are **manual steps**. Do not automate them. Instead, print them as clear next-step guidance:

```bash
log_section "NEXT STEPS — IS Component Migration"
log_warn "IS migration client is in place. Start the server manually."
log_warn ""
log_warn "1. Set JVM memory:"
log_warn "     export JVM_MEM_OPTS=\"-Xms1024m -Xmx4096m\""
log_warn ""
log_warn "2. Run migration:"
log_warn "     cd $APIM_HOME/bin"
log_warn "     sh api-manager.sh -Dmigrate -Dcomponent=identity"
log_warn ""
log_warn "3. Wait for completion, then stop the server."
log_warn "4. Run Script 5 before proceeding."
```

**Why:** Migration server runs can take a long time, produce errors requiring human review, and must not be chained automatically. Engineers running these scripts need to monitor each server run, check logs, and confirm completion before moving on.

### 4. Use feature flags for optional sections

Optional customization sections are controlled by `ENABLE_*` flags in `migration.config.sh`:

```bash
if [ "${ENABLE_UI_CUSTOMIZATIONS}" = "true" ]; then
    # DevPortal and Publisher customization steps
fi

if [ "${ENABLE_CUSTOM_HANDLERS}" = "true" ]; then
    # Custom handler JAR copy steps
fi
```

This allows users to re-run scripts with certain sections skipped without editing the script itself.

### 5. Use the helper functions from `lib/`

Always use the library functions — never reimplement them inline:

| Operation | Use |
|---|---|
| Logging | `log_info`, `log_warn`, `log_error`, `log_section` from `lib/logging.sh` |
| Test DB connection | `test_db_connection host user pass` from `lib/db_utils.sh` |
| Execute DB script | `execute_db_script host user pass db_name script_path` from `lib/db_utils.sh` |
| Replace a file (with backup) | `backup_and_replace_file src dst description` from `lib/file_utils.sh` |
| Replace a file (no backup) | `replace_file src dst description` from `lib/file_utils.sh` |
| Copy a file | `copy_file src dst description` from `lib/file_utils.sh` |
| Replace a directory | `replace_directory src dst description` from `lib/file_utils.sh` |
| Replace a directory (with backup) | `backup_and_replace_dir src dst description` from `lib/file_utils.sh` |
| Install dependencies | `install_all_dependencies java_version` from `lib/prereqs.sh` |
| Check permissions | `check_permissions` from `lib/prereqs.sh` |

### 6. Script structure — always use functions + `main()`

Every script must follow this structure:

```bash
#!/bin/bash
# Header comment: script purpose, what it does, when to run it

set -e
set -u

# Source lib and config
...

################################################################################
# Function definitions (one function per logical step)
################################################################################
step_one() { ... }
step_two() { ... }

################################################################################
# Main execution
################################################################################
main() {
    log_section "Script Title"
    
    # Guard: check APIM_HOME exists
    [ -d "$APIM_HOME" ] || { log_error "..."; exit 1; }
    
    step_one
    step_two
}

main "$@"
```

### 7. Validate prerequisites before acting — and search before failing

Every script that touches APIM_HOME should check it exists first. Every script that touches a database should test the connection first. Every script that reads a file should check it exists first.

For key artifact files (migration ZIPs, DB scripts, JKS files, deployment.toml), use a search-before-fail pattern: if the file is not at the expected path, search for it under `$MOUNT_DIR` before giving up. This handles cases where the user placed files in the wrong subdirectory.

```bash
# Pattern: check expected path first, fall back to search
resolve_file() {
    local expected="$1"
    local filename
    filename="$(basename "$expected")"
    if [ -f "$expected" ]; then
        echo "$expected"
        return
    fi
    local found
    found="$(find "$MOUNT_DIR" -name "$filename" -type f 2>/dev/null | head -1)"
    if [ -n "$found" ]; then
        log_warn "File not found at expected path: $expected"
        log_warn "Using file found at: $found"
        echo "$found"
        return
    fi
    log_error "File not found: $filename (searched under $MOUNT_DIR)"
    exit 1
}
```

Use this pattern for migration ZIPs, DB scripts, and JKS files. For directories (e.g. `IS_MIGRATION_DIR`), apply the same search-before-fail logic using `find -type d`.

### 8. Backup before replace

When replacing configuration files or keystores that exist in the target pack, always create a timestamped backup:
```bash
backup_and_replace_file "$source" "$destination" "description"
```

The `backup_and_replace_file` function in `lib/file_utils.sh` handles this automatically.

### 9. Checkpoints are built in — keep them

The approach depends on being able to restore and retry instead of starting over. Every generated set must keep these behaviours (they are already in the templates):

- **Script 1** asks for a snapshot label (`source` / `post-is` / other) unless `SNAPSHOT_LABEL` is set, and names files `<db>_<label>_<timestamp>.sql`.
- **Script 2** lists the snapshots in `$DUMP_DIR` and accepts a file name or a full path.
- **Script 5** ends by offering to take the post-IS checkpoint, calling `SNAPSHOT_LABEL=post-is bash 1_db_dump.sh` from its own folder.
- **Script 6** warns and asks before continuing if no `*_post-is_*.sql` exists in `$DUMP_DIR`.

### 10. Database connections — host and port are separate

Every `mysql` / `mysqldump` call uses `-h "$DB_HOST" -P "$DB_PORT" --protocol=TCP`. `--protocol=TCP` makes the client honour the port even when the host is `localhost` (otherwise it silently uses the local socket). `DB_HOST` never contains a port — `migration.config.sh` ends with a guard that rejects `host:port`.

---

## Migration Doc → Script Mapping

When reading a migration doc, map each doc section to the corresponding script:

| Migration Doc Section | Script |
|---|---|
| "Run the database scripts" | Script 4 (`run_database_script` function) |
| "IS migration-config.yaml" | Script 4 (`configure_migration_config` or similar) |
| "Copy IS migration JAR" | Script 4 |
| "Start server with `-Dcomponent=identity`" | Script 4 NEXT STEPS (not automated) |
| "Remove IS migration artifacts" | Script 5 |
| "APIM migration client setup" | Script 6 |
| "Start server with `-DmigrateFromVersion=x.x.x`" | Script 6 NEXT STEPS (not automated) |
| "Remove APIM migration artifacts" | Script 7 |
| "Re-indexing", "Restart server" | Script 7 post-migration guidance (not automated) |
| "Disable governance policy" | Pre-requirement in Script 4 |
| Deployment.toml / config changes | Script 3 |
| Keystore / JKS migration | Script 3 |

---

## Version-Specific Parts to Watch For

These sections of the migration doc WILL differ between version pairs — read them carefully:

**IS migration-config.yaml:**
- `currentVersion` and `migrateVersion` values
- Which `SchemaMigrator` steps to remove (if any) and which version block they belong to
- Whether `isSeparateRegistryDB` needs to be set

**APIM migration:**
- The exact `-DmigrateFromVersion` value
- Whether a pre-migration validation step (`-DrunPreMigration`) exists
- Whether `--swaggerRelaxedValidation` is mentioned as an option

**DB scripts:**
- Which database gets the script (shared_db, apim_db, or both)
- Any special PostgreSQL connection parameters (`preparedStatementCacheQueries=0`)

**Governance:**
- Whether the target version has a governance policy that needs disabling before migration (newer versions of APIM 4.x introduce this)

**Post-migration:**
- Whether re-indexing is required
- Governance feature re-enable instructions
- Distributed setup specifics

---

## Reference — Example Implementation

See `examples/apim-410-to-450/` for a complete working example of the 4.1.0 → 4.5.0 migration:
- `migration.config.sh` — shows how a filled-in config looks
- `scripts/1_db_dump.sh` through `7_cleanup_apim_artifacts.sh` — complete script set
- `examples/apim-410-to-450/README.md` — execution order and key conventions

See `templates/` for generic blueprint versions of each script with `[DOC_STEP: ...]` markers showing exactly where version-specific logic from the migration doc goes.

---

## Output Checklist

After generating, verify each generated file:

- [ ] `migration.config.sh` has no remaining `<REPLACE_...>` placeholders (or all placeholders are clearly explained)
- [ ] All scripts start with `set -e` and `set -u`
- [ ] `workspace/generated-scripts/lib/` exists and contains `logging.sh`, `db_utils.sh`, `file_utils.sh`, `prereqs.sh`
- [ ] All scripts load helpers via `SCRIPT_DIR`/`LIB_DIR` (no `REPO_ROOT`, no `../../lib`) and source `migration.config.sh` from `$SCRIPT_DIR`
- [ ] No hardcoded hostnames, passwords, or file paths outside of `migration.config.sh`
- [ ] `jq` is used for any JSON edits, `yq` for any YAML edits
- [ ] Server startup commands appear only in `log_warn` NEXT STEPS sections
- [ ] `ENABLE_*` flags control all optional sections
- [ ] Scripts 4 and 6 both end with clear NEXT STEPS guidance for the manual server run
- [ ] Script 7 prints post-migration actions from the migration doc
- [ ] `migration.config.sh` has both `DB_HOST` (no port) and `DB_PORT`, and ends with the host:port guard
- [ ] Every `mysql`/`mysqldump` call includes `-P "$DB_PORT" --protocol=TCP`
- [ ] Checkpoint behaviours from Rule #9 are present in Scripts 1, 2, 5 and 6
- [ ] Generated `README.md` includes the checkpoints and rollback section
