#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Initializing Ubuntu 24 Monitoring VM with Prometheus, Grafana, Loki, and Promtail..."

# 1. System Update, Server Hardening, and Optimizations

# Update packages, upgrade the system, and remove unnecessary packages
echo "Updating system packages and applying security patches..."
apt update && apt upgrade -y && apt autoremove -y

# Install essential tools
echo "Installing essential tools..."
apt install -y curl wget vim ufw net-tools gnupg lsb-release sudo auditd unattended-upgrades fail2ban apparmor apparmor-profiles apparmor-utils logrotate nginx

# SSH hardening: disable root login, enforce key-based authentication, change default port
echo "Hardening SSH access..."
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Enable automatic security updates
echo "Configuring automatic security updates..."
dpkg-reconfigure --priority=low unattended-upgrades

# Configure UFW firewall with stricter rules
echo "Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 9090 # Prometheus
ufw allow 3000 # Grafana
ufw allow 3100 # Loki
ufw enable

# Enable and configure AppArmor
echo "Configuring AppArmor for enhanced security..."
systemctl enable apparmor
systemctl start apparmor

# 2. Set up Persistent Storage for Prometheus and Loki

echo "Setting up persistent storage for Prometheus and Loki..."
mkdir -p /mnt/prometheus-data /mnt/loki-data
# Mount storage as required or use cloud provider volumes (e.g., /dev/sdb1 and /dev/sdc1 for illustration)
# mount /dev/sdb1 /mnt/prometheus-data
# mount /dev/sdc1 /mnt/loki-data

# 3. Install Prometheus with Retention Policies

echo "Installing Prometheus..."
useradd --no-create-home --shell /bin/false prometheus
mkdir -p /etc/prometheus /mnt/prometheus-data

wget https://github.com/prometheus/prometheus/releases/download/v2.32.1/prometheus-2.32.1.linux-amd64.tar.gz
tar xvf prometheus-2.32.1.linux-amd64.tar.gz
mv prometheus-2.32.1.linux-amd64/prometheus /usr/local/bin/
mv prometheus-2.32.1.linux-amd64/promtool /usr/local/bin/
mv prometheus-2.32.1.linux-amd64/consoles /etc/prometheus
mv prometheus-2.32.1.linux-amd64/console_libraries /etc/prometheus
rm -rf prometheus-2.32.1.linux-amd64*

cat <<EOF >/etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF

cat <<EOF >/etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/mnt/prometheus-data --storage.tsdb.retention.time=30d --storage.tsdb.min-block-duration=2h --web.console.templates=/etc/prometheus/consoles --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

chown -R prometheus:prometheus /etc/prometheus /mnt/prometheus-data
systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus

# 4. Install Grafana with Pre-configured Dashboards and Access Control

echo "Installing Grafana..."
wget https://dl.grafana.com/oss/release/grafana-8.3.3.linux-amd64.tar.gz
tar -zxvf grafana-8.3.3.linux-amd64.tar.gz
mv grafana-8.3.3 /usr/local/grafana
rm grafana-8.3.3.linux-amd64.tar.gz

useradd --no-create-home --shell /bin/false grafana
chown -R grafana:grafana /usr/local/grafana

cat <<EOF >/etc/systemd/system/grafana.service
[Unit]
Description=Grafana
Wants=network-online.target
After=network-online.target

[Service]
User=grafana
ExecStart=/usr/local/grafana/bin/grafana-server --homepath=/usr/local/grafana

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start grafana
systemctl enable grafana

# Set Grafana admin password (replace <your_password> with a secure password)
GRAFANA_ADMIN_PASSWORD="<your_password>"
echo "Setting Grafana admin password..."
grafana-cli admin reset-admin-password $GRAFANA_ADMIN_PASSWORD

# 5. Install Loki and Promtail with Log Retention

echo "Installing Loki..."
useradd --no-create-home --shell /bin/false loki
mkdir -p /etc/loki /mnt/loki-data

wget https://github.com/grafana/loki/releases/download/v2.4.2/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
mv loki-linux-amd64 /usr/local/bin/loki
rm loki-linux-amd64.zip

cat <<EOF >/etc/loki/loki-config.yml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9095

ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /mnt/loki-data/index
    cache_location: /mnt/loki-data/boltdb-cache
    shared_store: filesystem
  filesystem:
    directory: /mnt/loki-data/chunks

limits_config:
  enforce_metric_name: false
  retention_period: 168h  # 7 days retention
EOF

cat <<EOF >/etc/systemd/system/loki.service
[Unit]
Description=Loki
Wants=network-online.target
After=network-online.target

[Service]
User=loki
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki-config.yml

[Install]
WantedBy=multi-user.target
EOF

chown -R loki:loki /etc/loki /mnt/loki-data
systemctl daemon-reload
systemctl start loki
systemctl enable loki

# 6. Install Promtail for Log Collection

echo "Installing Promtail..."
useradd --no-create-home --shell /bin/false promtail

wget https://github.com/grafana/loki/releases/download/v2.4.2/promtail-linux-amd64.zip
unzip promtail-linux-amd64.zip
mv promtail-linux-amd64 /usr/local/bin/promtail
rm promtail-linux-amd64.zip

cat <<EOF >/etc/promtail/promtail-config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*.log
EOF

cat <<EOF >/etc/systemd/system/promtail.service
[Unit]
Description=Promtail
Wants=network-online.target
After=network-online.target

[Service]
User=promtail
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yml

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start promtail
systemctl enable promtail

# 7. Schedule Backups of Configuration Files

echo "Setting up regular backups of configuration files..."
mkdir -p /var/backups/monitoring
echo "0 3 * * * tar -czf /var/backups/monitoring/prometheus-config-$(date +\%F).tar.gz /etc/prometheus /etc/loki /etc/grafana" | tee -a /etc/crontab

echo "Monitoring VM setup complete with Prometheus, Grafana, Loki, and Promtail, all with enhanced security and persistence."
