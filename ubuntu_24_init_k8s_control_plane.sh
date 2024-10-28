#!/bin/bash

# Reusable Configuration Variables
CONTROL_PLANE_IP="192.168.1.100"
NODE_IP="<current_node_ip>"
CLUSTER_IPS=("192.168.1.101" "192.168.1.102" "192.168.1.103")
GRAFANA_ADMIN_PASSWORD="<your_password>"
EXTERNAL_STORAGE_BUCKET="s3://k8s-backups" # Replace with actual external storage

# Export environment variables for flexibility
export CONTROL_PLANE_IP NODE_IP CLUSTER_IPS GRAFANA_ADMIN_PASSWORD EXTERNAL_STORAGE_BUCKET

# Exit immediately if a command exits with a non-zero status
set -e

echo "Initializing Ubuntu 24 for Kubernetes Control-Plane Node with Enhanced Production Readiness..."

# 1. System Update, Security Patching, and Server Hardening
apt update && apt upgrade -y && apt autoremove -y
apt install -y curl wget vim ufw net-tools gnupg lsb-release sudo unattended-upgrades auditd fail2ban apparmor apparmor-profiles apparmor-utils logrotate haproxy

# Enable unattended security updates
dpkg-reconfigure --priority=low unattended-upgrades

# Set up AppArmor for custom profiles (ensure compatibility with critical services)
systemctl enable apparmor
systemctl start apparmor

# Custom AppArmor profile example for etcd
cat <<EOF >/etc/apparmor.d/custom/etcd
#include <tunables/global>
/usr/local/bin/etcd {
    # Add required permissions here
}
EOF
apparmor_parser -r /etc/apparmor.d/custom/etcd

# 2. High Availability and Disaster Recovery with Velero Off-Cluster Backups
echo "Setting up Velero with off-cluster storage for disaster recovery..."

# Install Velero and configure external storage
wget https://github.com/vmware-tanzu/velero/releases/download/v1.7.1/velero-v1.7.1-linux-amd64.tar.gz
tar -zxvf velero-v1.7.1-linux-amd64.tar.gz
mv velero-v1.7.1-linux-amd64/velero /usr/local/bin/
rm -rf velero-v1.7.1-linux-amd64*

# Velero setup for S3-compatible storage (e.g., MinIO, S3)
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.2.0 \
  --bucket $EXTERNAL_STORAGE_BUCKET \
  --secret-file /root/.aws/credentials \
  --use-volume-snapshots=false \
  --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http:// <minio-server-ip >:9000

# Set up cron job for scheduled Velero backups
kubectl create cronjob velero-backup --schedule="0 3 * * *" -- velero create backup daily-backup --ttl 168h0m0s

# 3. HAProxy and Load Balancing for Kubernetes API
echo "Configuring HAProxy for load-balanced Kubernetes API access..."

# Modify HAProxy configuration to balance across control-plane nodes
cat <<EOF >/etc/haproxy/haproxy.cfg
global
    log /dev/log    local0
    log /dev/log    local1 notice
    maxconn 2000
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 5s
    timeout client 50s
    timeout server 50s

frontend kubernetes
    bind *:6443
    default_backend kubernetes-backend

backend kubernetes-backend
    balance roundrobin
EOF

for ip in "${CLUSTER_IPS[@]}"; do
  echo "    server k8s-control-${ip} ${ip}:6443 check" >>/etc/haproxy/haproxy.cfg
done

systemctl restart haproxy

# 4. Networking and Traffic Management with NGINX Ingress and Istio mTLS
echo "Installing NGINX Ingress controller and enabling Istio mTLS..."

# Install NGINX Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Configure Istio for mTLS by default
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT
EOF

# 5. Performance Tuning with Pod Disruption Budgets and Node Affinity
echo "Adding Pod Disruption Budgets (PDBs) and Anti-Affinity rules for high availability..."

# Define a PDB for a critical application (e.g., etcd)
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: etcd-pdb
  namespace: kube-system
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: etcd
EOF

# Example of Node Affinity for workload isolation
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-deployment
spec:
  replicas: 2
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
                - key: app
                  operator: In
                  values:
                    - example-app
            topologyKey: "failure-domain.beta.kubernetes.io/zone"
EOF

# 6. Enhanced Observability and Alerting
echo "Configuring Prometheus alerts and adding Jaeger for distributed tracing..."

# Prometheus alerts for critical metrics
cat <<EOF >/etc/prometheus/alert.rules.yml
groups:
  - name: control-plane-alerts
    rules:
      - alert: EtcdHighLatency
        expr: etcd_disk_backend_commit_duration_seconds_bucket{le="0.5"} < 0.99
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "ETCD experiencing high latency"
EOF
systemctl restart prometheus

# Install Jaeger for tracing
kubectl create namespace observability
kubectl apply -n observability -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/crds/jaegertracing.io_jaegers_crd.yaml
kubectl apply -n observability -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/service_account.yaml
kubectl apply -n observability -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/role.yaml
kubectl apply -n observability -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/role_binding.yaml
kubectl apply -n observability -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/operator.yaml

# 7. Secure GitLab CI/CD with Vulnerability Scanning and RBAC
echo "Securing GitLab CI/CD pipeline and enforcing RBAC..."

# RBAC policies for GitLab Runner
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: gitlab-runner-role
  namespace: gitlab
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["pods", "pods/exec", "services"]
  verbs: ["get", "list", "create", "delete"]
EOF

# Add Trivy vulnerability scanning in GitLab pipeline
cat <<EOF >.gitlab-ci.yml
stages:
  - scan
  - deploy

scan:
  script:
    - trivy image $CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME

deploy:
  script:
    - kubectl apply -f deployment.yaml
EOF

echo "Control-Plane Node setup complete with all production readiness enhancements."
