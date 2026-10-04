#!/bin/bash
# =============================================================================
# migration.config.sh — Example configuration for APIM 4.1.0 → 4.5.0
#
# This is a reference implementation showing a filled-in config for a MySQL
# all-in-one deployment with U2 updates, JKS migration, UI customizations,
# custom handler JARs, and a custom velocity template.
#
# Replace all <YOUR_...> values with your actual environment values.
# =============================================================================

# -----------------------------------------------------------------------------
# MIGRATION VERSIONS
# -----------------------------------------------------------------------------
SOURCE_VERSION="4.1.0"
TARGET_VERSION="4.5.0"

IS_SOURCE_VERSION="5.11.0"
IS_TARGET_VERSION="6.0.0"

JAVA_REQUIRED_VERSION="21"

# -----------------------------------------------------------------------------
# DATABASE (MySQL)
# -----------------------------------------------------------------------------
DB_HOST="<YOUR_DB_HOST>"                  # e.g. my-db.example.com or 10.0.0.5 (no ":port")
DB_PORT="3306"
DB_ROOT_USER="root"
DB_APIM_NAME="wso2am_db"
DB_SHARED_NAME="wso2shared_db"

APIM_DB_USER="db_admin"
APIM_DB_PASSWORD="<YOUR_DB_PASSWORD>"

# -----------------------------------------------------------------------------
# PATHS
# -----------------------------------------------------------------------------
MOUNT_DIR="/mnt"

PACK_SOURCE="$MOUNT_DIR/apim_packs/wso2am-4.5.0.5.zip"
UNZIP_DEST="$MOUNT_DIR"
APIM_HOME="$UNZIP_DEST/wso2am-4.5.0"

ARTIFACTS_DIR="$MOUNT_DIR/artifacts"
DUMP_DIR="$MOUNT_DIR/db_dumps"

MIGRATION_ARTIFACTS_DIR="$MOUNT_DIR/artifacts/Data_migration_artifacts"
IS_MIGRATION_DIR="$MIGRATION_ARTIFACTS_DIR/is"
APIM_MIGRATION_DIR="$MIGRATION_ARTIFACTS_DIR/apim"
DB_SCRIPT_PATH="$MIGRATION_ARTIFACTS_DIR/db-scripts/MySQL.sql"

# -----------------------------------------------------------------------------
# WSO2 U2 UPDATE
# -----------------------------------------------------------------------------
ENABLE_U2_UPDATE="true"
U2_LEVEL="28"

# -----------------------------------------------------------------------------
# CUSTOMIZATIONS
# -----------------------------------------------------------------------------
ENABLE_UI_CUSTOMIZATIONS="true"
CUSTOMIZATIONS_DIR="$MOUNT_DIR/customizations/ui-customizations-wso2am-4.5.0-U28-<YOUR_BUILD_DATE>"

ENABLE_CUSTOM_HANDLERS="true"
CUSTOM_HANDLERS_DIR="$MOUNT_DIR/customizations/custom_handlers"

ENABLE_CUSTOM_VELOCITY_TEMPLATE="true"
CUSTOM_VELOCITY_TEMPLATE="$ARTIFACTS_DIR/4.5.0.28_custom_velocity_template.xml"

ENABLE_JKS_MIGRATION="true"
JKS_SOURCE_DIR="$ARTIFACTS_DIR/410_jks"

ENABLE_CIPHERTOOL="true"
ENABLE_IS_MIGRATION="true"

# -----------------------------------------------------------------------------
# Sanity check — DB_HOST must not contain a port (use DB_PORT instead)
# -----------------------------------------------------------------------------
case "$DB_HOST" in
    *:*) echo "ERROR: DB_HOST=\"$DB_HOST\" contains a port. Put the host in DB_HOST and the port in DB_PORT."; exit 1 ;;
esac
