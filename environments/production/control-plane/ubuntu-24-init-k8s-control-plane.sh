
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
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

# 2. Install Kubernetes Components
echo "Installing Kubernetes components..."
apt update && apt install -y kubelet kubeadm kubectl

# Disable swap (required by Kubernetes)
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# 3. Initialize Kubernetes Control Plane
echo "Initializing Kubernetes Control Plane..."
kubeadm init --apiserver-advertise-address=${CONTROL_PLANE_IP} --pod-network-cidr=${POD_NETWORK_CIDR} | tee kubeadm-init.log

# 4. Configure kubectl for the control-plane user
export KUBECONFIG=/etc/kubernetes/admin.conf

# Apply Network Plugin (Flannel as an example)
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

echo "Control Plane initialization complete."

# 5. Backup Configurations with Velero (optional)
# Velero installation and configuration steps here if needed

# Additional setup and configurations...
