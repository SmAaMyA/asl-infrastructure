# Project Infrastructure

This directory contains an optimized, environment-specific structure for managing infrastructure scripts, configurations, and policies.

## Directory Overview

- **environments/**: Contains `dev` and `production` subdirectories, with each service organized by functionality.
- **shared/**: Stores shared configurations, policies, and RBAC rules used across environments.
- **scripts/**: Houses standalone and reusable scripts.

## Key Files

- **CHANGELOG.md**: Records updates to infrastructure configurations and settings.
- **Makefile**: Provides automation for common tasks (e.g., setup, deploy, backup).

Refer to each service or environment's README for further details.

## VM Specifications

Each VM in the setup has specific roles and hardware requirements tailored to its purpose in the Kubernetes environment. Below is a summary of the recommended specifications for each node:

- **Control Plane Nodes (3 VMs)**:

  - **Components**: ETCD, Kubernetes API server, scheduler, controller-manager
  - **Purpose**: Ensures high availability for the Kubernetes control plane
  - **Specs**: 4 vCPUs, 8 GB RAM, 50 GB SSD

- **Worker Nodes (3 VMs, scalable based on workload needs)**:

  - **Purpose**: Dedicated to running application pods, scaling as required by workloads
  - **Specs**: 4 vCPUs, 8 GB RAM, 50 GB SSD (scalable based on application demand)

- **Monitoring Server (1 VM)**:

  - **Components**: Prometheus, Grafana, and Alertmanager
  - **Purpose**: Observability for metrics and alerting; can include Node Exporter for advanced monitoring
  - **Specs**: 4 vCPUs, 8 GB RAM, 50 GB SSD

- **Logging and Tracing Server (1 VM)**:

  - **Components**: Loki, Promtail, and Jaeger
  - **Purpose**: Aggregates logs and enables tracing for troubleshooting across the cluster
  - **Specs**: 4 vCPUs, 8 GB RAM, 50 GB SSD

- **GitLab CE Server (1 VM)**:

  - **Purpose**: Provides CI/CD pipelines and can integrate with Vault for secrets management
  - **Specs**: 4 vCPUs, 16 GB RAM, 100 GB SSD (scalable storage to meet CI/CD demands)

- **Secrets Management Server (Vault) (1 VM)**:

  - **Components**: HashiCorp Vault
  - **Purpose**: Centralized management for sensitive information in applications and CI/CD workflows
  - **Specs**: 4 vCPUs, 8 GB RAM, 50 GB SSD

- **Optional VM for Backup Storage and Disaster Recovery (1 VM)**:
  - **Purpose**: Stores backups from ETCD and Velero, ideally with high I/O performance and ample storage
  - **Specs**: 2 vCPUs, 4 GB RAM, scalable storage (500 GB+ SSD or network-attached storage)

This setup ensures a scalable, high-availability infrastructure with appropriate resources allocated to each node for performance and resilience.
