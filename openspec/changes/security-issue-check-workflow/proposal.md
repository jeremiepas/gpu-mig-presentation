## Why

Security vulnerabilities in dependencies and infrastructure code can go unnoticed for long periods. Currently, this project lacks automated security scanning in CI/CD. A security issue check workflow would proactively detect vulnerabilities in Terraform, Kubernetes manifests, and GitHub Actions, creating issues automatically so they don't get forgotten.

## What Changes

- Add new GitHub Actions workflow `.github/workflows/security-check.yml` that runs on schedule and manual trigger
- Integrate security scanning tools: tfsec (Terraform), checkov (Kubernetes YAML), trivy (container images), secret scanning
- Automate GitHub issue creation when vulnerabilities are found with severity levels
- Add security badge to README

## Capabilities

### New Capabilities

- **security-scanning-workflow**: Automated security scanning for Terraform, Kubernetes manifests, and container images with GitHub issue creation for findings

### Modified Capabilities

- None - this is a new capability

## Impact

- New workflow file: `.github/workflows/security-check.yml`
- GitHub Actions secrets required: None (uses public tools)
- Dependencies added: tfsec, checkov, trivy (via Docker or action)
- Affects: CI/CD pipeline, security monitoring