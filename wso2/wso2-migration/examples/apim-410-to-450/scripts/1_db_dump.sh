#!/bin/bash
# =============================================================================
# Script 1: Database Dump — APIM 4.1.0 → 4.5.0 Migration
# Purpose : Snapshot the APIM and shared databases.
#           - Run on SOURCE before migration        → label "source"
#           - Run on TARGET after IS migration      → label "post-is" (checkpoint)
#           Files: $DUMP_DIR/<db>_<label>_<timestamp>.sql
# =============================================================================

set -e
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../migration.config.sh"

log_section "APIM $SOURCE_VERSION → $TARGET_VERSION — DB Dump"
log_info "Host: $DB_HOST:$DB_PORT   User: $DB_ROOT_USER"
echo

command -v mysqldump >/dev/null 2>&1 || { log_error "mysqldump not found. Aborting."; exit 1; }

read -s -p "Enter MySQL password: " MYSQL_PASSWORD
echo
echo

read -p "APIM DB name    [default: $DB_APIM_NAME]: " input_apim
DB_APIM_NAME="${input_apim:-$DB_APIM_NAME}"

read -p "Shared DB name  [default: $DB_SHARED_NAME]: " input_shared
DB_SHARED_NAME="${input_shared:-$DB_SHARED_NAME}"

# Snapshot label — "source" for the first backup, "post-is" for the checkpoint
# after IS migration. Script 5 sets SNAPSHOT_LABEL=post-is when it calls this script.
SNAPSHOT_LABEL="${SNAPSHOT_LABEL:-}"
if [ -z "$SNAPSHOT_LABEL" ]; then
    read -p "Snapshot label [source / post-is / other] (default: source): " SNAPSHOT_LABEL
    SNAPSHOT_LABEL="${SNAPSHOT_LABEL:-source}"
fi
SNAPSHOT_LABEL="$(printf '%s' "$SNAPSHOT_LABEL" | tr -c 'A-Za-z0-9_-' '-')"
log_info "Snapshot label: $SNAPSHOT_LABEL"

mkdir -p "$DUMP_DIR"
STAMP=$(date +"%Y-%m-%d_%H%M%S")

dump_db() {
    local db_name="$1"
    local dump_file="$DUMP_DIR/${db_name}_${SNAPSHOT_LABEL}_${STAMP}.sql"

    log_info "Dumping $db_name → $dump_file ..."
    mysqldump -h "$DB_HOST" -P "$DB_PORT" --protocol=TCP -u "$DB_ROOT_USER" -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --set-gtid-purged=OFF \
        "$db_name" > "$dump_file"

    sed -i.bak 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/g' "$dump_file"
    rm -f "${dump_file}.bak"

    log_info "✓ $db_name dumped — $(du -h "$dump_file" | cut -f1)"
}

dump_db "$DB_APIM_NAME"
dump_db "$DB_SHARED_NAME"

log_section "DB Dump Complete"
log_info "Files saved to: $DUMP_DIR"
if [ "$SNAPSHOT_LABEL" = "source" ]; then
    log_info "Copy these dump files into $DUMP_DIR on your TARGET environment before running Script 2."
else
    log_info "Checkpoint '$SNAPSHOT_LABEL' saved. To roll back to it, run 2_db_restore.sh and pick these files."
fi
