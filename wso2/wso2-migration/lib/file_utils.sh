#!/bin/bash
# lib/file_utils.sh — File/directory operation helpers for WSO2 migration scripts
# Requires: lib/logging.sh to be sourced before this file

# Replace a directory (no backup). rsync preserves permissions and symlinks.
# Usage: replace_directory <source_dir> <destination_dir> <description>
replace_directory() {
    local source="$1"
    local destination="$2"
    local description="$3"

    if [ -d "$source" ]; then
        if [ -d "$destination" ]; then
            rm -rf "$destination"
            log_info "Removed existing $description"
        fi
        rsync -a "$source/" "$destination/" && \
            log_info "$description replaced successfully" || \
            log_warn "Failed to replace $description"
    else
        log_warn "Source $description not found: $source"
    fi
}

# Replace a file (no backup).
# Usage: replace_file <source_file> <destination_file> <description>
replace_file() {
    local source="$1"
    local destination="$2"
    local description="$3"

    if [ -f "$source" ]; then
        cp "$source" "$destination"
        log_info "$description replaced successfully"
    else
        log_warn "Source $description not found: $source"
    fi
}

# Copy a file (creates parent dirs if needed; does not overwrite by default).
# Usage: copy_file <source_file> <destination_file> <description>
copy_file() {
    local source="$1"
    local destination="$2"
    local description="$3"

    if [ -f "$source" ]; then
        mkdir -p "$(dirname "$destination")"
        cp "$source" "$destination"
        log_info "$description copied successfully"
    else
        log_warn "Source $description not found: $source"
    fi
}

# Backup the destination (timestamped .bkp) then replace with source.
# Usage: backup_and_replace_file <source_file> <destination_file> <description>
backup_and_replace_file() {
    local source="$1"
    local destination="$2"
    local description="$3"

    if [ -f "$source" ]; then
        if [ -f "$destination" ]; then
            cp "$destination" "${destination}.bkp.$(date +%Y%m%d_%H%M%S)"
            log_info "$description backed up"
        fi
        cp "$source" "$destination"
        log_info "$description replaced successfully"
    else
        log_warn "Source $description not found: $source"
    fi
}

# Backup the destination directory (timestamped .bkp) then replace with source.
# Usage: backup_and_replace_dir <source_dir> <destination_dir> <description>
backup_and_replace_dir() {
    local source="$1"
    local destination="$2"
    local description="$3"

    if [ -d "$source" ]; then
        if [ -d "$destination" ]; then
            cp -r "$destination" "${destination}.bkp.$(date +%Y%m%d_%H%M%S)"
            log_info "$description backed up"
            rm -rf "$destination"
        fi
        rsync -a "$source/" "$destination/" && \
            log_info "$description replaced successfully" || \
            log_warn "Failed to replace $description"
    else
        log_warn "Source $description not found: $source"
    fi
}
