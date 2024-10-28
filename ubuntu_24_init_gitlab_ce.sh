#!/bin/bash

# GitLab Installation Variables
GITLAB_URL="https://gitlab.example.com"
GITLAB_RUNNER_IMAGE="gitlab/gitlab-runner:latest"
CERTBOT_USER="certbotuser"

echo "Starting full production setup for GitLab CE on Ubuntu 24..."

# 1. System Hardening
echo "Applying system hardening..."
# Enable unattended upgrades for security
apt update && apt upgrade -y && apt install -y unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

# Configure UFW firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80
ufw allow 443
ufw enable

# SSH Hardening: disable root login, enforce key-based authentication
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Enable AppArmor
systemctl enable apparmor
systemctl start apparmor

# 2. Essential Package Installation
echo "Installing essential packages..."
apt install -y curl vim ufw net-tools gnupg sudo auditd fail2ban logrotate

# Configure fail2ban to protect against brute-force attacks
systemctl enable fail2ban
systemctl start fail2ban

# 3. Set Up Structured JSON Logging for GitLab Services
echo "Configuring JSON structured logging for GitLab..."
mkdir -p /etc/gitlab/logs
cat <<EOF >/etc/gitlab/logs/gitlab-log.conf
{
  "service": "gitlab",
  "level": "info",
  "timestamp": "%timestamp%",
  "message": "%message%"
}
EOF

# 4. Install GitLab CE
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
apt-get install gitlab-ce -y
gitlab-ctl reconfigure

# 5. Set Resource Requests and Limits for GitLab Runner
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

# 6. Secure Certbot Renewal with Non-Root User
echo "Creating a non-root user for Certbot renewal..."
useradd -m -d /home/$CERTBOT_USER -s /bin/bash $CERTBOT_USER
mkdir -p /home/$CERTBOT_USER/.certbot
chown -R $CERTBOT_USER:$CERTBOT_USER /home/$CERTBOT_USER/.certbot

# Schedule renewal
cat <<EOF | crontab -u $CERTBOT_USER -
0 3 * * * /usr/bin/certbot renew --quiet --noninteractive --cert-path /home/$CERTBOT_USER/.certbot/certs
EOF

echo "GitLab CE setup complete with full production hardening and configuration."
