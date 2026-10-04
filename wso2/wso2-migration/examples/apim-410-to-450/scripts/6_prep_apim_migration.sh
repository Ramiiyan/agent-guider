#!/bin/bash
# =============================================================================
# Script 6: Prepare APIM Component Data Migration — APIM 4.1.0 → 4.5.0
# Purpose : Extract APIM migration client (wso2am-migration-4.5.0.25), copy
#           migration-resources and JAR to APIM_HOME, then run pre-migration
#           validation (-DrunPreMigration).
#           After this script, follow NEXT STEPS to run the server manually.
# =============================================================================

set -e
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../migration.config.sh"

log_section "APIM $SOURCE_VERSION → $TARGET_VERSION — APIM Migration Preparation"
log_info "APIM_HOME: $APIM_HOME"

[ -d "$APIM_HOME" ] || { log_error "APIM_HOME not found: $APIM_HOME — run Script 3 first."; exit 1; }

# Checkpoint guard — warn if there is no post-IS snapshot to fall back to
if ! ls "$DUMP_DIR"/*_post-is_*.sql >/dev/null 2>&1; then
    log_warn "No post-IS checkpoint found in $DUMP_DIR."
    log_warn "If the APIM migration fails, you would have to restart from the source dump."
    read -p "Continue without a post-IS checkpoint? (yes/no) [no]: " continue_without
    [[ "${continue_without:-no}" == "yes" ]] || { log_info "Run:  SNAPSHOT_LABEL=post-is ./1_db_dump.sh  — then rerun this script."; exit 1; }
else
    log_info "✓ Post-IS checkpoint found: $(ls -1t "$DUMP_DIR"/*_post-is_*.sql | head -1 | xargs basename)"
fi

################################################################################
# STEP 1: Extract APIM migration client
################################################################################
log_section "Step 1: Extracting APIM Migration Client"

APIM_ZIP=$(ls "$APIM_MIGRATION_DIR"/wso2am-migration-*.zip 2>/dev/null | head -1)
[ -n "$APIM_ZIP" ] || { log_error "APIM migration ZIP not found in: $APIM_MIGRATION_DIR"; exit 1; }
log_info "Found: $(basename "$APIM_ZIP")"
cd "$APIM_MIGRATION_DIR" && unzip -o -q "$APIM_ZIP" && cd - > /dev/null
log_info "✓ APIM migration client extracted"

################################################################################
# STEP 2: Copy migration-resources to APIM_HOME
################################################################################
log_section "Step 2: Copying migration-resources to APIM_HOME"

MIGRATION_RESOURCES_SRC=$(find "$APIM_MIGRATION_DIR" -path "*/wso2am-migration-*/migration-resources" -type d 2>/dev/null | head -1)
[ -n "$MIGRATION_RESOURCES_SRC" ] || { log_error "migration-resources not found in $APIM_MIGRATION_DIR"; exit 1; }

MIGRATION_RESOURCES_DEST="$APIM_HOME/migration-resources"
[ -d "$MIGRATION_RESOURCES_DEST" ] && { log_warn "Removing existing migration-resources..."; rm -rf "$MIGRATION_RESOURCES_DEST"; }
cp -r "$MIGRATION_RESOURCES_SRC" "$MIGRATION_RESOURCES_DEST"
log_info "✓ migration-resources copied"

################################################################################
# STEP 3: Copy APIM migration JAR to dropins
################################################################################
log_section "Step 3: Copying APIM Migration JAR to Dropins"

APIM_JAR=$(find "$APIM_MIGRATION_DIR" -path "*/wso2am-migration-*/dropins/org.wso2.carbon.apimgt.migrate.client-*.jar" -type f 2>/dev/null | head -1)
[ -n "$APIM_JAR" ] || { log_error "APIM migration JAR not found in $APIM_MIGRATION_DIR"; exit 1; }
cp "$APIM_JAR" "$APIM_HOME/repository/components/dropins/"
log_info "✓ APIM migration JAR copied: $(basename "$APIM_JAR")"

################################################################################
# STEP 4: Pre-migration validation
################################################################################
log_section "Step 4: Pre-Migration Validation"

log_info "Setting JVM memory options..."
export JVM_MEM_OPTS="-Xms1024m -Xmx4096m"

read -p "Generate report in CSV format? (yes/no) [default: no]: " use_csv
use_csv="${use_csv:-no}"

read -p "Save invalid API definitions? (yes/no) [default: no]: " save_invalid
save_invalid="${save_invalid:-no}"

VALIDATION_CMD="sh api-manager.sh -Dmigrate -DmigrateFromVersion=$SOURCE_VERSION -DrunPreMigration"
[[ "$use_csv"      == "yes" ]] && VALIDATION_CMD="$VALIDATION_CMD -DfileExtension=csv"
[[ "$save_invalid" == "yes" ]] && VALIDATION_CMD="$VALIDATION_CMD -DsaveInvalidDefinition"

log_info "Running: $VALIDATION_CMD"
cd "$APIM_HOME/bin"

if eval "$VALIDATION_CMD"; then
    cd - > /dev/null
    log_info "✓ Pre-migration validation completed"

    REPORTS_DIR="$APIM_HOME/validation-reports"
    if [ -d "$REPORTS_DIR" ]; then
        log_info "Validation reports: $REPORTS_DIR"
        ls -lh "$REPORTS_DIR" 2>/dev/null | tail -n +2 | awk '{print "  - " $9 " (" $5 ")"}'
    fi
else
    cd - > /dev/null
    log_error "Pre-migration validation failed — resolve issues before proceeding"
    exit 1
fi

################################################################################
# NEXT STEPS
################################################################################
log_section "NEXT STEPS — APIM Component Migration"
log_warn "IMPORTANT: Review validation reports before starting migration."
log_warn "  Reports: $APIM_HOME/validation-reports/"
log_warn ""
log_warn "Once reviewed and all validations pass:"
log_warn ""
log_warn "1. Set JVM memory options:"
log_warn "     export JVM_MEM_OPTS=\"-Xms1024m -Xmx4096m\""
log_warn ""
log_warn "2. Navigate to APIM bin:"
log_warn "     cd $APIM_HOME/bin"
log_warn ""
log_warn "3. Start the server for APIM migration:"
log_warn "     sh api-manager.sh -Dmigrate -DmigrateFromVersion=$SOURCE_VERSION"
log_warn ""
log_warn "4. Wait for migration to complete, then STOP the server."
log_warn "5. Run Script 7 (APIM cleanup + post-migration guidance)."
