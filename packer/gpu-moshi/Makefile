# Makefile for GPU Moshi Demo Packer Image Building

.PHONY: help validate build build-dry clean init

PACKER_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

help:
	@echo "GPU Moshi Demo Packer Image Builder"
	@echo ""
	@echo "Available targets:"
	@echo "  make init       - Initialize Packer plugins"
	@echo "  make validate  - Validate Packer templates"
	@echo "  make build     - Build the GPU Moshi demo image"
	@echo "  make build-dry - Validate and plan only"
	@echo "  make clean     - Clean build artifacts"
	@echo ""
	@echo "Environment variables:"
	@echo "  SCW_PROJECT_ID    - Scaleway project ID (required)"
	@echo "  IMAGE_NAME        - Name for the built image (default: gpu-moshi-demo-ubuntu-22.04)"
	@echo "  INSTANCE_TYPE    - Scaleway instance type (default: H100-1-80G)"
	@echo ""
	@echo "Example usage:"
	@echo "  SCW_PROJECT_ID=xxx make build"

init:
	@echo "Initializing Packer plugins..."
	packer init $(PACKER_DIR)

validate:
	@echo "Validating Packer templates..."
	@if [ -z "$(SCW_PROJECT_ID)" ]; then \
		echo "ERROR: SCW_PROJECT_ID is not set"; \
		exit 1; \
	fi
	packer validate \
		-var "project_id=$(SCW_PROJECT_ID)" \
		-var "image_name=$(IMAGE_NAME)" \
		-var "instance_type=$(INSTANCE_TYPE)" \
		$(PACKER_DIR)

build-dry: validate
	@echo "Running build plan (dry run)..."
	packer build \
		-var "project_id=$(SCW_PROJECT_ID)" \
		-var "image_name=$(IMAGE_NAME)" \
		-var "instance_type=$(INSTANCE_TYPE)" \
		-only=*.scaleway \
		-dry-run \
		$(PACKER_DIR)

build:
	@echo "Building GPU Moshi demo image..."
	@if [ -z "$(SCW_PROJECT_ID)" ]; then \
		echo "ERROR: SCW_PROJECT_ID is not set"; \
		exit 1; \
	fi
	packer build \
		-var "project_id=$(SCW_PROJECT_ID)" \
		-var "image_name=$(IMAGE_NAME)" \
		-var "instance_type=$(INSTANCE_TYPE)" \
		$(PACKER_DIR)

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(PACKER_DIR)/output-*
	rm -f $(PACKER_DIR)/*.pkrvars.hcl
	rm -f $(PACKER_DIR)/packer.log
	rm -rf $(PACKER_DIR)/.packer*

# Debug target
debug:
	@echo "Packer version:"
	@packer version
	@echo ""
	@echo "Environment:"
	@echo "  SCW_PROJECT_ID: $(SCW_PROJECT_ID)"
	@echo "  IMAGE_NAME: $(IMAGE_NAME)"
	@echo "  INSTANCE_TYPE: $(INSTANCE_TYPE)"
