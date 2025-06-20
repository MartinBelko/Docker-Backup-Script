#!/bin/bash

# ==============================================================================
# Automated Docker Backup, Encryption, Local Pruning, and rsync Synchronization
# Designed for Cron Job Automation with Discord Notifications
# ==============================================================================

# --- User Configuration ---

# The absolute path to the folder containing your 'docker-compose.yml' and data.
SOURCE_DIR="/home/user/homepage"

# A temporary local directory for the initial backup file (will be moved after encryption).
BACKUP_TEMP_DIR="/tmp/docker_backups"

# The local directory where encrypted backups will be stored before syncing to cloud.
# This directory will be synchronized with the remote storage.
LOCAL_ENCRYPTED_BACKUP_DIR="/var/backups/docker_encrypted" # <<< CONSIDER CHANGING THIS TO A PERSISTENT LOCATION

# Discord webhook URL for notifications.
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/"

# The passphrase for GPG encryption.
# IMPORTANT: For cron jobs, you must hardcode the passphrase here.
# For better security, consider using a passphrase file (see commented line).
GPG_PASSPHRASE="secret_passphrase"
# GPG_PASSPHRASE_FILE="/root/.secure/gpg-pass" # Alternative: use a file

# Remote Backup Server Details (e.g., Hetzner Storage Box)
REMOTE_USER="u123456(-sub1)"
REMOTE_HOST="u123456.your-storagebox.de"
REMOTE_DIR="folder/"

# SSH key location for Hetzner authentication
SSH_KEY_PATH="/path/to/.ssh/file"

# Number of backups to keep on the local storage and, by synchronization, on the remote server.
BACKUPS_TO_KEEP=5

# --- Advanced Configuration ---
LOG_FILE="/tmp/log/docker_backup.log"
HOSTNAME="$1"

# ==============================================================================
# Script Logic
# ==============================================================================
set -e # Exit immediately if a command exits with a non-zero status.

# --- Global Variables ---
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BASENAME=$(basename "$SOURCE_DIR")
ARCHIVE_FILE_TEMP="${BACKUP_TEMP_DIR}/${BASENAME}_${TIMESTAMP}.tar.gz" # Temporary unencrypted
ENCRYPTED_FILE_TEMP="${ARCHIVE_FILE_TEMP}.gpg" # Temporary encrypted file in /tmp
ENCRYPTED_FILE_FINAL="${LOCAL_ENCRYPTED_BACKUP_DIR}/${BASENAME}_${TIMESTAMP}.tar.gz.gpg" # Final location for encrypted file

STATUS="SUCCESS"
ERROR_MESSAGE=""

# Clear log file so it does not build up over time
> "$LOG_FILE"

# --- Functions ---

# Function for logging with timestamps
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to send Discord notifications
send_discord_notification() {
    local color=65280 # Green
    if [ "$STATUS" != "SUCCESS" ]; then
        color=16711680 # Red
    fi

    local description="Backup of \`$BASENAME\` on server \`$HOSTNAME\` completed with status: **$STATUS**."
    if [ ! -z "$ERROR_MESSAGE" ]; then
        description="$description\n\n**Error Details:**\n\`\`\`$ERROR_MESSAGE\`\`\`"
    fi

    JSON_PAYLOAD=$(printf '{
      "embeds": [{
        "title": "Docker Backup Notification",
        "description": "%s",
        "color": %d,
        "timestamp": "%s",
        "footer": { "text": "Backup Script" }
      }]
    }' "$description" "$color" "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")")

    curl -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$DISCORD_WEBHOOK_URL" &>/dev/null || log "WARNING: Failed to send Discord notification."
}

# Function for error handling and final cleanup
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ "$STATUS" == "SUCCESS" ]; then
        STATUS="FAILURE"
        ERROR_MESSAGE="Script exited unexpectedly at line ${BASH_LINENO[0]}. Check log at ${LOG_FILE}."
    fi

    log "INFO: Performing cleanup and restarting services..."
    if [ -f "${SOURCE_DIR}/docker-compose.yml" ]; then
        log "INFO: Ensuring Docker services are running in '${SOURCE_DIR}'..."
        docker compose -f "${SOURCE_DIR}/docker-compose.yml" up -d &>/dev/null || log "WARNING: Failed to restart Docker services."
    fi

    # Clean up local temporary files from the /tmp directory only
    if [ -f "$ARCHIVE_FILE_TEMP" ]; then
        rm -f "$ARCHIVE_FILE_TEMP"
        log "INFO: Removed temporary local tarball: $ARCHIVE_FILE_TEMP"
    fi
    if [ -f "$ENCRYPTED_FILE_TEMP" ]; then
        rm -f "$ENCRYPTED_FILE_TEMP"
        log "INFO: Removed temporary encrypted file: $ENCRYPTED_FILE_TEMP"
    fi

    log "INFO: Sending final status to Discord..."
    send_discord_notification

    if [ "$STATUS" == "SUCCESS" ]; then
        log "===================== Docker Backup Finished Successfully ====================="
    else
        log "===================== Docker Backup Failed ====================="
    fi
}

# Trap signals to ensure cleanup and notification runs on exit or error
trap cleanup EXIT INT TERM

# --- Main Script Execution ---

log "===================== Starting Docker Backup ====================="

# Validate configurations
if [ -z "$GPG_PASSPHRASE" ]; then
    STATUS="FAILURE"; ERROR_MESSAGE="GPG Passphrase is not set."; log "ERROR: $ERROR_MESSAGE"; exit 1
fi

if [ ! -f "$SSH_KEY_PATH" ]; then
    STATUS="FAILURE"; ERROR_MESSAGE="SSH key not found at '${SSH_KEY_PATH}'."; log "ERROR: $ERROR_MESSAGE"; exit 1
fi

if [ ! -d "$SOURCE_DIR" ] || [ ! -f "${SOURCE_DIR}/docker-compose.yml" ]; then
    STATUS="FAILURE"; ERROR_MESSAGE="Source directory '${SOURCE_DIR}' or its 'docker-compose.yml' not found."; log "ERROR: $ERROR_MESSAGE"; exit 1
fi

# Ensure backup directories exist
mkdir -p "$BACKUP_TEMP_DIR" || { STATUS="FAILURE"; ERROR_MESSAGE="Failed to create temporary backup directory: ${BACKUP_TEMP_DIR}."; log "ERROR: $ERROR_MESSAGE"; exit 1; }
mkdir -p "$LOCAL_ENCRYPTED_BACKUP_DIR" || { STATUS="FAILURE"; ERROR_MESSAGE="Failed to create local encrypted backup directory: ${LOCAL_ENCRYPTED_BACKUP_DIR}."; log "ERROR: $ERROR_MESSAGE"; exit 1; }


# 1. Stop Docker Containers
log "INFO: Stopping Docker services..."
docker compose -f "${SOURCE_DIR}/docker-compose.yml" down || { STATUS="FAILURE"; ERROR_MESSAGE="Failed to stop Docker services."; log "ERROR: $ERROR_MESSAGE"; exit 1; }

# 2. Create Compressed Archive
log "INFO: Creating compressed tarball..."
# The -C option changes the directory before adding, ensuring only the basename is in the archive root
tar -czf "$ARCHIVE_FILE_TEMP" -C "$(dirname "$SOURCE_DIR")" "$BASENAME" || { STATUS="FAILURE"; ERROR_MESSAGE="Failed to create tarball."; log "ERROR: $ERROR_MESSAGE"; exit 1; }

# 3. Encrypt the Archive
log "INFO: Encrypting the archive with GPG..."
gpg --symmetric --cipher-algo AES256 --batch --yes --passphrase "$GPG_PASSPHRASE" -o "$ENCRYPTED_FILE_TEMP" "$ARCHIVE_FILE_TEMP" || { STATUS="FAILURE"; ERROR_MESSAGE="GPG encryption failed."; log "ERROR: $ERROR_MESSAGE"; exit 1; }
rm -f "$ARCHIVE_FILE_TEMP" # Remove unencrypted tarball immediately after encryption

# 4. Move encrypted file to local backup storage
log "INFO: Moving encrypted backup to local storage: $LOCAL_ENCRYPTED_BACKUP_DIR"
mv "$ENCRYPTED_FILE_TEMP" "$ENCRYPTED_FILE_FINAL" || { STATUS="FAILURE"; ERROR_MESSAGE="Failed to move encrypted file to local storage."; log "ERROR: $ERROR_MESSAGE"; exit 1; }

# 5. Prune Old Backups on Local Server
log "INFO: Pruning old backups on local server. Keeping last ${BACKUPS_TO_KEEP}."
# Get list of files, sort by time, keep specified number, remove the rest
FILES_TO_DELETE=$(ls -1t "${LOCAL_ENCRYPTED_BACKUP_DIR}"/${BASENAME}_*.tar.gz.gpg | tail -n +$((${BACKUPS_TO_KEEP} + 1)))
if [ -n "$FILES_TO_DELETE" ]; then
    log "INFO: Deleting old local backups:\n${FILES_TO_DELETE}"
    echo "$FILES_TO_DELETE" | xargs -r rm || {
        log "WARNING: Failed to prune old local backups. This might lead to excessive local storage use."
        # We don't set STATUS to FAILURE here as the backup itself is valid.
    }
else
    log "INFO: No old local backups to prune."
fi
log "INFO: Local pruning process complete."

# 6. Synchronize Local Backups to Remote Server using rsync
log "INFO: Synchronizing local encrypted backups to remote server using rsync..."
# -a: archive mode (preserves permissions, timestamps, etc.)
# -z: compress file data during transfer
# --delete: delete files on the remote that are not in the local source directory
# The trailing slash on LOCAL_ENCRYPTED_BACKUP_DIR/ means copy contents INTO REMOTE_DIR
rsync -avz --delete \
    -e "ssh -p 23 -i \"$SSH_KEY_PATH\" -o StrictHostKeyChecking=no -o BatchMode=yes" \
    "${LOCAL_ENCRYPTED_BACKUP_DIR}/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}" || {
        STATUS="FAILURE"; ERROR_MESSAGE="rsync synchronization to remote server failed."; log "ERROR: $ERROR_MESSAGE"; exit 1;
    }
log "SUCCESS: Local backups synchronized with remote server."

# The 'trap' will now automatically run the cleanup function on successful exit.
exit 0