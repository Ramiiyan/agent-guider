#!/bin/bash
# =============================================================================
# Script 7: Cleanup APIM Artifacts + Post-Migration Guidance
#           APIM 4.1.0 → 4.5.0 Migration
# Purpose : Remove APIM migration JAR and migration-resources from APIM_HOME,
#           then print post-migration startup actions (re-indexing, restart).
# =============================================================================

set -e
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../migration.config.sh"

log_section "APIM $SOURCE_VERSION → $TARGET_VERSION — APIM Artifacts Cleanup"
log_info "APIM_HOME: $APIM_HOME"

[ -d "$APIM_HOME" ] || { log_error "APIM_HOME not found: $APIM_HOME"; exit 1; }

log_warn "IMPORTANT: WSO2 API Manager must be stopped before running this cleanup."
read -p "Have you stopped the server and confirmed APIM migration completed? (yes/no): " confirm
[[ "$confirm" == "yes" ]] || { log_error "Aborted. Stop the server and verify migration first."; exit 1; }
log_info "✓ Confirmed"
echo

APIM_DROPINS="$APIM_HOME/repository/components/dropins"
MIGRATION_RESOURCES_DIR="$APIM_HOME/migration-resources"

log_section "Step 1: Removing APIM Migration JAR from Dropins"
APIM_JARS=$(find "$APIM_DROPINS" -name "org.wso2.carbon.apimgt.migrate.client-*.jar" 2>/dev/null || true)
if [ -n "$APIM_JARS" ]; then
    echo "$APIM_JARS" | while read -r jar; do
        rm -f "$jar"
        log_info "✓ Removed: $(basename "$jar")"
    done
else
    log_warn "No APIM migration JARs found (may already be removed)"
fi

log_section "Step 2: Removing migration-resources Directory"
if [ -d "$MIGRATION_RESOURCES_DIR" ]; then
    DIR_SIZE=$(du -sh "$MIGRATION_RESOURCES_DIR" 2>/dev/null | cut -f1)
    log_info "Directory size: $DIR_SIZE"
    rm -rf "$MIGRATION_RESOURCES_DIR"
    log_info "✓ migration-resources removed"
else
    log_warn "migration-resources not found (may already be removed)"
fi

log_section "Step 3: Validation Reports (Optional Cleanup)"
VALIDATION_REPORTS_DIR="$APIM_HOME/validation-reports"
if [ -d "$VALIDATION_REPORTS_DIR" ]; then
    FILE_COUNT=$(find "$VALIDATION_REPORTS_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    log_info "Found $FILE_COUNT validation report file(s)"
    read -p "Remove validation reports? (yes/no): " remove_reports
    [[ "$remove_reports" == "yes" ]] && { rm -rf "$VALIDATION_REPORTS_DIR"; log_info "✓ Removed"; } \
        || log_info "Kept at: $VALIDATION_REPORTS_DIR"
fi

################################################################################
# POST-MIGRATION GUIDED ACTIONS
################################################################################
log_section "Post-Migration Actions — Follow These Steps to Complete Migration"

log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_warn "ACTION 1: Re-Index API Manager Artifacts"
log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Add to deployment.toml ($APIM_HOME/repository/conf/deployment.toml):"
echo ""
echo "       [indexing]"
echo "       re_indexing = 1"
echo ""
echo "     (Increment if re_indexing already exists)"
echo ""
echo "  2. Backup and delete solr directory:"
echo "       cp -r $APIM_HOME/solr $APIM_HOME/solr.bkp"
echo "       rm -rf $APIM_HOME/solr"
echo ""

log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_warn "ACTION 2: Re-Apply Tenant Customizations (if any)"
log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Copy tenant userstores from source to target if applicable:"
echo "    <APIM_4.1.0_HOME>/repository/tenants/<tenantid>/"
echo "  → $APIM_HOME/repository/tenants/<tenantid>/"
echo ""

log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_warn "ACTION 3: Start the API Manager"
log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "    cd $APIM_HOME/bin"
echo "    sh api-manager.sh"
echo ""

log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_warn "ACTION 4: Post-Migration Verification"
log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  - Publisher and Developer portals load without errors"
echo "  - All APIs are accessible and functional"
echo "  - Check server logs for errors"
echo "  - Governance feature (4.5.0): Once stable, re-enable default policy via Admin Portal"
echo "    Docs: https://apim.docs.wso2.com/en/4.5.0/governance/overview/"
echo ""

log_section "Migration Complete"
log_info "All data migration scripts have run. Follow the actions above to finalize."
