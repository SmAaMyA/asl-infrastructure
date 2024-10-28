
#!/bin/bash

echo "Initializing Enhanced Setup for Logging and Tracing Server..."

# 1. System Update and Install Dependencies
apt update && apt upgrade -y
apt install -y curl wget gnupg ufw

# 2. Configure Firewall with Restricted Access
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 3100/tcp  # Loki
ufw allow from <trusted-ip> to any port 16686 # Jaeger UI access
ufw enable

# 3. Install and Configure Loki
echo "Installing and Configuring Loki..."
curl -s -O https://raw.githubusercontent.com/grafana/loki/v2.3.0/production/helm/loki-stack/templates/loki.yaml
kubectl apply -f loki.yaml

# Add retention and storage settings for Loki
kubectl patch configmap loki-config -n loki --patch '{
  "data": {
    "retention_period": "168h", # 7 days
    "storage": {
      "type": "filesystem",
      "config": {
        "directory": "/loki"
      }
    }
  }
}'

# 4. Install Promtail for Log Collection
echo "Installing Promtail..."
curl -s -O https://raw.githubusercontent.com/grafana/loki/v2.3.0/production/promtail-daemonset.yaml
kubectl apply -f promtail-daemonset.yaml

# 5. Install Jaeger for Distributed Tracing
echo "Installing Jaeger..."
kubectl create namespace observability
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/operator.yaml -n observability

# Configure Jaeger with restricted access
kubectl apply -f - <<EOF
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: observability
spec:
  ingress:
    enabled: true
    hosts:
      - "jaeger.example.com"
EOF

echo "Logging and Tracing Server setup complete with enhanced configurations."
