## ADDED Requirements

### Requirement: Security scanning workflow executes on schedule
The security scanning workflow SHALL run automatically on a weekly schedule and be triggerable manually via GitHub Actions workflow_dispatch.

#### Scenario: Weekly scheduled scan
- **WHEN** the scheduled time arrives (Sunday midnight UTC)
- **THEN** the workflow executes all security scanners

#### Scenario: Manual scan trigger
- **WHEN** user triggers workflow via workflow_dispatch
- **THEN** the workflow executes all security scanners with the same behavior as scheduled runs

### Requirement: Terraform files are scanned for vulnerabilities
The system SHALL scan all Terraform files in the repository using tfsec and report any security findings.

#### Scenario: No Terraform vulnerabilities found
- **WHEN** tfsec scan completes with no findings
- **THEN** workflow reports success with no issues created

#### Scenario: Terraform vulnerabilities detected
- **WHEN** tfsec finds security issues with severity HIGH or CRITICAL
- **THEN** a GitHub issue is created with the vulnerability details including file, line number, and description

### Requirement: Kubernetes manifests are scanned for misconfigurations
The system SHALL scan all Kubernetes YAML manifests using checkov and report any security findings.

#### Scenario: No Kubernetes misconfigurations found
- **WHEN** checkov scan completes with no findings
- **THEN** workflow reports success with no issues created

#### Scenario: Kubernetes misconfigurations detected
- **WHEN** checkov finds security issues with severity HIGH or CRITICAL
- **THEN** a GitHub issue is created with the misconfiguration details

### Requirement: Container images are scanned for vulnerabilities
The system SHALL scan container images referenced in the project using trivy and report any CVE findings.

#### Scenario: No container vulnerabilities found
- **WHEN** trivy scan completes with no findings
- **THEN** workflow reports success with no issues created

#### Scenario: Container vulnerabilities detected
- **WHEN** trivy finds vulnerabilities with severity HIGH or CRITICAL
- **THEN** a GitHub issue is created with vulnerability details including CVE ID, severity, and affected image

### Requirement: Security findings are tracked via GitHub Issues
The system SHALL create GitHub issues for security findings to enable tracking, assignment, and remediation workflow.

#### Scenario: New security finding
- **WHEN** a scanner detects a new HIGH or CRITICAL issue
- **THEN** a GitHub issue is created with title indicating severity and tool, body containing finding details, and label "security"

#### Scenario: Duplicate finding exists
- **WHEN** a scanner detects an issue that already has an open issue
- **THEN** no new issue is created (prevent duplicate tracking)

### Requirement: Scan results are summarized in workflow output
The system SHALL provide a clear summary of all scan results in the workflow run output.

#### Scenario: Workflow completes
- **WHEN** all scanners finish execution
- **THEN** workflow outputs a summary table showing: tool name, findings count by severity, issue creation status