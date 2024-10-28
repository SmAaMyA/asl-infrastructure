#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Initializing Ubuntu 24 Monitoring VM with Prometheus, Alertmanager, Grafana, Loki, Promtail, and Elastic Stack..."

# 1. System Update, Server Hardening, and Optimizations

# Update packages, upgrade the system, and remove unnecessary packages
echo "Updating system packages and applying security patches..."
apt update && apt upgrade -y && apt autoremove -y

# Install essential tools
echo "Installing essential tools..."
apt install -y curl wget vim ufw net-tools gnupg lsb-release sudo auditd unattended-upgrades fail2ban apparmor apparmor-profiles apparmor-utils logrotate nginx apache2-utils certbot

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
ufw allow 9200 # Elasticsearch
ufw allow 5601 # Kibana
ufw enable

# Enable and configure AppArmor
echo "Configuring AppArmor for enhanced security..."
systemctl enable apparmor
systemctl start apparmor

# 2. Install Prometheus with Alertmanager and Federation

echo "Installing Prometheus and Alertmanager..."
useradd --no-create-home --shell /bin/false prometheus
mkdir -p /etc/prometheus /mnt/prometheus-data

wget https://github.com/prometheus/prometheus/releases/download/v2.32.1/prometheus-2.32.1.linux-amd64.tar.gz
tar xvf prometheus-2.32.1.linux-amd64.tar.gz
mv prometheus-2.32.1.linux-amd64/prometheus /usr/local/bin/
mv prometheus-2.32.1.linux-amd64/promtool /usr/local/bin/
mv prometheus-2.32.1.linux-amd64/consoles /etc/prometheus
mv prometheus-2.32.1.linux-amd64/console_libraries /etc/prometheus
rm -rf prometheus-2.32.1.linux-amd64*

wget https://github.com/prometheus/alertmanager/releases/download/v0.23.0/alertmanager-0.23.0.linux-amd64.tar.gz
tar xvf alertmanager-0.23.0.linux-amd64.tar.gz
mv alertmanager-0.23.0.linux-amd64/alertmanager /usr/local/bin/
mv alertmanager-0.23.0.linux-amd64/amtool /usr/local/bin/
rm -rf alertmanager-0.23.0.linux-amd64*

cat <<EOF >/etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']

  # Prometheus Federation configuration
  - job_name: 'federate'
    honor_labels: true
    metrics_path: /federate
    params:
      'match[]':
        - '{job="node_exporter"}'
        - '{job="kubernetes-pods"}'
    static_configs:
      - targets:
          - 'remote-prometheus-server:9090'  # replace with actual Prometheus instance
EOF

# Prometheus alert rules
cat <<EOF >/etc/prometheus/alert.rules.yml
groups:
  - name: system_alerts
    rules:
      - alert: HighMemoryUsage
        expr: node_memory_Active_bytes / node_memory_MemTotal_bytes > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 80% for more than 5 minutes."

      - alert: HighCPUUsage
        expr: (100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 5 minutes."
EOF

# Alertmanager configuration
cat <<EOF >/etc/alertmanager/alertmanager.yml
global:
  resolve_timeout: 5m

route:
  receiver: 'slack_notifications'

receivers:
  - name: 'slack_notifications'
    slack_configs:
    - api_url: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX'
      channel: '#alerts'
      send_resolved: true
EOF

# Prometheus and Alertmanager systemd services
cat <<EOF >/etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/mnt/prometheus-data --storage.tsdb.retention.time=30d --storage.tsdb.min-block-duration=2h --web.console.templates=/etc/prometheus/consoles --web.console.libraries=/etc/prometheus/console_libraries
MemoryLimit=1G
CPUQuota=50%

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/alertmanager.service
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/alertmanager --config.file=/etc/alertmanager/alertmanager.yml
MemoryLimit=512M
CPUQuota=25%

[Install]
WantedBy=multi-user.target
EOF

chown -R prometheus:prometheus /etc/prometheus /mnt/prometheus-data
systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus
systemctl start alertmanager
systemctl enable alertmanager

# 3. Install Elastic Stack (Elasticsearch, Logstash, Kibana) for Logging

echo "Installing Elastic Stack..."
# Elasticsearch
apt install -y elasticsearch
sed -i 's/#network.host: 192.168.0.1/network.host: localhost/' /etc/elasticsearch/elasticsearch.yml
systemctl enable elasticsearch
systemctl start elasticsearch

# Logstash
apt install -y logstash
cat <<EOF >/etc/logstash/conf.d/logstash.conf
input {
  tcp {
    port => 5000
    codec => json
  }
}

filter {
  json {
    source => "message"
  }
}

output {
  elasticsearch {
    hosts => ["localhost:9200"]
    index => "logstash-%{+YYYY.MM.dd}"
  }
}
EOF
systemctl enable logstash
systemctl start logstash

# Kibana
apt install -y kibana
echo "server.host: 'localhost'" >>/etc/kibana/kibana.yml
systemctl enable kibana
systemctl start kibana

# Configure Fluentd to forward logs to Logstash
echo "Configuring Fluentd to forward logs to Logstash..."
cat <<EOF >/etc/td-agent/td-agent.conf
<source>
  @type tail
  path /var/log/*.log
  pos_file /var/log/td-agent/td-agent.log.pos
  tag kubernetes.*
  format none
</source>

<match kubernetes.**>
  @type forward
  tls false
  <server>
    host localhost
    port 5000
  </server>
</match>
EOF
systemctl restart td-agent

echo "Phase 1: Monitoring and Logging enhancements complete with Prometheus Alertmanager, Federation, and Elastic Stack integration."
