#!/bin/bash
# =============================================================================
# Script 3: Prepare Target APIM Pack — APIM 4.1.0 → 4.5.0 Migration
# Purpose : Unzip the 4.5.0 pack, apply U2 update to level 28, replace
#           deployment.toml, copy JKS keystores, JDBC driver, UI customizations
#           (DevPortal + Publisher), custom handler JARs, custom velocity
#           template, and run ciphertool.
# =============================================================================

set -e
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/file_utils.sh"
source "$REPO_ROOT/lib/prereqs.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../migration.config.sh"

log_section "APIM $SOURCE_VERSION → $TARGET_VERSION — Prepare Target Pack"
check_permissions
install_all_dependencies "$JAVA_REQUIRED_VERSION"

################################################################################
# STEP 1: Unzip APIM pack
################################################################################
log_section "Step 1: Unzipping APIM Pack"

[ -f "$PACK_SOURCE" ] || { log_error "Pack not found: $PACK_SOURCE"; exit 1; }

if [ -d "$APIM_HOME" ]; then
    log_warn "Directory already exists: $APIM_HOME"
    read -p "Remove it and continue? (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || { log_error "Aborted."; exit 1; }
    sudo rm -rf "$APIM_HOME"
fi

unzip -q "$PACK_SOURCE" -d "$UNZIP_DEST"
log_info "✓ Pack unzipped to $UNZIP_DEST"

################################################################################
# STEP 2: Apply U2 Update to level 28
################################################################################
if [ "${ENABLE_U2_UPDATE}" = "true" ]; then
    log_section "Step 2: Applying U2 Update to Level $U2_LEVEL"

    [ -f "$APIM_HOME/bin/wso2update_linux" ] || { log_error "wso2update_linux not found."; exit 1; }
    chmod +x "$APIM_HOME/bin/wso2update_linux"

    log_warn "WSO2 Update tool requires authentication"
    read -p "Enter WSO2 username: " WSO2_USERNAME
    read -s -p "Enter WSO2 password: " WSO2_PASSWORD
    echo

    export WSO2_UPDATES_SKIP_CONFLICTS="true"
    cd "$APIM_HOME/bin"

    log_info "Updating the U2 tool itself..."
    ./wso2update_linux -u "$WSO2_USERNAME" --password "$WSO2_PASSWORD" || [[ $? -eq 2 ]]

    log_info "Updating pack to U2 level $U2_LEVEL ..."
    ./wso2update_linux -u "$WSO2_USERNAME" --password "$WSO2_PASSWORD" -l "$U2_LEVEL" --no-backup || [[ $? -eq 2 ]]

    CONFIG_FILE="$APIM_HOME/updates/config.json"
    if [ -f "$CONFIG_FILE" ]; then
        jq '.username = "" | ."backup-dir" = "" | .product.backup = "" | .product."backup-size" = 0 | .service."access-token" = "" | .service."refresh-token" = ""' \
            "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"
        log_info "✓ PI info removed from config.json"
    fi

    cd - > /dev/null
    log_info "✓ U2 update applied"
fi

################################################################################
# STEP 3: Replace deployment.toml
################################################################################
log_section "Step 3: Replacing deployment.toml"

backup_and_replace_file \
    "$ARTIFACTS_DIR/deployment.toml" \
    "$APIM_HOME/repository/conf/deployment.toml" \
    "deployment.toml"

################################################################################
# STEP 4: Copy JKS keystores from 4.1.0 source
################################################################################
if [ "${ENABLE_JKS_MIGRATION}" = "true" ]; then
    log_section "Step 4: Copying JKS Keystores"

    SECURITY_DIR="$APIM_HOME/repository/resources/security"
    BACKUP_DIR="$SECURITY_DIR/backup_$(date +%Y%m%d_%H%M%S)"

    mkdir -p "$BACKUP_DIR"
    ls "$SECURITY_DIR"/*.jks 1>/dev/null 2>&1 && cp "$SECURITY_DIR"/*.jks "$BACKUP_DIR/" && log_info "Existing JKS files backed up to $BACKUP_DIR"
    ls "$JKS_SOURCE_DIR"/*.jks 1>/dev/null 2>&1 && cp "$JKS_SOURCE_DIR"/*.jks "$SECURITY_DIR/" && log_info "✓ JKS files copied from $JKS_SOURCE_DIR" \
        || { log_error "No JKS files found in $JKS_SOURCE_DIR"; exit 1; }
fi

################################################################################
# STEP 5: Copy JDBC driver (MySQL connector)
################################################################################
log_section "Step 5: Copying JDBC Driver"

copy_file \
    "$ARTIFACTS_DIR/mysql-connector-java-8.0.20.jar" \
    "$APIM_HOME/repository/components/lib/mysql-connector-java-8.0.20.jar" \
    "MySQL JDBC driver"

################################################################################
# STEP 6: Copy UI customizations (DevPortal + Publisher)
################################################################################
if [ "${ENABLE_UI_CUSTOMIZATIONS}" = "true" ]; then
    log_section "Step 6: Copying UI Customizations"

    DEVPORTAL="$APIM_HOME/repository/deployment/server/webapps/devportal"
    PUBLISHER="$APIM_HOME/repository/deployment/server/webapps/publisher"
    CUSTOM_DEVPORTAL="$CUSTOMIZATIONS_DIR/devportal"
    CUSTOM_PUBLISHER="$CUSTOMIZATIONS_DIR/publisher"

    log_info "Step 6.1: DevPortal customizations..."
    replace_directory      "$CUSTOM_DEVPORTAL/site/public/dist"            "$DEVPORTAL/site/public/dist"            "DevPortal dist"
    replace_file           "$CUSTOM_DEVPORTAL/site/public/pages/index.jsp" "$DEVPORTAL/site/public/pages/index.jsp" "DevPortal index.jsp"
    copy_file              "$CUSTOM_DEVPORTAL/site/public/images/MO_MASTER.png" "$DEVPORTAL/site/public/images/MO_MASTER.png" "DevPortal logo"
    replace_directory      "$CUSTOM_DEVPORTAL/site/public/images/landing"  "$DEVPORTAL/site/public/images/landing"  "DevPortal landing images"
    backup_and_replace_file "$CUSTOM_DEVPORTAL/site/public/theme/userTheme.json" "$DEVPORTAL/site/public/theme/userTheme.json" "DevPortal userTheme.json"

    log_info "Step 6.2: Publisher customizations..."
    replace_directory      "$CUSTOM_PUBLISHER/site/public/dist"             "$PUBLISHER/site/public/dist"            "Publisher dist"
    replace_file           "$CUSTOM_PUBLISHER/site/public/pages/index.jsp"  "$PUBLISHER/site/public/pages/index.jsp" "Publisher index.jsp"
    copy_file              "$CUSTOM_PUBLISHER/site/public/images/MO_MASTER.png" "$PUBLISHER/site/public/images/MO_MASTER.png" "Publisher logo"
    copy_file              "$CUSTOM_PUBLISHER/site/public/images/ai/MO_DesignAssistant.svg" "$PUBLISHER/site/public/images/ai/MO_DesignAssistant.svg" "Publisher AI icon"
    backup_and_replace_file "$CUSTOM_PUBLISHER/site/public/conf/userThemes.js" "$PUBLISHER/site/public/conf/userThemes.js" "Publisher userThemes.js"
fi

################################################################################
# STEP 7: Copy custom handler JARs
################################################################################
if [ "${ENABLE_CUSTOM_HANDLERS}" = "true" ]; then
    log_section "Step 7: Copying Custom Handler JARs"

    LIB_DEST="$APIM_HOME/repository/components/lib"
    DROPINS_DEST="$APIM_HOME/repository/components/dropins"
    mkdir -p "$DROPINS_DEST"

    for jar in \
        "apim-wso2-analytics-1.2.jar" \
        "apim-wso2-handlers-2.0.2.jar" \
        "apim-wso2-message-mediator-1.0.6.jar" \
        "apim-wso2-workflow-2.0.5.jar"; do
        copy_file "$CUSTOM_HANDLERS_DIR/$jar" "$LIB_DEST/$jar" "$jar"
    done

    copy_file \
        "$CUSTOM_HANDLERS_DIR/apim-wso2-jwt-self-contained-2.0.4.jar" \
        "$DROPINS_DEST/apim-wso2-jwt-self-contained-2.0.4.jar" \
        "JWT handler (dropins)"
fi

################################################################################
# STEP 8: Replace custom velocity_template.xml
################################################################################
if [ "${ENABLE_CUSTOM_VELOCITY_TEMPLATE}" = "true" ]; then
    log_section "Step 8: Replacing velocity_template.xml"
    backup_and_replace_file \
        "$CUSTOM_VELOCITY_TEMPLATE" \
        "$APIM_HOME/repository/resources/api_templates/velocity_template.xml" \
        "velocity_template.xml"
fi

################################################################################
# STEP 9: Run ciphertool
################################################################################
if [ "${ENABLE_CIPHERTOOL}" = "true" ]; then
    log_section "Step 9: Ciphertool Configuration"
    [ -f "$APIM_HOME/bin/ciphertool.sh" ] || { log_error "ciphertool.sh not found."; exit 1; }
    cd "$APIM_HOME/bin"
    ./ciphertool.sh -Dconfigure
    cd - > /dev/null
    log_info "✓ Ciphertool configuration complete"
fi

log_section "Pack Preparation Complete"
log_info "APIM_HOME: $APIM_HOME"
log_info "Target pack is ready — proceed to Script 4 (IS migration preparation)."
