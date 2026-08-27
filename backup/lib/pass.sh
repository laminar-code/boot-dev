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

    local staging_dir="${backup_dir}/pass_staging_${ts}"
    mkdir -p "$staging_dir/pass"
    cp -a "$pass_dir" "$staging_dir/pass/"

    local archive_file="${backup_dir}/${BACKUP_NAME:-pass_${ts}}.tar.gz"
    tar -czf "$archive_file" -C "$staging_dir" pass 2>/dev/null
    rm -rf "$staging_dir"

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

    # Work on a temp copy so the original backup is never modified
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local file="${tmp_dir}/$(basename "${backup_file%.gpg}")"
    cp "$backup_file" "$file"

    if [[ "$backup_file" == *.gpg ]]; then
        log_info "Decrypting backup..."
        file=$(decrypt_file "$file")
    fi

    gunzip -f "$file" 2>/dev/null
    file="${file%.gz}"

    local staging_dir="${tmp_dir}/staging"
    mkdir -p "$staging_dir"
    tar -xf "$file" -C "$staging_dir" 2>/dev/null

    local pass_store="${PASS_STORE_DIR:-$HOME/.password-store}"
    if [[ -d "${staging_dir}/pass/.password-store" ]]; then
        mkdir -p "$pass_store"
        cp -a "${staging_dir}/pass/.password-store/." "$pass_store/" 2>/dev/null
        log_success "Pass store restored to: $pass_store"
    else
        log_warn "No pass directory found in backup"
    fi

    rm -rf "$tmp_dir"
}
