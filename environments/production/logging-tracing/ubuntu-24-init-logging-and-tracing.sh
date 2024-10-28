#!/bin/bash

echo "Initializing Logging and Tracing Server..."

# Update and install dependencies
apt update && apt upgrade -y
apt install -y curl wget gnupg ufw

# Configure firewall with restricted access
ufw default deny incoming
ufw allow out
ufw allow ssh
ufw allow from any port 3100 <node-ips >to    # Loki
ufw allow from any port 16686 <trusted-ip >to # Jaeger UI access (office or VPN IP)
ufw enable

# Install Loki
echo "Installing Loki..."
curl -s -O https://raw.githubusercontent.com/grafana/loki/v2.3.0/production/helm/loki-stack/templates/loki.yaml
kubectl apply -f loki.yaml

# Install Promtail (Log Collector)
echo "Installing Promtail..."
kubectl apply -f https://raw.githubusercontent.com/grafana/loki/v2.3.0/production/promtail-daemonset.yaml

# Install Jaeger for Distributed Tracing
echo "Installing Jaeger..."
kubectl create namespace observability
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/operator.yaml -n observability

echo "Logging and Tracing Server setup complete with Loki, Promtail, and restricted Jaeger access."
