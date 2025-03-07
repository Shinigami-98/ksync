#!/bin/bash

# Create config directory and file if they don't exist
CONFIG_DIR="$HOME/.config/ksyncb"
CONFIG_FILE="$CONFIG_DIR/config.json"
LOG_FILE="/var/log/ksyncb-auto.log"

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Start log with separator
log "======== Starting KSyncB Automated Backup ========"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    log "ERROR: jq is not installed. Please install it to use configuration features."
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    log "ERROR: Config file not found at $CONFIG_FILE"
    log "Please run the interactive script first to create the config."
    exit 1
fi

# Function to get all device IDs from config
get_device_ids() {
    jq -r '.devices | keys[]' "$CONFIG_FILE"
}

# Function to get device name
get_device_name() {
    local device_id="$1"
    jq -r ".devices[\"$device_id\"].name // \"Unknown Device\"" "$CONFIG_FILE"
}

# Function to get directories for a device
get_device_directories() {
    local device_id="$1"
    jq -r ".devices[\"$device_id\"].directories[]" "$CONFIG_FILE" 2>/dev/null
}

# Function to get autobackup directories for a device
get_device_autobackup_directories() {
    local device_id="$1"
    # Get autobackup directories as JSON array
    local dirs_json=$(jq -r ".devices[\"$device_id\"].autobackup_directories[]" "$CONFIG_FILE" 2>/dev/null)
    echo "$dirs_json"
}

# Function to get autobackup setting for a device
get_device_autobackup() {
    local device_id="$1"
    # Get autobackup status, default to false if not set
    local autobackup=$(jq -r ".devices[\"$device_id\"].autobackup // false" "$CONFIG_FILE" 2>/dev/null)
    echo "$autobackup"
}

# Function to check if a device is currently connected
is_device_connected() {
    local device_id="$1"
    if kdeconnect-cli -a | grep -q "$device_id"; then
        return 0  # Device is available
    else
        return 1  # Device is not available
    fi
}

# Function to log messages
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Function to perform the backup
perform_backup() {
    local source="$1"
    local destination="$2"
    
    log_message "Backing up from: $source"
    log_message "To: $destination"
    
    # Create destination directory if it doesn't exist
    mkdir -p "$destination"
    
    # Run rsync with reduced verbosity for automated runs
    result=$(rsync -a --ignore-existing "$source/" "$destination/" 2>&1)
    status=$?
    
    # Log the result (but only failures in detail)
    if [ $status -eq 0 ]; then
        log_message "✅ Backup from $source completed successfully"
    else
        log_message "❌ Error during backup from $source"
        log_message "Error details: $result"
    fi
    
    return $status
}

# Function to send completion notification 
send_notification() {
    local device_id="$1"
    local message="$2"
    
    log_message "Sending notification to device $device_id: $message"
    kdeconnect-cli -d "$device_id" --ping-msg "$message" >/dev/null 2>&1
    kdeconnect-cli -d "$device_id" --send-message "KSyncB Auto: $message" >/dev/null 2>&1
}

# Process each device in config
process_devices() {
    local device_ids=$(get_device_ids)
    if [ -z "$device_ids" ]; then
        log_message "No devices found in config file."
        exit 0
    fi

    log_message "Found $(echo "$device_ids" | wc -l) devices in config file."
    for device_id in $device_ids; do
        process_device "$device_id"
    done
}

# Function to process a single device
process_device() {
    local device_id="$1"
    local device_name=$(get_device_name "$device_id")
    log_message "Processing device: $device_name ($device_id)"
    
    # Check if autobackup is enabled for this device
    local autobackup_status=$(get_device_autobackup "$device_id")
    if [ "$autobackup_status" != "true" ]; then
        log_message "Autobackup is disabled for device $device_name. Skipping."
        return
    fi
    
    # Check if device is connected
    if ! is_device_connected "$device_id"; then
        log_message "Device $device_name is not connected. Skipping."
        return
    fi
    
    log_message "Device $device_name is connected. Processing..."
    
    # Get autobackup directories for this device
    local dirs=$(get_device_autobackup_directories "$device_id")
    if [ -z "$dirs" ]; then
        log_message "No autobackup directories configured for device $device_name. Skipping."
        return
    fi
    
    # Set up backup destination
    local BACKUP_DIR="$HOME/Backup/$device_name"
    
    # Count directories properly
    local dir_count=0
    while IFS= read -r dir; do
        if [ -n "$dir" ]; then
            ((dir_count++))
        fi
    done <<< "$dirs"
    
    # Send notification that backup is starting
    local notification_message="Starting automated backup of $dir_count directories"
    log_message "$notification_message"
    send_notification "$device_id" "$notification_message"
    
    # Process each directory
    log_message "Starting backup process for $dir_count directories..."
    local success_count=0
    local failed_dirs=""
    
    while IFS= read -r dir; do
        if [ -z "$dir" ]; then
            continue
        fi
        
        # Extract the last component of the path for the subdirectory name
        local subdir=$(basename "$dir")
        local dest_dir="$BACKUP_DIR/$subdir"
        
        # Perform backup
        if perform_backup "$dir" "$dest_dir"; then
            ((success_count++))
        else
            failed_dirs+="$(basename "$dir") "
        fi
    done <<< "$dirs"
    
    # Send completion notification
    local completion_message=""
    if [ -n "$failed_dirs" ]; then
        completion_message="Backup completed with issues. $success_count successful, $(($dir_count-$success_count)) failed."
        log_message "Failed directories: $failed_dirs"
    else
        completion_message="Backup completed successfully. $success_count directories backed up."
    fi
    
    log_message "$completion_message"
    send_notification "$device_id" "$completion_message"
}

# Start processing devices
process_devices

log_message "======== KSyncB Automated Backup Completed ========" 