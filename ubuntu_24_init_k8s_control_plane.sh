#!/bin/bash

# Reusable Configuration Variables
CONTROL_PLANE_IP="192.168.1.100"
NODE_IP="<current_node_ip>"
CLUSTER_IPS=("192.168.1.101" "192.168.1.102" "192.168.1.103")

echo "Initializing Kubernetes Control Plane with cert-manager, ETCD backups, and advanced alerting..."

# 1. Install Kubernetes Components and Dependencies
apt update && apt install -y curl vim apt-transport-https ca-certificates gnupg lsb-release software-properties-common

# Install kubeadm, kubelet, and kubectl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt update && apt install -y kubelet kubeadm kubectl
systemctl enable kubelet

# 2. Cert-manager for Automatic Certificate Renewal
echo "Installing cert-manager..."
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml

# cert-manager configuration for automatic renewal
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

# 3. ETCD Backup Cron Job
echo "Setting up cron job for ETCD backups..."
mkdir -p /var/backups/etcd
echo "0 2 * * * etcdctl snapshot save /var/backups/etcd/snapshot-\$(date +\%F).db" >>/etc/crontab

# 4. Prometheus Alert Rules for Kubernetes Events
echo "Configuring Prometheus alerts for critical Kubernetes events..."
cat <<EOF >/etc/prometheus/alert.rules.yml
groups:
  - name: control-plane-alerts
    rules:
      - alert: KubeAPIErrors
        expr: apiserver_request_total{code=~"5.."} > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "API server returning errors"
      - alert: KubeletDown
        expr: up{job="kubelet"} == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Kubelet instance down on a node"
EOF
systemctl restart prometheus
