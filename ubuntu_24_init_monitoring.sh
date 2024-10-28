#!/bin/bash

echo "Setting up Monitoring Stack with SSL/TLS for Elastic Stack and Promtail..."

# 1. Install Prometheus and Configure Alerts
kubectl apply -f https://prometheus-community.github.io/helm-charts
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml

# 2. Install and Configure Promtail for Distributed Logging
echo "Installing Promtail for Loki integration..."
kubectl apply -f https://github.com/grafana/loki/blob/main/production/promtail-kubernetes.yaml

# 3. Set Up SSL/TLS for Elastic Stack
echo "Configuring SSL for Elastic Stack..."
openssl req -newkey rsa:4096 -nodes -keyout /etc/elasticsearch/ssl/elasticsearch.key -out /etc/elasticsearch/ssl/elasticsearch.crt -subj "/CN=elasticsearch"
kubectl create secret generic elastic-cert --from-file=/etc/elasticsearch/ssl/elasticsearch.crt --from-file=/etc/elasticsearch/ssl/elasticsearch.key -n monitoring

# 4. Expanded Prometheus Alert Rules for Network and Disk Monitoring
cat <<EOF >/etc/prometheus/alert.rules.yml
groups:
  - name: node-health
    rules:
      - alert: DiskRunningOut
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) < 0.15
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Node running out of disk space"
      - alert: HighNetworkTraffic
        expr: rate(node_network_receive_bytes_total[5m]) > 1e6
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High network traffic detected on node"
EOF
systemctl restart prometheus

echo "Monitoring stack setup complete with SSL, Promtail, and advanced alerting."
