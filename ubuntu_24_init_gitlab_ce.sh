#!/bin/bash

# GitLab Installation Variables
GITLAB_URL="https://gitlab.example.com"
GITLAB_RUNNER_IMAGE="gitlab/gitlab-runner:latest"
CERTBOT_USER="certbotuser"
OFF_CLUSTER_BACKUP="/mnt/backups/gitlab"

echo "Starting improved production setup for GitLab CE on Ubuntu 24..."

# 1. System Hardening
echo "Applying enhanced system hardening..."
apt update && apt upgrade -y && apt install -y unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

# UFW Firewall: open only necessary ports
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80
ufw allow 443
ufw enable

# SSH Hardening: enforce key-based login only, change default port
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Enable AppArmor for additional security
systemctl enable apparmor
systemctl start apparmor

# 2. Essential Package Installation (Preserving Existing)
echo "Installing essential packages..."
apt install -y curl vim ufw net-tools gnupg sudo auditd fail2ban logrotate

# Enable and start Fail2Ban
systemctl enable fail2ban
systemctl start fail2ban

# 3. Install GitLab CE (Existing Step)
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
apt-get install gitlab-ce -y
gitlab-ctl reconfigure

# 4. GitLab Runner Resource Limits
echo "Configuring resource requests and limits for GitLab Runner..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitlab-runner
  namespace: gitlab
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: gitlab-runner
    spec:
      containers:
        - name: gitlab-runner
          image: $GITLAB_RUNNER_IMAGE
          resources:
            requests:
              memory: "500Mi"
              cpu: "250m"
            limits:
              memory: "1Gi"
              cpu: "500m"
EOF

# 5. Automated GitLab Backups
echo "Setting up automated GitLab backups to off-cluster storage..."
mkdir -p $OFF_CLUSTER_BACKUP
echo "0 2 * * * gitlab-backup create -s -d $OFF_CLUSTER_BACKUP" >>/etc/crontab

# 6. Loki for Log Aggregation (New Addition)
echo "Installing and configuring Loki for centralized log aggregation..."
kubectl apply -f https://raw.githubusercontent.com/grafana/loki/master/production/helm/loki-stack/templates/loki.yaml

echo "GitLab CE setup complete with advanced hardening, resource management, and disaster recovery."
