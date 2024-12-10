#!/bin/bash

# Exit on error
set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Configure error handling
error_handler() {
    local exit_code=$?
    echo "Error occurred in script at line: ${1} (exit code: ${exit_code})"
    # Send notification or log to monitoring service
    exit $exit_code
}
trap 'error_handler ${LINENO}' ERR

# Initialize logging
LOG_FILE="/app/logs/app.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Check required directories
required_dirs=(
    "/app/data"
    "/app/logs"
    "/app/backup"
    "/app/images/input"
    "/app/images/output"
    "/app/images/temp"
    "/app/models"
)

for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        log "Creating directory: $dir"
        mkdir -p "$dir"
    fi
done

# Check and set permissions
log "Setting directory permissions..."
chown -R appuser:appuser /app
chmod -R 755 /app

# Initialize database if needed
if [ ! -f "$DB_PATH" ]; then
    log "Initializing database..."
    sqlite3 "$DB_PATH" < /app/sql/init.sql
    chown appuser:appuser "$DB_PATH"
fi

# Start monitoring if enabled
if [ "$PROMETHEUS_ENABLED" = true ]; then
    log "Starting Prometheus metrics exporter..."
    python3 /app/python_src/metrics_exporter.py &
fi

# Check for model files
if [ ! -d "$MODEL_PATH/t5-base" ]; then
    log "Downloading required models..."
    python3 -c "from transformers import AutoTokenizer, AutoModel; AutoTokenizer.from_pretrained('t5-base', cache_dir='$MODEL_PATH'); AutoModel.from_pretrained('t5-base', cache_dir='$MODEL_PATH')"
fi

# Check for Google Cloud credentials
if [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    if [ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
        log "Warning: Google Cloud credentials file not found"
    fi
fi

# Start health check service
log "Starting health check service..."
lua /app/lua-scripts/healthcheck.lua &

# Function to clean old logs and temporary files
cleanup_old_files() {
    find /app/logs -type f -name "*.log" -mtime +7 -delete
    find /app/images/temp -type f -mtime +1 -delete
}

# Schedule cleanup
(cron -f | (
    echo "0 0 * * * /app/cleanup_old_files.sh"
    crontab -
)) &

# Backup function
perform_backup() {
    if [ "$BACKUP_ENABLED" = true ]; then
        log "Performing scheduled backup..."
        lua /app/lua-scripts/backup.lua
    fi
}

# Schedule backup if enabled
if [ "$BACKUP_ENABLED" = true ]; then
    (cron -f | (
        echo "0 0 * * * /app/backup.sh"
        crontab -
    )) &
fi

# Start the main application
log "Starting EbaySEOApp..."
exec lua /app/lua-scripts/pipeline.lua