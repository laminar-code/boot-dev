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

    # Store members under their basenames so archives extract to
    # clean relative paths instead of embedding absolute locations
    local src_args=()
    local src
    for src in "${sources[@]}"; do
        src_args+=(-C "$(dirname "$src")" "$(basename "$src")")
    done

    tar -czf "$output" "${exclude_args[@]}" "${src_args[@]}"
}

# Encrypt a file with GPG
encrypt_file() {
    local file="$1"
    local recipient="${GPG_RECIPIENT:-}"
    local passphrase="${GPG_PASSPHRASE:-}"

    if [[ -z "$recipient" ]]; then
        if [[ -z "$passphrase" ]]; then
            log_error "Symmetric encryption requires GPG_PASSPHRASE to be set (or configure GPG_RECIPIENT)"
            return 1
        fi
        gpg --batch --yes --pinentry-mode loopback \
            --symmetric --cipher-algo AES256 \
            --passphrase "$passphrase" \
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

    local pfargs=()
    if [[ -z "${GPG_RECIPIENT:-}" && -n "${GPG_PASSPHRASE:-}" ]]; then
        pfargs=(--pinentry-mode loopback --passphrase "$GPG_PASSPHRASE")
    fi

    gpg --batch --yes "${pfargs[@]}" --decrypt -o "$output" "$file"
    echo "$output"
}

# Bundle multiple backup files into a single encrypted archive.
# The bundle replaces the individual files, which are removed after
# encryption so no association between them remains on disk.
create_bundle() {
    local name="$1"
    shift
    local files=("$@")

    local backup_dir
    backup_dir=$(ensure_backup_dir)
    local bundle_path="${backup_dir}/${name}.tar.gz"

    local members=()
    local f
    for f in "${files[@]}"; do
        members+=("$(basename "$f")")
    done

    log_info "Creating bundle: $(basename "$bundle_path")"
    tar -czf "$bundle_path" -C "$backup_dir" "${members[@]}"

    # Always encrypt the bundle so its contents stay opaque
    log_info "Encrypting bundle..."
    local encrypted
    encrypted=$(encrypt_file "$bundle_path")

    # Remove individual archives; the bundle replaces them
    rm -f "${files[@]}"

    s3_upload "$encrypted"

    log_success "Bundle complete: $encrypted ($(human_size "$encrypted"))"
    echo "$encrypted"
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
