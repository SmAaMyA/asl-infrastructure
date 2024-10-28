#!/bin/bash

# Reusable Configuration Variables
CONTROL_PLANE_IP="192.168.1.100"
JOIN_COMMAND="<kubeadm join command from control-plane setup>"

echo "Initializing Ubuntu 24 for Kubernetes Worker Node with Anti-Affinity and Autoscaler support..."

# 1. Install Docker and Kubernetes Dependencies
apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common
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

# 2. Join the Kubernetes Cluster
$JOIN_COMMAND

# 3. Node Labels and Taints for Workload Isolation
echo "Adding labels and taints for workload isolation..."
kubectl label node $NODE_IP node-type=worker
kubectl taint node $NODE_IP dedicated=worker:NoSchedule

# 4. Anti-Affinity for Key Deployments
echo "Configuring anti-affinity for workload separation..."
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

echo "Worker Node initialization complete with workload isolation and anti-affinity."
