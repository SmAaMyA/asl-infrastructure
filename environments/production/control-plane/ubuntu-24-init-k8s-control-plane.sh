#!/bin/bash

# Configuration Variables
CONTROL_PLANE_IP="192.168.1.100"   # IP for Control Plane
POD_NETWORK_CIDR="10.244.0.0/16"   # Example Pod network CIDR
BACKUP_BUCKET="s3://k8s-backups"   # Replace with your storage bucket for Velero
NODE_IP="<current_node_ip>"        # Current node IP for load balancing
VAULT_ADDR="http://127.0.0.1:8200" # Vault server address

echo "Starting production-grade setup for Kubernetes Control Plane on Ubuntu 24..."

# 1. System Hardening
echo "Applying enhanced system hardening..."
apt update && apt upgrade -y && apt install -y unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

# UFW Firewall: Allow only necessary ports
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 6443          # Kubernetes API server
ufw allow 2379:2380/tcp # ETCD server client API
ufw allow 10250/tcp     # Kubelet API
ufw enable

# SSH Hardening: enforce key-based login only, change default port
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Enable AppArmor for additional security
systemctl enable apparmor
systemctl start apparmor

# 2. Essential Package Installation
echo "Installing essential packages..."
apt install -y curl vim ufw net-tools gnupg sudo auditd fail2ban logrotate

# Enable and start Fail2Ban
systemctl enable fail2ban
systemctl start fail2ban

# 3. Install Docker with Production Configurations (Kubernetes Dependency)
echo "Installing Docker..."
apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update && apt install -y docker-ce
systemctl enable docker

# Configure Docker for Kubernetes
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

# 4. Install Kubernetes Components (kubeadm, kubelet, kubectl)
echo "Installing Kubernetes components..."
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt update && apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl # prevent automatic upgrades
systemctl enable kubelet

# 5. Initialize Kubernetes Control Plane
echo "Initializing Kubernetes control-plane node with HA..."
kubeadm init --control-plane-endpoint "$CONTROL_PLANE_IP:6443" --pod-network-cidr="$POD_NETWORK_CIDR" --upload-certs

# Set up kubeconfig for non-root user
echo "Configuring kubeconfig for k8sadmin user..."
mkdir -p /home/k8sadmin/.kube
cp -i /etc/kubernetes/admin.conf /home/k8sadmin/.kube/config
chown "$(id -u k8sadmin):$(id -g k8sadmin)" /home/k8sadmin/.kube/config

# Apply CNI Plugin (Flannel)
echo "Applying Flannel CNI plugin for network overlay..."
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# 6. MetalLB Installation for Load Balancing
echo "Setting up MetalLB for load balancing..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/metallb.yaml

# Configure MetalLB with IP range for load balancing
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - $CONTROL_PLANE_IP
EOF

# 7. Velero for Disaster Recovery and Off-Cluster ETCD Backups
echo "Installing Velero for disaster recovery..."
curl -L https://github.com/vmware-tanzu/velero/releases/download/v1.6.3/velero-v1.6.3-linux-amd64.tar.gz | tar xz
mv velero-v1.6.3-linux-amd64/velero /usr/local/bin/
rm -rf velero-v1.6.3-linux-amd64

# Set up Velero with off-cluster storage (S3-compatible)
velero install --provider aws --bucket $BACKUP_BUCKET --use-restic --use-volume-snapshots=false

# Schedule daily backups with Velero
kubectl create cronjob velero-backup --schedule="0 2 * * *" -- velero create backup daily-backup --ttl 168h0m0s

# 8. HashiCorp Vault for Secrets Management
echo "Installing Vault for secure secrets management..."
wget https://releases.hashicorp.com/vault/1.8.4/vault_1.8.4_linux_amd64.zip
unzip vault_1.8.4_linux_amd64.zip
mv vault /usr/local/bin/
rm vault_1.8.4_linux_amd64.zip

# Start Vault in development mode for demo (production should use a secure setup)
vault server -dev &

# Configure Vault Kubernetes authentication (optional for app secrets)
vault auth enable kubernetes

echo "Vault and disaster recovery setup complete."

# 9. Prometheus Alerts for Resource Usage
echo "Configuring Prometheus alerts for resource usage thresholds..."
cat <<EOF >/etc/prometheus/alert.rules.yml
groups:
  - name: resource-usage
    rules:
      - alert: HighCPULoad
        expr: instance:node_cpu_utilisation:rate1m > 0.85
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High CPU load detected on node"
      - alert: HighMemoryUsage
        expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected on node"
EOF
systemctl restart prometheus

echo "Kubernetes Control Plane setup complete with high availability, disaster recovery, secrets management, and monitoring."
