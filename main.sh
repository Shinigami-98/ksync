#!/bin/bash

# Create config directory and file if they don't exist
CONFIG_DIR="$HOME/.config/ksyncb"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Initialize config file if it doesn't exist
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    # Create a default empty config
    echo '{"devices":{}}' > "$CONFIG_FILE"
    echo "Created new configuration file at $CONFIG_FILE"
fi

# Function to load settings for a device
load_device_config() {
    local device_id="$1"
    # Check if device exists in config
    if jq -e ".devices[\"$device_id\"]" "$CONFIG_FILE" &>/dev/null; then
        # Device exists in config
        echo "Loading saved configuration for device: $device_id"
        return 0
    else
        # Device doesn't exist in config
        echo "No saved configuration for device: $device_id"
        return 1
    fi
}

# Simplified user interaction for directory selection
select_directories() {
    local prompt="$1"
    local -n selected_dirs="$2"
    local -n available_dirs="$3"
    
    echo "$prompt"
    for dir in "${available_dirs[@]}"; do
        if kdialog --yesno "Include directory?\n$dir"; then
            selected_dirs+=("$dir")
            echo "Added: $dir"
        fi
    done
}

# Function to get directories for a device
get_device_directories() {
    local device_id="$1"
    # Get directories as JSON array, then convert to bash array
    local dirs_json=$(jq -r ".devices[\"$device_id\"].directories[]" "$CONFIG_FILE" 2>/dev/null)
    echo "$dirs_json"
}

# Function to get autobackup directories for a device
get_device_autobackup_directories() {
    local device_id="$1"
    # Get autobackup directories as JSON array
    local dirs_json=$(jq -r ".devices[\"$device_id\"].autobackup_directories[]" "$CONFIG_FILE" 2>/dev/null)
    echo "$dirs_json"
}

# Function to get autobackup status for a device
get_device_autobackup() {
    local device_id="$1"
    # Get autobackup status, default to false if not set
    local autobackup=$(jq -r ".devices[\"$device_id\"].autobackup // false" "$CONFIG_FILE" 2>/dev/null)
    echo "$autobackup"
}

# Function to toggle autobackup status for a device
toggle_device_autobackup() {
    local device_id="$1"
    local current_status=$(get_device_autobackup "$device_id")
    
    # Toggle the status (true to false, false to true)
    local new_status="true"
    if [ "$current_status" = "true" ]; then
        new_status="false"
    fi
    
    # Create a temporary file to hold updated config
    local temp_file=$(mktemp)
    
    # Update only the autobackup field
    jq ".devices[\"$device_id\"].autobackup = $new_status" "$CONFIG_FILE" > "$temp_file"
    
    # Replace the original file
    mv "$temp_file" "$CONFIG_FILE"
    
    echo "Autobackup for device $device_id is now: $new_status"
}

# Function to convert bash array to JSON array
array_to_json() {
    local array=("$@")
    local json="["
    for ((i=0; i<${#array[@]}; i++)); do
        json+="\"${array[i]}\""
        if [ $i -lt $((${#array[@]}-1)) ]; then
            json+=","
        fi
    done
    json+="]"
    echo "$json"
}

# Function to save device settings to config
save_device_config() {
    local device_id="$1"
    local device_name="$2"
    shift 2
    local dirs=("$@")
    
    # Convert bash array to JSON array format
    local json_dirs=$(array_to_json "${dirs[@]}")
    
    # Create a temporary file to hold updated config
    local temp_file=$(mktemp)
    
    # Update the JSON, by default set autobackup_directories to the same as directories
    jq ".devices[\"$device_id\"] = {\"name\": \"$device_name\", \"last_used\": \"$(date +%Y-%m-%d)\", \"autobackup\": true, \"directories\": $json_dirs, \"autobackup_directories\": $json_dirs}" "$CONFIG_FILE" > "$temp_file"
    
    # Replace the original file
    mv "$temp_file" "$CONFIG_FILE"
    
    echo "Saved configuration for device: $device_id"
}

# Function to save autobackup directories for a device
save_device_autobackup_directories() {
    local device_id="$1"
    shift
    local dirs=("$@")
    
    # Convert bash array to JSON array format
    local json_dirs=$(array_to_json "${dirs[@]}")
    
    # Create a temporary file to hold updated config
    local temp_file=$(mktemp)
    
    # Update only the autobackup_directories field
    jq ".devices[\"$device_id\"].autobackup_directories = $json_dirs" "$CONFIG_FILE" > "$temp_file"
    
    # Replace the original file
    mv "$temp_file" "$CONFIG_FILE"
    
    echo "Autobackup directories for device $device_id updated"
}

# Function to perform the backup
perform_backup() {
    local source="$1"
    local destination="$2"
    
    echo "Backing up from: $source"
    echo "To: $destination"
    
    # Run rsync to copy only files that don't exist in the destination
    rsync -av --ignore-existing --progress "$source/" "$destination/"
    
    # Check the exit status
    if [ $? -eq 0 ]; then
        echo "✅ Backup from $source completed successfully"
    else
        echo "❌ Error during backup from $source"
    fi
}

# Run the kdeconnect-cli command and capture the output
output=$(kdeconnect-cli -l)

# Read each line and process it
declare -a names ids statuses  # Arrays to store multiple devices
device_count=""

while IFS= read -r line; do
    if [[ "$line" == -* ]]; then
        # Extract values from device lines
        name=$(echo "$line" | sed 's/- //' | awk -F': ' '{print $1}')
        id=$(echo "$line" | awk -F': ' '{print $2}' | awk '{print $1}')
        status=$(echo "$line" | awk -F'[()]' '{print $2}')
        
        # Store in arrays
        names+=("$name")
        ids+=("$id")
        statuses+=("$status")
    else
        # Store the final device count line
        device_count="$line"
    fi
done <<< "$output"

# Print tabular output
echo "------------------------------------------------------------"
printf "%-5s | %-15s | %-40s | %-20s\n" "SN" "Name" "ID" "Status"
echo "------------------------------------------------------------"
for i in "${!names[@]}"; do
    printf "%-5s | %-15s | %-40s | %-20s\n" "$((i+1))" "${names[i]}" "${ids[i]}" "${statuses[i]}"
done
echo "------------------------------------------------------------"
echo "$device_count"
echo ""

# Ask user for selection
read -p "Enter SN of the device to select: " choice

# Validate input
if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#names[@]} )); then
    index=$((choice-1))
    name_selected=${names[index]}
    id_selected=${ids[index]}
    status_selected=${statuses[index]}
else
    echo "Invalid selection!"
    exit 1
fi

echo "You selected:"
echo "------------------------------------"
echo "Name  : $name_selected"
echo "ID    : $id_selected"
echo "Status: $status_selected"
echo "------------------------------------"

# Refresh the device list
kdeconnect-cli --refresh    

# Get the backup path
BACKUP_DIR="$HOME/Backup/$name_selected"

if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

# Get the target directory
TARGET_DIR="kdeconnect://$id_selected"

# Initialize an array for selected directories
declare -a SELECTED_DIRS

# Check if we have saved config for this device
if load_device_config "$id_selected"; then
    # Get autobackup status
    autobackup_status=$(get_device_autobackup "$id_selected")
    echo "Autobackup status: $autobackup_status"
    
    # Ask if user wants to change autobackup setting
    if kdialog --yesno "Do you want to change autobackup status (current: $autobackup_status)?"; then
        toggle_device_autobackup "$id_selected"
        autobackup_status=$(get_device_autobackup "$id_selected")
        echo "Autobackup status updated to: $autobackup_status"
    fi
    
    # If autobackup is enabled, ask if user wants to configure separate autobackup directories
    if [ "$autobackup_status" = "true" ]; then
        # Get regular directories for reference
        declare -a REGULAR_DIRS=()
        while IFS= read -r dir; do
            if [ -n "$dir" ]; then  # Skip empty lines
                REGULAR_DIRS+=("$dir")
            fi
        done < <(get_device_directories "$id_selected")
        
        # Configure autobackup directories
        declare -a AUTO_DIRS=()
        select_directories "Configure autobackup directories:" AUTO_DIRS REGULAR_DIRS
        
        # Save the selected autobackup directories
        save_device_autobackup_directories "$id_selected" "${AUTO_DIRS[@]}"
    fi
    
    # Convert saved directories to array
    while IFS= read -r dir; do
        if [ -n "$dir" ]; then  # Skip empty lines
            SAVED_DIRS+=("$dir")
        fi
    done < <(get_device_directories "$id_selected")
    
    # If we have directories saved, ask if user wants to use them
    if [ ${#SAVED_DIRS[@]} -gt 0 ]; then
        echo "Found saved directories for this device:"
        for dir in "${SAVED_DIRS[@]}"; do
            echo "- $dir"
        done
        
        if kdialog --yesno "Do you want to use the previously saved directories?"; then
            SELECTED_DIRS=("${SAVED_DIRS[@]}")
            echo "Using saved directories"
        else
            echo "You chose to select new directories"
            SELECTED_DIRS=()
        fi
    fi
fi

# Loop to select multiple directories if none were loaded from config
if [ ${#SELECTED_DIRS[@]} -eq 0 ]; then
    while true; do
        # Ask user if they want to select another directory
        if [ ${#SELECTED_DIRS[@]} -gt 0 ]; then
            if ! kdialog --yesno "You have selected ${#SELECTED_DIRS[@]} directories. Do you want to select another directory?"; then
                break
            fi
        fi
        
        # Get the remote directory
        REMOTE_DIR=$(kdialog --title "Select Source Directory $(( ${#SELECTED_DIRS[@]} + 1 ))" --getexistingdirectory "$TARGET_DIR")
        
        if [ -z "$REMOTE_DIR" ]; then
            if [ ${#SELECTED_DIRS[@]} -eq 0 ]; then
                kdialog --error "No directories selected. Exiting."
                echo "No directories selected. Exiting."
                exit 1
            else
                # User canceled but already has selections
                break
            fi
        fi
        
        # Add to array of selected directories
        SELECTED_DIRS+=("$REMOTE_DIR")
        echo "Added directory: $REMOTE_DIR"
    done
    
    # Save the selected directories to config file
    save_device_config "$id_selected" "$name_selected" "${SELECTED_DIRS[@]}"
fi

# Display all selected directories
echo "Selected directories:"
for dir in "${SELECTED_DIRS[@]}"; do
    echo "- $dir"

done

# Define SOURCE_DIR for compatibility with rest of script
if [ ${#SELECTED_DIRS[@]} -eq 1 ]; then
    SOURCE_DIR="${SELECTED_DIRS[0]}"
    echo "SOURCE_DIR: $SOURCE_DIR"
else
    # Multiple directories selected - you may want to handle this differently
    SOURCE_DIR="${SELECTED_DIRS[*]}"
    echo "SOURCE_DIRS: $SOURCE_DIR"
fi

# Send ping notification to the device
kdeconnect-cli -d "$id_selected" --ping-msg "$notification_message"

# Alternative methods to send notification
# 1. Send a plain message
kdeconnect-cli -d "$id_selected" --send-message "KSyncB: $notification_message"


# Backup each selected directory
echo "Starting backup process..."
echo "------------------------"

if [ ${#SELECTED_DIRS[@]} -eq 1 ]; then
    # Single directory mode
    perform_backup "$SOURCE_DIR" "$BACKUP_DIR"
else
    # Multiple directories mode
    for dir in "${SELECTED_DIRS[@]}"; do
        # Extract the last component of the path for the subdirectory name
        subdir=$(basename "$dir")
        dest_dir="$BACKUP_DIR/$subdir"
        
        # Create subdirectory in backup location if needed
        if [ ! -d "$dest_dir" ]; then
            mkdir -p "$dest_dir"
            echo "Created directory: $dest_dir"
        fi
        
        # Perform backup
        perform_backup "$dir" "$dest_dir"
    done
fi

echo "------------------------"
echo "Backup process completed"
echo "Files backed up to: $BACKUP_DIR"