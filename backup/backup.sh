#!/usr/bin/env bash
# Main backup script
# Usage: ./backup.sh [module] [--name <name>] [--no-encrypt] [--no-s3]
# Modules: keys, gpg, ssh, certs, config, pass, all (default: all)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/s3.sh"
source "${SCRIPT_DIR}/lib/keys.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/pass.sh"

# Parse arguments
MODULE="all"
BACKUP_NAME=""
NO_ENCRYPT=false
NO_S3=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        keys|gpg|ssh|certs|config|pass|all)
            MODULE="$1"
            shift
            ;;
        --name)
            BACKUP_NAME="$2"
            shift 2
            ;;
        --no-encrypt)
            NO_ENCRYPT=true
            shift
            ;;
        --no-s3)
            NO_S3=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [module] [--name <name>] [--no-encrypt] [--no-s3]"
            echo ""
            echo "Modules:"
            echo "  keys    Backup security keys (SSH, GPG, SSL) and pass store"
            echo "  gpg     Backup GPG keys only"
            echo "  ssh     Backup SSH keys only"
            echo "  certs   Backup SSL certificates only"
            echo "  config  Backup configuration files"
            echo "  pass    Backup pass password store"
            echo "  all     Backup everything (default)"
            echo ""
            echo "Options:"
            echo "  --name <name>  Custom output filename (keys/all: single encrypted bundle)"
            echo "  --no-encrypt   Skip GPG encryption"
            echo "  --no-s3        Skip S3 upload"
            echo "  -h, --help     Show this help"
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Export for backup functions
export BACKUP_NAME

# Load configuration
load_config

# Apply overrides
if [[ "$NO_ENCRYPT" == "true" ]]; then
    ENCRYPT_BACKUPS="false"
fi
if [[ "$NO_S3" == "true" ]]; then
    S3_BUCKET=""
fi

# Named composite runs are bundled into a single encrypted archive:
# submodules use default names and skip individual S3 uploads, then the
# bundle is encrypted and uploaded on its own.
BUNDLE_NAME=""
if [[ -n "$BACKUP_NAME" ]]; then
    case "$MODULE" in
        keys|all)
            BUNDLE_NAME="$BACKUP_NAME"
            BACKUP_NAME=""
            S3_BUCKET_SAVE="$S3_BUCKET"
            S3_BUCKET=""
            ;;
    esac
fi

# Run backup
echo ""
log_info "========================================="
log_info "  Backup Started - Module: ${MODULE}"
log_info "========================================="
echo ""

backups=()

case "$MODULE" in
    keys)
        backups+=("$(backup_keys)")
        backups+=("$(backup_pass)")
        ;;
    gpg)
        backups+=("$(backup_gpg)")
        ;;
    ssh)
        backups+=("$(backup_ssh)")
        ;;
    certs)
        backups+=("$(backup_certs)")
        ;;
    config)
        backups+=("$(backup_config)")
        ;;
    pass)
        backups+=("$(backup_pass)")
        ;;
    all)
        backups+=("$(backup_keys)")
        backups+=("$(backup_config)")
        backups+=("$(backup_pass)")
        ;;
esac

# Replace named composite results with a single encrypted bundle
if [[ -n "${BUNDLE_NAME}" ]] && [[ ${#backups[@]} -gt 0 ]]; then
    bundle_path=$(create_bundle "$BUNDLE_NAME" "${backups[@]}")
    backups=("$bundle_path")
    S3_BUCKET="${S3_BUCKET_SAVE:-}"
fi

# Cleanup old local backups
if [[ "${LOCAL_RETENTION_DAYS:-0}" -gt 0 ]]; then
    log_info "Cleaning local backups older than ${LOCAL_RETENTION_DAYS} days..."
    find "$(ensure_backup_dir)" -name "*.tar.gz*" -mtime "+${LOCAL_RETENTION_DAYS}" -delete 2>/dev/null || true
fi

# Cleanup old S3 backups
s3_cleanup

echo ""
log_info "========================================="
log_success "  Backup Complete"
log_info "========================================="
echo ""

for backup in "${backups[@]}"; do
    if [[ -n "$backup" ]]; then
        echo "  -> $backup ($(human_size "$backup"))"
    fi
done
echo ""
