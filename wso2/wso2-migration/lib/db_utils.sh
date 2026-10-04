#!/bin/bash
# lib/db_utils.sh — Database helper functions for WSO2 migration scripts
# Requires: lib/logging.sh to be sourced before this file
# Uses DB_PORT from migration.config.sh (defaults to 3306). Always connects over TCP,
# so the port is honoured even when DB_HOST is "localhost".

# Usage: test_db_connection <host> <user> <password>
test_db_connection() {
    local db_host="$1"
    local db_user="$2"
    local db_password="$3"

    log_info "Testing database connection to $db_host..."
    if mysql -h "$db_host" -P "${DB_PORT:-3306}" --protocol=TCP -u "$db_user" -p"$db_password" \
        -e "SELECT 1;" >/dev/null 2>&1; then
        log_info "✓ Database connection successful"
        return 0
    else
        log_error "Failed to connect to database at $db_host"
        log_error "Please verify your credentials and try again"
        return 1
    fi
}

# Usage: execute_db_script <host> <user> <password> <db_name> <script_path>
execute_db_script() {
    local db_host="$1"
    local db_user="$2"
    local db_password="$3"
    local db_name="$4"
    local script_path="$5"

    if [ ! -f "$script_path" ]; then
        log_error "DB script not found: $script_path"
        return 1
    fi

    log_info "Executing DB script on database: $db_name"
    log_warn "This operation will modify your database. Ensure you have a backup."

    if mysql -h "$db_host" -P "${DB_PORT:-3306}" --protocol=TCP -u "$db_user" -p"$db_password" "$db_name" < "$script_path"; then
        log_info "✓ DB script executed successfully on $db_name"
        return 0
    else
        log_error "Failed to execute DB script: $script_path"
        return 1
    fi
}

# Usage: prompt_db_credentials
# Populates: DB_NAME, DB_USER, DB_PASSWORD (caller must declare these as local or global)
prompt_db_credentials() {
    local label="${1:-database}"
    read -p "Enter $label name: " DB_NAME
    read -p "Enter $label username: " DB_USER
    read -s -p "Enter $label password: " DB_PASSWORD
    echo

    if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
        log_error "Database credentials cannot be empty"
        return 1
    fi
}
