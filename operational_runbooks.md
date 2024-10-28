
# Operational Runbooks

## 1. Scaling the Cluster
- **Horizontal Pod Autoscaler (HPA)**: Review `environments/dev/example_app_hpa.yaml` for pod autoscaling configurations.
- **Cluster Autoscaler**: Refer to `shared/scaling/cluster_autoscaler_config.yaml`.

## 2. Monitoring and Alerting
- **Grafana Dashboards**: View pre-configured dashboards for system metrics.
- **Prometheus Alerts**: Check `prometheus_application_alert_rules.yaml` for configured alerts.

## 3. Backup and Disaster Recovery
- **Automated Backup Testing**: Refer to `scripts/test_etcd_backup.sh`.
- **Offsite Backup**: Run `scripts/offsite_etcd_backup.sh` to upload backups.

## 4. Troubleshooting
- **Log Aggregation**: Use Loki and Jaeger for log and trace collection.
- **Common Issues**: Review project README for known issues and solutions.
