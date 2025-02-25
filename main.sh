#!/bin/bash

# Script to list KDE Connect devices
# This script requires kdeconnect to be installed

# Check if kdeconnect-cli is installed
if ! command -v kdeconnect-cli &> /dev/null; then
    echo "Error: kdeconnect-cli is not installed."
    echo "Please install KDE Connect first."
    echo "For example: sudo apt install kdeconnect"
    exit 1
fi

echo "Looking for KDE Connect devices..."
echo "--------------------------------"

# Function to format device output in tabular format
format_devices() {
    # Create a temporary file to store the output
    TEMP_FILE=$(mktemp)
    
    # Get the raw output from kdeconnect-cli
    $1 > "$TEMP_FILE"
    
    # Print header
    printf "%-5s %-40s %-40s %-10s\n" "INDEX" "DEVICE NAME" "DEVICE ID" "STATUS"
    printf "%-5s %-40s %-40s %-10s\n" "-----" "$(printf '%0.s-' {1..40})" "$(printf '%0.s-' {1..40})" "$(printf '%0.s-' {1..10})"
    
    # Create an array to store device IDs
    declare -a DEVICE_IDS
    
    # Parse and format the output
    INDEX=1
    while IFS= read -r line; do
        if [[ $line == *"- "* ]]; then
            # Extract device name and ID (assuming format "- device_id: device_name (status)")
            DEVICE_NAME=$(echo "$line" | cut -d' ' -f2 | cut -d':' -f1)
            DEVICE_ID=$(echo "$line" | cut -d':' -f2 | sed 's/^ //' | cut -d'(' -f1 | sed 's/ *$//')
            
            # Store device ID in array
            DEVICE_IDS[$INDEX]="$DEVICE_ID"
            
            # Determine status
            if [[ $line == *"(paired and reachable)"* ]]; then
                STATUS="Connected"
            elif [[ $line == *"(paired)"* ]]; then
                STATUS="Paired"
            elif [[ $line == *"(reachable)"* ]]; then
                STATUS="Reachable"
            else
                STATUS="Unknown"
            fi
            
            # Print formatted row with index
            printf "%-5s %-40s %-40s %-10s\n" "$INDEX" "${DEVICE_NAME:0:39}" "${DEVICE_ID:0:39}" "$STATUS"
            
            # Increment index
            ((INDEX++))
        fi
    done < "$TEMP_FILE"
    
    # Clean up
    rm "$TEMP_FILE"
    
    # If no devices were found
    if [ $INDEX -eq 1 ]; then
        echo "No devices found."
        return 1
    fi
    
    # Get user selection
    echo "Enter the index of the device whose ID you want to use:"
    read -p "Index: " SELECTED_INDEX
    
    # Validate input
    if [[ ! "$SELECTED_INDEX" =~ ^[0-9]+$ ]] || [ "$SELECTED_INDEX" -lt 1 ] || [ "$SELECTED_INDEX" -ge $INDEX ]; then
        echo "Invalid selection."
        return 1
    fi
    
    # Return the selected device ID
    SELECTED_DEVICE="${DEVICE_IDS[$SELECTED_INDEX]}"
}

format_devices "kdeconnect-cli --list-available"
echo "$SELECTED_DEVICE"

# Define the local directory
LOCAL_DIR="/home/shinigami/android"

# Define the remote directory
REMOTE_DIR="/run/user/1000/$SELECTED_DEVICE/storage/emulated/0/DCIM"

# Function to sync new files from remote to local directory
sync_new_files() {
    # Use rsync to copy new files while preserving the directory structure
    rsync -av --ignore-existing "$REMOTE_DIR/" "$LOCAL_DIR/"
}

# Call the function to sync files
sync_new_files