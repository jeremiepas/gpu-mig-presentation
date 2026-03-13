# Implementation Plan: Multi-Environment Terraform & Kubernetes Restructure

## Overview

This implementation plan restructures the GPU MIG presentation infrastructure to support three distinct environments (prod, pre-prod, homelab) with clear separation between common and environment-specific Kubernetes configurations. The implementation introduces Terraform modules for shared infrastructure code, reorganizes Kubernetes manifests, configures ArgoCD for GitOps, and updates automation tooling.

## Tasks

- [x] 1. Create Terraform module structure and base modules
  - [x] 1.1 Create scaleway-instance module
    - Create terraform/modules/scaleway-instance/ directory structure
    - Write main.tf with instance and IP resources
    - Write variables.tf with environment, instance_type, instance_name, zone, tags, ssh_public_key, root_volume_size
    - Write outputs.tf exposing instance_ip and instance_id
    - Write versions.tf with Scaleway provider constraints (~> 2.40)
    - Create cloud-init.yaml.tpl template for user data
    - _Requirements: 1.1, 1.4, 1.5, 1.6_
  
  - [x] 1.2 Write property test for scaleway-instance module
    - **Property 1: Module Interface Contract**
    - **Validates: Requirements 1.4, 1.5, 1.6**
  
  - [x] 1.3 Create k3s-cluster module
    - Create terraform/modules/k3s-cluster/ directory structure
    - Write main.tf with null_resource for K3s installation via remote-exec
    - Write variables.tf with instance_ip, ssh_private_key, environment, k3s_version
    - Write outputs.tf exposing cluster_ready trigger and kubeconfig
    - Create templates/k3s-install.sh.tpl for K3s installation script
    - _Requirements: 1.2, 1.4, 1.5, 10.1, 10.4_
  
  - [x] 1.4 Write property test for k3s-cluster module
    - **Property 1: Module Interface Contract**
    - **Validates: Requirements 1.4, 1.5, 1.6**
  
  - [x] 1.5 Create argocd-bootstrap module
    - Create terraform/modules/argocd-bootstrap/ directory structure
    - Write main.tf with null_resource for ArgoCD installation via remote-exec
    - Write variables.tf with instance_ip, ssh_private_key, environment, git_repo_url, k3s_ready
    - Write outputs.tf exposing argocd_url and initial_password
    - Create templates/argocd-install.sh.tpl for ArgoCD installation script
    - _Requirements: 1.3, 1.4, 1.5, 11.1, 11.2, 11.3, 11.4_
  
  - [x] 1.6 Write property test for argocd-bootstrap module
    - **Property 1: Module Interface Contract**
    - **Validates: Requirements 1.4, 1.5, 1.6**

- [x] 2. Checkpoint - Validate Terraform modules
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Create environment configurations for prod and pre-prod
  - [x] 3.1 Create prod environment configuration
    - Create terraform/environments/prod/ directory
    - Write main.tf with S3 backend config (key: prod/terraform.tfstate)
    - Invoke scaleway-instance module with prod-specific variables
    - Invoke k3s-cluster module with instance_ip from scaleway-instance
    - Invoke argocd-bootstrap module with cluster_ready dependency
    - Write variables.tf declaring all required variables
    - Write outputs.tf exposing instance_ip, kubeconfig, argocd_url
    - Write versions.tf with Terraform >= 1.0 and Scaleway provider
    - Create terraform.tfvars.example template with prod values
    - _Requirements: 2.1, 2.4, 2.7, 5.1, 5.4, 5.5_
  
  - [x] 3.2 Write property test for environment state isolation
    - **Property 2: Environment State Isolation**
    - **Validates: Requirements 5.1, 5.5**
  
  - [x] 3.3 Create pre-prod environment configuration
    - Create terraform/environments/pre-prod/ directory
    - Write main.tf with S3 backend config (key: pre-prod/terraform.tfstate)
    - Invoke scaleway-instance module with pre-prod-specific variables
    - Invoke k3s-cluster module with instance_ip from scaleway-instance
    - Invoke argocd-bootstrap module with cluster_ready dependency
    - Write variables.tf declaring all required variables
    - Write outputs.tf exposing instance_ip, kubeconfig, argocd_url
    - Write versions.tf with Terraform >= 1.0 and Scaleway provider
    - Create terraform.tfvars.example template with pre-prod values
    - _Requirements: 2.2, 2.4, 2.7, 5.1, 5.4, 5.5_
  
  - [x] 3.4 Write property test for environment resource isolation
    - **Property 3: Environment Resource Isolation**
    - **Validates: Requirements 5.3, 5.4**

- [x] 4. Create homelab environment configuration
  - [x] 4.1 Create homelab environment configuration
    - Create terraform/environments/homelab/ directory
    - Write main.tf with local backend config (no S3)
    - Do NOT invoke scaleway-instance module
    - Invoke k3s-cluster module with homelab_ip variable (existing server)
    - Invoke argocd-bootstrap module with cluster_ready dependency
    - Write variables.tf declaring homelab_ip, git_repo_url, k3s_version
    - Write outputs.tf exposing kubeconfig and argocd_url
    - Write versions.tf with Terraform >= 1.0 and null provider
    - Create terraform.tfvars.example template with homelab IP placeholder
    - _Requirements: 2.3, 2.5, 2.6, 2.8_
  
  - [x] 4.2 Write unit tests for homelab configuration
    - Test that scaleway-instance module is NOT invoked
    - Test that k3s-cluster uses provided homelab_ip
    - Test that local backend is configured
    - _Requirements: 2.5, 2.6_

- [x] 5. Checkpoint - Validate environment configurations
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Reorganize Kubernetes manifests into common directory
  - [x] 6.1 Create common manifests directory structure
    - Create k8s/common/ directory
    - Move 00-namespaces.yaml to k8s/common/
    - Move 00-nvidia-runtimeclass.yaml to k8s/common/ (if exists)
    - Move 01-gpu-operator.yaml to k8s/common/
    - Move 03-prometheus.yaml to k8s/common/
    - Move 04-grafana.yaml to k8s/common/
    - Move 04-grafana-datasources.yaml to k8s/common/ (if exists)
    - Move 05-moshi-setup.yaml to k8s/common/
    - Move 09-node-exporter.yaml to k8s/common/ (if exists)
    - Move 12-kube-state-metrics.yaml to k8s/common/ (if exists)
    - Move 14-dcgm-exporter.yaml to k8s/common/ (if exists)
    - _Requirements: 3.1, 3.3, 8.1, 13.1, 13.2, 13.3, 13.4, 13.5_
  
  - [x] 6.2 Write property test for manifest classification
    - **Property 4: Manifest Classification Completeness**
    - **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5**

- [x] 7. Create environment-specific Kubernetes manifests
  - [x] 7.1 Create prod environment manifests
    - Create k8s/environments/prod/ directory
    - Copy or create 02-mig-config.yaml with MIG strategy configuration
    - Copy or create 06-moshi-mig.yaml (if exists) or 07-moshi-mig.yaml
    - Copy or create 07-moshi-inference-mig.yaml or 10-moshi-inference-mig.yaml (if exists)
    - Create ingress-prod.yaml with production domain and TLS
    - Create resource-quotas.yaml with production resource limits
    - Create network-policies.yaml with production network restrictions
    - _Requirements: 3.2, 3.4, 8.2, 8.3, 8.4, 12.1, 15.5_
  
  - [x] 7.2 Create pre-prod environment manifests
    - Create k8s/environments/pre-prod/ directory
    - Copy or create 02-timeslicing-config.yaml with 4 replicas
    - Copy or create 06-moshi-timeslicing.yaml
    - Copy or create 07-moshi-inference-timeslicing.yaml or 09-moshi-inference-timeslicing.yaml (if exists)
    - Create ingress-preprod.yaml with pre-prod domain
    - Create resource-quotas.yaml with pre-prod resource limits
    - _Requirements: 3.2, 3.5, 8.2, 8.3, 8.4, 12.2_
  
  - [x] 7.3 Create homelab environment manifests
    - Create k8s/environments/homelab/ directory
    - Copy or create 02-timeslicing-config.yaml with 2 replicas
    - Copy or create 06-moshi-timeslicing.yaml
    - Create local-storage.yaml with local storage class
    - Create ingress-homelab.yaml with .montech.mylab domain suffix for all services:
      - argocd.montech.mylab (ArgoCD UI)
      - grafana.montech.mylab (Grafana dashboard)
      - moshi.montech.mylab (Moshi application)
      - prometheus.montech.mylab (Prometheus)
    - Create reduced-resources.yaml with lower resource requests
    - _Requirements: 3.2, 3.6, 8.2, 8.3, 8.4, 12.3_
  
  - [x] 7.4 Write unit tests for environment-specific manifests
    - Test prod uses MIG configuration
    - Test pre-prod uses Time Slicing with 4 replicas
    - Test homelab uses Time Slicing with 2 replicas
    - _Requirements: 3.4, 3.5, 3.6, 12.1, 12.2, 12.3_

- [x] 8. Checkpoint - Validate Kubernetes manifests
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Create ArgoCD common and environment-specific applications
  - [x] 9.1 Create ArgoCD common manifests
    - Create k8s/argocd/common/ directory
    - Create 00-namespace.yaml for argocd namespace
    - Create 01-argocd-install.yaml referencing stable ArgoCD release
    - Create 04-argocd-appproject.yaml with gpu-demo project and RBAC
    - _Requirements: 4.1, 11.2, 15.6_
  
  - [x] 9.2 Create prod ArgoCD applications
    - Create k8s/argocd/environments/prod/ directory
    - Create applications.yaml with two Application resources:
      - common-infrastructure app pointing to k8s/common/
      - prod-specific app pointing to k8s/environments/prod/
    - Configure automated sync and self-heal policies
    - Add environment=prod labels
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6_
  
  - [x] 9.3 Create pre-prod ArgoCD applications
    - Create k8s/argocd/environments/pre-prod/ directory
    - Create applications.yaml with two Application resources:
      - common-infrastructure app pointing to k8s/common/
      - pre-prod-specific app pointing to k8s/environments/pre-prod/
    - Configure automated sync and self-heal policies
    - Add environment=pre-prod labels
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6_
  
  - [x] 9.4 Create homelab ArgoCD applications
    - Create k8s/argocd/environments/homelab/ directory
    - Create applications.yaml with two Application resources:
      - common-infrastructure app pointing to k8s/common/
      - homelab-specific app pointing to k8s/environments/homelab/ (includes ingress-homelab.yaml with .montech.mylab domains)
    - Configure automated sync and self-heal policies
    - Add environment=homelab labels
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6_
  
  - [x] 9.5 Write property test for ArgoCD application structure
    - **Property 6: ArgoCD Application Structure**
    - **Validates: Requirements 4.3, 4.4, 4.5**

- [x] 10. Update Makefile for multi-environment support
  - [x] 10.1 Update Makefile targets
    - Update init target to accept ENV variable and use terraform/environments/$(ENV)
    - Update validate target to use terraform/environments/$(ENV)
    - Update deploy-scaleway target to use terraform/environments/$(ENV)
    - Update deploy-local target to use terraform/environments/homelab
    - Update destroy target to use terraform/environments/$(ENV)
    - Update clean target for new directory structure
    - Add deploy-prod convenience target (ENV=prod)
    - Add deploy-preprod convenience target (ENV=pre-prod)
    - Add deploy-homelab convenience target (ENV=homelab)
    - Update status target to use ENV variable
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6_
  
  - [x] 10.2 Write unit tests for Makefile targets
    - Test init with ENV=prod, pre-prod, homelab
    - Test validate with each environment
    - Test that deploy-scaleway is NOT used for homelab
    - _Requirements: 16.1, 16.2, 16.3, 16.4_

- [x] 11. Update CI/CD workflows
  - [x] 11.1 Update validation workflow
    - Update .github/workflows/validate.yml to validate all three environments
    - Add Terraform validate for terraform/environments/prod
    - Add Terraform validate for terraform/environments/pre-prod
    - Add Terraform validate for terraform/environments/homelab
    - Add Kubernetes manifest validation for all YAML files
    - _Requirements: 20.1, 20.2_
  
  - [x] 11.2 Update deployment workflows
    - Update .github/workflows/deploy.yml to support environment selection
    - Add workflow_dispatch input for environment (prod, pre-prod)
    - Update terraform apply to use selected environment path
    - Add separate workflow for homelab deployment (if needed)
    - _Requirements: 20.3, 20.4, 20.6_
  
  - [x] 11.3 Update destroy workflow
    - Update .github/workflows/destroy.yml to support environment selection
    - Add workflow_dispatch input for environment (prod, pre-prod, homelab)
    - Update terraform destroy to use selected environment path
    - _Requirements: 20.5, 20.6_
  
  - [x] 11.4 Write integration tests for CI/CD workflows
    - Test validation workflow with act
    - Test deployment workflow with act (dry-run)
    - _Requirements: 20.1, 20.2_

- [x] 12. Checkpoint - Validate automation updates
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 13. Create migration scripts and documentation
  - [x] 13.1 Create backup script
    - Create scripts/backup-current-state.sh
    - Backup Terraform state files from dev, prod, local environments
    - Backup all k8s/*.yaml manifests
    - Backup ArgoCD applications from cluster
    - Store backups in backups/ directory with timestamp
    - _Requirements: 17.1, 17.2_
  
  - [x] 13.2 Create manifest classification script
    - Create scripts/classify-manifests.sh
    - Implement classification logic based on file patterns
    - Move common manifests to k8s/common/
    - Move environment-specific manifests to k8s/environments/{env}/
    - Generate classification report
    - _Requirements: 17.3, 8.1, 8.2, 8.3, 8.4, 8.5_
  
  - [x] 13.3 Create rollback script
    - Create scripts/rollback-migration.sh
    - Restore Terraform state from backups
    - Restore Kubernetes manifests from backups
    - Restore ArgoCD applications from backups
    - _Requirements: 17.4_
  
  - [x] 13.4 Write unit tests for migration scripts
    - Test backup script creates all expected files
    - Test classification script correctly categorizes manifests
    - Test rollback script restores previous state
    - _Requirements: 17.1, 17.2, 17.3, 17.4_

- [ ] 14. Create comprehensive documentation
  - [x] 14.1 Update README.md
    - Add overview of multi-environment structure
    - Add quick start guide for each environment
    - Add environment comparison table
    - Add deployment commands for each environment
    - _Requirements: 19.1_
  
  - [x] 14.2 Update AGENTS.md
    - Update project structure section with new paths
    - Update environment table with prod, pre-prod, homelab
    - Update Makefile targets documentation
    - Update Terraform commands for new structure
    - _Requirements: 19.2_
  
  - [x] 14.3 Create MIGRATION.md
    - Document migration phases (backup, restructure, validate, cleanup)
    - Provide step-by-step migration instructions
    - Document rollback procedures
    - Add troubleshooting section
    - _Requirements: 19.3_
  
  - [x] 14.4 Create ARCHITECTURE.md
    - Add architecture diagrams (Terraform, Kubernetes, ArgoCD layers)
    - Document component interactions
    - Describe module dependencies
    - Document ArgoCD sync workflow
    - _Requirements: 19.4_
  
  - [x] 14.5 Add inline documentation
    - Add comments to all Terraform module files
    - Add comments to all Kubernetes manifest files
    - Document variable purposes and constraints
    - Document output usage
    - _Requirements: 19.5, 19.6_

- [x] 15. Checkpoint - Review documentation
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 16. Validation and integration testing
  - [x] 16.1 Validate Terraform modules
    - Run terraform validate on scaleway-instance module
    - Run terraform validate on k3s-cluster module
    - Run terraform validate on argocd-bootstrap module
    - Run terraform fmt -check -recursive on all Terraform files
    - _Requirements: 18.1, 6.1_
  
  - [x] 16.2 Validate Kubernetes manifests
    - Run kubectl apply --dry-run=client on all common manifests
    - Run kubectl apply --dry-run=client on all prod manifests
    - Run kubectl apply --dry-run=client on all pre-prod manifests
    - Run kubectl apply --dry-run=client on all homelab manifests
    - Run PyYAML validation on all YAML files
    - _Requirements: 18.2, 18.3_
  
  - [x] 16.3 Run integration tests for homelab
    - Deploy homelab environment from scratch
    - Verify K3s cluster is accessible
    - Verify ArgoCD applications sync successfully
    - Verify GPU resources are available
    - Verify monitoring stack is operational
    - _Requirements: 18.4, 18.5, 18.6_
  
  - [x] 16.4 Run integration tests for pre-prod
    - Deploy pre-prod environment from scratch
    - Verify K3s cluster is accessible
    - Verify ArgoCD applications sync successfully
    - Verify GPU resources are available with Time Slicing (4 replicas)
    - Verify monitoring stack is operational
    - _Requirements: 18.4, 18.5, 18.6_
  
  - [x] 16.5 Run integration tests for prod
    - Deploy prod environment from scratch (or migrate existing)
    - Verify K3s cluster is accessible
    - Verify ArgoCD applications sync successfully
    - Verify GPU resources are available with MIG
    - Verify monitoring stack is operational
    - _Requirements: 18.4, 18.5, 18.6_
  
  - [x] 16.6 Write property test for deployment idempotency
    - **Property 7: Deployment Idempotency**
    - **Validates: Requirements 7.1**

- [ ] 17. Security hardening and validation
  - [x] 17.1 Implement secrets management
    - Update .gitignore to exclude terraform.tfvars, credentials*.env, ssh_key*
    - Verify no credentials in Git history
    - Document environment variable usage for Scaleway credentials
    - Create example credential files with placeholders
    - _Requirements: 15.1, 15.2_
  
  - [x] 17.2 Configure state encryption
    - Enable S3 backend encryption for prod state
    - Enable S3 backend encryption for pre-prod state
    - Verify state files are encrypted at rest
    - _Requirements: 9.5, 15.3_
  
  - [x] 17.3 Implement network policies for prod
    - Apply network-policies.yaml in prod environment
    - Test pod-to-pod traffic restrictions
    - Verify monitoring namespace can access metrics
    - _Requirements: 15.5_
  
  - [x] 17.4 Write property test for credential exclusion
    - **Property 10: Credential Exclusion**
    - **Validates: Requirements 15.1**

- [ ] 18. Final checkpoint and cleanup
  - [x] 18.1 Run full validation suite
    - Execute all Terraform validates
    - Execute all Kubernetes manifest validations
    - Execute all property tests
    - Execute all integration tests
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5, 18.6_
  
  - [x] 18.2 Archive old structure
    - Create tarball of old terraform/environments/{dev,local,gpu-worker}
    - Create tarball of old k8s/*.yaml files
    - Store archives in backups/ directory
    - _Requirements: 17.6_
  
  - [x] 18.3 Clean up old directories
    - Remove terraform/environments/dev (after verification)
    - Remove terraform/environments/local (after verification)
    - Remove terraform/environments/gpu-worker (if exists, after verification)
    - Remove old k8s/*.yaml files that have been moved
    - _Requirements: 17.6_
  
  - [x] 18.4 Final verification
    - Verify only prod, pre-prod, homelab environments exist
    - Verify all manifests are in common or environments directories
    - Verify all Makefile targets work correctly
    - Verify all documentation is up to date
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2_

- [x] 19. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- Property tests validate universal correctness properties from the design
- Unit tests validate specific examples and edge cases
- Integration tests verify end-to-end workflows across all environments
- The homelab environment does NOT provision infrastructure - it only configures K3s and ArgoCD on an existing server
- Migration should proceed in order: homelab → pre-prod → prod to minimize risk
- All Terraform modules must be validated before environment configurations
- All Kubernetes manifests must be validated before deployment
- Security hardening should be completed before production deployment
