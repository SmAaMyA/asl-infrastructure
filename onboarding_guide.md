
# Onboarding Guide

## Welcome to the Kubernetes Infrastructure Project

This guide provides an overview of the project's setup and step-by-step instructions for setting up a local development environment.

### Initial Setup
1. **Clone the Repository**:
   ```bash
   git clone <repository_url>
   ```

2. **Install Required Tools**:
   - Docker
   - kubectl
   - Helm

3. **Environment Setup**:
   - Refer to the `.env` files in `environments/dev` and `environments/production` for configuration variables.
   - Set up secrets using Vault as outlined in the project README.

4. **Running a Local Test Deployment**:
   - Use the provided `Makefile` for common tasks:
     ```bash
     make setup ENV=dev
     make deploy ENV=dev
     ```

### Key Project Components
- **Control Plane**: Manages Kubernetes API and scheduling.
- **Secrets Management**: Vault for secure secrets storage and dynamic secret injection.
- **CI/CD Pipelines**: Automated GitLab pipelines for continuous deployment.

For additional help, refer to the README files within each service folder.
