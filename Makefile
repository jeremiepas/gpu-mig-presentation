# Makefile for GPU MIG vs Time Slicing Deployment
# Supports multi-environment deployments: prod, pre-prod, homelab

.PHONY: help validate build destroy clean init deploy-local deploy-scaleway deploy-prod deploy-preprod deploy-homelab status

help:
	@echo "GPU MIG vs Time Slicing Deployment"
	@echo ""
	@echo "Available targets:"
	@echo "  make init              - Initialize Terraform (ENV=prod|pre-prod|homelab)"
	@echo "  make validate          - Validate configurations (ENV=prod|pre-prod|homelab)"
	@echo "  make deploy-scaleway   - Deploy to Scaleway (ENV=prod|pre-prod)"
	@echo "  make deploy-prod       - Deploy to production environment"
	@echo "  make deploy-preprod    - Deploy to pre-production environment"
	@echo "  make deploy-homelab    - Deploy to homelab environment"
	@echo "  make destroy           - Destroy deployment (ENV=prod|pre-prod|homelab)"
	@echo "  make clean             - Clean local state files"
	@echo "  make status            - Check pod status (ENV=prod|pre-prod|homelab)"
	@echo ""
	@echo "Environment variables:"
	@echo "  ENV      - Environment to deploy (prod/pre-prod/homelab - default: prod)"
	@echo "  MODE     - GPU mode (timeslicing/mig - default: timeslicing)"

init:
	@ENV_NAME=$${ENV:-prod}; \
	echo "Initializing Terraform for $$ENV_NAME environment..."; \
	terraform -chdir=terraform/environments/$$ENV_NAME init

validate:
	@ENV_NAME=$${ENV:-prod}; \
	echo "Validating Terraform configuration for $$ENV_NAME environment..."; \
	terraform -chdir=terraform/environments/$$ENV_NAME validate

deploy-scaleway:
	@ENV_NAME=$${ENV:-prod}; \
	if [ "$$ENV_NAME" = "homelab" ]; then \
		echo "Error: Cannot use deploy-scaleway for homelab environment. Use 'make deploy-homelab' instead."; \
		exit 1; \
	fi; \
	echo "Deploying to Scaleway ($$ENV_NAME environment)..."; \
	terraform -chdir=terraform/environments/$$ENV_NAME init; \
	terraform -chdir=terraform/environments/$$ENV_NAME validate; \
	terraform -chdir=terraform/environments/$$ENV_NAME plan -out=tfplan; \
	terraform -chdir=terraform/environments/$$ENV_NAME apply -auto-approve tfplan

deploy-prod:
	@echo "Deploying to production environment..."
	@ENV=prod $(MAKE) deploy-scaleway

deploy-preprod:
	@echo "Deploying to pre-production environment..."
	@ENV=pre-prod $(MAKE) deploy-scaleway

deploy-homelab:
	@echo "Deploying to homelab environment..."
	@terraform -chdir=terraform/environments/homelab init
	@terraform -chdir=terraform/environments/homelab validate
	@terraform -chdir=terraform/environments/homelab plan -out=tfplan
	@terraform -chdir=terraform/environments/homelab apply -auto-approve tfplan

deploy-local:
	@echo "Deploying to local GPU machine..."
	@./deploy-local.sh

deploy-local-simple:
	@echo "Deploying to local GPU machine (simple approach)..."
	@./deploy-local-simple.sh

destroy:
	@ENV_NAME=$${ENV:-prod}; \
	echo "Destroying $$ENV_NAME deployment..."; \
	terraform -chdir=terraform/environments/$$ENV_NAME destroy

clean:
	@echo "Cleaning local state files..."
	@rm -f terraform/environments/prod/terraform.tfstate*
	@rm -f terraform/environments/pre-prod/terraform.tfstate*
	@rm -f terraform/environments/homelab/terraform.tfstate*
	@rm -rf terraform/environments/prod/.terraform
	@rm -rf terraform/environments/pre-prod/.terraform
	@rm -rf terraform/environments/homelab/.terraform
	@echo "Clean complete."

# GPU mode switching targets
switch-timeslicing:
	@ENV_NAME=$${ENV:-prod}; \
	if [ "$$ENV_NAME" = "homelab" ]; then \
		echo "Switching to Time Slicing mode on homelab..."; \
		kubectl apply -f k8s/environments/homelab/02-timeslicing-config.yaml; \
	else \
		echo "Switching to Time Slicing mode on $$ENV_NAME..."; \
		kubectl apply -f k8s/environments/$$ENV_NAME/02-timeslicing-config.yaml; \
	fi

switch-mig:
	@ENV_NAME=$${ENV:-prod}; \
	if [ "$$ENV_NAME" = "homelab" ]; then \
		echo "Error: MIG mode not available for homelab environment."; \
		exit 1; \
	else \
		echo "Switching to MIG mode on $$ENV_NAME..."; \
		kubectl apply -f k8s/environments/$$ENV_NAME/02-mig-config.yaml; \
	fi

# Status checking
status:
	@ENV_NAME=$${ENV:-prod}; \
	echo "Checking status on $$ENV_NAME environment..."; \
	kubectl get pods -A