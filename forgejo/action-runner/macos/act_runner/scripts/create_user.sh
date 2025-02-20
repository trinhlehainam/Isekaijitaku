#!/bin/bash

# TODO: add option to create daemon or agent (GUI) user.

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Constants
USER_NAME="_act_runner"
GROUP_NAME="_act_runner"
USER_ID=385
GROUP_ID=385
HOME_DIR="/var/lib/act_runner"
CONFIG_DIR="/etc/act_runner"

# Check if group ID is available
if dscl . -list /Groups PrimaryGroupID | grep -q "$GROUP_ID"; then
    echo "Error: Group ID $GROUP_ID is already in use"
    exit 1
fi

# Check if user ID is available
if dscl . -list /Users UniqueID | grep -q "$USER_ID"; then
    echo "Error: User ID $USER_ID is already in use"
    exit 1
fi

echo "Creating group $GROUP_NAME..."
dscl . -create /Groups/$GROUP_NAME
dscl . -create /Groups/$GROUP_NAME PrimaryGroupID $GROUP_ID

echo "Creating user $USER_NAME..."
dscl . -create /Users/$USER_NAME
dscl . -create /Users/$USER_NAME UserShell /usr/bin/false
dscl . -create /Users/$USER_NAME RealName "Gitea Action Runner"
dscl . -create /Users/$USER_NAME UniqueID $USER_ID
dscl . -create /Users/$USER_NAME PrimaryGroupID $GROUP_ID
dscl . -create /Users/$USER_NAME NFSHomeDirectory $HOME_DIR

echo "Creating configuration directories..."
mkdir -p $CONFIG_DIR
mkdir -p $HOME_DIR

echo "Setting permissions..."
chown -R $USER_NAME:$GROUP_NAME $CONFIG_DIR
chown -R $USER_NAME:$GROUP_NAME $HOME_DIR

echo "Verifying setup..."
echo "User information:"
dscl . -read /Users/$USER_NAME

echo "Directory permissions:"
ls -la $HOME_DIR $CONFIG_DIR

echo "Setup complete!"
