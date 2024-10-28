#!/bin/bash

# Reusable Configuration Variables
CONTROL_PLANE_IP="192.168.1.100"
NODE_IP="<current_node_ip>"
CLUSTER_IPS=("192.168.1.101" "192.168.1.102" "192.168.1.103")

echo "Starting full production setup for Kubernetes Control Plane on Ubuntu 24..."

# 1. System Hardening
echo "Applying system hardening..."
apt update && apt upgrade -y && apt install -y unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 6443
ufw enable

sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

systemctl enable apparmor
systemctl start apparmor

# 2. Essential Package Installation
echo "Installing essential packages..."
apt install -y curl vim ufw net-tools gnupg sudo auditd fail2ban logrotate

systemctl enable fail2ban
systemctl start fail2ban

# 3. Install kubeadm, kubelet, and kubectl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt update && apt install -y kubelet kubeadm kubectl
systemctl enable kubelet

# 4. Install Cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml

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

# 5. Configure ETCD Backup
mkdir -p /var/backups/etcd
echo "0 2 * * * etcdctl snapshot save /var/backups/etcd/snapshot-\$(date +\%F).db" >>/etc/crontab

# 6. Prometheus Alerting Rules
cat <<EOF >/etc/prometheus/alert.rules.yml
groups:
  - name: control-plane-alerts
    rules:
      - alert: KubeAPIErrors
        expr: apiserver_request_total{code=~"5.."} > 0
        for: 5m
        labels:
          severity: critical
EOF
systemctl restart prometheus

echo "Kubernetes Control Plane setup complete with production hardening and configuration."
