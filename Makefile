
# Makefile for automating infrastructure tasks

# Define environment variables for configuration paths
ENV_DEV=./environments/dev
ENV_PROD=./environments/production
SCRIPTS=./scripts
SHARED=./shared

# Default environment is dev; override with `make ENV=production <task>`
ENV ?= dev

# Setup tasks for initializing environments
setup:
	@echo "Setting up $(ENV) environment..."
	# Add setup commands for control plane, networking, etc.
	kubectl apply -f $(ENV)_control_plane.yaml
	kubectl apply -f $(ENV)_networking.yaml

deploy:
	@echo "Deploying configurations to $(ENV) environment..."
	kubectl apply -f $(ENV_DEV)/control-plane/
	kubectl apply -f $(ENV_DEV)/networking/

backup-etcd:
	@echo "Backing up etcd data for $(ENV) environment..."
	bash $(SCRIPTS)/etcd_backup_remote.sh

install-istio:
	@echo "Installing Istio service mesh in $(ENV) environment..."
	bash $(SCRIPTS)/service_mesh_istio_install.sh

# Help menu
help:
	@echo "Usage: make <target> ENV=<environment>"
	@echo "Targets:"
	@echo "  setup           - Setup infrastructure for the selected environment"
	@echo "  deploy          - Deploy configurations to the environment"
	@echo "  backup-etcd     - Run etcd backup"
	@echo "  install-istio   - Install Istio service mesh"
	@echo "  help            - Display this help menu"
