#!/usr/bin/env python3
"""
Simple test runner for CI/CD workflow tests (no pytest required).
"""

import yaml
import sys
from pathlib import Path


def test_validation_workflow():
    """Test the validate.yml workflow configuration."""
    print("Testing validation workflow...")
    
    workflow_path = Path(".github/workflows/validate.yml")
    assert workflow_path.exists(), "validate.yml does not exist"
    
    with open(workflow_path) as f:
        workflow = yaml.safe_load(f)
    
    # Test triggers on pull request (YAML parses 'on:' as True)
    on_key = True if True in workflow else "on"
    assert "pull_request" in workflow[on_key], "Missing pull_request trigger"
    assert "main" in workflow[on_key]["pull_request"]["branches"], "Missing main branch"
    
    # Test validates all environments
    terraform_job = workflow["jobs"]["terraform-validate"]
    assert "strategy" in terraform_job, "Missing strategy"
    assert "matrix" in terraform_job["strategy"], "Missing matrix"
    
    environments = terraform_job["strategy"]["matrix"]["environment"]
    assert "prod" in environments, "Missing prod environment"
    assert "pre-prod" in environments, "Missing pre-prod environment"
    assert "homelab" in environments, "Missing homelab environment"
    
    # Test YAML validation job exists
    assert "yaml-validate" in workflow["jobs"], "Missing yaml-validate job"
    
    print("✓ Validation workflow tests passed")
    
    # Test validates all environments
    terraform_job = workflow["jobs"]["terraform-validate"]
    assert "strategy" in terraform_job, "Missing strategy"
    assert "matrix" in terraform_job["strategy"], "Missing matrix"
    
    environments = terraform_job["strategy"]["matrix"]["environment"]
    assert "prod" in environments, "Missing prod environment"
    assert "pre-prod" in environments, "Missing pre-prod environment"
    assert "homelab" in environments, "Missing homelab environment"
    
    # Test YAML validation job exists
    assert "yaml-validate" in workflow["jobs"], "Missing yaml-validate job"
    
    print("✓ Validation workflow tests passed")


def test_deployment_workflow():
    """Test the deploy.yml workflow configuration."""
    print("Testing deployment workflow...")
    
    workflow_path = Path(".github/workflows/deploy.yml")
    assert workflow_path.exists(), "deploy.yml does not exist"
    
    with open(workflow_path) as f:
        workflow = yaml.safe_load(f)
    
    # Test manual trigger only (YAML parses 'on:' as True)
    on_key = True if True in workflow else "on"
    assert "workflow_dispatch" in workflow[on_key], "Missing workflow_dispatch"
    
    # Test environment input supports prod and pre-prod
    inputs = workflow[on_key]["workflow_dispatch"]["inputs"]
    assert "environment" in inputs, "Missing environment input"
    
    env_input = inputs["environment"]
    assert env_input["type"] == "choice", "Environment input should be choice"
    assert "prod" in env_input["options"], "Missing prod option"
    assert "pre-prod" in env_input["options"], "Missing pre-prod option"
    assert env_input["default"] == "prod", "Default should be prod"
    
    # Test uses GitHub Secrets
    env_vars = workflow["env"]
    assert "${{ secrets.SCW_ACCESS_KEY }}" in str(env_vars), "Missing SCW_ACCESS_KEY secret"
    assert "${{ secrets.SCW_SECRET_KEY }}" in str(env_vars), "Missing SCW_SECRET_KEY secret"
    
    # Test deploys common manifests
    deploy_job = workflow["jobs"]["deploy-mig"]
    common_step = next(
        s for s in deploy_job["steps"]
        if "Common Manifests" in s["name"]
    )
    assert "k8s/common/" in common_step["run"], "Missing k8s/common/ path"
    
    # Test deploys environment-specific manifests
    env_step = next(
        s for s in deploy_job["steps"]
        if "Environment-Specific" in s["name"]
    )
    assert "k8s/environments/" in env_step["run"], "Missing k8s/environments/ path"
    
    print("✓ Deployment workflow tests passed")


def test_destroy_workflow():
    """Test the destroy.yml workflow configuration."""
    print("Testing destroy workflow...")
    
    workflow_path = Path(".github/workflows/destroy.yml")
    assert workflow_path.exists(), "destroy.yml does not exist"
    
    with open(workflow_path) as f:
        workflow = yaml.safe_load(f)
    
    # Test manual trigger only (YAML parses 'on:' as True)
    on_key = True if True in workflow else "on"
    assert "workflow_dispatch" in workflow[on_key], "Missing workflow_dispatch"
    
    # Test environment input supports all environments
    inputs = workflow[on_key]["workflow_dispatch"]["inputs"]
    assert "environment" in inputs, "Missing environment input"
    
    env_input = inputs["environment"]
    assert "prod" in env_input["options"], "Missing prod option"
    assert "pre-prod" in env_input["options"], "Missing pre-prod option"
    assert "homelab" in env_input["options"], "Missing homelab option"
    
    # Test requires confirmation
    assert "confirm" in inputs, "Missing confirm input"
    assert inputs["confirm"]["required"] is True, "Confirm should be required"
    
    print("✓ Destroy workflow tests passed")


def test_homelab_deployment_workflow():
    """Test the deploy-homelab.yml workflow configuration."""
    print("Testing homelab deployment workflow...")
    
    workflow_path = Path(".github/workflows/deploy-homelab.yml")
    assert workflow_path.exists(), "deploy-homelab.yml does not exist"
    
    with open(workflow_path) as f:
        workflow = yaml.safe_load(f)
    
    # Test manual trigger only (YAML parses 'on:' as True)
    on_key = True if True in workflow else "on"
    assert "workflow_dispatch" in workflow[on_key], "Missing workflow_dispatch"
    
    # Test uses homelab IP secret
    env_vars = workflow["env"]
    assert "${{ secrets.HOMELAB_IP }}" in str(env_vars), "Missing HOMELAB_IP secret"
    
    # Test uses homelab environment path
    job = workflow["jobs"]["deploy-homelab"]
    init_step = next(
        s for s in job["steps"]
        if s["name"] == "Terraform Init"
    )
    assert "terraform/environments/homelab" in init_step["working-directory"], \
        "Missing homelab environment path"
    
    # Test deploys common and homelab manifests
    common_step = next(
        s for s in job["steps"]
        if "Common Manifests" in s["name"]
    )
    assert "k8s/common/" in common_step["run"], "Missing k8s/common/ path"
    
    homelab_step = next(
        s for s in job["steps"]
        if "Homelab-Specific" in s["name"]
    )
    assert "k8s/environments/homelab/" in homelab_step["run"], \
        "Missing k8s/environments/homelab/ path"
    
    print("✓ Homelab deployment workflow tests passed")


def test_workflow_integration():
    """Integration tests for workflow interactions."""
    print("Testing workflow integration...")
    
    workflow_files = [
        ".github/workflows/validate.yml",
        ".github/workflows/deploy.yml",
        ".github/workflows/destroy.yml",
        ".github/workflows/deploy-homelab.yml",
    ]
    
    # Test all workflows use same Terraform version
    terraform_versions = set()
    for workflow_file in workflow_files:
        with open(workflow_file) as f:
            workflow = yaml.safe_load(f)
            for job in workflow["jobs"].values():
                for step in job["steps"]:
                    if step.get("uses", "").startswith("hashicorp/setup-terraform"):
                        version = step.get("with", {}).get("terraform_version")
                        if version:
                            terraform_versions.add(version)
    
    assert len(terraform_versions) == 1, "Workflows use different Terraform versions"
    assert "1.7.0" in terraform_versions, "Terraform version should be 1.7.0"
    
    # Test all workflows reference new k8s structure
    for workflow_file in [".github/workflows/deploy.yml", ".github/workflows/deploy-homelab.yml"]:
        with open(workflow_file) as f:
            content = f.read()
            assert "k8s/common/" in content, f"{workflow_file} missing k8s/common/"
            assert "k8s/environments/" in content, f"{workflow_file} missing k8s/environments/"
            assert "k8s/argocd/common/" in content, f"{workflow_file} missing k8s/argocd/common/"
            assert "k8s/argocd/environments/" in content, \
                f"{workflow_file} missing k8s/argocd/environments/"
    
    print("✓ Workflow integration tests passed")


def main():
    """Run all tests."""
    print("=" * 60)
    print("Running CI/CD Workflow Tests")
    print("=" * 60)
    print()
    
    tests = [
        test_validation_workflow,
        test_deployment_workflow,
        test_destroy_workflow,
        test_homelab_deployment_workflow,
        test_workflow_integration,
    ]
    
    failed = []
    for test in tests:
        try:
            test()
        except AssertionError as e:
            print(f"✗ {test.__name__} failed: {e}")
            failed.append(test.__name__)
        except Exception as e:
            print(f"✗ {test.__name__} error: {e}")
            failed.append(test.__name__)
        print()
    
    print("=" * 60)
    if failed:
        print(f"FAILED: {len(failed)} test(s) failed")
        for name in failed:
            print(f"  - {name}")
        sys.exit(1)
    else:
        print("SUCCESS: All tests passed!")
        sys.exit(0)


if __name__ == "__main__":
    main()
