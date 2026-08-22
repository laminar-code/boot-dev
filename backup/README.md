# Backup

A modular bash-based backup system for security keys and configuration files, supporting local and S3 storage.

## Quick Start

```bash
# Edit configuration
vim config/backup.conf

# Run full backup
./backup.sh

# Backup specific module
./backup.sh keys
./backup.sh config

# Restore from backup
./restore.sh <backup-file>
./restore.sh --latest keys
```

## Structure

```
backup/
├── backup.sh          # Main backup entry point
├── restore.sh         # Restore from backup
├── config/
│   └── backup.conf    # Configuration (paths, S3, encryption)
├── lib/
│   ├── common.sh      # Logging and utilities
│   ├── s3.sh          # S3 upload/download
│   ├── keys.sh        # Security/keys backup
│   └── config.sh      # Configuration files backup
└── .backupignore      # Exclusion patterns
```

## Modules

- **keys** - SSH keys, GPG keys, SSL certificates, credentials, pass password store
- **config** - System configs, app configs, dotfiles

## Requirements

- `tar`, `gpg` (for encryption), `aws` CLI (for S3)
