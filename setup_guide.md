
# Full Environment Setup Guide

This guide provides step-by-step instructions for setting up the Kubernetes infrastructure from scratch using the configurations and scripts in this project.

---

## Prerequisites

1. **Install Required Tools**:
   - **Docker**: Install Docker on all nodes.
   - **kubectl**: For Kubernetes CLI access.
   - **Helm**: To manage Kubernetes applications.
   - **AWS CLI** (for offsite backup if using AWS S3).
   - **Vault**: For secrets management (optional, if not using the cloud).

2. **Prepare Nodes**: Provision and configure nodes according to specifications in `README.md`. Ensure network connectivity between nodes.

---

## Step 1: Configure Kubernetes Cluster

1. **Control Plane Setup**:
   - On each control plane node, use the `Makefile` command:
     ```bash
     make setup ENV=dev
     ```
   - This command applies Kubernetes configurations from `environments/dev` and `environments/production` folders as specified in the `Makefile`.

2. **Worker Nodes**:
   - Join worker nodes to the cluster:
     ```bash
     kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
     ```
   - Add worker nodes as needed by following the control-plane join instructions.

---

## Step 2: Apply Vault Secrets Management

1. **Vault Server Setup**:
   - On the Vault server, initialize and unseal Vault.
   - Apply the Vault policy `vault_dynamic_secrets_policy.hcl`:
     ```bash
     vault policy write app-policy shared/policies/vault_dynamic_secrets_policy.hcl
     ```

2. **Vault Agent Injector**:
   - Apply `vault_agent_injector.yaml` to enable secret injection in Kubernetes:
     ```bash
     kubectl apply -f environments/dev/vault_agent_injector.yaml
     ```

---

## Step 3: Set Up Monitoring and Logging

1. **Install Prometheus and Grafana**:
   - Use Helm charts to install Prometheus and Grafana:
     ```bash
     helm install prometheus prometheus-community/prometheus
     helm install grafana grafana/grafana
     ```
   - Import `grafana_dashboard_k8s.json` into Grafana for cluster monitoring.

2. **Apply Prometheus Alert Rules**:
   - Apply alert rules from `prometheus_application_alert_rules.yaml` for custom alerts:
     ```bash
     kubectl apply -f shared/monitoring/prometheus_application_alert_rules.yaml
     ```

3. **Configure Loki and Jaeger**:
   - Follow Loki and Jaeger setup instructions to enable logging and tracing.

---

## Step 4: Set Up CI/CD Pipeline with GitLab

1. **Configure GitLab CI/CD**:
   - Import `.gitlab-ci.yml` to GitLab for automated pipelines with build, test, and deploy stages.
   - Set environment variables in GitLab for secure access to secrets and deployment credentials.

2. **Enable Security Scanning**:
   - Configure Trivy in `.gitlab-ci.yml` to scan Docker images.

---

## Step 5: Configure Network Policies and Security Standards

1. **Network Policies**:
   - Apply the network policy `network_policy_restrict_namespace.yaml` to restrict inter-namespace traffic:
     ```bash
     kubectl apply -f shared/policies/network_policy_restrict_namespace.yaml
     ```

2. **Pod Security Policies**:
   - Apply the restricted pod security policy `pod_security_policy_restricted.yaml`:
     ```bash
     kubectl apply -f shared/policies/pod_security_policy_restricted.yaml
     ```

3. **Enable mTLS with Istio**:
   - Install Istio, then apply `istio_mtls_strict.yaml` to enforce mutual TLS:
     ```bash
     istioctl install --set profile=default
     kubectl apply -f environments/dev/istio_mtls_strict.yaml
     ```

---

## Step 6: Configure Scaling

1. **Horizontal Pod Autoscaler (HPA)**:
   - Apply HPA configuration to enable autoscaling for `example-app`:
     ```bash
     kubectl apply -f environments/dev/example_app_hpa.yaml
     ```

2. **Cluster Autoscaler**:
   - Apply `cluster_autoscaler_config.yaml` to enable dynamic node scaling:
     ```bash
     kubectl apply -f shared/scaling/cluster_autoscaler_config.yaml
     ```

---

## Step 7: Configure Backups and Disaster Recovery

1. **Automated Backups**:
   - Schedule `offsite_etcd_backup.sh` in a cron job to regularly upload backups to AWS S3.

2. **Disaster Recovery**:
   - Refer to `disaster_recovery_playbook.md` for steps to restore the cluster in case of failure.

---

## Step 8: Use Runbooks and Onboarding Guide

1. **Operational Runbooks**:
   - Follow `operational_runbooks.md` for common operational tasks like scaling, monitoring, and troubleshooting.

2. **Onboarding Guide**:
   - New team members can refer to `onboarding_guide.md` for a streamlined setup process and an overview of key components.

---

This setup guide provides detailed instructions to fully configure and deploy the infrastructure.
