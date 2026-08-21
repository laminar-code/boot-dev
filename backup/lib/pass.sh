#!/usr/bin/env bash
# Pass password store backup module

backup_pass() {
    local backup_dir
    backup_dir=$(ensure_backup_dir)
    local ts
    ts=$(timestamp)

    local pass_dir="${PASS_STORE_DIR:-$HOME/.password-store}"
    if [[ ! -d "$pass_dir" ]]; then
        log_error "Pass store not found: $pass_dir"
        return 1
    fi

    log_info "Starting pass backup..."
    log_info "Including: $pass_dir"

    local archive_file="${backup_dir}/${BACKUP_NAME:-pass_${ts}}.tar.gz"
    tar -czf "$archive_file" "$pass_dir" 2>/dev/null

    local final_file="$archive_file"
    if [[ "${ENCRYPT_BACKUPS:-false}" == "true" ]]; then
        log_info "Encrypting backup..."
        final_file=$(encrypt_file "$archive_file")
    fi

    s3_upload "$final_file"

    log_success "Pass backup complete: $final_file ($(human_size "$final_file"))"
    echo "$final_file"
}

restore_pass() {
    local backup_file="$1"
    local restore_dir="${2:-/}"

    log_info "Restoring pass store from: $backup_file"

    local file="$backup_file"
    if [[ "$file" == *.gpg ]]; then
        log_info "Decrypting backup..."
        file=$(decrypt_file "$file")
    fi

    gunzip -f "$file" 2>/dev/null
    file="${file%.gz}"

    tar -xf "$file" -C "$restore_dir" 2>/dev/null

    log_success "Pass store restored to: $restore_dir"
}
