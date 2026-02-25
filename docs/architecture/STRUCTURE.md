# Project Structure

## Directory Overview

This document provides a comprehensive overview of the project directory structure, explaining the purpose and contents of each major directory and file in the repository. Understanding the structure is essential for navigating the codebase, making modifications, and understanding how different components work together.

The project follows a standard structure for infrastructure-as-code projects, with clear separation between Terraform configurations, Kubernetes manifests, CI/CD workflows, and documentation. This organization makes it easy to locate specific files and understand the relationships between different parts of the system.

## Root Directory

The root directory contains configuration files, documentation, and the main entry points for the project. Here are the key files and directories found at the root level:

The AGENTS.md file contains guidelines specifically written for AI coding agents that work in this repository. It provides detailed instructions on how to use Terraform, Kubernetes, and the various tools available in this project. This file is particularly useful for understanding the recommended workflows and best practices for making changes to the infrastructure.

The README.md file serves as the main introduction to the project, containing setup instructions, usage guidelines, and quick reference information. New users should start here to understand what the project does and how to get started.

The shell.nix file defines the development environment using Nix, ensuring consistent tool versions across different development machines. This file includes all necessary tools such as the GitHub CLI, Scaleway CLI, kubectl, and other utilities needed for working with the project.

The credentials.env file contains environment variables for authenticating with Scaleway. This file is gitignored and should never be committed to the repository, as it contains sensitive credentials.

The ssh_key and ssh_key.pub files provide SSH access to the provisioned GPU instance. The private key is also gitignored for security reasons.

## Terraform Directory

The terraform/ directory contains all Terraform configurations used to provision the cloud infrastructure on Scaleway. This directory is organized into environments and contains the core infrastructure code.

The main.tf file in the terraform/ directory defines the Terraform provider configuration for Scaleway. It specifies the region, project ID, and other essential provider settings that apply across all environments. This file also configures the remote state backend when used outside of environment-specific directories.

The variables.tf file defines input variables that can be customized when deploying the infrastructure. These variables include settings like the instance type, region, and other configurable parameters that affect how resources are provisioned.

The outputs.tf file defines output values that are displayed after Terraform applies the configuration. These outputs typically include the instance IP address, connection information, and other useful values for interacting with the provisioned resources.

The instances.tf file contains the main resource definitions for the GPU instance, including the compute instance, IP address, and volume attachments. This is where the H100-1-80G instance type is specified along with the cloud-init configuration.

The cloud-init.yaml.tpl file is a template used during instance provisioning to configure the operating system. It installs K3s and sets up the basic environment needed for Kubernetes to function.

## Terraform Environments

The terraform/environments/ directory contains environment-specific Terraform configurations. This separation allows for different deployment configurations while maintaining shared modules and best practices.

The dev/ subdirectory contains the development environment configuration. This environment uses S3 state backend and is typically used for local development and testing. The configuration in this directory is similar to the prod environment but may use different resource sizes or settings for development purposes.

The prod/ subdirectory contains the production environment configuration. This environment is deployed via GitHub Actions and uses the same S3 state backend but with a separate state key to isolate it from the development environment. The prod configuration is typically more conservative with resources and includes additional safety measures.

Each environment directory contains the same set of files: main.tf, variables.tf, outputs.tf, and instances.tf. These files override or specialize the root configuration for the specific environment.

## Kubernetes Directory

The k8s/ directory contains all Kubernetes manifests used to deploy applications and services on the cluster. These files are organized numerically to ensure proper deployment order, with lower-numbered files typically containing foundational resources that other resources depend on.

The 00-namespaces.yaml file defines the Kubernetes namespaces used in the project. These namespaces provide logical separation for different components and workloads, including moshi-demo for the demonstration application and nvidia-gpu-operator for the GPU infrastructure.

The 01-gpu-operator.yaml file deploys the NVIDIA GPU Operator, which is responsible for managing GPU resources in the cluster. This operator handles driver installation, device plugin configuration, and GPU resource discovery.

The 02-mig-config.yaml and 02-timeslicing-config.yaml files contain the configurations for switching between MIG and Time Slicing modes. These ConfigMaps modify how the GPU operator handles GPU allocation and are the key files for demonstrating the differences between the two approaches.

The 03-prometheus.yaml file deploys Prometheus for metrics collection. This includes the Prometheus server, service monitors, and configuration for scraping GPU and Kubernetes metrics.

The 04-grafana.yaml file deploys Grafana along with the datasources configuration. The Grafana deployment includes pre-configured dashboards for monitoring GPU utilization and comparing MIG versus Time Slicing behavior.

The 05-moshi-setup.yaml file contains the initial setup for the Moshi demonstration application. This includes ConfigMaps and initial resource definitions needed by the application.

The 06-moshi-timeslicing.yaml and 07-moshi-mig.yaml files contain the deployment configurations for running the Moshi application in Time Slicing and MIG modes respectively. These files demonstrate how the same application behaves differently under each GPU allocation strategy.

Additional files in the k8s/ directory handle ingress routing, the landing page, monitoring ingress, and the visualization workload. These files extend the basic demonstration with additional features and access methods.

The dashboards/ subdirectory contains Grafana dashboard JSON definitions. The mig-vs-timeslicing.json file provides a pre-configured dashboard specifically designed for comparing GPU behavior between MIG and Time Slicing modes.

## GitHub Workflows

The .github/workflows/ directory contains GitHub Actions workflow definitions that automate various aspects of the project. These workflows handle validation, deployment, and destruction of resources.

The deploy.yml workflow handles automatic deployment of the infrastructure. It can be triggered manually or on push to specific branches, and it runs both Terraform apply and kubectl apply to provision all resources.

The validate.yml workflow runs on pull requests to. validate the configuration This includes Terraform initialization and validation, plan generation, and Kubernetes YAML validation to catch errors before they reach production.

The destroy.yml workflow provides a safe mechanism for destroying the infrastructure. It requires manual confirmation and destroys resources in the correct order to avoid orphaned resources.

## Documentation

The docs/ directory contains all project documentation organized by topic. This directory follows a structured organization to make it easy to find relevant documentation.

The architecture/ subdirectory contains architecture-related documentation, including this file. It covers project overview, structure, components, and the technical details of MIG and Time Slicing modes.

The guides/ and references/ subdirectories are available for additional documentation as needed. The project follows a pattern where these directories can be created as documentation needs evolve.

The docs/AGENT_GUIDE.md file provides specific guidance for AI agents working on documentation tasks, explaining what the documentation agent can and cannot do.

The docs/QUICKSTART.md file provides a quick start guide for getting oriented with the project and understanding the available tools and workflows.

## Tasks Directory

The tasks/ directory contains task definitions for tracking work items related to the project. These tasks are typically created by documentation agents or project maintainers to track progress on various initiatives.

The tasks/README.md file provides an overview of how tasks are organized and managed in this directory.

Scripts in the tasks/ directory, such as deploy-moshi-vis.sh, automate specific demonstration tasks and provide examples of common operations.

## OpenCode Configuration

The .opencode/ directory contains configuration for the OpenCode AI assistant platform. This includes skill definitions, agent configurations, and platform-specific settings.

The skills/ subdirectory contains skill definitions for specialized tasks. The terraform-scaleway skill provides guidance for working with Scaleway infrastructure. The grafana-dashboard skill helps with creating and managing Grafana dashboards. The github-workflow-manager skill assists with GitHub Actions workflow management.

The agents/ subdirectory contains agent-specific configurations and instructions. The platform-engineer.md file provides context for the platform engineer agent that manages GPU infrastructure.

## ArgoCD Configuration

The argo-app/ directory contains ArgoCD application definitions for GitOps-based deployment. This directory is optional and is used if ArgoCD is integrated into the deployment pipeline.

The applications.yaml file defines the ArgoCD applications that sync from the repository to the Kubernetes cluster, enabling declarative continuous deployment.

## File Naming Conventions

The project follows specific naming conventions to maintain consistency and make it easy to locate files. Terraform files use snake_case, such as instance_type and gpu_instance. Kubernetes resources use kebab-case, such as migstrategy-config and gpu-operator-deployment. Kubernetes manifest files use number prefixes to indicate deployment order, such as 00-namespaces.yaml and 01-gpu-operator.yaml.

## Related Documentation

For more detailed information about specific topics, refer to these additional documents:

The README.md file contains the primary user documentation and quick reference guide.

The AGENTS.md file contains comprehensive guidelines for AI agents working in the repository.

The docs/architecture/OVERVIEW.md document provides a higher-level introduction to the project and its goals.

The docs/architecture/COMPONENTS.md document provides detailed information about individual components and their interactions.

The docs/architecture/MODES.md document explains the technical differences between MIG and Time Slicing modes.
