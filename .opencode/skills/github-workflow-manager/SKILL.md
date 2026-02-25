---
name: github-workflow-manager
description: Manage GitHub Actions workflow runs and logs
license: MPL-2.0
compatibility: opencode
metadata:
  audience: developers
  workflow: ci-cd
---
# GitHub Workflow Manager Skill

This skill provides specialized instructions and workflows for managing GitHub Actions workflow runs.

## Overview

GitHub Actions workflow runs can be monitored and managed effectively using the GitHub CLI (gh). This skill covers common tasks such as listing workflow runs, viewing run details, examining logs, and troubleshooting failed runs.

## Prerequisites

1. GitHub CLI (gh) installed and configured
2. Proper repository permissions
3. Authenticated with GitHub CLI using `gh auth login`

## Basic Commands

### List Recent Workflow Runs

```bash
gh run list
```

This command shows:
- Status (completed/failed/success)
- Workflow name
- Branch
- Trigger event
- Run ID
- Duration
- Timestamp

### View Details of a Specific Run

```bash
gh run view <run-id>
```

Replace `<run-id>` with the actual run ID from the list command. This shows:
- Run status
- Event that triggered the run
- Branch name
- Commit SHA and message
- Jobs and their statuses

### View Logs for a Run

```bash
# View all logs
gh run view <run-id> --log

# View only failed job logs
gh run view <run-id> --log-failed
```

## Advanced Usage

### Filter Workflow Runs

You can filter workflow runs by workflow name, branch, and status:

```bash
# List runs for a specific workflow
gh run list --workflow=deploy.yml

# List runs on a specific branch
gh run list --branch=main

# List only failed runs
gh run list --status=failure
```

### Re-run Workflows

```bash
# Re-run a specific workflow run
gh run rerun <run-id>

# Re-run failed jobs only
gh run rerun <run-id> --failed
```

### Watch Workflow Progress

```bash
# Watch a run in real-time
gh run watch <run-id>
```

## Common Troubleshooting Patterns

### Failed Deployments

When a deployment fails:
1. Identify the run ID with `gh run list`
2. View details with `gh run view <run-id>`
3. Examine logs with `gh run view <run-id> --log-failed`

Look for:
- Container build errors
- Kubernetes deployment issues
- Terraform apply failures
- Missing secrets or permissions

### Timeout Issues

For workflows that timeout:
1. Check if services are properly responding
2. Examine network connectivity issues
3. Review resource constraints in configuration files

## Best Practices

1. Regularly monitor workflow runs to catch failures early
2. Use descriptive names for workflows and jobs
3. Include meaningful commit messages that reflect changes
4. Set up notifications for critical workflow failures
5. Archive important workflow logs for audit purposes

## Useful Combinations

### Quick Status Check
```bash
gh run list --limit=5 --status=failure
```

### Monitor a Running Workflow
```bash
watch -n 30 'gh run list --limit=1'
```

### Export Workflow Information
```bash
gh run list --export > workflow-runs.json
```

This skill enables efficient management and monitoring of GitHub Actions workflows, helping maintain a reliable CI/CD pipeline.