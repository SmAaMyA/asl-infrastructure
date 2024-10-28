
# Architecture Diagram

This diagram provides a high-level overview of the Kubernetes infrastructure, illustrating key components and their relationships.

```
[ Control Plane (3 Nodes) ] --> Manages API Server, Scheduler, Controller-Manager, etcd
               |
               |
[ Worker Nodes ] --> Hosts application pods, autoscaled with HPA and Cluster Autoscaler
               |
               |
[ Monitoring Server ] --> Runs Prometheus, Grafana, and Alertmanager for observability
               |
               |
[ Logging and Tracing ] --> Aggregates logs with Loki and traces with Jaeger
               |
               |
[ GitLab CI/CD ] --> Manages pipelines for deployment and testing
               |
               |
[ Secrets Management (Vault) ] --> Provides secure secrets storage and access control
```

Each service in the architecture communicates through defined network policies, ensuring secure and controlled traffic between namespaces.
