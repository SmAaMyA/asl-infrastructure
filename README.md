
# Kubernetes Environment Setup Summary

### Total Suggested VM Count: 10-11 VMs

#### Breakdown

- **Control Plane Nodes (3 VMs)**:
  - **Components**: Each node includes ETCD, Kubernetes API server, scheduler, and controller-manager.
  - **Purpose**: Ensures high availability for the Kubernetes control plane.
  - **Specs**: 4 vCPUs, 8 GB RAM, 50 GB SSD.

- **Worker Nodes (3 VMs, scalable based on workload needs)**:
  - **Purpose**: Dedicated to running application pods, scaling as required by workloads.
  - **Specs**: 4 vCPUs, 8 GB RAM, 50 GB SSD (scalable based on application demand).

- **Monitoring Server (1 VM)**:
  - **Components**: Runs Prometheus, Grafana, and Alertmanager to monitor the Kubernetes cluster and workloads.
  - **Purpose**: Observability for metrics and alerting; can include Node Exporter for advanced monitoring.
  - **Specs**: 4 vCPUs, 8 GB RAM, 50 GB SSD.

- **Logging and Tracing Server (1 VM)**:
  - **Components**: Runs Loki, Promtail, and Jaeger for centralized logging and tracing.
  - **Purpose**: Aggregates logs and enables tracing for troubleshooting across the cluster.
  - **Specs**: 4 vCPUs, 8 GB RAM, 50 GB SSD.

- **GitLab CE Server (1 VM)**:
  - **Purpose**: Provides CI/CD pipelines and can integrate with Vault for secrets management.
  - **Specs**: 4 vCPUs, 16 GB RAM, 100 GB SSD (scalable storage to meet CI/CD demands).

- **Secrets Management Server (Vault) (1 VM)**:
  - **Components**: Runs HashiCorp Vault for secure secrets management.
  - **Purpose**: Centralized management for sensitive information in applications and CI/CD workflows.
  - **Specs**: 4 vCPUs, 8 GB RAM, 50 GB SSD.

- **Optional VM for Backup Storage and Disaster Recovery (1 VM)**:
  - **Purpose**: Stores backups from ETCD and Velero, ideally with high I/O performance and ample storage.
  - **Specs**: 2 vCPUs, 4 GB RAM, scalable storage (500 GB+ SSD or network-attached storage).

#### Summary
- **Core Setup**: 10 VMs (3 control planes, 3 workers, 1 monitoring, 1 logging, 1 GitLab CE, 1 Vault).
- **Optional for Backup**: 1 additional VM for off-cluster storage.

This layout ensures redundancy, high availability, security, and observability, scalable to production needs.

---

# Project Infrastructure

This directory contains an optimized, environment-specific structure for managing infrastructure scripts, configurations, and policies. Below is an overview:

- `environments/`: Contains `dev` and `production` subdirectories, with each service organized by functionality.
- `shared/`: Stores shared configurations, policies, and RBAC rules used across environments.
- `scripts/`: Houses standalone and reusable scripts.
