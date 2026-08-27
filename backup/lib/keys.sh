#!/usr/bin/env bash
# Security/keys backup module

backup_keys() {
    local backup_dir
    backup_dir=$(ensure_backup_dir)
    local ts
    ts=$(timestamp)
    local archive_name="${BACKUP_NAME:-keys_${ts}}"
    local staging_dir="${backup_dir}/staging_${ts}"
    local gpg_staging="${staging_dir}/gpg"

    mkdir -p "$staging_dir" "$gpg_staging"

    log_info "Starting keys backup..."

    # Export GPG keys
    local gpg_found=false
    if command -v gpg &>/dev/null; then
        # Count existing keys first; listing never needs a passphrase
        local pub_count sec_count
        pub_count=$(gpg --list-keys 2>/dev/null | grep -c '^pub' || true)
        sec_count=$(gpg --list-secret-keys 2>/dev/null | grep -c '^sec' || true)

        log_info "Exporting GPG public keys..."
        if [[ "$pub_count" -gt 0 ]]; then
            if ! gpg --export --output "${gpg_staging}/pubkeys.gpg"; then
                log_error "Failed to export GPG public keys"
                rm -rf "$staging_dir"
                return 1
            fi
            gpg_found=true
        else
            log_warn "No GPG public keys found"
        fi

        log_info "Exporting GPG secret keys..."
        if [[ "$sec_count" -gt 0 ]]; then
            rm -f "${gpg_staging}/secretkeys.gpg"
            if ! gpg --export-secret-keys --output "${gpg_staging}/secretkeys.gpg"; then
                log_error "Failed to export GPG secret keys (wrong passphrase?)"
                rm -rf "$staging_dir"
                return 1
            fi
            # A cancelled or wrong passphrase can yield an empty export
            if [[ ! -s "${gpg_staging}/secretkeys.gpg" ]]; then
                log_error "GPG secret key export produced no data (passphrase rejected?)"
                rm -rf "$staging_dir"
                return 1
            fi
            gpg_found=true
        else
            log_warn "No GPG secret keys found"
        fi

        log_info "Exporting GPG trust database..."
        if gpg --export-ownertrust 2>/dev/null | grep -q .; then
            gpg --export-ownertrust "${gpg_staging}/trustdb.txt" 2>/dev/null
        fi

        if [[ "$gpg_found" == "true" ]]; then
            log_success "GPG keys exported to staging"
        fi
    else
        log_warn "GPG not found, skipping GPG key export"
    fi

    # Collect sources for tar
    local sources=()

    # SSH keys (key pairs + config only)
    local ssh_dir="${SSH_KEYS_DIR:-$HOME/.ssh}"
    if [[ -d "$ssh_dir" ]]; then
        local ssh_staging="${staging_dir}/ssh"
        mkdir -p "$ssh_staging"
        for f in "$ssh_dir"/*; do
            local name
            name=$(basename "$f")
            case "$name" in
                *.pub|config)
                    cp "$f" "$ssh_staging/"
                    log_info "Including SSH: $name"
                    ;;
                known_hosts|authorized_keys)
                    ;;
                *)
                    if [[ -f "$f" ]] && { [[ -f "${f}.pub" ]] || [[ "$name" != *.* ]]; }; then
                        cp "$f" "$ssh_staging/"
                        log_info "Including SSH: $name"
                    fi
                    ;;
            esac
        done
        if [[ -n "$(ls -A "$ssh_staging" 2>/dev/null)" ]]; then
            sources+=("$ssh_staging")
        else
            rmdir "$ssh_staging" 2>/dev/null || true
            log_warn "No SSH key pairs found"
        fi
    else
        log_warn "SSH directory not found: $ssh_dir"
    fi

    # SSL certificates
    if [[ -n "${SSL_CERT_PATHS:-}" ]]; then
        for cert_path in $SSL_CERT_PATHS; do
            if [[ -e "$cert_path" ]]; then
                sources+=("$cert_path")
                log_info "Including SSL certs: $cert_path"
            else
                log_warn "SSL path not found: $cert_path"
            fi
        done
    fi

    # Add exported GPG keys (relative path for clean restore)
    if [[ "$gpg_found" == "true" ]] && [[ -n "$(ls -A "$gpg_staging" 2>/dev/null)" ]]; then
        sources+=("$gpg_staging")
    fi

    if [[ ${#sources[@]} -eq 0 ]]; then
        log_error "No keys found to backup"
        rm -rf "$staging_dir"
        return 1
    fi

    # Create gzipped tar
    local archive_file="${backup_dir}/${archive_name}.tar.gz"
    log_info "Creating archive: ${archive_name}.tar.gz"

    # Store members under their basenames (ssh/, gpg/, ...) so restores
    # land in clean relative paths and the gpg/* patterns keep working
    local src_args=()
    local src
    for src in "${sources[@]}"; do
        src_args+=(-C "$(dirname "$src")" "$(basename "$src")")
    done
    tar -czf "$archive_file" "${src_args[@]}" 2>/dev/null

    # Cleanup staging
    rm -rf "$staging_dir"

    # Encrypt if enabled
    local final_file="$archive_file"
    if [[ "${ENCRYPT_BACKUPS:-false}" == "true" ]]; then
        log_info "Encrypting backup..."
        final_file=$(encrypt_file "$archive_file")
    fi

    # Upload to S3
    s3_upload "$final_file"

    log_success "Keys backup complete: $final_file ($(human_size "$final_file"))"
    echo "$final_file"
}

# Restore keys from backup
restore_keys() {
    local backup_file="$1"
    local restore_dir="${2:-/}"

    log_info "Restoring keys from: $backup_file"

    local staging_dir
    staging_dir=$(mktemp -d)
    local gpg_staging="${staging_dir}/gpg_extracted"
    mkdir -p "$gpg_staging"

    # Work on a temp copy so the original backup is never modified
    local file="${staging_dir}/$(basename "${backup_file%.gpg}")"
    cp "$backup_file" "$file"

    # Decrypt if needed
    if [[ "$backup_file" == *.gpg ]]; then
        log_info "Decrypting backup..."
        file=$(decrypt_file "$file")
    fi

    # Gunzip
    log_info "Decompressing backup..."
    gunzip -f "$file" 2>/dev/null
    file="${file%.gz}"

    # Find the tar file
    local tar_file="$file"

    if [[ ! -f "$tar_file" ]]; then
        log_error "No tar file found after decompression"
        rm -rf "$staging_dir" "$gpg_staging"
        return 1
    fi

    # Extract GPG exports to staging for import
    if tar -tf "$tar_file" 2>/dev/null | grep -q "^gpg/"; then
        log_info "Extracting GPG keys..."
        tar -xf "$tar_file" -C "$gpg_staging" --wildcards 'gpg/*' 2>/dev/null || true
    fi

    # Import GPG keys
    if [[ -d "${gpg_staging}/gpg" ]]; then
        if [[ -f "${gpg_staging}/gpg/pubkeys.gpg" ]]; then
            log_info "Importing GPG public keys..."
            gpg --import "${gpg_staging}/gpg/pubkeys.gpg" 2>&1 | tail -1 || log_warn "Failed to import public keys"
        fi
        if [[ -f "${gpg_staging}/gpg/secretkeys.gpg" ]]; then
            log_info "Importing GPG secret keys..."
            gpg --import "${gpg_staging}/gpg/secretkeys.gpg" 2>&1 | tail -1 || log_warn "Failed to import secret keys"
        fi
        if [[ -f "${gpg_staging}/gpg/trustdb.txt" ]]; then
            log_info "Importing GPG trust database..."
            gpg --import-ownertrust "${gpg_staging}/gpg/trustdb.txt" 2>&1 | tail -1 || log_warn "Failed to import trust database"
        fi
        log_success "GPG keys imported"
    fi

    # Restore everything else (SSH keys, SSL certs, credentials) to restore_dir
    log_info "Restoring files to: $restore_dir"
    tar -xf "$tar_file" -C "$restore_dir" --exclude='gpg/*' 2>/dev/null

    # Cleanup
    rm -rf "$staging_dir" "$gpg_staging"

    log_success "Keys restored to: $restore_dir"
}

# --- GPG module ---

backup_gpg() {
    local backup_dir
    backup_dir=$(ensure_backup_dir)
    local ts
    ts=$(timestamp)
    local staging_dir="${backup_dir}/staging_${ts}"
    local gpg_staging="${staging_dir}/gpg"

    mkdir -p "$staging_dir" "$gpg_staging"

    log_info "Starting GPG backup..."

    local gpg_found=false
    if ! command -v gpg &>/dev/null; then
        log_error "GPG not found"
        rm -rf "$staging_dir"
        return 1
    fi

    log_info "Exporting GPG public keys..."
    if gpg --export 2>/dev/null | grep -q .; then
        gpg --export --output "${gpg_staging}/pubkeys.gpg" 2>/dev/null
        gpg_found=true
    else
        log_warn "No GPG public keys found"
    fi

    log_info "Exporting GPG secret keys..."
    if gpg --export-secret-keys 2>/dev/null | grep -q .; then
        gpg --export-secret-keys --output "${gpg_staging}/secretkeys.gpg" 2>/dev/null
        gpg_found=true
    else
        log_warn "No GPG secret keys found"
    fi

    log_info "Exporting GPG trust database..."
    if gpg --export-ownertrust 2>/dev/null | grep -q .; then
        gpg --export-ownertrust "${gpg_staging}/trustdb.txt" 2>/dev/null
    fi

    if [[ "$gpg_found" != "true" ]]; then
        log_error "No GPG keys found to backup"
        rm -rf "$staging_dir"
        return 1
    fi

    local archive_file="${backup_dir}/${BACKUP_NAME:-gpg_${ts}}.tar.gz"
    tar -czf "$archive_file" "$gpg_staging" 2>/dev/null
    rm -rf "$staging_dir"

    local final_file="$archive_file"
    if [[ "${ENCRYPT_BACKUPS:-false}" == "true" ]]; then
        log_info "Encrypting backup..."
        final_file=$(encrypt_file "$archive_file")
    fi

    s3_upload "$final_file"

    log_success "GPG backup complete: $final_file ($(human_size "$final_file"))"
    echo "$final_file"
}

restore_gpg() {
    local backup_file="$1"
    local restore_dir="${2:-/}"

    log_info "Restoring GPG keys from: $backup_file"

    local staging_dir
    staging_dir=$(mktemp -d)

    local file="$backup_file"
    if [[ "$file" == *.gpg ]]; then
        log_info "Decrypting backup..."
        file=$(decrypt_file "$file")
    fi

    gunzip -f "$file" 2>/dev/null
    file="${file%.gz}"

    if tar -tf "$file" 2>/dev/null | grep -q "^.*gpg/"; then
        tar -xf "$file" -C "$staging_dir" --wildcards '*/gpg/*' 2>/dev/null || true
    fi

    local gpg_dir
    gpg_dir=$(find "$staging_dir" -type d -name "gpg" | head -1)

    if [[ -n "$gpg_dir" ]]; then
        if [[ -f "${gpg_dir}/pubkeys.gpg" ]]; then
            log_info "Importing GPG public keys..."
            gpg --import "${gpg_dir}/pubkeys.gpg" 2>&1 | tail -1 || log_warn "Failed to import public keys"
        fi
        if [[ -f "${gpg_dir}/secretkeys.gpg" ]]; then
            log_info "Importing GPG secret keys..."
            gpg --import "${gpg_dir}/secretkeys.gpg" 2>&1 | tail -1 || log_warn "Failed to import secret keys"
        fi
        if [[ -f "${gpg_dir}/trustdb.txt" ]]; then
            log_info "Importing GPG trust database..."
            gpg --import-ownertrust "${gpg_dir}/trustdb.txt" 2>&1 | tail -1 || log_warn "Failed to import trust database"
        fi
        log_success "GPG keys imported"
    fi

    rm -rf "$staging_dir"
    log_success "GPG restore complete"
}

# --- SSH module ---

backup_ssh() {
    local backup_dir
    backup_dir=$(ensure_backup_dir)
    local ts
    ts=$(timestamp)

    local ssh_dir="${SSH_KEYS_DIR:-$HOME/.ssh}"
    if [[ ! -d "$ssh_dir" ]]; then
        log_error "SSH directory not found: $ssh_dir"
        return 1
    fi

    log_info "Starting SSH backup..."

    local staging_dir="${backup_dir}/staging_${ts}"
    mkdir -p "$staging_dir/ssh"

    # Copy key pairs (private + public) and config
    local count=0
    for f in "$ssh_dir"/*; do
        local name
        name=$(basename "$f")
        case "$name" in
            *.pub)
                cp "$f" "$staging_dir/ssh/"
                log_info "Including public key: $name"
                count=$((count + 1))
                ;;
            config)
                cp "$f" "$staging_dir/ssh/"
                log_info "Including config: $name"
                count=$((count + 1))
                ;;
            known_hosts|authorized_keys|*.pub)
                ;;
            *)
                # Private key if a matching .pub exists, or if no extension
                if [[ -f "$f" ]] && { [[ -f "${f}.pub" ]] || [[ "$name" != *.* ]]; }; then
                    cp "$f" "$staging_dir/ssh/"
                    log_info "Including private key: $name"
                    count=$((count + 1))
                fi
                ;;
        esac
    done

    if [[ $count -eq 0 ]]; then
        log_error "No SSH key pairs or config found"
        rm -rf "$staging_dir"
        return 1
    fi

    local archive_file="${backup_dir}/${BACKUP_NAME:-ssh_${ts}}.tar.gz"
    tar -czf "$archive_file" -C "$staging_dir" ssh 2>/dev/null
    rm -rf "$staging_dir"

    local final_file="$archive_file"
    if [[ "${ENCRYPT_BACKUPS:-false}" == "true" ]]; then
        log_info "Encrypting backup..."
        final_file=$(encrypt_file "$archive_file")
    fi

    s3_upload "$final_file"

    log_success "SSH backup complete: $final_file ($(human_size "$final_file"))"
    echo "$final_file"
}

restore_ssh() {
    local backup_file="$1"
    local restore_dir="${2:-/}"

    log_info "Restoring SSH keys from: $backup_file"

    local file="$backup_file"
    if [[ "$file" == *.gpg ]]; then
        log_info "Decrypting backup..."
        file=$(decrypt_file "$file")
    fi

    gunzip -f "$file" 2>/dev/null
    file="${file%.gz}"

    local staging_dir
    staging_dir=$(mktemp -d)
    tar -xf "$file" -C "$staging_dir" 2>/dev/null

    local ssh_dir="${SSH_KEYS_DIR:-$HOME/.ssh}"
    if [[ -d "${staging_dir}/ssh" ]]; then
        mkdir -p "$ssh_dir"
        mv "${staging_dir}"/ssh/* "$ssh_dir"/ 2>/dev/null
        log_success "SSH keys restored to: $ssh_dir"
    else
        log_warn "No ssh directory found in backup"
    fi

    rm -rf "$staging_dir"
}

# --- Certs module ---

backup_certs() {
    local backup_dir
    backup_dir=$(ensure_backup_dir)
    local ts
    ts=$(timestamp)

    local private_dir="${SSL_PRIVATE_DIR:-/etc/ssl/private}"
    local certs_dir="${SSL_CERTS_DIR:-/etc/ssl/certs}"
    local ca_certs_dir="${SSL_CA_CERTS_DIR:-/usr/local/share/ca-certificates}"

    if [[ ! -d "$private_dir" ]]; then
        log_error "Private key directory not found: $private_dir"
        return 1
    fi

    log_info "Starting certs backup..."

    local staging_dir="${backup_dir}/staging_${ts}"
    mkdir -p "$staging_dir/ssl_private" "$staging_dir/ssl_certs" "$staging_dir/ssl_ca_certs"

    # Copy all private keys
    local count=0
    cp "$private_dir"/* "$staging_dir/ssl_private/" 2>/dev/null || true
    count=$(find "$staging_dir/ssl_private" -type f | wc -l)

    # Find matching certs for each private key
    if [[ -d "$certs_dir" ]]; then
        for key_file in "$staging_dir/ssl_private"/*; do
            [[ -f "$key_file" ]] || continue
            local base
            base=$(basename "$key_file")
            base="${base%.*}"  # strip .key/.pem/etc extension

            for ext in crt pem; do
                local cert="${certs_dir}/${base}.${ext}"
                if [[ -f "$cert" ]]; then
                    cp "$cert" "$staging_dir/ssl_certs/"
                    log_info "Including cert: ${base}.${ext}"
                fi
            done
        done
    fi

    # Copy CA certificates
    if [[ -d "$ca_certs_dir" ]]; then
        cp "$ca_certs_dir"/* "$staging_dir/ssl_ca_certs/" 2>/dev/null || true
        local ca_count
        ca_count=$(find "$staging_dir/ssl_ca_certs" -type f | wc -l)
        if [[ $ca_count -gt 0 ]]; then
            log_info "Including CA certificates: $ca_certs_dir ($ca_count files)"
        fi
    fi

    if [[ $count -eq 0 ]]; then
        log_error "No private keys found to backup"
        rm -rf "$staging_dir"
        return 1
    fi

    local archive_file="${backup_dir}/${BACKUP_NAME:-certs_${ts}}.tar.gz"
    tar -czf "$archive_file" -C "$staging_dir" ssl_private ssl_certs ssl_ca_certs 2>/dev/null
    rm -rf "$staging_dir"

    local final_file="$archive_file"
    if [[ "${ENCRYPT_BACKUPS:-false}" == "true" ]]; then
        log_info "Encrypting backup..."
        final_file=$(encrypt_file "$archive_file")
    fi

    s3_upload "$final_file"

    log_success "Certs backup complete: $final_file ($(human_size "$final_file"))"
    echo "$final_file"
}

restore_certs() {
    local backup_file="$1"
    local restore_dir="${2:-/}"

    log_info "Restoring SSL certificates from: $backup_file"

    local file="$backup_file"
    if [[ "$file" == *.gpg ]]; then
        log_info "Decrypting backup..."
        file=$(decrypt_file "$file")
    fi

    gunzip -f "$file" 2>/dev/null
    file="${file%.gz}"

    local staging_dir
    staging_dir=$(mktemp -d)
    tar -xf "$file" -C "$staging_dir" 2>/dev/null

    local private_dir="${SSL_PRIVATE_DIR:-/etc/ssl/private}"
    local certs_dir="${SSL_CERTS_DIR:-/etc/ssl/certs}"
    local ca_certs_dir="${SSL_CA_CERTS_DIR:-/usr/local/share/ca-certificates}"

    if [[ -d "${staging_dir}/ssl_private" ]]; then
        mkdir -p "${restore_dir}${private_dir}"
        cp "${staging_dir}"/ssl_private/* "${restore_dir}${private_dir}/" 2>/dev/null || true
        log_info "Private keys restored to ${restore_dir}${private_dir}"
    fi

    if [[ -d "${staging_dir}/ssl_certs" ]]; then
        mkdir -p "${restore_dir}${certs_dir}"
        cp "${staging_dir}"/ssl_certs/* "${restore_dir}${certs_dir}/" 2>/dev/null || true
        log_info "Certificates restored to ${restore_dir}${certs_dir}"
    fi

    if [[ -d "${staging_dir}/ssl_ca_certs" ]] && [[ -n "$(ls -A "${staging_dir}/ssl_ca_certs" 2>/dev/null)" ]]; then
        mkdir -p "${restore_dir}${ca_certs_dir}"
        cp "${staging_dir}"/ssl_ca_certs/* "${restore_dir}${ca_certs_dir}/" 2>/dev/null || true
        log_info "CA certificates restored to ${restore_dir}${ca_certs_dir}"
    fi

    rm -rf "$staging_dir"

    log_success "SSL certificates restored to: $restore_dir"
}
