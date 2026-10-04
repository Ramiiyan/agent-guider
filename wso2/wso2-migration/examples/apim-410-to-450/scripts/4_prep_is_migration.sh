#!/bin/bash
# =============================================================================
# Script 4: Prepare IS Component Data Migration — APIM 4.1.0 → 4.5.0
# Purpose : Disable governance policy, run DB script on shared_db, extract
#           IS migration client (wso2is-migration-1.1.179), configure
#           migration-config.yaml (IS 5.11.0 → 6.0.0), and copy the IS
#           migration JAR to dropins.
#           After this script, follow NEXT STEPS to run the server manually.
# =============================================================================

set -e
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/db_utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../migration.config.sh"

log_section "APIM $SOURCE_VERSION → $TARGET_VERSION — IS Migration Preparation"
log_info "APIM_HOME: $APIM_HOME"

[ -d "$APIM_HOME" ] || { log_error "APIM_HOME not found: $APIM_HOME — run Script 3 first."; exit 1; }

################################################################################
# PRE-REQUIREMENT: Disable default governance policy
################################################################################
log_section "Pre-Requirement: Disabling Default Governance Policy"

GOVERNANCE_POLICY_FILE="$APIM_HOME/repository/resources/governance/default-policies/wso2_api_mgt_best_practices.yaml"

if [ -f "$GOVERNANCE_POLICY_FILE" ]; then
    cp "$GOVERNANCE_POLICY_FILE" "${GOVERNANCE_POLICY_FILE}.bkp.$(date +%Y%m%d_%H%M%S)"
    yq -i '.labels = []' "$GOVERNANCE_POLICY_FILE"

    if grep -q 'labels: \[\]' "$GOVERNANCE_POLICY_FILE"; then
        log_info "✓ Governance policy disabled (labels set to [])"
    else
        log_error "Failed to disable governance policy"
        exit 1
    fi
else
    log_warn "Governance policy file not found — skipping"
fi

################################################################################
# STEP 1: Run DB script on shared_db
################################################################################
log_section "Step 1: Running DB Script on shared_db"

[ -f "$DB_SCRIPT_PATH" ] || { log_error "DB script not found: $DB_SCRIPT_PATH"; exit 1; }
log_info "DB script: $DB_SCRIPT_PATH"
echo

log_info "Enter shared_db connection credentials:"
read -p "Shared DB name     [default: $DB_SHARED_NAME]: " input_shared
DB_SHARED_NAME="${input_shared:-$DB_SHARED_NAME}"
read -p "Shared DB username: " SHARED_DB_USER
read -s -p "Shared DB password: " SHARED_DB_PASS
echo

[ -n "$SHARED_DB_USER" ] && [ -n "$SHARED_DB_PASS" ] \
    || { log_error "DB credentials cannot be empty."; exit 1; }

test_db_connection "$DB_HOST" "$SHARED_DB_USER" "$SHARED_DB_PASS"
execute_db_script  "$DB_HOST" "$SHARED_DB_USER" "$SHARED_DB_PASS" "$DB_SHARED_NAME" "$DB_SCRIPT_PATH"

################################################################################
# STEP 2: IS Component Migration Setup (IS 5.11.0 → 6.0.0)
################################################################################
if [ "${ENABLE_IS_MIGRATION}" = "true" ]; then

    log_section "Step 2: IS Component Migration Setup (IS $IS_SOURCE_VERSION → $IS_TARGET_VERSION)"

    # Step 2.1 — Extract IS migration client
    log_info "Step 2.1: Extracting IS migration client..."
    IS_ZIP=$(ls "$IS_MIGRATION_DIR"/wso2is-migration-*.zip 2>/dev/null | head -1)
    [ -n "$IS_ZIP" ] || { log_error "IS migration ZIP not found in: $IS_MIGRATION_DIR"; exit 1; }
    log_info "Found: $(basename "$IS_ZIP")"
    cd "$IS_MIGRATION_DIR" && unzip -o -q "$IS_ZIP" && cd - > /dev/null
    log_info "✓ Extracted"

    # Step 2.2 — Copy migration-resources to APIM_HOME
    log_info "Step 2.2: Copying migration-resources to APIM_HOME..."
    MIGRATION_RESOURCES_SRC=$(ls -d "$IS_MIGRATION_DIR"/wso2is-migration-*/migration-resources 2>/dev/null | head -1)
    [ -n "$MIGRATION_RESOURCES_SRC" ] || { log_error "migration-resources not found in extracted ZIP"; exit 1; }
    cp -r "$MIGRATION_RESOURCES_SRC" "$APIM_HOME/"
    log_info "✓ migration-resources copied to $APIM_HOME/migration-resources"

    # Step 2.3 — Backup and update migration-config.yaml
    log_info "Step 2.3: Updating migration-config.yaml..."
    MIGRATION_CONFIG="$APIM_HOME/migration-resources/migration-config.yaml"
    [ -f "$MIGRATION_CONFIG" ] || { log_error "migration-config.yaml not found."; exit 1; }

    cp "$MIGRATION_CONFIG" "${MIGRATION_CONFIG}.original"

    yq -i ".currentVersion = \"$IS_SOURCE_VERSION\"" "$MIGRATION_CONFIG"
    yq -i ".migrateVersion = \"$IS_TARGET_VERSION\"" "$MIGRATION_CONFIG"
    log_info "✓ currentVersion=$IS_SOURCE_VERSION  migrateVersion=$IS_TARGET_VERSION"

    # Remove SchemaMigrator consent step (required for 5.11.0 → 6.0.0 per migration doc)
    yq -i '(.versions[] | select(.version == "6.0.0").migratorConfigs) |= map(select(.name != "SchemaMigrator" or .order != 4 or .parameters.location != "step3" or .parameters.schema != "consent"))' "$MIGRATION_CONFIG"
    log_info "✓ SchemaMigrator consent step removed"

    log_info "migration-config.yaml:"
    echo "  migrationEnable : $(yq '.migrationEnable' "$MIGRATION_CONFIG")"
    echo "  currentVersion  : $(yq '.currentVersion'  "$MIGRATION_CONFIG")"
    echo "  migrateVersion  : $(yq '.migrateVersion'  "$MIGRATION_CONFIG")"

    # Step 2.4 — Copy IS migration JAR to dropins
    log_info "Step 2.4: Copying IS migration JAR to dropins..."
    IS_JAR=$(find "$IS_MIGRATION_DIR" -path "*/wso2is-migration-*/dropins/org.wso2.carbon.is.migration*.jar" 2>/dev/null | head -1)
    [ -n "$IS_JAR" ] || { log_error "IS migration JAR not found in $IS_MIGRATION_DIR"; exit 1; }
    cp "$IS_JAR" "$APIM_HOME/repository/components/dropins/"
    log_info "✓ IS migration JAR copied: $(basename "$IS_JAR")"
fi

################################################################################
# NEXT STEPS
################################################################################
log_section "NEXT STEPS — IS Component Migration"
log_warn "IS migration client is in place. Run the server manually to execute migration."
log_warn ""
log_warn "1. Set JVM memory options:"
log_warn "     export JVM_MEM_OPTS=\"-Xms1024m -Xmx4096m\""
log_warn ""
log_warn "2. Navigate to APIM bin:"
log_warn "     cd $APIM_HOME/bin"
log_warn ""
log_warn "3. Start the server for IS migration:"
log_warn "     sh api-manager.sh -Dmigrate -Dcomponent=identity"
log_warn ""
log_warn "4. Wait for migration to complete, then STOP the server."
log_warn "5. Run Script 5 (IS cleanup) before proceeding to Script 6."
