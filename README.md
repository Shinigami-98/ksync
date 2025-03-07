# KSyncB Backup Tool

KSyncB is a versatile backup tool designed to automate the backup of directories from devices connected via KDE Connect. It supports both automatic and manual backups, allowing users to configure separate directories for autobackup and manual backup processes.

## Features

- **Automatic Backup**: Schedule automatic backups for specified directories at regular intervals.
- **Manual Backup**: Manually select directories for immediate backup.
- **Configurable Directories**: Set up different directories for autobackup and manual backup.

## Prerequisites

- **KDE Connect**: Ensure KDE Connect is installed and configured on your devices.
- **jq**: A lightweight and flexible command-line JSON processor.
- **rsync**: A fast and versatile file-copying tool.

## Installation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/yourusername/ksyncb.git
   cd ksyncb
   ```

## Usage

## Setting Up the KSyncB Service

The `install-service.sh` script is used to set up and start the KSyncB backup tool as a systemd service. This allows the tool to run automatically at scheduled intervals.

### How to Use `install-service.sh`

1. **Ensure Prerequisites**:
   - Make sure you have proper permission for executing the script `chmod 777 install-service.sh`

2. **Run the Script**:
   - Execute the `install-service.sh` script to set up the service and timer:
     ```bash
     ./install-service.sh
     ```

3. **What the Script Does**:
   - **Makes the Backup Script Executable**: Ensures `ksyncb-auto.sh` is executable.
   - **Creates Systemd User Directory**: Sets up the necessary directory for user-level systemd services.
   - **Copies Service and Timer Files**: Places `ksyncb.service` and `ksyncb.timer` in the systemd user directory.
   - **Reloads Systemd Daemon**: Refreshes the systemd configuration to recognize the new service and timer.
   - **Enables and Starts the Timer**: Activates the timer to schedule automatic backups.

4. **Check the Status**:
   - After running the script, it will display the status of the `ksyncb.timer` to confirm that it is active and running:
     ```bash
     systemctl --user status ksyncb.timer
     ```

5. **View Next Scheduled Runs**:
   - The script will also show the next scheduled run times for the backup service:
     ```bash
     systemctl --user list-timers | grep ksyncb
     ```

6. **Manual Operations**:
   - To manually run the backup service, use:
     ```bash
     systemctl --user start ksyncb.service
     ```
   - To view logs for the service, use:
     ```bash
     journalctl --user -u ksyncb.service
     ```

## Running the interactive session

The `main.sh` script is used for configuring devices and selecting directories for backup.

### How to Run `main.sh`

1. **Execute the Script**:
   - Run the `main.sh` script to start the configuration process:
     ```bash
     ./main.sh
     ```

2. **Configure Devices**:
   - Follow the interactive prompts to select devices and configure directories for backup.

3. **Select Directories**:
   - Choose directories for manual or automatic backup as prompted by the script.

By following these steps, you can easily set up and manage the KSyncB backup tool, ensuring your directories are backed up at regular intervals or on-demand as needed.

### Running the Backup Tool

2. **Configure Devices**:
   - Use the interactive prompts to configure devices and select directories for backup.

3. **Automatic Backup**:
   - The tool will automatically back up configured directories at scheduled intervals.

4. **Manual Backup**:
   - Select directories manually for immediate backup.

### Configuration

- **Config File**: Located at `~/.config/ksyncb/config.json`.
- **Autobackup**: Enable or disable autobackup for each device and configure directories.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request for any improvements or bug fixes.

