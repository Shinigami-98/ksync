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
