# GitHub Workflow Manager

This directory contains the GitHub Workflow Manager skill for the platform engineer agent.

## About this skill

This skill provides specialized instructions and workflows for managing GitHub Actions workflow runs, including:
- Listing and filtering workflow runs
- Viewing run details and logs
- Re-running failed workflows
- Monitoring workflow progress

## Manual usage

Until the skill loading issue is resolved, you can use these commands directly:

### List Recent Workflow Runs
```bash
gh run list
```

### View Details of a Specific Run
```bash
gh run view <run-id>
```

### View Logs for a Run
```bash
# View all logs
gh run view <run-id> --log

# View only failed job logs
gh run view <run-id> --log-failed
```

### Filter Workflow Runs
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

## Troubleshooting

If you encounter issues with the GitHub CLI:
1. Ensure you're authenticated: `gh auth login`
2. Verify repository permissions
3. Check that GitHub CLI is installed: `gh --version`