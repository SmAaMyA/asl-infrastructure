#!/bin/bash

# Reusable Configuration Variables
CONTROL_PLANE_IP="192.168.1.100"     # Control plane endpoint IP
MONITORING_SERVER_IP="192.168.1.101" # Monitoring server IP
POD_NETWORK_CIDR="10.244.0.0/16"     # Pod network CIDR

# Exit immediately if a command exits with a non-zero status
set -e

echo "Initializing Ubuntu 24 for Kubernetes Control-Plane Node..."

# 1. System Update, Server Hardening, and Optimizations

# Update packages, upgrade the system, and remove unnecessary packages
echo "Updating system packages and applying security patches..."
apt update && apt upgrade -y && apt autoremove -y

# Install essential tools
echo "Installing essential tools..."
apt install -y curl wget vim ufw net-tools gnupg lsb-release sudo auditd unattended-upgrades fail2ban apparmor apparmor-profiles apparmor-utils logrotate

# Customized Auditd Rules
echo "Setting up customized auditd rules for Kubernetes monitoring..."
echo '-w /etc/kubernetes/ -p wa -k kubernetes' >>/etc/audit/rules.d/audit.rules
echo '-w /var/log/kubernetes/ -p wa -k kube_logs' >>/etc/audit/rules.d/audit.rules
systemctl restart auditd

# Configure UFW firewall with stricter rules
echo "Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 6443          # Kubernetes API server port
ufw allow 10250/tcp     # Kubelet API
ufw allow 2379:2380/tcp # ETCD server client API
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

# Kernel parameter optimizations for Kubernetes networking and resource limits
echo "Configuring kernel parameters for Kubernetes..."
cat <<EOF >>/etc/sysctl.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
vm.swappiness = 10
fs.file-max = 500000
kernel.pid_max = 65536
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.rp_filter = 1
EOF
sysctl -p

# Enable audit logging for security events
echo "Enabling audit logging..."
systemctl enable auditd
systemctl start auditd

# Set resource limits for Kubernetes processes
echo "Setting resource limits..."
cat <<EOF >>/etc/security/limits.conf
* soft nofile 102400
* hard nofile 102400
EOF

# Enable and configure AppArmor
echo "Configuring AppArmor for enhanced security..."
systemctl enable apparmor
systemctl start apparmor

# 2. Create Kubernetes Maintenance User with Limited Privileges

# Add a new user and grant only required permissions
echo "Creating Kubernetes maintenance user: k8sadmin"
adduser --disabled-password --gecos "" k8sadmin
usermod -aG sudo k8sadmin

# Configure sudoers file for limited permissions
echo "k8sadmin ALL=(ALL) NOPASSWD: /usr/bin/kubectl, /usr/bin/kubeadm, /usr/bin/kubelet" | sudo tee /etc/sudoers.d/k8sadmin

# 3. Install Kubernetes Dependencies and Control-Plane Components

# Install Docker with production configurations
echo "Installing Docker..."
apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update && apt install -y docker-ce
systemctl enable docker

# Configure Docker for Kubernetes with additional security configurations
cat <<EOF >/etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "userns-remap": "default",
  "seccomp-profile": "/etc/docker/seccomp.json"
}
EOF
systemctl restart docker

# Install kubeadm, kubelet, and kubectl
echo "Installing kubeadm, kubelet, and kubectl..."
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt update && apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl # prevent automatic upgrades

# Enable kubelet to start at boot
systemctl enable kubelet

# Initialize Kubernetes control-plane node
echo "Initializing Kubernetes control-plane node with HA..."
kubeadm init --control-plane-endpoint "$CONTROL_PLANE_IP:6443" --pod-network-cidr="$POD_NETWORK_CIDR" --upload-certs

# Set up kubeconfig for the non-root user
echo "Configuring kubeconfig for k8sadmin..."
mkdir -p /home/k8sadmin/.kube
cp -i /etc/kubernetes/admin.conf /home/k8sadmin/.kube/config
chown "$(id -u k8sadmin)":"$(id -g k8sadmin)" /home/k8sadmin/.kube/config

# Apply CNI plugin (Flannel for network overlay)
echo "Deploying Flannel CNI plugin..."
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# ETCD Backup Automation
echo "Setting up ETCD backup automation..."
mkdir -p /backup
echo "0 2 * * * root /usr/bin/etcdctl snapshot save /backup/etcd-$(date +%Y%m%d%H%M%S).db" | tee -a /etc/crontab

# 4. Install Prometheus Node Exporter for Resource Monitoring

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

# 5. Install Fluentd for Log Exporting to Monitoring Server

echo "Installing Fluentd for log exporting..."
curl -fsSL https://toolbelt.treasuredata.com/sh/install-ubuntu-focal-td-agent4.sh | sh
systemctl start td-agent
systemctl enable td-agent

# Configure Fluentd to export logs to monitoring server
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

echo "Kubernetes control-plane node initialization complete."
