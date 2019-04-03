#!/bin/bash
set -ex

# Shutdown the SSHD service before the reboot is initiated to prevent Packer
# from trying to SSH in and executing the outstanding shell provisioning
# scripts.
# Source: https://github.com/mitchellh/packer/issues/3487#issue-152469296
echo "Shutting down the SSHD service and rebooting:"
sudo systemctl stop sshd.service

echo "Rebooting:"
nohup sudo reboot -f </dev/null >/dev/null 2>&1 &
exit 0