#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 user@host"
    exit 1
fi

REMOTE="$1"
SOCKET="/tmp/ssh-setup-$$"

# Open a persistent connection (authenticates once)
ssh -M -f -N -o ControlPath="$SOCKET" "$REMOTE"
trap 'ssh -O exit -o ControlPath="$SOCKET" "$REMOTE" 2>/dev/null' EXIT

SSH="ssh -o ControlPath=$SOCKET"
SCP="scp -o ControlPath=$SOCKET"

# Create ~/.ssh on remote if needed
$SSH "$REMOTE" 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'

# Transfer files
$SCP ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub "$REMOTE":~/.ssh/
$SCP ~/.gitconfig "$REMOTE":~/.gitconfig

# Set correct permissions on remote
$SSH "$REMOTE" 'chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/id_ed25519.pub'

echo "Done. SSH keys and gitconfig transferred to $REMOTE"
