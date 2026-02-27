# Makefile for GPU MIG vs Time Slicing Deployment
# Supports both Scaleway cloud and local deployments

.PHONY: help validate build destroy clean init deploy-local deploy-local-simple deploy-scaleway

help:
	@echo "GPU MIG vs Time Slicing Deployment"
	@echo ""
	@echo "Available targets:"
	@echo "  make init              - Initialize Terraform"
	@echo "  make validate          - Validate configurations"
	@echo "  make deploy-scaleway   - Deploy to Scaleway (dev environment by default)"
	@echo "  make deploy-local      - Deploy to local GPU machine"
	@echo "  make deploy-local-simple - Deploy to local GPU machine (simple approach)"
	@echo "  make destroy           - Destroy Scaleway deployment"
	@echo "  make clean             - Clean local state files"
	@echo ""
	@echo "Environment variables:"
	@echo "  ENV      - Environment to deploy (dev/prod/local - default: dev)"
	@echo "  MODE     - GPU mode (timeslicing/mig - default: timeslicing)"

init:
	@if [ "$(ENV)" = "local" ]; then \
		echo "Initializing local Terraform environment..."; \
		terraform -chdir=terraform/environments/local init; \
	else \
		echo "Initializing default (dev) Terraform environment..."; \
		terraform -chdir=terraform/environments/dev init; \
	fi

validate:
	@if [ "$(ENV)" = "local" ]; then \
		echo "Validating local Terraform configuration..."; \
		terraform -chdir=terraform/environments/local validate; \
	elif [ "$(ENV)" = "prod" ]; then \
		echo "Validating prod Terraform configuration..."; \
		terraform -chdir=terraform/environments/prod validate; \
	else \
		echo "Validating dev Terraform configuration..."; \
		terraform -chdir=terraform/environments/dev validate; \
	fi

deploy-scaleway:
	@echo "Deploying to Scaleway ($(ENV) environment)..."
	@./deploy-cluster.sh $(ENV)

deploy-local:
	@echo "Deploying to local GPU machine..."
	@./deploy-local.sh

deploy-local-simple:
	@echo "Deploying to local GPU machine (simple approach)..."
	@./deploy-local-simple.sh

destroy:
	@if [ "$(ENV)" = "local" ]; then \
		echo "Destroying local deployment is not supported."; \
		echo "Please manually clean up on the local machine."; \
	elif [ "$(ENV)" = "prod" ]; then \
		echo "Destroying prod deployment..."; \
		terraform -chdir=terraform/environments/prod destroy; \
	else \
		echo "Destroying dev deployment..."; \
		terraform -chdir=terraform/environments/dev destroy; \
	fi

clean:
	@echo "Cleaning local state files..."
	@rm -f terraform/environments/dev/terraform.tfstate*
	@rm -f terraform/environments/prod/terraform.tfstate*
	@rm -f terraform/environments/local/terraform.tfstate*
	@rm -rf terraform/environments/dev/.terraform
	@rm -rf terraform/environments/prod/.terraform
	@rm -rf terraform/environments/local/.terraform
	@echo "Clean complete."

# GPU mode switching targets
switch-timeslicing:
	@if [ "$(ENV)" = "local" ]; then \
		echo "Switching to Time Slicing mode on local machine..."; \
		ssh -i ssh_key jeremie@192.168.1.96 'sudo k3s kubectl apply -f ~/k8s-manifests/02-timeslicing-config.yaml'; \
	else \
		echo "Switching to Time Slicing mode on Scaleway..."; \
		kubectl apply -f k8s/02-timeslicing-config.yaml; \
	fi

switch-mig:
	@if [ "$(ENV)" = "local" ]; then \
		echo "Switching to MIG mode on local machine..."; \
		ssh -i ssh_key jeremie@192.168.1.96 'sudo k3s kubectl apply -f ~/k8s-manifests/02-mig-config.yaml'; \
	else \
		echo "Switching to MIG mode on Scaleway..."; \
		kubectl apply -f k8s/02-mig-config.yaml; \
	fi

# Status checking
status:
	@if [ "$(ENV)" = "local" ]; then \
		echo "Checking status on local machine..."; \
		ssh -i ssh_key jeremie@192.168.1.96 'sudo k3s kubectl get pods -A'; \
	else \
		echo "Checking status on Scaleway..."; \
		kubectl get pods -A; \
	fi