#!/bin/bash

echo "Initializing Secrets Management Server with Vault..."

# Update and install dependencies
apt update && apt upgrade -y
apt install -y curl wget unzip gnupg ufw

# Configure firewall
ufw allow ssh
ufw allow 8200 # Vault
ufw enable

# Install Vault
echo "Installing Vault..."
wget https://releases.hashicorp.com/vault/1.8.4/vault_1.8.4_linux_amd64.zip
unzip vault_1.8.4_linux_amd64.zip
mv vault /usr/local/bin/
rm vault_1.8.4_linux_amd64.zip

# Start Vault in development mode
echo "Starting Vault in development mode..."
vault server -dev -dev-root-token-id="root" &

# Enable Kubernetes Authentication (Optional for Kubernetes integrations)
vault login root
vault auth enable kubernetes

echo "Vault Secrets Management Server setup complete. Production configurations are recommended for security."
