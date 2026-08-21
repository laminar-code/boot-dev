#!/usr/bin/env bash
# Common utilities for backup scripts

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_success() {
    echo -e "${GREEN}[OK]${NC}   $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_error() {
    echo -e "${RED}[ERR]${NC}  $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

# Check if a command exists
require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: $cmd"
        return 1
    fi
}

# Load configuration
load_config() {
    local config_file="${1:-$(dirname "$(realpath "$0")")/config/backup.conf}"
    if [[ -f "$config_file" ]]; then
        # shellcheck source=/dev/null
        source "$config_file"
    else
        log_error "Configuration file not found: $config_file"
        return 1
    fi
}

# Ensure backup directory exists
ensure_backup_dir() {
    local dir="${BACKUP_DIR:-$HOME/backups}"
    mkdir -p "$dir"
    echo "$dir"
}

# Generate timestamp for backup filenames
timestamp() {
    date '+%Y%m%d_%H%M%S'
}

# Get file size in human-readable format
human_size() {
    local file="$1"
    if [[ -f "$file" ]]; then
        du -h "$file" | cut -f1
    else
        echo "0"
    fi
}

# Create tar archive with exclusion patterns
create_archive() {
    local output="$1"
    shift
    local sources=("$@")

    local exclude_args=()
    local ignore_file="$(dirname "$(realpath "$0")")/.backupignore"

    if [[ -f "$ignore_file" ]]; then
        while IFS= read -r pattern; do
            [[ -z "$pattern" || "$pattern" == \#* ]] && continue
            exclude_args+=(--exclude="$pattern")
        done < "$ignore_file"
    fi

    local level="${COMPRESSION_LEVEL:-6}"
    tar -czf "$output" "${exclude_args[@]}" "${sources[@]}" 2>/dev/null
}

# Encrypt a file with GPG
encrypt_file() {
    local file="$1"
    local recipient="${GPG_RECIPIENT:-}"

    if [[ -z "$recipient" ]]; then
        gpg --batch --yes --symmetric --cipher-algo AES256 \
            --passphrase-file /dev/stdin <<< "" \
            -o "${file}.gpg" "$file" 2>/dev/null || \
        gpg --batch --yes --symmetric --cipher-algo AES256 \
            -o "${file}.gpg" "$file"
    else
        gpg --batch --yes --recipient "$recipient" \
            --trust-model always \
            -o "${file}.gpg" "$file"
    fi

    rm -f "$file"
    echo "${file}.gpg"
}

# Decrypt a file with GPG
decrypt_file() {
    local file="$1"
    local output="${2:-}"

    if [[ -z "$output" ]]; then
        output="${file%.gpg}"
    fi

    gpg --batch --yes --decrypt -o "$output" "$file"
    echo "$output"
}

# Parse module from arguments
parse_module() {
    local module="${1:-all}"
    case "$module" in
        keys|gpg|ssh|certs|config|pass|all)
            echo "$module"
            ;;
        *)
            log_error "Unknown module: $module"
            log_info "Available modules: keys, gpg, ssh, certs, config, pass, all"
            exit 1
            ;;
    esac
}
