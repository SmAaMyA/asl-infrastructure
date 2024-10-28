#!/bin/bash

# Reusable Configuration Variables
CONTROL_PLANE_IP="192.168.1.100"
JOIN_COMMAND="<kubeadm join command from control-plane setup>"

# Exit immediately if a command exits with a non-zero status
set -e

echo "Initializing Ubuntu 24 for Kubernetes Worker Node with Autoscaling Compatibility..."

# Install Docker and Kubernetes dependencies
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

# Join the Kubernetes cluster
$JOIN_COMMAND

echo "Worker Node initialized and compatible with Cluster Autoscaler."
