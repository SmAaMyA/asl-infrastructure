#!/bin/bash

# Configuration Variables
CONTROL_PLANE_IP="192.168.1.100"
JOIN_COMMAND="<kubeadm join command from control-plane setup>"
NODE_IP="<current_node_ip>"

echo "Starting production-grade setup for Kubernetes Worker Node on Ubuntu 24..."

# 1. System Hardening
echo "Applying enhanced system hardening..."
apt update && apt upgrade -y && apt install -y unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

# UFW Firewall: open only necessary ports
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 10250/tcp # Kubelet API
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

# 3. Docker and Kubernetes Dependencies (Preserving Existing)
apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update && apt install -y docker-ce
systemctl enable docker

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt update && apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

# 4. Join the Kubernetes Cluster
$JOIN_COMMAND

# 5. Node Labels and Taints for Workload Isolation
echo "Adding labels and taints for workload isolation..."
kubectl label node $NODE_IP node-type=worker
kubectl taint node $NODE_IP dedicated=worker:NoSchedule

# 6. Configure Cluster Autoscaler for Scaling Worker Nodes
echo "Installing Cluster Autoscaler for worker node scaling..."
kubectl apply -f https://github.com/kubernetes/autoscaler/releases/download/cluster-autoscaler-1.21.1/cluster-autoscaler.yaml

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      containers:
        - name: cluster-autoscaler
          image: k8s.gcr.io/cluster-autoscaler:v1.21.1
          command:
            - ./cluster-autoscaler
            - --cloud-provider=aws
            - --nodes=1:5:$NODE_IP
          resources:
            requests:
              cpu: 100m
              memory: 200Mi
            limits:
              cpu: 500m
              memory: 1Gi
EOF

echo "Worker Node setup complete with workload isolation, autoscaling, and production-grade hardening."
