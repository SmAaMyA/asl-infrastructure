
#!/bin/bash

# GitLab Installation Variables
GITLAB_URL="https://gitlab.example.com"
GITLAB_RUNNER_IMAGE="gitlab/gitlab-runner:latest"
CERTBOT_USER="certbotuser"
OFF_CLUSTER_BACKUP="/mnt/backups/gitlab"
GITLAB_BACKUP_PATH="/var/opt/gitlab/backups"

echo "Starting improved production setup for GitLab CE on Ubuntu 24..."

# 1. System Hardening
echo "Applying enhanced system hardening..."
apt update && apt upgrade -y && apt install -y unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

# UFW Firewall: open only necessary ports
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp       # HTTP for GitLab
ufw allow 443/tcp      # HTTPS for GitLab
ufw enable

# SSH Hardening: enforce key-based login only, change default port
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Enable AppArmor for additional security
systemctl enable apparmor && systemctl start apparmor

# 2. Install GitLab
echo "Installing GitLab CE..."
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash
apt install -y gitlab-ce
gitlab-ctl reconfigure

# Configure GitLab URL
gitlab-ctl set-url "${GITLAB_URL}"

# 3. Configure SSL with Certbot
echo "Setting up SSL with Certbot..."
apt install -y certbot
certbot certonly --standalone -d ${GITLAB_URL} --agree-tos -m "${CERTBOT_USER}@${GITLAB_URL}" --non-interactive
ln -sf /etc/letsencrypt/live/${GITLAB_URL}/fullchain.pem /etc/gitlab/ssl/${GITLAB_URL}.crt
ln -sf /etc/letsencrypt/live/${GITLAB_URL}/privkey.pem /etc/gitlab/ssl/${GITLAB_URL}.key
gitlab-ctl reconfigure

# 4. GitLab Runner Setup
echo "Setting up GitLab Runner..."
docker pull ${GITLAB_RUNNER_IMAGE}
docker run -d --name gitlab-runner --restart always   -v /var/run/docker.sock:/var/run/docker.sock   -v /srv/gitlab-runner/config:/etc/gitlab-runner   ${GITLAB_RUNNER_IMAGE} register   --non-interactive   --url ${GITLAB_URL}   --registration-token <your_registration_token>   --executor docker   --docker-image "docker:latest"

# 5. Setup Automated Backups
echo "Configuring automated GitLab backups..."
echo "0 2 * * * gitlab-backup create" >> /etc/crontab

# Off-cluster backup script to copy to the designated path
mkdir -p "${OFF_CLUSTER_BACKUP}"
cp -r "${GITLAB_BACKUP_PATH}/*" "${OFF_CLUSTER_BACKUP}"

echo "GitLab CE setup complete. Backups configured to ${OFF_CLUSTER_BACKUP}."
