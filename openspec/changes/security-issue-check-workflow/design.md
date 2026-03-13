## Context

This project manages GPU infrastructure on Scaleway using Terraform and Kubernetes. Security vulnerabilities in infrastructure-as-code can lead to misconfigurations being deployed to production. Currently, there is no automated security scanning - vulnerabilities can go unnoticed until they're exploited.

The project uses GitHub Actions for CI/CD. A new security scanning workflow will integrate with the existing CI/CD system to detect and track security issues.

## Goals / Non-Goals

**Goals:**
- Automatically scan Terraform files for security misconfigurations using tfsec
- Scan Kubernetes YAML manifests using checkov
- Scan container images used in the project using trivy
- Create GitHub issues automatically when vulnerabilities are found
- Run scans on schedule (weekly) and manual trigger

**Non-Goals:**
- Block deployments based on scan results (informational only initially)
- Scan local development machines
- Integrate with external security platforms (Snyk, Dependabot already handled)
- Real-time alerting (issues are sufficient for tracking)

## Decisions

1. **Tool Selection**: Use aquasecurity/tfsec for Terraform, bridgecrew/checkov for Kubernetes, aquasecurity/trivy for container images. These are industry-standard, well-maintained tools with GitHub Actions integration.

2. **GitHub Issue Creation**: Use the peter-evans/create-issue-from-json-file action or GitHub CLI to create issues. Issues allow tracking, assignment, and discussion - better than just commenting on PRs.

3. **Severity Handling**: Categorize findings by severity (CRITICAL, HIGH, MEDIUM, LOW). Only create issues for HIGH and CRITICAL by default to avoid noise. Include lower severities in the workflow summary.

4. **Workflow Trigger**: Run weekly on schedule (Sunday midnight) plus manual workflow_dispatch for on-demand scans. Don't run on every PR to avoid rate limiting and reduce CI costs.

5. **No Auto-blocking**: The workflow will report findings but not fail builds. This allows gradual adoption. Teams can enable blocking once they address initial findings.

## Risks / Trade-offs

- **[Risk]** Scanner tools may produce false positives → **Mitigation**: Document how to suppress false positives using inline annotations (e.g., # tfsec:ignore:...)
- **[Risk]** GitHub API rate limits for issue creation → **Mitigation**: Batch findings into single issues per tool, use GitHub CLI which handles auth
- **[Risk]** Workflow runtime costs → **Mitigation**: Run weekly instead of on every commit, use caching for tool installations
- **[Risk]** New dependencies = new attack surface → **Mitigation**: Use pinned versions, verify tool signatures

## Migration Plan

1. Add new workflow file `.github/workflows/security-check.yml`
2. Test workflow manually to verify tool installation and scanning
3. Review initial findings and suppress false positives
4. Verify issue creation works correctly
5. Document the workflow in project README
6. Optionally: Enable auto-blocking after initial stabilization

## Open Questions

- Should we also scan GitHub Actions workflows themselves for security issues?
- Should findings be posted to a specific security project board?
- Do we want email notifications for new security issues?