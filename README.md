
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
