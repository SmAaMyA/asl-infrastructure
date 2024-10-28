
#!/bin/bash

echo "Initializing Production-Grade Secrets Management Server with Vault..."

# 1. System Update and Install Dependencies
apt update && apt upgrade -y
apt install -y curl wget unzip gnupg ufw

# 2. Configure Firewall
ufw default deny incoming
ufw allow ssh
ufw allow 8200/tcp  # Vault HTTP API
ufw enable

# 3. Install Vault
echo "Installing Vault..."
VAULT_VERSION="1.8.4"
wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip vault_${VAULT_VERSION}_linux_amd64.zip
mv vault /usr/local/bin/
rm vault_${VAULT_VERSION}_linux_amd64.zip

# 4. Configure Vault for Production Mode
# Create Vault configuration file
mkdir -p /etc/vault
cat <<EOF > /etc/vault/vault.hcl
ui = true
storage "file" {
  path = "/opt/vault/data"
}
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
api_addr = "http://$(hostname -I | awk '{print $1}'):8200"
cluster_addr = "http://$(hostname -I | awk '{print $1}'):8201"
EOF

# Create Vault data directory
mkdir -p /opt/vault/data
chown -R vault:vault /opt/vault

# 5. Start Vault as a System Service
useradd --system --home /etc/vault.d --shell /bin/false vault
cat <<EOF > /etc/systemd/system/vault.service
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target

[Service]
User=vault
Group=vault
ExecStart=/usr/local/bin/vault server -config=/etc/vault/vault.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Reload and start Vault service
systemctl daemon-reload
systemctl enable vault
systemctl start vault

# 6. Initialize and Unseal Vault
echo "Initializing Vault..."
vault operator init -key-shares=1 -key-threshold=1 > /etc/vault/init-keys.txt
vault operator unseal $(grep 'Unseal Key 1:' /etc/vault/init-keys.txt | awk '{print $4}')

echo "Vault production setup complete. Keys saved to /etc/vault/init-keys.txt."
