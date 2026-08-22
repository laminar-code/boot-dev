#!/usr/bin/env bash
# Configuration files backup module

backup_config() {
    local backup_dir
    backup_dir=$(ensure_backup_dir)
    local ts
    ts=$(timestamp)
    local archive_name="${BACKUP_NAME:-config_${ts}}.tar.gz"
    local archive_path="${backup_dir}/${archive_name}"

    log_info "Starting configuration backup..."

    local sources=()
    local staging_dir="${backup_dir}/config_staging_${ts}"
    mkdir -p "$staging_dir"

    # System config directories
    if [[ -n "${SYSTEM_CONFIG_DIRS:-}" ]]; then
        for dir in $SYSTEM_CONFIG_DIRS; do
            if [[ -d "$dir" ]]; then
                # Copy to staging to avoid permission issues
                local staging_dest="${staging_dir}/$(basename "$dir")"
                cp -a "$dir" "$staging_dest" 2>/dev/null || {
                    log_warn "Could not copy $dir (try running as root)"
                    continue
                }
                sources+=("$staging_dest")
                log_info "Including system config: $dir"
            else
                log_warn "System config dir not found: $dir"
            fi
        done
    fi

    # User config directories
    if [[ -n "${USER_CONFIG_DIRS:-}" ]]; then
        for dir in $USER_CONFIG_DIRS; do
            if [[ -d "$dir" ]]; then
                sources+=("$dir")
                log_info "Including user config: $dir"
            else
                log_warn "User config dir not found: $dir"
            fi
        done
    fi

    # Dotfiles
    if [[ -n "${DOTFILES:-}" ]]; then
        local dots_dir="${staging_dir}/dotfiles"
        mkdir -p "$dots_dir"

        for dotfile in $DOTFILES; do
            local src="$HOME/$dotfile"
            if [[ -f "$src" ]]; then
                cp "$src" "$dots_dir/"
                log_info "Including dotfile: $dotfile"
            else
                log_warn "Dotfile not found: $dotfile"
            fi
        done

        if [[ -d "$dots_dir" ]] && [[ -n "$(ls -A "$dots_dir" 2>/dev/null)" ]]; then
            sources+=("$dots_dir")
        fi
    fi

    if [[ ${#sources[@]} -eq 0 ]]; then
        log_error "No configuration files found to backup"
        rm -rf "$staging_dir"
        return 1
    fi

    # Create archive
    log_info "Creating archive: $archive_name"
    create_archive "$archive_path" "${sources[@]}"

    # Cleanup staging
    rm -rf "$staging_dir"

    local final_file="$archive_path"
    if [[ "${ENCRYPT_BACKUPS:-false}" == "true" ]]; then
        log_info "Encrypting backup..."
        final_file=$(encrypt_file "$archive_path")
    fi

    # Upload to S3
    s3_upload "$final_file"

    log_success "Configuration backup complete: $final_file ($(human_size "$final_file"))"
    echo "$final_file"
}

# Restore configuration from backup
restore_config() {
    local backup_file="$1"
    local restore_dir="${2:-/}"

    log_info "Restoring configuration from: $backup_file"

    # Work on a temp copy so the original backup is never modified
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local file="${tmp_dir}/$(basename "${backup_file%.gpg}")"
    cp "$backup_file" "$file"

    # Decrypt if needed
    if [[ "$backup_file" == *.gpg ]]; then
        log_info "Decrypting backup..."
        file=$(decrypt_file "$file")
    fi

    # Extract
    tar -xzf "$file" -C "$restore_dir"

    # Cleanup temp files
    rm -rf "$tmp_dir"

    log_success "Configuration restored to: $restore_dir"
}
