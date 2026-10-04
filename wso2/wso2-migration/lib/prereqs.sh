#!/bin/bash
# lib/prereqs.sh — Prerequisite checks and dependency installation for WSO2 migration scripts
# Requires: lib/logging.sh to be sourced before this file

# Usage: check_command <command_name>
# Returns 0 if found, 1 if not.
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Usage: check_permissions
# Warns if not running as root (some steps may need sudo).
check_permissions() {
    if [ "$EUID" -ne 0 ]; then
        log_warn "Not running as root — some operations may require sudo"
    fi
}

# Install jq if missing.
install_jq() {
    if check_command jq; then
        log_info "jq is already installed"
        return 0
    fi
    log_warn "jq not found — installing..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if check_command apt-get; then
            sudo apt-get update && sudo apt-get install -y jq
        elif check_command yum; then
            sudo yum install -y jq
        else
            log_error "No supported package manager found. Install jq manually."
            return 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        check_command brew && brew install jq || { log_error "Homebrew not found. Install jq manually."; return 1; }
    else
        log_error "Unsupported OS. Install jq manually."
        return 1
    fi
    log_info "jq installed successfully"
}

# Install yq if missing.
install_yq() {
    if check_command yq; then
        log_info "yq is already installed"
        return 0
    fi
    log_warn "yq not found — installing..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        sudo chmod +x /usr/local/bin/yq
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        check_command brew && brew install yq || { log_error "Homebrew not found. Install yq manually."; return 1; }
    else
        log_error "Unsupported OS. Install yq manually."
        return 1
    fi
    log_info "yq installed successfully"
}

# Install rsync if missing.
install_rsync() {
    if check_command rsync; then
        log_info "rsync is already installed"
        return 0
    fi
    log_warn "rsync not found — installing..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if check_command apt-get; then
            sudo apt-get update && sudo apt-get install -y rsync
        elif check_command yum; then
            sudo yum install -y rsync
        else
            log_error "No supported package manager found. Install rsync manually."
            return 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        log_error "rsync not found on macOS. Install it manually."
        return 1
    fi
    log_info "rsync installed successfully"
}

# Check Java version. Accepts required major version as argument (default: 21).
# Usage: check_java <required_major_version>
check_java() {
    local required="${1:-21}"
    log_info "Checking Java installation (required: Java $required)..."

    if ! check_command java; then
        log_error "Java not found. Install OpenJDK $required."
        return 1
    fi

    local installed
    installed=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
    log_info "Detected Java major version: $installed"

    if [ "$installed" != "$required" ]; then
        log_warn "Java $required required, but Java $installed found"
        log_warn "Install OpenJDK $required and ensure it is on PATH before running migration scripts"
        return 1
    fi

    # Set JAVA_HOME if not already set
    if [ -z "${JAVA_HOME:-}" ]; then
        local java_path
        java_path=$(readlink -f "$(which java)" 2>/dev/null || which java)
        export JAVA_HOME
        JAVA_HOME=$(dirname "$(dirname "$java_path")")
        log_info "JAVA_HOME set to: $JAVA_HOME"
    fi

    export PATH="$JAVA_HOME/bin:$PATH"
    log_info "Java $required: OK — $(java -version 2>&1 | head -n 1)"
}

# Install all standard migration dependencies (jq, yq, rsync) and check Java.
# Usage: install_all_dependencies <java_version>
install_all_dependencies() {
    local java_version="${1:-21}"
    log_section "Installing Migration Dependencies"
    install_jq
    install_yq
    install_rsync
    check_java "$java_version"
    echo
}
