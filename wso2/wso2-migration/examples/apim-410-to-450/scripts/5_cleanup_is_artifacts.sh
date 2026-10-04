#!/bin/bash
# =============================================================================
# Script 5: Cleanup IS Migration Artifacts — APIM 4.1.0 → 4.5.0 Migration
# Purpose : Remove IS migration JAR and migration-resources from APIM_HOME
#           after confirmed IS component migration completion.
# =============================================================================

set -e
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../migration.config.sh"

log_section "APIM $SOURCE_VERSION → $TARGET_VERSION — IS Artifacts Cleanup"
log_info "APIM_HOME: $APIM_HOME"

[ -d "$APIM_HOME" ] || { log_error "APIM_HOME not found: $APIM_HOME"; exit 1; }

log_warn "IMPORTANT: WSO2 API Manager must be stopped before running this cleanup."
read -p "Have you stopped the server and confirmed IS migration completed? (yes/no): " confirm
[[ "$confirm" == "yes" ]] || { log_error "Aborted. Stop the server and verify migration first."; exit 1; }
log_info "✓ Confirmed"
echo

APIM_DROPINS="$APIM_HOME/repository/components/dropins"
MIGRATION_RESOURCES_DIR="$APIM_HOME/migration-resources"

log_section "Step 1: Removing IS Migration JAR from Dropins"
IS_JARS=$(find "$APIM_DROPINS" -name "org.wso2.carbon.is.migration*.jar" 2>/dev/null || true)
if [ -n "$IS_JARS" ]; then
    echo "$IS_JARS" | while read -r jar; do
        rm -f "$jar"
        log_info "✓ Removed: $(basename "$jar")"
    done
else
    log_warn "No IS migration JARs found (may already be removed)"
fi

log_section "Step 2: Removing migration-resources Directory"
if [ -d "$MIGRATION_RESOURCES_DIR" ]; then
    rm -rf "$MIGRATION_RESOURCES_DIR"
    log_info "✓ migration-resources removed"
else
    log_warn "migration-resources not found (may already be removed)"
fi

log_section "Post-IS Checkpoint"
log_info "The databases now hold the migrated IS data — your most valuable restore point."
log_info "If the APIM migration fails later, you restore this instead of starting over."
read -p "Take the post-IS checkpoint now (runs 1_db_dump.sh)? (yes/no) [yes]: " take_checkpoint
take_checkpoint="${take_checkpoint:-yes}"
if [[ "$take_checkpoint" == "yes" ]]; then
    SNAPSHOT_LABEL="post-is" bash "$(dirname "${BASH_SOURCE[0]}")/1_db_dump.sh"
else
    log_warn "Skipped. Before Script 6, run:  SNAPSHOT_LABEL=post-is ./1_db_dump.sh"
fi

log_section "IS Artifacts Cleanup Complete"
log_info "Proceed to Script 6 — APIM Component Migration Preparation."
