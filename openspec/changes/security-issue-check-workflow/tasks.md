## 1. Create Security Check Workflow

- [x] 1.1 Create `.github/workflows/security-check.yml` with workflow_dispatch and schedule triggers
- [x] 1.2 Add tfsec action to scan Terraform files
- [x] 1.3 Add checkov action to scan Kubernetes YAML manifests
- [x] 1.4 Add trivy action to scan container images
- [x] 1.5 Configure workflow to run on Ubuntu latest runner

## 2. Implement GitHub Issue Creation

- [x] 2.1 Add GitHub CLI setup to workflow
- [x] 2.2 Create script to parse tfsec results and create issues for HIGH/CRITICAL
- [x] 2.3 Create script to parse checkov results and create issues for HIGH/CRITICAL
- [x] 2.4 Create script to parse trivy results and create issues for HIGH/CRITICAL
- [x] 2.5 Add logic to check for existing issues before creating duplicates
- [x] 2.6 Add "security" label to created issues

## 3. Configure Workflow Behavior

- [x] 3.1 Set up weekly schedule (Sunday midnight UTC)
- [x] 3.2 Configure severity filtering (only HIGH and CRITICAL create issues)
- [x] 3.3 Add workflow summary output showing all scan results
- [x] 3.4 Ensure workflow doesn't fail on findings (informational only)

## 4. Testing and Documentation

- [ ] 4.1 Test workflow manually using workflow_dispatch
- [ ] 4.2 Verify issue creation works correctly
- [ ] 4.3 Review initial findings and add suppression annotations for false positives
- [ ] 4.4 Add security workflow badge to README.md

## 5. Optional Enhancements

- [ ] 5.1 Add GitHub Actions workflow security scanning (if desired)
- [ ] 5.2 Configure project board for security issues (if desired)
- [ ] 5.3 Add email notifications for new security issues (if desired)