#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipestatus: return status of the last command in a pipe that failed
set -o pipefail

# --- Configuration & Setup ---
# Attempt to determine the project's root directory (parent of the 'scripts' directory)
PROJECT_ROOT_DIR_CMD_RESULT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROJECT_ROOT_DIR=${PROJECT_ROOT_DIR_CMD_RESULT}

DOCKER_COMPOSE_FILE="${PROJECT_ROOT_DIR}/docker-compose.yml"
ENV_FILE="${PROJECT_ROOT_DIR}/.env" # Path to the .env file to be restored

# Log file for the current restore run (consider putting this in a general log area or PROJECT_ROOT_DIR initially)
LOG_DIR="${PROJECT_ROOT_DIR}/logs" # Ensure this directory exists or is created by user/script
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/restore_run_$(date +%Y%m%d_%H%M%S).log"

# Docker Compose project name (usually the name of the parent directory of docker-compose.yml)
# This is used to correctly identify Docker-managed volumes.
# Attempt to get it from the .env file (once restored), otherwise use the directory name.
# Note: .env might not be available until restored, so using directory name initially.
COMPOSE_PROJECT_NAME_FROM_ENV="" # Will be updated after .env is restored if possible
if [ -f "${ENV_FILE}" ]; then # Check if .env exists at start (might be old one)
    TEMP_PROJECT_NAME=$(grep -E '^COMPOSE_PROJECT_NAME=' "${ENV_FILE}" 2>/dev/null || true)
    if [ -n "${TEMP_PROJECT_NAME}" ]; then
      COMPOSE_PROJECT_NAME_FROM_ENV=$(echo "${TEMP_PROJECT_NAME}" | cut -d '=' -f2-)
    fi
fi

if [ -n "${COMPOSE_PROJECT_NAME_FROM_ENV}" ]; then
    COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME_FROM_ENV}"
else
    COMPOSE_PROJECT_NAME=$(basename "${PROJECT_ROOT_DIR}")
fi


# --- Logging Function ---
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - ${message}" | tee -a "${LOG_FILE}"
}

# --- Argument Parsing & Validation ---
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_backup_directory>"
    echo "Example: $0 /opt/docker-stack-backups/20231027_103000"
    exit 1
fi

BACKUP_SOURCE_DIR="$1"

# Start logging as early as possible, but after we know LOG_FILE path
log_message "INFO: Restore script initiated."
log_message "INFO: Backup source directory provided: ${BACKUP_SOURCE_DIR}"


if [ ! -d "${BACKUP_SOURCE_DIR}" ]; then
    log_message "ERROR: Backup source directory '${BACKUP_SOURCE_DIR}' not found or is not a directory."
    exit 1
fi

# --- Main Script ---
log_message "INFO: Starting restore process from: ${BACKUP_SOURCE_DIR}"
log_message "INFO: Project root directory: ${PROJECT_ROOT_DIR}"
log_message "INFO: Docker Compose file to be used (after potential restore): ${DOCKER_COMPOSE_FILE}"
log_message "INFO: Target .env file (after potential restore): ${ENV_FILE}"
log_message "INFO: Docker Compose Project Name (initial/best guess): ${COMPOSE_PROJECT_NAME}"


# --- Stop and Clean Existing Docker Environment ---
log_message "INFO: Stopping and removing existing Docker Compose services, networks, and containers..."
log_message "INFO: This will use 'docker compose down'. Named volumes will be handled separately."

# It's important to use the DOCKER_COMPOSE_FILE that is about to be restored if it's different
# from one potentially in the project root. However, for 'down', the current one is usually fine.
# If docker-compose.yml is part of the backup and might change, consider copying it first, then 'down'.
# For now, assume the current docker-compose.yml in the project is sufficient to 'down' the services.
if [ -f "${DOCKER_COMPOSE_FILE}" ]; then
    if docker compose -f "${DOCKER_COMPOSE_FILE}" down --remove-orphans; then
        log_message "INFO: Successfully stopped and removed services, networks, and containers."
    else
        log_message "ERROR: Failed to execute 'docker compose down'. Check Docker Compose logs or system state."
        log_message "ERROR: Manual intervention might be required to clean the Docker environment before proceeding with restore."
        exit 1 # Critical to stop if 'down' fails
    fi
else
    log_message "WARN: ${DOCKER_COMPOSE_FILE} not found. Assuming no services are running or managed by it at this location."
    log_message "WARN: If services ARE running from a different compose file, they might conflict. Manual check advised."
fi
# Add a small delay to allow resources to be released
sleep 5


# --- Restore Critical Project Files ---
log_message "INFO: Starting restoration of critical project files (.env, docker-compose.yml)..."

CRITICAL_FILES_TO_RESTORE=(
    ".env.backup"
    "docker-compose.yml.backup"
    # Add other critical files here if they were backed up with a similar pattern
)

RESTORE_SUCCESSFUL_FLAG=true # Flag to track overall success of this section

for backup_filename_ext in "${CRITICAL_FILES_TO_RESTORE[@]}"; do
    source_file_path="${BACKUP_SOURCE_DIR}/${backup_filename_ext}"
    # Derive target filename by removing .backup extension if present
    if [[ "${backup_filename_ext}" == *.backup ]]; then
        target_filename=$(basename "${backup_filename_ext}" .backup)
    else
        target_filename=$(basename "${backup_filename_ext}")
    fi
    target_file_path="${PROJECT_ROOT_DIR}/${target_filename}"

    if [ -f "${source_file_path}" ]; then
        log_message "INFO: Restoring '${source_file_path}' to '${target_file_path}'..."
        if cp "${source_file_path}" "${target_file_path}"; then
            log_message "INFO: Successfully restored '${target_file_path}'."
        else
            log_message "ERROR: Failed to restore '${target_file_path}' from '${source_file_path}'."
            RESTORE_SUCCESSFUL_FLAG=false
        fi
    else
        log_message "WARN: Backup for critical file '${backup_filename_ext}' not found at '${source_file_path}'. Skipping."
        # Depending on how critical, you might want to set RESTORE_SUCCESSFUL_FLAG to false or even exit
        if [ "${backup_filename_ext}" == ".env.backup" ] || [ "${backup_filename_ext}" == "docker-compose.yml.backup" ]; then
             log_message "ERROR: Essential file ${backup_filename_ext} not found in backup. This is critical."
             RESTORE_SUCCESSFUL_FLAG=false
        fi
    fi
done

if ! ${RESTORE_SUCCESSFUL_FLAG}; then
    log_message "ERROR: One or more critical project files could not be restored. Review logs. Exiting."
    exit 1
fi

# Re-source the .env file to load potentially restored/changed variables for subsequent steps
if [ -f "${ENV_FILE}" ]; then
    log_message "INFO: Re-sourcing environment variables from restored ${ENV_FILE}..."
    set -a # Automatically export all variables
    source "${ENV_FILE}"
    set +a # Stop automatically exporting variables
    log_message "INFO: Environment variables re-sourced."

    # Update COMPOSE_PROJECT_NAME if it was defined in the restored .env
    # Ensure grep doesn't fail if the file or variable is missing, and handle empty result
    NEW_PROJECT_NAME_FROM_ENV_TEMP=$(grep -E '^COMPOSE_PROJECT_NAME=' "${ENV_FILE}" 2>/dev/null || true)
    NEW_PROJECT_NAME_FROM_ENV=""
    if [ -n "${NEW_PROJECT_NAME_FROM_ENV_TEMP}" ]; then
        NEW_PROJECT_NAME_FROM_ENV=$(echo "${NEW_PROJECT_NAME_FROM_ENV_TEMP}" | cut -d '=' -f2-)
    fi

    if [ -n "${NEW_PROJECT_NAME_FROM_ENV}" ] && [ "${COMPOSE_PROJECT_NAME}" != "${NEW_PROJECT_NAME_FROM_ENV}" ]; then
        log_message "INFO: COMPOSE_PROJECT_NAME updated from .env to: ${NEW_PROJECT_NAME_FROM_ENV}"
        COMPOSE_PROJECT_NAME="${NEW_PROJECT_NAME_FROM_ENV}"
    fi
else
    log_message "WARN: Restored .env file not found at ${ENV_FILE} after copy. Cannot re-source variables."
    # This should ideally not happen if the copy was successful and RESTORE_SUCCESSFUL_FLAG was true.
fi


# --- Restore Mapped Configuration Directories ---
log_message "INFO: Starting restoration of mapped configuration directories..."
MAPPED_CONFIG_DIRS_PARENT="${PROJECT_ROOT_DIR}/config"
# These are the names of the subdirectories within ./config that were backed up.
MAPPED_CONFIG_SUBDIRS_TO_RESTORE="authelia caddy homer waha"

RESTORE_CONFIG_SUCCESSFUL_FLAG=true # Use a new flag for this specific section

for subdir_name in ${MAPPED_CONFIG_SUBDIRS_TO_RESTORE}; do
    # Assuming backup.sh created archives like 'config_authelia.tar.gz' inside BACKUP_SOURCE_DIR
    source_archive_name="config_${subdir_name}.tar.gz"
    source_archive_path="${BACKUP_SOURCE_DIR}/${source_archive_name}"
    target_extract_parent_dir="${MAPPED_CONFIG_DIRS_PARENT}"
    target_subdir_path="${target_extract_parent_dir}/${subdir_name}"

    if [ -f "${source_archive_path}" ]; then
        log_message "INFO: Restoring mapped config directory '${subdir_name}' from '${source_archive_path}'..."

        log_message "INFO: Removing existing directory '${target_subdir_path}' if it exists, before extraction..."
        if rm -rf "${target_subdir_path}"; then
            log_message "INFO: Successfully removed existing '${target_subdir_path}'."
        else
            # This might not be an error if the directory simply didn't exist, hence a warning.
            log_message "WARN: Could not remove existing '${target_subdir_path}' (it may not have existed). Continuing with extraction."
        fi

        # Ensure parent directory for extraction exists (it should, as it's PROJECT_ROOT_DIR/config)
        mkdir -p "${target_extract_parent_dir}"

        log_message "INFO: Extracting '${source_archive_path}' to '${target_extract_parent_dir}'..."
        # The tar command in backup.sh was: tar -czvf "${backup_filepath}" -C "${MAPPED_CONFIG_DIRS_PARENT}" "${subdir_name}"
        # This means the archive contains the subdir_name itself. So, extracting to MAPPED_CONFIG_DIRS_PARENT is correct.
        if tar -xzvf "${source_archive_path}" -C "${target_extract_parent_dir}"; then
            log_message "INFO: Successfully restored and extracted '${subdir_name}' to '${target_extract_parent_dir}'."
        else
            log_message "ERROR: Failed to extract '${source_archive_path}' for '${subdir_name}'."
            RESTORE_CONFIG_SUCCESSFUL_FLAG=false
        fi
    else
        log_message "WARN: Backup archive '${source_archive_name}' not found in '${BACKUP_SOURCE_DIR}'. Skipping restore for '${subdir_name}'."
        # Depending on how critical this config is, you might set the flag to false.
        # For now, we'll assume individual missing configs are warnings but not critical failures for the whole script.
    fi
done

if ! ${RESTORE_CONFIG_SUCCESSFUL_FLAG}; then
    log_message "ERROR: One or more mapped configuration directories could not be fully restored. Review logs."
    # Consider exiting if any config restore fails: exit 1
fi


# --- Restore Docker Named Volumes ---
log_message "INFO: Starting restoration of Docker named volumes..."
# These are the suffixes for volumes like ${COMPOSE_PROJECT_NAME}_n8n_data, etc.
# Assumes backup.sh created archives like 'volume_n8n_data.tar.gz' inside BACKUP_SOURCE_DIR.
DOCKER_VOLUMES_TO_RESTORE="n8n_data caddy_data caddy_config redis_data postgres_data" # Added postgres_data

RESTORE_VOLUME_SUCCESSFUL_FLAG=true # Use a new flag for this specific section

for volume_suffix in ${DOCKER_VOLUMES_TO_RESTORE}; do
    full_volume_name="${COMPOSE_PROJECT_NAME}_${volume_suffix}"
    # Expected fixed archive name within BACKUP_SOURCE_DIR
    source_archive_name="volume_${volume_suffix}.tar.gz"
    source_archive_path="${BACKUP_SOURCE_DIR}/${source_archive_name}"

    if [ -f "${source_archive_path}" ]; then
        log_message "INFO: Restoring Docker volume '${full_volume_name}' from '${source_archive_path}'..."

        log_message "INFO: Attempting to remove existing volume '${full_volume_name}' (if it exists) for a clean restore..."
        if docker volume rm "${full_volume_name}" >/dev/null 2>&1; then
            log_message "INFO: Successfully removed existing volume '${full_volume_name}'."
        else
            log_message "INFO: Volume '${full_volume_name}' did not exist or could not be removed (may be in use if 'docker compose down' failed, or already removed). Proceeding to create."
        fi

        log_message "INFO: Creating new volume '${full_volume_name}'..."
        if docker volume create "${full_volume_name}" >/dev/null; then
            log_message "INFO: Successfully created volume '${full_volume_name}'."

            log_message "INFO: Extracting '${source_archive_path}' into volume '${full_volume_name}' using a temporary container..."
            # We need the absolute path for the backup source for the Docker volume mount.
            ABS_BACKUP_SOURCE_DIR=$(cd "${BACKUP_SOURCE_DIR}" && pwd) # Ensure this is correct if BACKUP_SOURCE_DIR is relative

            if docker run --rm \
                -v "${ABS_BACKUP_SOURCE_DIR}/${source_archive_name}":/backup_archive.tar.gz:ro \
                -v "${full_volume_name}":/restore_volume \
                alpine sh -c "tar -xzvf /backup_archive.tar.gz -C /restore_volume"; then
                log_message "INFO: Successfully extracted data into volume '${full_volume_name}'."
            else
                log_message "ERROR: Failed to extract data into volume '${full_volume_name}'."
                RESTORE_VOLUME_SUCCESSFUL_FLAG=false
            fi
        else
            log_message "ERROR: Failed to create volume '${full_volume_name}'."
            RESTORE_VOLUME_SUCCESSFUL_FLAG=false
        fi
    else
        log_message "WARN: Backup archive '${source_archive_name}' not found in '${BACKUP_SOURCE_DIR}'. Skipping restore for '${full_volume_name}'."
        # For data volumes like postgres_data, n8n_data, this is critical.
        if [ "${volume_suffix}" == "postgres_data" ] || [ "${volume_suffix}" == "n8n_data" ] || [ "${volume_suffix}" == "redis_data" ]; then
             log_message "ERROR: Essential data volume backup '${source_archive_name}' not found. This is critical."
             RESTORE_VOLUME_SUCCESSFUL_FLAG=false
        fi
    fi
done

if ! ${RESTORE_VOLUME_SUCCESSFUL_FLAG}; then
    log_message "ERROR: One or more Docker volumes could not be fully restored. Review logs."
    # exit 1 # Optionally exit
fi


# --- Restore PostgreSQL Database from SQL Dump ---
log_message "INFO: Starting PostgreSQL database restoration from SQL dump..."
# Assumes backup.sh created 'postgres_dump.sql.gz' (fixed name) inside BACKUP_SOURCE_DIR.
SQL_DUMP_GZ_NAME="postgres_dump.sql.gz" # EXPECTED FIXED NAME from backup.sh (needs reconciliation)
SQL_DUMP_GZ_PATH="${BACKUP_SOURCE_DIR}/${SQL_DUMP_GZ_NAME}"
SQL_DUMP_FILE_PATH_TEMP="${BACKUP_SOURCE_DIR}/postgres_dump_to_restore.sql" # Temporary decompressed file

if [ -f "${SQL_DUMP_GZ_PATH}" ]; then
    log_message "INFO: Decompressing PostgreSQL dump file '${SQL_DUMP_GZ_PATH}' to '${SQL_DUMP_FILE_PATH_TEMP}'..."
    if gunzip -c "${SQL_DUMP_GZ_PATH}" > "${SQL_DUMP_FILE_PATH_TEMP}"; then
        log_message "INFO: Successfully decompressed to '${SQL_DUMP_FILE_PATH_TEMP}'."
    else
        log_message "ERROR: Failed to decompress '${SQL_DUMP_GZ_PATH}'. Skipping PostgreSQL restore from dump."
        # Clean up potentially partially decompressed file
        rm -f "${SQL_DUMP_FILE_PATH_TEMP}"
    fi

    if [ -f "${SQL_DUMP_FILE_PATH_TEMP}" ]; then # Proceed if .sql file exists
        log_message "INFO: Ensuring only PostgreSQL service is running for restore..."
        # Note: 'docker compose down' was run earlier. We only bring up postgres here.
        # The postgres_data volume should have been restored in the previous step.
        # pg_dumpall includes commands to drop/create databases so it will overwrite.

        log_message "INFO: Starting PostgreSQL service..."
        if ! docker compose -f "${DOCKER_COMPOSE_FILE}" up -d postgres; then
            log_message "ERROR: Failed to start PostgreSQL service. Cannot restore database from dump."
            rm -f "${SQL_DUMP_FILE_PATH_TEMP}" # Clean up
            exit 1 # Critical
        fi

        log_message "INFO: Waiting for PostgreSQL to initialize (e.g., 15 seconds)..."
        sleep 15

        POSTGRES_CONTAINER_ID=$(docker compose -f "${DOCKER_COMPOSE_FILE}" ps -q postgres)
        if [ -z "${POSTGRES_CONTAINER_ID}" ]; then
            log_message "ERROR: PostgreSQL container not found or not running after attempt to start. Cannot restore."
            rm -f "${SQL_DUMP_FILE_PATH_TEMP}" # Clean up
            exit 1 # Critical
        fi
        log_message "INFO: PostgreSQL container ID: ${POSTGRES_CONTAINER_ID}"

        # POSTGRES_USER and POSTGRES_PASSWORD should be available from re-sourcing .env
        if [ -z "${POSTGRES_USER:-}" ] || [ -z "${POSTGRES_PASSWORD:-}" ]; then
            log_message "ERROR: POSTGRES_USER or POSTGRES_PASSWORD not set in environment. Cannot restore PostgreSQL."
            rm -f "${SQL_DUMP_FILE_PATH_TEMP}" # Clean up
            exit 1 # Critical
        fi

        log_message "INFO: Restoring database from '${SQL_DUMP_FILE_PATH_TEMP}'..."
        # For pg_dumpall, it's common to connect to a default db like 'postgres' or 'template1' as superuser.
        # The dump file itself will contain CREATE DATABASE, etc.
        # Use absolute path for the SQL dump file when passing to docker exec.
        ABS_SQL_DUMP_FILE_PATH_TEMP=$(cd "$(dirname "${SQL_DUMP_FILE_PATH_TEMP}")" && pwd)/$(basename "${SQL_DUMP_FILE_PATH_TEMP}")

        if docker exec -i -e PGPASSWORD="${POSTGRES_PASSWORD}" "${POSTGRES_CONTAINER_ID}" psql -U "${POSTGRES_USER}" -d postgres < "${ABS_SQL_DUMP_FILE_PATH_TEMP}"; then
            log_message "INFO: PostgreSQL database restore completed successfully."
        else
            log_message "ERROR: PostgreSQL database restore failed. Check psql output or Docker logs for the container."
            # exit 1 # Optionally exit
        fi

        log_message "INFO: Cleaning up decompressed SQL dump file: ${SQL_DUMP_FILE_PATH_TEMP}"
        rm -f "${SQL_DUMP_FILE_PATH_TEMP}"
    fi
else
    log_message "WARN: PostgreSQL dump file '${SQL_DUMP_GZ_NAME}' not found in '${BACKUP_SOURCE_DIR}'. Skipping restore from dump."
    log_message "INFO: PostgreSQL will rely on data restored from its volume backup (if that was performed and successful)."
fi


# --- Start All Services ---
log_message "INFO: Starting all services based on restored configuration and data..."

# Ensure DOCKER_COMPOSE_FILE points to the restored docker-compose.yml
# and .env has been re-sourced for any COMPOSE_PROJECT_NAME changes.
# This should have been handled by the 'Restore Critical Project Files' step.

if [ -f "${DOCKER_COMPOSE_FILE}" ]; then
    log_message "INFO: Executing 'docker compose -f "${DOCKER_COMPOSE_FILE}" up -d'..."
    if docker compose -f "${DOCKER_COMPOSE_FILE}" up -d; then
        log_message "INFO: All services started successfully in detached mode."
        log_message "INFO: It may take a few minutes for all services to be fully initialized and accessible."
        log_message "INFO: Please check service logs using 'docker compose logs <service_name>' if issues arise."
    else
        log_message "ERROR: Failed to start all services using 'docker compose up -d'."
        log_message "ERROR: Check Docker Compose logs and the state of individual containers."
        # exit 1 # Critical if services don't come up
    fi
else
    log_message "ERROR: Restored ${DOCKER_COMPOSE_FILE} not found. Cannot start services."
    exit 1 # Critical
fi


log_message "INFO: Restore process completed."
log_message "INFO: ==================================================================="
log_message "INFO: PLEASE MANUALLY VERIFY ALL SERVICES AND DATA THOROUGHLY!"
log_message "INFO: Check individual service logs: docker compose logs <service_name>"
log_message "INFO: Test application functionality and data integrity."
log_message "INFO: ==================================================================="
exit 0
```
