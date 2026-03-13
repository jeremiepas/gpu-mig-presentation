# Requirements Document

## Introduction

This document specifies the requirements for restructuring the GPU MIG presentation infrastructure to support three distinct environments (prod, pre-prod, homelab) with clear separation between common and environment-specific Kubernetes configurations. The system introduces Terraform modules for shared infrastructure code, environment-specific variable overrides, and ArgoCD applications that dynamically load configurations based on the target environment.

## Glossary

- **System**: The multi-environment Terraform and Kubernetes infrastructure
- **Terraform_Module**: Reusable Terraform code component (scaleway-instance, k3s-cluster, argocd-bootstrap)
- **Environment**: One of three deployment targets (prod, pre-prod, homelab)
- **Common_Manifest**: Kubernetes YAML file deployed across all environments
- **Environment_Manifest**: Kubernetes YAML file specific to one environment
- **ArgoCD_Application**: ArgoCD resource that manages deployment of Kubernetes manifests
- **State_Backend**: S3-compatible storage for Terraform state files
- **GPU_Mode**: GPU sharing strategy (MIG or Time Slicing)
- **Homelab**: Local GPU server environment that uses existing infrastructure

## Requirements

### Requirement 1: Terraform Module Structure

**User Story:** As an infrastructure engineer, I want reusable Terraform modules, so that I can eliminate code duplication and ensure consistency across environments.

#### Acceptance Criteria

1. THE System SHALL provide a scaleway-instance module that provisions Scaleway GPU instances
2. THE System SHALL provide a k3s-cluster module that installs K3s on target instances
3. THE System SHALL provide an argocd-bootstrap module that deploys ArgoCD to K3s clusters
4. WHEN a module is invoked, THE System SHALL accept environment-specific variables as inputs
5. WHEN a module completes execution, THE System SHALL expose outputs for downstream consumption
6. THE System SHALL define all module variables with type, description, and default values where appropriate

### Requirement 2: Environment Configuration

**User Story:** As an infrastructure engineer, I want separate environment configurations, so that I can manage prod, pre-prod, and homelab independently.

#### Acceptance Criteria

1. THE System SHALL provide a prod environment configuration in terraform/environments/prod/
2. THE System SHALL provide a pre-prod environment configuration in terraform/environments/pre-prod/
3. THE System SHALL provide a homelab environment configuration in terraform/environments/homelab/
4. WHEN deploying prod or pre-prod, THE System SHALL invoke the scaleway-instance module to provision infrastructure
5. WHEN deploying homelab, THE System SHALL NOT invoke the scaleway-instance module
6. WHEN deploying homelab, THE System SHALL configure K3s and ArgoCD on an existing server specified by IP address
7. THE System SHALL use unique S3 backend state keys for prod and pre-prod environments
8. THE System SHALL use local backend for homelab environment state

### Requirement 3: Kubernetes Manifest Organization

**User Story:** As a platform engineer, I want common manifests separated from environment-specific manifests, so that I can share base configurations while allowing environment customization.

#### Acceptance Criteria

1. THE System SHALL store common manifests in k8s/common/ directory
2. THE System SHALL store environment-specific manifests in k8s/environments/{env}/ directories
3. THE System SHALL include namespaces, GPU operator base, Prometheus, Grafana, and monitoring components in common manifests
4. WHEN deploying prod, THE System SHALL use MIG configuration as the GPU mode
5. WHEN deploying pre-prod, THE System SHALL use Time Slicing with 4 replicas as the GPU mode
6. WHEN deploying homelab, THE System SHALL use Time Slicing with 2 replicas as the GPU mode
7. THE System SHALL apply common manifests before environment-specific manifests

### Requirement 4: ArgoCD Application Management

**User Story:** As a platform engineer, I want ArgoCD to automatically deploy the correct manifests for each environment, so that I can achieve GitOps-based infrastructure management.

#### Acceptance Criteria

1. THE System SHALL provide ArgoCD common installation manifests in k8s/argocd/common/
2. THE System SHALL provide environment-specific ArgoCD applications in k8s/argocd/environments/{env}/
3. WHEN an ArgoCD application is deployed, THE System SHALL create an application for common-infrastructure that references k8s/common/
4. WHEN an ArgoCD application is deployed, THE System SHALL create an application for environment-specific manifests that references k8s/environments/{env}/
5. THE System SHALL configure ArgoCD applications with automated sync and self-heal policies
6. WHEN Git repository changes are detected, THE System SHALL automatically sync affected applications

### Requirement 5: Environment Isolation

**User Story:** As an infrastructure engineer, I want complete isolation between environments, so that changes in one environment do not affect others.

#### Acceptance Criteria

1. WHEN two different environments are deployed, THE System SHALL maintain separate Terraform state files
2. WHEN two different environments are deployed, THE System SHALL provision separate Kubernetes clusters
3. WHEN two different environments are deployed, THE System SHALL ensure no shared resources exist between them
4. THE System SHALL use environment-specific tags for all cloud resources
5. THE System SHALL use environment-specific backend state keys in format {env}/terraform.tfstate

### Requirement 6: Module Reusability

**User Story:** As an infrastructure engineer, I want modules that work across all environments, so that I can maintain a single codebase for infrastructure patterns.

#### Acceptance Criteria

1. WHEN a Terraform module is invoked by any environment, THE System SHALL execute successfully with appropriate variables
2. THE System SHALL NOT include hard-coded environment-specific values in module code
3. THE System SHALL parameterize all environment-specific settings through module variables
4. WHEN a module is updated, THE System SHALL apply changes consistently across all environments that use it

### Requirement 7: Deployment Idempotency

**User Story:** As an infrastructure engineer, I want idempotent deployments, so that running the same deployment multiple times produces consistent results.

#### Acceptance Criteria

1. WHEN terraform apply is executed twice on the same environment without changes, THE System SHALL report no changes on the second execution
2. WHEN ArgoCD syncs an application that is already synced, THE System SHALL maintain the current state without modifications
3. WHEN kubectl apply is executed on manifests that are already applied, THE System SHALL not create duplicate resources

### Requirement 8: Manifest Classification

**User Story:** As a platform engineer, I want automated manifest classification, so that I can ensure all manifests are correctly categorized as common or environment-specific.

#### Acceptance Criteria

1. THE System SHALL classify manifests containing namespaces, GPU operator base, and monitoring stack as common
2. THE System SHALL classify manifests containing GPU mode configuration as environment-specific
3. THE System SHALL classify manifests containing ingress with environment-specific domains as environment-specific
4. THE System SHALL classify manifests containing workload deployments with GPU requirements as environment-specific
5. WHEN a manifest is classified, THE System SHALL place it in exactly one category

### Requirement 9: State Management

**User Story:** As an infrastructure engineer, I want reliable state management, so that I can track infrastructure changes and enable team collaboration.

#### Acceptance Criteria

1. WHEN Terraform state is modified, THE System SHALL store it in the configured backend
2. WHEN multiple users attempt to modify the same environment simultaneously, THE System SHALL use state locking to prevent conflicts
3. WHEN state locking prevents an operation, THE System SHALL return an error message with lock ID and timestamp
4. THE System SHALL enable state versioning for rollback capability
5. THE System SHALL encrypt Terraform state at rest in S3 backend

### Requirement 10: K3s Cluster Provisioning

**User Story:** As an infrastructure engineer, I want automated K3s installation, so that I can provision Kubernetes clusters without manual intervention.

#### Acceptance Criteria

1. WHEN infrastructure is provisioned, THE System SHALL install K3s using cloud-init during instance boot
2. WHEN K3s installation completes, THE System SHALL expose a kubeconfig output for cluster access
3. WHEN K3s installation fails, THE System SHALL timeout after 300 seconds and report an error
4. THE System SHALL install K3s version v1.28.5+k3s1 or later
5. THE System SHALL configure K3s with embedded etcd for high availability

### Requirement 11: ArgoCD Bootstrap

**User Story:** As a platform engineer, I want automated ArgoCD installation, so that I can enable GitOps workflows immediately after cluster provisioning.

#### Acceptance Criteria

1. WHEN K3s cluster is ready, THE System SHALL install ArgoCD in the argocd namespace
2. WHEN ArgoCD is installed, THE System SHALL apply common ArgoCD manifests from k8s/argocd/common/
3. WHEN ArgoCD is installed, THE System SHALL apply environment-specific application manifests from k8s/argocd/environments/{env}/
4. THE System SHALL install ArgoCD version v2.9+ from stable release
5. WHEN ArgoCD installation completes, THE System SHALL expose ArgoCD URL and initial credentials as outputs

### Requirement 12: GPU Configuration

**User Story:** As a platform engineer, I want environment-specific GPU configurations, so that I can test different GPU sharing strategies across environments.

#### Acceptance Criteria

1. WHEN prod environment is deployed, THE System SHALL configure GPU operator with MIG strategy
2. WHEN pre-prod environment is deployed, THE System SHALL configure GPU operator with Time Slicing and 4 replicas
3. WHEN homelab environment is deployed, THE System SHALL configure GPU operator with Time Slicing and 2 replicas
4. THE System SHALL deploy GPU operator version v23.9.0 or later
5. WHEN GPU configuration is applied, THE System SHALL make GPU resources available to workloads within 5 minutes

### Requirement 13: Monitoring Stack

**User Story:** As a platform engineer, I want a monitoring stack deployed across all environments, so that I can observe GPU utilization and cluster health.

#### Acceptance Criteria

1. THE System SHALL deploy Prometheus v2.45+ to the monitoring namespace
2. THE System SHALL deploy Grafana v10.0+ to the monitoring namespace
3. THE System SHALL deploy DCGM Exporter for GPU metrics collection
4. THE System SHALL deploy Node Exporter for node metrics collection
5. THE System SHALL deploy Kube State Metrics for Kubernetes object metrics
6. THE System SHALL configure Grafana with Prometheus as a datasource
7. THE System SHALL expose Grafana on port 30300 and Prometheus on port 30090

### Requirement 14: Error Handling and Recovery

**User Story:** As an infrastructure engineer, I want clear error messages and recovery procedures, so that I can troubleshoot and resolve deployment failures.

#### Acceptance Criteria

1. WHEN Terraform state lock conflict occurs, THE System SHALL return an error with lock ID and timestamp
2. WHEN ArgoCD application sync fails, THE System SHALL mark the application as OutOfSync or Degraded
3. WHEN K3s cluster is not ready within timeout, THE System SHALL return a timeout error
4. WHEN GPU operator installation fails, THE System SHALL report pod status and logs
5. THE System SHALL provide recovery commands in error messages where applicable

### Requirement 15: Security Controls

**User Story:** As a security engineer, I want security controls for credentials and access, so that I can protect sensitive infrastructure and data.

#### Acceptance Criteria

1. THE System SHALL NOT store Scaleway credentials in Git repository
2. THE System SHALL read Scaleway credentials from environment variables
3. THE System SHALL encrypt Terraform state files at rest in S3 backend
4. THE System SHALL use SSH key authentication for instance access
5. THE System SHALL apply Kubernetes NetworkPolicies to restrict pod-to-pod traffic in prod environment
6. THE System SHALL configure RBAC for ArgoCD applications using AppProjects

### Requirement 16: Makefile Automation

**User Story:** As a developer, I want Makefile targets for common operations, so that I can deploy and manage environments with simple commands.

#### Acceptance Criteria

1. WHEN make init ENV={env} is executed, THE System SHALL initialize Terraform for the specified environment
2. WHEN make validate ENV={env} is executed, THE System SHALL validate Terraform configuration for the specified environment
3. WHEN make deploy-scaleway ENV={env} is executed, THE System SHALL deploy the specified environment to Scaleway
4. WHEN make deploy-homelab is executed, THE System SHALL configure K3s and ArgoCD on the existing homelab server
5. WHEN make destroy ENV={env} is executed, THE System SHALL destroy all resources in the specified environment
6. WHEN make status ENV={env} is executed, THE System SHALL display pod status for the specified environment

### Requirement 17: Migration Support

**User Story:** As an infrastructure engineer, I want a migration strategy from the current structure, so that I can safely transition to the new multi-environment architecture.

#### Acceptance Criteria

1. THE System SHALL provide a backup procedure for current Terraform state files
2. THE System SHALL provide a backup procedure for current Kubernetes manifests
3. THE System SHALL provide a manifest classification script to categorize existing manifests
4. THE System SHALL provide a rollback procedure to restore previous state if migration fails
5. THE System SHALL migrate environments in order: homelab, pre-prod, prod
6. WHEN migration is complete, THE System SHALL archive old directory structure

### Requirement 18: Validation and Testing

**User Story:** As a quality engineer, I want validation and testing procedures, so that I can verify the system works correctly across all environments.

#### Acceptance Criteria

1. THE System SHALL validate all Terraform modules using terraform validate
2. THE System SHALL validate all Kubernetes manifests using kubectl apply --dry-run=client
3. THE System SHALL validate all YAML files using PyYAML parser
4. WHEN integration tests are run, THE System SHALL deploy each environment and verify ArgoCD sync
5. WHEN integration tests are run, THE System SHALL verify GPU resources are available in each environment
6. WHEN integration tests are run, THE System SHALL verify monitoring stack is operational

### Requirement 19: Documentation

**User Story:** As a developer, I want comprehensive documentation, so that I can understand and use the multi-environment infrastructure.

#### Acceptance Criteria

1. THE System SHALL provide README.md with overview and quick start guide
2. THE System SHALL provide AGENTS.md with AI agent guidelines for the new structure
3. THE System SHALL provide MIGRATION.md with step-by-step migration instructions
4. THE System SHALL provide ARCHITECTURE.md with design diagrams and component descriptions
5. THE System SHALL include inline comments in all Terraform modules
6. THE System SHALL include inline comments in all Kubernetes manifests

### Requirement 20: CI/CD Integration

**User Story:** As a DevOps engineer, I want CI/CD workflows for automated validation and deployment, so that I can ensure code quality and enable continuous delivery.

#### Acceptance Criteria

1. WHEN a pull request is created, THE System SHALL run Terraform validate on all environments
2. WHEN a pull request is created, THE System SHALL run Kubernetes manifest validation
3. THE System SHALL provide a manual workflow for deploying to prod environment
4. THE System SHALL provide a manual workflow for deploying to pre-prod environment
5. THE System SHALL provide a manual workflow for destroying environments
6. WHEN CI/CD workflows execute, THE System SHALL use GitHub Secrets for Scaleway credentials
