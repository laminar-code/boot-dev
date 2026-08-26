#!/usr/bin/env bash
# S3 upload/download utilities (s3cmd)

S3_BASE="s3://${S3_BUCKET:-}"
if [[ -n "${S3_PREFIX:-}" ]]; then
    S3_BASE="${S3_BASE}/${S3_PREFIX}"
fi

# Upload a file to S3
s3_upload() {
    local file="$1"
    local bucket="${S3_BUCKET:-}"

    if [[ -z "$bucket" ]]; then
        return 0
    fi

    if [[ "${SKIP_S3:-false}" == "true" ]]; then
        return 0
    fi

    require_cmd s3cmd || return 1

    local filename
    filename=$(basename "$file")
    local s3_path="${S3_BASE}/${filename}"

    log_info "Uploading to ${s3_path}..."
    if s3cmd put "$file" "$s3_path" --quiet 2>/dev/null; then
        log_success "Uploaded to ${s3_path}"
    else
        log_error "Failed to upload to ${s3_path}"
        return 1
    fi
}

# Download a file from S3
s3_download() {
    local filename="$1"
    local output="${2:-.}"
    local bucket="${S3_BUCKET:-}"

    if [[ -z "$bucket" ]]; then
        log_error "S3 bucket not configured"
        return 1
    fi

    require_cmd s3cmd || return 1

    local s3_path="${S3_BASE}/${filename}"

    log_info "Downloading from ${s3_path}..."
    if s3cmd get "$s3_path" "$output" --quiet; then
        log_success "Downloaded from ${s3_path}"
    else
        log_error "Failed to download from ${s3_path}"
        return 1
    fi
}

# List backups in S3
s3_list() {
    local bucket="${S3_BUCKET:-}"

    if [[ -z "$bucket" ]]; then
        log_error "S3 bucket not configured"
        return 1
    fi

    require_cmd s3cmd || return 1

    log_info "Listing backups in ${S3_BASE}/..."
    s3cmd ls "${S3_BASE}/"
}

# Clean old backups from S3
s3_cleanup() {
    local bucket="${S3_BUCKET:-}"
    local retention="${S3_RETENTION_DAYS:-90}"

    if [[ -z "$bucket" || "$retention" -eq 0 ]]; then
        return 0
    fi

    require_cmd s3cmd || return 1

    local cutoff_date
    cutoff_date=$(date -d "-${retention} days" '+%Y-%m-%d' 2>/dev/null || \
                  date -v-"${retention}"d '+%Y-%m-%d')

    log_info "Cleaning S3 backups older than ${retention} days..."

    s3cmd ls "${S3_BASE}/" | \
    while read -r line; do
        local file_date
        file_date=$(echo "$line" | awk '{print $1}')
        local file_path
        file_path=$(echo "$line" | awk '{print $NF}')

        if [[ -n "$file_path" && "$file_date" < "$cutoff_date" ]]; then
            log_info "Deleting old backup: $(basename "$file_path")"
            s3cmd del "$file_path" --quiet 2>/dev/null
        fi
    done
}
