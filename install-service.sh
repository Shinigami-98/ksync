#!/bin/bash

# Make the script executable
chmod +x ksyncb-auto.sh

# Create systemd user directory if it doesn't exist
mkdir -p ~/.config/systemd/user

# Copy service and timer files to systemd user directory
cp ksyncb.service ~/.config/systemd/user/
cp ksyncb.timer ~/.config/systemd/user/

# Reload systemd user daemon
systemctl --user daemon-reload

# Enable and start the timer
systemctl --user enable ksyncb.timer
systemctl --user start ksyncb.timer

# Show status
echo "KSyncB timer installed and started."
echo "Status:"
systemctl --user status ksyncb.timer

echo ""
echo "Next run times:"
systemctl --user list-timers | grep ksyncb

echo ""
echo "To manually run the backup now:"
echo "systemctl --user start ksyncb.service"

echo ""
echo "To view logs:"
echo "journalctl --user -u ksyncb.service" 