#!/usr/bin/env bash
set -euo pipefail

KEY_PATH="$HOME/.ssh/github_actions_ed25519"
AUTH_KEYS="$HOME/.ssh/authorized_keys"

echo "============================================================"
echo "  GITHUB ACTIONS CI/CD DEPLOY KEY SETUP FOR GOOGLE CLOUD VM"
echo "============================================================"

# Ensure ~/.ssh directory exists with correct permissions
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

# Generate key if not already generated
if [ ! -f "$KEY_PATH" ]; then
  echo "Generating dedicated Ed25519 CI/CD deploy key..."
  ssh-keygen -t ed25519 -N "" -C "github-actions-deploy-$(hostname)" -f "$KEY_PATH"
else
  echo "Key already exists at: $KEY_PATH"
fi

PUB_KEY=$(cat "${KEY_PATH}.pub")

# Ensure public key is in authorized_keys
if ! grep -qxF "$PUB_KEY" "$AUTH_KEYS" 2>/dev/null; then
  echo "$PUB_KEY" >> "$AUTH_KEYS"
  echo "Public key successfully added to $AUTH_KEYS."
else
  echo "Public key is already present in $AUTH_KEYS."
fi

# Detect external IP if available
EXT_IP=$(curl -s -m 5 https://ifconfig.me 2>/dev/null || echo "35.192.18.39")
USER_NAME=$(whoami)
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo ""
echo "------------------------------------------------------------"
echo "  ADD THE FOLLOWING SECRETS IN YOUR GITHUB REPOSITORY / ORG"
echo "  (Settings -> Secrets and variables -> Actions)"
echo "------------------------------------------------------------"
echo ""
echo "Secret Name:  VM_HOST"
echo "Secret Value: $EXT_IP"
echo ""
echo "Secret Name:  VM_USER"
echo "Secret Value: $USER_NAME"
echo ""
echo "Secret Name:  VM_DEPLOY_PATH"
echo "Secret Value: $DEPLOY_DIR"
echo ""
echo "Secret Name:  VM_SSH_KEY"
echo "Secret Value:"
echo "------------------------------------------------------------"
cat "$KEY_PATH"
echo "------------------------------------------------------------"
echo ""
echo "Setup complete. Keypair generated and authorized."
