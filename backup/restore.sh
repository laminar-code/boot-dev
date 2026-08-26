#!/usr/bin/env bash
# Restore script
# Usage: ./restore.sh <backup-file> [restore-dir]
#        ./restore.sh --latest [module] [restore-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Track temp files for cleanup on exit
TEMP_FILES=()
cleanup() {
    for f in "${TEMP_FILES[@]}"; do
        [[ -e "$f" ]] && rm -rf "$f"
    done
}
trap cleanup EXIT

# Source libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/s3.sh"
source "${SCRIPT_DIR}/lib/keys.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/pass.sh"

# Parse arguments
RESTORE_DIR="/"
BACKUP_FILE=""
LATEST=false
MODULE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --latest)
            LATEST=true
            shift
            ;;
        keys|gpg|ssh|certs|config|pass)
            MODULE="$1"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 <backup-file> [restore-dir]"
            echo "       $0 --latest [module] [restore-dir]"
            echo ""
            echo "Options:"
            echo "  --latest    Restore from most recent backup"
            echo "  keys        Restore keys backup"
            echo "  gpg         Restore GPG keys backup"
            echo "  ssh         Restore SSH keys backup"
            echo "  certs       Restore SSL certificates backup"
            echo "  config      Restore config backup"
            echo "  pass        Restore pass password store"
            echo "  -h, --help  Show this help"
            exit 0
            ;;
        *)
            if [[ -z "$BACKUP_FILE" && "$LATEST" != "true" ]]; then
                BACKUP_FILE="$1"
            else
                RESTORE_DIR="$1"
            fi
            shift
            ;;
    esac
done

# Load configuration
load_config

# Recompute S3 base path now that config is loaded
S3_BASE="s3://${S3_BUCKET:-}"
if [[ -n "${S3_PREFIX:-}" ]]; then
    S3_BASE="${S3_BASE}/${S3_PREFIX}"
fi

# Find latest backup if requested
if [[ "$LATEST" == "true" ]]; then
    backup_dir=$(ensure_backup_dir)

    pattern="*.tar.gz*"
    if [[ -n "$MODULE" ]]; then
        pattern="${MODULE}_*.tar.gz*"
    fi

    BACKUP_FILE=$(ls -t "${backup_dir}"/${pattern} 2>/dev/null | head -1)

    if [[ -z "$BACKUP_FILE" ]]; then
        log_error "No backups found matching pattern: $pattern"
        exit 1
    fi

    log_info "Found latest backup: $BACKUP_FILE"
fi

if [[ -z "$BACKUP_FILE" ]]; then
    log_error "No backup file specified"
    echo "Usage: $0 <backup-file> [restore-dir]"
    echo "       $0 --latest [module] [restore-dir]"
    exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
    # Try to download from S3 into a unique temp directory
    s3tmp_dir=$(mktemp -d)
    TEMP_FILES+=("$s3tmp_dir")
    filename=$(basename "$BACKUP_FILE")
    log_info "Local file not found, attempting S3 download..."
    s3_download "$filename" "$s3tmp_dir" || {
        log_error "Backup file not found: $BACKUP_FILE"
        exit 1
    }
    BACKUP_FILE="${s3tmp_dir}/${filename}"
fi

echo ""
log_info "========================================="
log_info "  Restore Started"
log_info "  File: $BACKUP_FILE"
log_info "  Target: $RESTORE_DIR"
log_info "========================================="
echo ""

# Determine module from filename
detected_module=""
if [[ "$BACKUP_FILE" == *keys_* ]]; then
    detected_module="keys"
elif [[ "$BACKUP_FILE" == *gpg_* ]]; then
    detected_module="gpg"
elif [[ "$BACKUP_FILE" == *ssh_* ]]; then
    detected_module="ssh"
elif [[ "$BACKUP_FILE" == *certs_* ]]; then
    detected_module="certs"
elif [[ "$BACKUP_FILE" == *config_* ]]; then
    detected_module="config"
elif [[ "$BACKUP_FILE" == *pass_* ]]; then
    detected_module="pass"
fi

if [[ -n "$detected_module" ]]; then
    case "$detected_module" in
        keys)
            restore_keys "$BACKUP_FILE" "$RESTORE_DIR"
            ;;
        gpg)
            restore_gpg "$BACKUP_FILE" "$RESTORE_DIR"
            ;;
        ssh)
            restore_ssh "$BACKUP_FILE" "$RESTORE_DIR"
            ;;
        certs)
            restore_certs "$BACKUP_FILE" "$RESTORE_DIR"
            ;;
        config)
            restore_config "$BACKUP_FILE" "$RESTORE_DIR"
            ;;
        pass)
            restore_pass "$BACKUP_FILE" "$RESTORE_DIR"
            ;;
    esac
else
    # Generic restore - extract bundle and handle inner encrypted archives
    log_info "Extracting backup..."

    # Work on a temp copy so the original backup is never modified
    tmp_dir=$(mktemp -d)
    TEMP_FILES+=("$tmp_dir")
    file="${tmp_dir}/$(basename "${BACKUP_FILE%.gpg}")"
    cp "$BACKUP_FILE" "$file"

    if [[ "$BACKUP_FILE" == *.gpg ]]; then
        log_info "Decrypting bundle..."
        file=$(decrypt_file "$file")
    fi

    # Untar the bundle to a staging directory
    bundle_extract="${tmp_dir}/bundle"
    mkdir -p "$bundle_extract"
    tar -xzf "$file" -C "$bundle_extract"

    # Find and process all inner .tar.gz.gpg files
    inner_files=()
    while IFS= read -r -d '' f; do
        inner_files+=("$f")
    done < <(find "$bundle_extract" -name "*.tar.gz.gpg" -print0 2>/dev/null)

    if [[ ${#inner_files[@]} -gt 0 ]]; then
        log_info "Found ${#inner_files[@]} encrypted archive(s) in bundle"
        for inner_file in "${inner_files[@]}"; do
            log_info "Processing: $(basename "$inner_file")"
            extracted="$inner_file"
            if [[ "$inner_file" == *.gpg ]]; then
                extracted=$(decrypt_file "$inner_file")
            fi
            gunzip -f "$extracted" 2>/dev/null || true
            tar_file="${extracted%.gz}"
            if [[ -f "$tar_file" ]]; then
                tar -xf "$tar_file" -C "$RESTORE_DIR" 2>/dev/null
                log_success "Restored: $(basename "$tar_file")"
            fi
        done
    else
        # No inner encrypted archives, just extract directly
        tar -xzf "$file" -C "$RESTORE_DIR"
    fi

    log_success "Backup restored to: $RESTORE_DIR"
fi

echo ""
log_info "========================================="
log_success "  Restore Complete"
log_info "========================================="
echo ""
