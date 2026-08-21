#!/usr/bin/env bash
# Main backup script
# Usage: ./backup.sh [module] [--name <name>] [--no-encrypt] [--no-s3]
# Modules: keys, gpg, ssh, certs, config, all (default: all)

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
            echo "  keys    Backup security keys (SSH, GPG, SSL)"
            echo "  gpg     Backup GPG keys only"
            echo "  ssh     Backup SSH keys only"
            echo "  certs   Backup SSL certificates only"
            echo "  config  Backup configuration files"
            echo "  pass    Backup pass password store"
            echo "  all     Backup everything (default)"
            echo ""
            echo "Options:"
            echo "  --name <name>  Custom output filename (without extension)"
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
