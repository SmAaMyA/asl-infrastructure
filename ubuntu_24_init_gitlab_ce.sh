#!/bin/bash

# Reusable Configuration Variables
GITLAB_DOMAIN="gitlab.example.com"              # Replace with your GitLab domain or server IP
K8S_API_SERVER="https://192.168.1.100:6443"     # Kubernetes API server endpoint
K8S_TOKEN="<YOUR_K8S_TOKEN>"                    # Kubernetes service account token for GitLab Runner
K8S_CA_CERT="/etc/gitlab-runner/k8s-ca.crt"     # Path to Kubernetes CA certificate
RUNNER_REGISTRATION_TOKEN="<YOUR_RUNNER_TOKEN>" # GitLab Runner registration token
MONITORING_SERVER_IP="192.168.1.101"            # Monitoring server IP for Fluentd log exporting

# Exit immediately if a command exits with a non-zero status
set -e

echo "Initializing Ubuntu 24 for GitLab CE with Kubernetes Deployment Integration..."

# 1. System Update, Server Hardening, and Optimizations

# Update packages, upgrade the system, and remove unnecessary packages
echo "Updating system packages and applying security patches..."
apt update && apt upgrade -y && apt autoremove -y

# Install essential tools
echo "Installing essential tools..."
apt install -y curl wget vim ufw net-tools gnupg lsb-release sudo auditd unattended-upgrades fail2ban apparmor apparmor-profiles apparmor-utils logrotate

# Customized Auditd Rules
echo "Setting up customized auditd rules for GitLab monitoring..."
echo '-w /var/opt/gitlab/ -p wa -k gitlab' >>/etc/audit/rules.d/audit.rules
systemctl restart auditd

# Configure UFW firewall with stricter rules
echo "Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80  # HTTP
ufw allow 443 # HTTPS
ufw allow 22  # SSH
ufw enable

# SSH hardening: disable root login, enforce key-based authentication, change default port
echo "Hardening SSH access..."
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Enable automatic security updates
echo "Configuring automatic security updates..."
dpkg-reconfigure --priority=low unattended-upgrades

# Install and configure Fail2Ban
echo "Setting up Fail2Ban to protect against brute-force attacks..."
systemctl enable fail2ban
systemctl start fail2ban

# Kernel parameter optimizations for GitLab and Docker
echo "Configuring kernel parameters for GitLab and Docker..."
cat <<EOF >>/etc/sysctl.conf
fs.file-max = 500000
vm.swappiness = 10
EOF
sysctl -p

# Enable audit logging for security events
echo "Enabling audit logging..."
systemctl enable auditd
systemctl start auditd

# Set resource limits for GitLab processes
echo "Setting resource limits..."
cat <<EOF >>/etc/security/limits.conf
* soft nofile 102400
* hard nofile 102400
EOF

# Enable and configure AppArmor
echo "Configuring AppArmor for enhanced security..."
systemctl enable apparmor
systemctl start apparmor

# 2. Install Docker for GitLab CE

echo "Installing Docker..."
apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update && apt install -y docker-ce
systemctl enable docker

# Configure Docker for GitLab
cat <<EOF >/etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
systemctl restart docker

# 3. Install GitLab CE with Docker

echo "Installing GitLab CE..."
docker run --detach \
    --hostname $GITLAB_DOMAIN \
    --publish 443:443 --publish 80:80 --publish 2222:22 \
    --name gitlab \
    --restart always \
    --volume /srv/gitlab/config:/etc/gitlab \
    --volume /srv/gitlab/logs:/var/log/gitlab \
    --volume /srv/gitlab/data:/var/opt/gitlab \
    gitlab/gitlab-ce:latest

# Configure SSL for GitLab with Let’s Encrypt
echo "Configuring SSL for GitLab with Let’s Encrypt..."
apt install -y certbot
certbot certonly --standalone -d $GITLAB_DOMAIN --non-interactive --agree-tos -m admin@$GITLAB_DOMAIN
cat <<EOF >>/srv/gitlab/config/gitlab.rb
external_url "https://$GITLAB_DOMAIN"
nginx['ssl_certificate'] = "/etc/letsencrypt/live/$GITLAB_DOMAIN/fullchain.pem"
nginx['ssl_certificate_key'] = "/etc/letsencrypt/live/$GITLAB_DOMAIN/privkey.pem"
EOF
docker restart gitlab

# Schedule SSL certificate renewal
echo "0 0 * * * certbot renew --quiet && docker restart gitlab" | tee -a /etc/crontab

# 4. Enable Prometheus Monitoring in GitLab
cat <<EOF >>/srv/gitlab/config/gitlab.rb
prometheus_monitoring['enable'] = true
gitlab_rails['monitoring_whitelist'] = ['0.0.0.0/0']
EOF
docker restart gitlab

# 5. Configure Backups for GitLab Data
echo "Setting up GitLab backups..."
mkdir -p /srv/gitlab/backups
cat <<EOF >>/srv/gitlab/config/gitlab.rb
gitlab_rails['backup_path'] = "/srv/gitlab/backups"
gitlab_rails['backup_archive_permissions'] = 0644
gitlab_rails['backup_keep_time'] = 604800  # 7 days
EOF
docker restart gitlab

# Schedule daily backup in crontab
echo "0 3 * * * docker exec gitlab gitlab-rake gitlab:backup:create" | tee -a /etc/crontab

# 6. Install GitLab Runner with Kubernetes Executor

echo "Installing GitLab Runner..."
curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
chmod +x /usr/local/bin/gitlab-runner

# Register GitLab Runner with Kubernetes executor and configure caching
echo "Registering GitLab Runner with Kubernetes executor..."
gitlab-runner register --non-interactive \
    --url "https://$GITLAB_DOMAIN/" \
    --registration-token "$RUNNER_REGISTRATION_TOKEN" \
    --executor kubernetes \
    --description "k8s-runner" \
    --kubernetes-host "$K8S_API_SERVER" \
    --kubernetes-bearer_token "$K8S_TOKEN" \
    --kubernetes-ca_file "$K8S_CA_CERT" \
    --kubernetes-namespace "gitlab-runner" \
    --kubernetes-pull_policy "always" \
    --kubernetes-privileged=true \
    --kubernetes-volumes host_path=/var/run/docker.sock,mount_path=/var/run/docker.sock \
    --cache-dir "/srv/gitlab/cache" # Enable caching to speed up CI/CD builds

# Enable and start GitLab Runner service
systemctl enable gitlab-runner
systemctl start gitlab-runner

# 7. Install Fluentd with Log Filtering

echo "Installing Fluentd for log exporting..."
curl -fsSL https://toolbelt.treasuredata.com/sh/install-ubuntu-focal-td-agent4.sh | sh
systemctl start td-agent
systemctl enable td-agent

# Configure Fluentd with log filtering
cat <<EOF >/etc/td-agent/td-agent.conf
<source>
  @type tail
  path /var/log/gitlab/*.log
  pos_file /var/log/td-agent/td-agent.log.pos
  tag gitlab.*
  format none
</source>

<filter gitlab.**>
  @type grep
  <regexp>
    key message
    pattern "ERROR|WARN|FATAL"
  </regexp>
</filter>

<match gitlab.**>
  @type forward
  tls false
  <server>
    host $MONITORING_SERVER_IP
    port 24224
  </server>
</match>
EOF
systemctl restart td-agent

# Logrotate configuration for Fluentd
cat <<EOF >/etc/logrotate.d/td-agent
/var/log/td-agent/*.log {
  daily
  missingok
  rotate 7
  compress
  notifempty
  copytruncate
}
EOF

# 8. Install Prometheus Node Exporter for Resource Monitoring

echo "Installing Prometheus Node Exporter for resource monitoring..."
wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.3.1.linux-amd64.tar.gz
mv node_exporter-1.3.1.linux-amd64/node_exporter /usr/local/bin/
useradd -rs /bin/false prometheus
cat <<EOF >/etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF
systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

echo "GitLab CE VM initialization complete and integrated with Kubernetes."
