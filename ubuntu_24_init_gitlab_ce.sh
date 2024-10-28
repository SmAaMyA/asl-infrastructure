#!/bin/bash

# GitLab Installation Variables
GITLAB_URL="https://gitlab.example.com"
GITLAB_RUNNER_IMAGE="gitlab/gitlab-runner:latest"
CERTBOT_USER="certbotuser"

echo "Starting GitLab CE setup with secure Certbot and optimized GitLab Runner..."

# 1. Set Up Structured JSON Logging for GitLab Services
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

# 2. Install GitLab CE
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
apt-get install gitlab-ce -y
gitlab-ctl reconfigure

# 3. Set Resource Requests and Limits for GitLab Runner
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

# 4. Secure Certbot Renewal with Non-Root User
echo "Creating a non-root user for Certbot renewal..."
useradd -m -d /home/$CERTBOT_USER -s /bin/bash $CERTBOT_USER
mkdir -p /home/$CERTBOT_USER/.certbot
chown -R $CERTBOT_USER:$CERTBOT_USER /home/$CERTBOT_USER/.certbot

# Schedule renewal
cat <<EOF | crontab -u $CERTBOT_USER -
0 3 * * * /usr/bin/certbot renew --quiet --noninteractive --cert-path /home/$CERTBOT_USER/.certbot/certs
EOF

echo "GitLab CE setup complete with secure Certbot renewal and GitLab Runner optimizations."
