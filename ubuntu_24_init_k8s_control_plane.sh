#!/bin/bash

# Reusable Configuration Variables
CONTROL_PLANE_IP="192.168.1.100"
NODE_IP="<current_node_ip>"
CLUSTER_IPS=("192.168.1.101" "192.168.1.102" "192.168.1.103")
POD_NETWORK_CIDR="10.244.0.0/16" # Example Pod network CIDR
OFF_CLUSTER_BACKUP="/mnt/backups/etcd"

echo "Starting improved production setup for Kubernetes Control Plane on Ubuntu 24..."

# 1. System Hardening
echo "Applying enhanced system hardening..."
apt update && apt upgrade -y && apt install -y unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

# UFW Firewall: open only necessary ports
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

# 2. Essential Package Installation (Preserving Existing)
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

# 6. Install Cert-manager for Automatic Certificate Renewal
echo "Installing cert-manager..."
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml

# Configure cert-manager with Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# 7. Automated ETCD Backups
echo "Setting up automated ETCD backups to off-cluster storage..."
mkdir -p $OFF_CLUSTER_BACKUP
echo "0 3 * * * etcdctl snapshot save $OFF_CLUSTER_BACKUP/etcd-snapshot-\$(date +\%F).db" >>/etc/crontab

# 8. Prometheus Alerts for Resource Usage
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

# 9. Jaeger for Distributed Tracing
echo "Installing Jaeger for application and service tracing..."
kubectl create namespace observability
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/operator.yaml -n observability

echo "Kubernetes Control Plane setup complete with all initializations, advanced hardening, monitoring, and tracing."
