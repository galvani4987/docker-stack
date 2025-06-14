#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipestatus: return status of the last command in a pipe that failed
set -o pipefail

# --- Configuration ---
# Base directory for all backups
BACKUP_BASE_DIR="/opt/docker-stack-backups" # Recommended: Use a dedicated backup disk or path

# Attempt to determine the project's root directory (parent of the 'scripts' directory)
PROJECT_ROOT_DIR_CMD_RESULT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROJECT_ROOT_DIR=${PROJECT_ROOT_DIR_CMD_RESULT} # Assign the result of the command to the variable

DOCKER_COMPOSE_FILE="${PROJECT_ROOT_DIR}/docker-compose.yml"
ENV_FILE="${PROJECT_ROOT_DIR}/.env"

# Timestamp for the current backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CURRENT_BACKUP_DIR="${BACKUP_BASE_DIR}/${TIMESTAMP}"

# Log file for the current backup run
LOG_FILE="${CURRENT_BACKUP_DIR}/backup_run.log"

# Number of days to retain backups
DAYS_TO_RETAIN_BACKUPS=7

# Docker Compose project name (usually the name of the parent directory of docker-compose.yml)
# This is used to correctly identify Docker-managed volumes.
# Attempt to get it from the .env file, otherwise use the directory name.
PROJECT_NAME_FROM_ENV=$(grep -E '^COMPOSE_PROJECT_NAME=' "${ENV_FILE}" 2>/dev/null || true) # Added 2>/dev/null and || true
if [ -n "${PROJECT_NAME_FROM_ENV}" ]; then
    # Extract value after '='
    COMPOSE_PROJECT_NAME=$(echo "${PROJECT_NAME_FROM_ENV}" | cut -d '=' -f2-)
else
    COMPOSE_PROJECT_NAME=$(basename "${PROJECT_ROOT_DIR}")
fi


# --- Logging Function ---
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - ${message}" | tee -a "${LOG_FILE}"
}

# --- Main Script ---

# Ensure backup directories exist
mkdir -p "${BACKUP_BASE_DIR}"
if [ ! -d "${BACKUP_BASE_DIR}" ]; then
    echo "Error: Base backup directory ${BACKUP_BASE_DIR} could not be created. Please check permissions or path."
    exit 1
fi
# Create directory for the current backup
mkdir -p "${CURRENT_BACKUP_DIR}"
if [ ! -d "${CURRENT_BACKUP_DIR}" ]; then
    # Try to log this error, though LOG_FILE might not be writable if CURRENT_BACKUP_DIR creation failed.
    # Fallback to echo if log_message itself fails.
    log_message "ERROR: Current backup directory ${CURRENT_BACKUP_DIR} could not be created." || \
    echo "ERROR: Current backup directory ${CURRENT_BACKUP_DIR} could not be created. Log file unavailable."
    exit 1
fi

# Start logging
log_message "INFO: Starting backup process for project: ${COMPOSE_PROJECT_NAME}"
log_message "INFO: Project root directory: ${PROJECT_ROOT_DIR}"
log_message "INFO: Backup will be stored in: ${CURRENT_BACKUP_DIR}"
log_message "INFO: Docker Compose file: ${DOCKER_COMPOSE_FILE}"
log_message "INFO: Environment file: ${ENV_FILE}"

# Check for .env file
if [ ! -f "${ENV_FILE}" ]; then
    log_message "ERROR: Environment file .env not found at ${ENV_FILE}. Cannot proceed without it for credentials."
    exit 1
fi

# Source environment variables from .env file to get credentials for pg_dump, etc.
# This makes variables like POSTGRES_USER, POSTGRES_PASSWORD available to the script.
log_message "INFO: Sourcing environment variables from ${ENV_FILE}"
set -a # Automatically export all variables
# Make sure to handle cases where .env might not exist, though we check above.
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
else
    log_message "ERROR: .env file disappeared before sourcing. Exiting."
    exit 1
fi
set +a # Stop automatically exporting variables


# --- Stop Services ---
log_message "INFO: Stopping application services to ensure data consistency..."
SERVICES_TO_STOP="n8n caddy authentik-server authentik-worker authentik-redis" # Define services that don't need special handling like DBs for their dump

if docker compose -f "${DOCKER_COMPOSE_FILE}" stop ${SERVICES_TO_STOP}; then
    log_message "INFO: Successfully stopped services: ${SERVICES_TO_STOP}."
else
    log_message "ERROR: Failed to stop one or more services: ${SERVICES_TO_STOP}. Please check Docker Compose logs."
    # Decide if script should exit here. For now, let's allow it to continue to try backing up what it can,
    # but this indicates a potential issue with the backup's consistency for these services.
    # exit 1 # Uncomment to make script exit on failure to stop services
fi
# Add a small delay to allow services to shut down gracefully if needed
sleep 5


# --- Backup PostgreSQL ---
log_message "INFO: Starting PostgreSQL backup..."
# Ensure POSTGRES_USER is set from the sourced .env file
if [ -z "${POSTGRES_USER:-}" ]; then
    log_message "ERROR: POSTGRES_USER is not set. Cannot perform PostgreSQL backup."
    # exit 1 # Decide if script should exit
else
    # Dynamically get the running postgres container ID
    # Ensure the postgres service is running for the backup. If it was stopped above, it needs to be started.
    # For pg_dumpall, postgres service must be running. It was not part of SERVICES_TO_STOP.
    POSTGRES_CONTAINER_ID=$(docker compose -f "${DOCKER_COMPOSE_FILE}" ps -q postgres)

    if [ -z "${POSTGRES_CONTAINER_ID}" ]; then
        log_message "ERROR: PostgreSQL container not found or not running. Attempting to start it for backup..."
        if docker compose -f "${DOCKER_COMPOSE_FILE}" up -d postgres; then
            log_message "INFO: Successfully started postgres container for backup."
            sleep 10 # Give postgres time to initialize fully
            POSTGRES_CONTAINER_ID=$(docker compose -f "${DOCKER_COMPOSE_FILE}" ps -q postgres)
            if [ -z "${POSTGRES_CONTAINER_ID}" ]; then
                 log_message "ERROR: Failed to start postgres container for backup. Skipping PostgreSQL backup."
            fi
        else
            log_message "ERROR: Could not start postgres container. Skipping PostgreSQL backup."
        fi
    fi

    # Proceed if POSTGRES_CONTAINER_ID is now set
    if [ -n "${POSTGRES_CONTAINER_ID:-}" ]; then
        log_message "INFO: Found/Started PostgreSQL container ID: ${POSTGRES_CONTAINER_ID}"
        PG_DUMP_FILENAME="postgres_dump.sql" # Removed timestamp
        PG_DUMP_PATH="${CURRENT_BACKUP_DIR}/${PG_DUMP_FILENAME}"

        # Use PGPASSWORD environment variable for pg_dumpall
        # POSTGRES_PASSWORD should be available in the script's environment due to sourcing .env
        if [ -z "${POSTGRES_PASSWORD:-}" ]; then
            log_message "ERROR: POSTGRES_PASSWORD is not set. Cannot perform authenticated PostgreSQL backup."
            # exit 1 # Decide if script should exit
        else
            log_message "INFO: Performing pg_dumpall to ${PG_DUMP_PATH}..."
            if docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" "${POSTGRES_CONTAINER_ID}" pg_dumpall -U "${POSTGRES_USER}" --clean --if-exists > "${PG_DUMP_PATH}"; then
                log_message "INFO: PostgreSQL backup successfully created at ${PG_DUMP_PATH}."
                # Compress the SQL dump
                log_message "INFO: Compressing PostgreSQL dump..."
                if gzip "${PG_DUMP_PATH}"; then
                    log_message "INFO: PostgreSQL dump compressed successfully to ${PG_DUMP_PATH}.gz."
                else
                    log_message "ERROR: Failed to compress PostgreSQL dump."
                fi
            else
                log_message "ERROR: PostgreSQL backup failed. Check pg_dumpall output or Docker logs for the container."
                # Consider removing the failed dump file: rm -f "${PG_DUMP_PATH}"
            fi
        fi
    else
        log_message "INFO: Skipping PostgreSQL backup as container is not running."
    fi
fi

# --- Backup Authentik PostgreSQL ---
log_message "INFO: Starting Authentik PostgreSQL backup..."
# Ensure AUTHENTIK_POSTGRES_USER is set from the sourced .env file
if [ -z "${AUTHENTIK_POSTGRES_USER:-}" ]; then
    log_message "ERROR: AUTHENTIK_POSTGRES_USER is not set. Cannot perform Authentik PostgreSQL backup."
else
    AUTHENTIK_POSTGRES_CONTAINER_ID=$(docker compose -f "${DOCKER_COMPOSE_FILE}" ps -q authentik-postgres)

    if [ -z "${AUTHENTIK_POSTGRES_CONTAINER_ID}" ]; then
        log_message "ERROR: Authentik PostgreSQL container not found or not running. Attempting to start it for backup..."
        if docker compose -f "${DOCKER_COMPOSE_FILE}" up -d authentik-postgres; then
            log_message "INFO: Successfully started authentik-postgres container for backup."
            sleep 10 # Give postgres time to initialize fully
            AUTHENTIK_POSTGRES_CONTAINER_ID=$(docker compose -f "${DOCKER_COMPOSE_FILE}" ps -q authentik-postgres)
            if [ -z "${AUTHENTIK_POSTGRES_CONTAINER_ID}" ]; then
                 log_message "ERROR: Failed to start authentik-postgres container for backup. Skipping Authentik PostgreSQL backup."
            fi
        else
            log_message "ERROR: Could not start authentik-postgres container. Skipping Authentik PostgreSQL backup."
        fi
    fi

    if [ -n "${AUTHENTIK_POSTGRES_CONTAINER_ID:-}" ]; then
        log_message "INFO: Found/Started Authentik PostgreSQL container ID: ${AUTHENTIK_POSTGRES_CONTAINER_ID}"
        AUTHENTIK_PG_DUMP_FILENAME="authentik_postgres_dump.sql"
        AUTHENTIK_PG_DUMP_PATH="${CURRENT_BACKUP_DIR}/${AUTHENTIK_PG_DUMP_FILENAME}"

        if [ -z "${AUTHENTIK_POSTGRES_PASSWORD:-}" ]; then
            log_message "ERROR: AUTHENTIK_POSTGRES_PASSWORD is not set. Cannot perform authenticated Authentik PostgreSQL backup."
        else
            log_message "INFO: Performing pg_dumpall for Authentik to ${AUTHENTIK_PG_DUMP_PATH}..."
            # Note: For Authentik, it's typically one database. pg_dump might be more appropriate if DB name is known.
            # Using pg_dumpall for consistency with the other DB backup, assuming AUTHENTIK_POSTGRES_USER has rights.
            # If AUTHENTIK_POSTGRES_DB is defined in .env, pg_dump -d "${AUTHENTIK_POSTGRES_DB}" would be better.
            # For now, pg_dumpall is used.
            if docker exec -e PGPASSWORD="${AUTHENTIK_POSTGRES_PASSWORD}" "${AUTHENTIK_POSTGRES_CONTAINER_ID}" pg_dumpall -U "${AUTHENTIK_POSTGRES_USER}" --clean --if-exists > "${AUTHENTIK_PG_DUMP_PATH}"; then
                log_message "INFO: Authentik PostgreSQL backup successfully created at ${AUTHENTIK_PG_DUMP_PATH}."
                log_message "INFO: Compressing Authentik PostgreSQL dump..."
                if gzip "${AUTHENTIK_PG_DUMP_PATH}"; then
                    log_message "INFO: Authentik PostgreSQL dump compressed successfully to ${AUTHENTIK_PG_DUMP_PATH}.gz."
                else
                    log_message "ERROR: Failed to compress Authentik PostgreSQL dump."
                fi
            else
                log_message "ERROR: Authentik PostgreSQL backup failed."
            fi
        fi
    else
        log_message "INFO: Skipping Authentik PostgreSQL backup as container is not running."
    fi
fi


# --- Backup Mapped Configuration Directories ---
log_message "INFO: Starting backup of mapped configuration directories..."
MAPPED_CONFIG_DIRS_PARENT="${PROJECT_ROOT_DIR}/config"
MAPPED_CONFIG_SUBDIRS="caddy" # Add other config subdirs if any

for subdir_name in ${MAPPED_CONFIG_SUBDIRS}; do
    source_path="${MAPPED_CONFIG_DIRS_PARENT}/${subdir_name}"
    backup_filename="config_${subdir_name}.tar.gz" # Removed timestamp
    backup_filepath="${CURRENT_BACKUP_DIR}/${backup_filename}"

    if [ -d "${source_path}" ]; then
        log_message "INFO: Archiving mapped config directory '${source_path}' to '${backup_filepath}'..."
        if tar -czvf "${backup_filepath}" -C "${MAPPED_CONFIG_DIRS_PARENT}" "${subdir_name}"; then
            log_message "INFO: Successfully archived '${source_path}'."
        else
            log_message "ERROR: Failed to archive '${source_path}'."
        fi
    else
        log_message "WARN: Mapped config directory '${source_path}' not found. Skipping."
    fi
done

# --- Backup Authentik Mapped Project Directories ---
log_message "INFO: Starting backup of Authentik mapped project directories..."
AUTHENTIK_MAPPED_PROJECT_DIRS="media custom-templates" # Relative to PROJECT_ROOT_DIR

for dir_name in ${AUTHENTIK_MAPPED_PROJECT_DIRS}; do
    source_path="${PROJECT_ROOT_DIR}/${dir_name}"
    backup_filename="authentik_${dir_name}.tar.gz"
    backup_filepath="${CURRENT_BACKUP_DIR}/${backup_filename}"

    if [ -d "${source_path}" ]; then
        log_message "INFO: Archiving Authentik mapped directory '${source_path}' to '${backup_filepath}'..."
        # Archive relative to PROJECT_ROOT_DIR to keep the path structure simple in the tarball
        if tar -czvf "${backup_filepath}" -C "${PROJECT_ROOT_DIR}" "${dir_name}"; then
            log_message "INFO: Successfully archived '${source_path}'."
        else
            log_message "ERROR: Failed to archive '${source_path}'."
        fi
    else
        log_message "WARN: Authentik mapped directory '${source_path}' not found. Skipping."
    fi
done

# --- Backup Key Docker Volumes ---
log_message "INFO: Starting backup of key Docker volumes..."
# Ensure services using these volumes were stopped in the 'Stop Services' step if direct volume copy is sensitive
# n8n, caddy, authentik-server, authentik-worker, authentik-redis were in SERVICES_TO_STOP.

DOCKER_VOLUMES_TO_BACKUP="n8n_data caddy_data caddy_config authentik_redis authentik_certs" # Add other key volumes if any

for volume_suffix in ${DOCKER_VOLUMES_TO_BACKUP}; do
    full_volume_name="${COMPOSE_PROJECT_NAME}_${volume_suffix}"
    volume_mountpoint=$(docker volume inspect "${full_volume_name}" -f '{{ .Mountpoint }}' 2>/dev/null)
    backup_filename="volume_${volume_suffix}.tar.gz" # Removed timestamp
    backup_filepath="${CURRENT_BACKUP_DIR}/${backup_filename}"

    if [ -z "${volume_mountpoint}" ]; then
        log_message "ERROR: Could not find mount point for Docker volume '${full_volume_name}'. Skipping."
    elif [ ! -d "${volume_mountpoint}" ]; then
        log_message "ERROR: Docker volume mount point '${volume_mountpoint}' for '${full_volume_name}' does not exist or is not a directory. Skipping."
    else
        log_message "INFO: Archiving Docker volume '${full_volume_name}' (from ${volume_mountpoint}) to '${backup_filepath}'..."
        if tar -czvf "${backup_filepath}" -C "${volume_mountpoint}" .; then # Backup the contents of the directory
            log_message "INFO: Successfully archived Docker volume '${full_volume_name}'."
        else
            log_message "ERROR: Failed to archive Docker volume '${full_volume_name}'."
        fi
    fi
done


# --- Backup Critical Project Files ---
log_message "INFO: Starting backup of critical project files..."

CRITICAL_FILES_TO_BACKUP=(
    "${ENV_FILE}" # .env file path already in a variable
    "${DOCKER_COMPOSE_FILE}" # docker-compose.yml file path already in a variable
    # Add any other critical files from PROJECT_ROOT_DIR here if needed
    # e.g., "${PROJECT_ROOT_DIR}/some_other_important_file.txt"
)

for file_path in "${CRITICAL_FILES_TO_BACKUP[@]}"; do
    if [ -f "${file_path}" ]; then
        base_filename=$(basename "${file_path}")
        backup_filepath="${CURRENT_BACKUP_DIR}/${base_filename}.backup" # Add .backup extension
        log_message "INFO: Copying critical file '${file_path}' to '${backup_filepath}'..."
        if cp "${file_path}" "${backup_filepath}"; then
            log_message "INFO: Successfully copied '${file_path}'."
        else
            log_message "ERROR: Failed to copy critical file '${file_path}'."
        fi
    else
        log_message "WARN: Critical file '${file_path}' not found. Skipping."
    fi
done


# --- Start Services ---
log_message "INFO: Starting services back up..."

# Start other application services that were stopped
# SERVICES_TO_STOP variable was defined in the "Stop Services" section
if [ -n "${SERVICES_TO_STOP:-}" ]; then # Check if SERVICES_TO_STOP was actually set
    log_message "INFO: Starting application services: ${SERVICES_TO_STOP}..."
    if docker compose -f "${DOCKER_COMPOSE_FILE}" start ${SERVICES_TO_STOP}; then
        log_message "INFO: Successfully started application services: ${SERVICES_TO_STOP}."
    else
        log_message "ERROR: Failed to start one or more application services: ${SERVICES_TO_STOP}. Check Docker Compose logs."
    fi
else
    log_message "WARN: SERVICES_TO_STOP variable was not defined or empty; skipping restart of these services (this might be an issue)."
fi


# --- Cleanup Old Backups ---
log_message "INFO: Starting cleanup of old backups..."
if [ -z "${DAYS_TO_RETAIN_BACKUPS##*[!0-9]*}" ]; then # Check if it's a non-negative integer
    log_message "WARN: DAYS_TO_RETAIN_BACKUPS ('${DAYS_TO_RETAIN_BACKUPS}') is not a valid non-negative integer. Skipping cleanup."
else
    log_message "INFO: Removing backup directories older than ${DAYS_TO_RETAIN_BACKUPS} days from ${BACKUP_BASE_DIR}..."
    # Using -mindepth 1 to ensure we don't try to delete BACKUP_BASE_DIR itself if it somehow matches
    # Using -maxdepth 1 to only find direct children (the timestamped backup folders)
    # The backup folders are named with YYYYMMDD_HHMMSS timestamp.
    # find will compare against the modification time of these folders.
    find_output=$(find "${BACKUP_BASE_DIR}" -mindepth 1 -maxdepth 1 -type d -mtime "+${DAYS_TO_RETAIN_BACKUPS}" -print -exec rm -rf {} \; 2>&1)

    if [ $? -eq 0 ]; then
        if [ -n "${find_output}" ]; then
            log_message "INFO: Successfully removed old backup directories listed below:"
            echo "${find_output}" | while IFS= read -r line; do log_message "INFO: Removed: ${line}"; done
        else
            log_message "INFO: No old backup directories found to remove."
        fi
    else
        log_message "ERROR: Cleanup of old backups failed. 'find' command exited with error."
        if [ -n "${find_output}" ]; then
            log_message "ERROR: Output from find: ${find_output}"
        fi
    fi
fi


log_message "INFO: Backup process completed successfully."
exit 0
```
