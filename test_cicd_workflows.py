"""
Integration tests for CI/CD workflows.

These tests validate the structure and configuration of GitHub Actions workflows
for the multi-environment Terraform & Kubernetes infrastructure.

Requirements validated:
- 20.1: Terraform validate on all environments for PRs
- 20.2: Kubernetes manifest validation for PRs
- 20.3: Manual workflow for deploying to prod environment
- 20.4: Manual workflow for deploying to pre-prod environment
- 20.5: Manual workflow for destroying environments
- 20.6: GitHub Secrets usage for Scaleway credentials
"""

import yaml
import os
import pytest
from pathlib import Path


class TestValidationWorkflow:
    """Test the validate.yml workflow configuration."""

    @pytest.fixture
    def workflow(self):
        """Load the validation workflow."""
        workflow_path = Path(".github/workflows/validate.yml")
        with open(workflow_path) as f:
            return yaml.safe_load(f)

    def test_workflow_exists(self):
        """Test that validate.yml exists."""
        assert Path(".github/workflows/validate.yml").exists()

    def test_triggers_on_pull_request(self, workflow):
        """Test that workflow triggers on pull requests to main."""
        assert "pull_request" in workflow["on"]
        assert "main" in workflow["on"]["pull_request"]["branches"]

    def test_validates_all_environments(self, workflow):
        """Test that workflow validates prod, pre-prod, and homelab.
        
        Validates: Requirements 20.1
        """
        terraform_job = workflow["jobs"]["terraform-validate"]
        assert "strategy" in terraform_job
        assert "matrix" in terraform_job["strategy"]
        
        environments = terraform_job["strategy"]["matrix"]["environment"]
        assert "prod" in environments
        assert "pre-prod" in environments
        assert "homelab" in environments

    def test_terraform_init_uses_matrix_env(self, workflow):
        """Test that terraform init uses matrix environment variable."""
        terraform_job = workflow["jobs"]["terraform-validate"]
        init_step = next(
            s for s in terraform_job["steps"] 
            if s["name"] == "Terraform Init"
        )
        assert "${{ matrix.environment }}" in init_step["working-directory"]

    def test_terraform_validate_step_exists(self, workflow):
        """Test that terraform validate step exists."""
        terraform_job = workflow["jobs"]["terraform-validate"]
        validate_steps = [
            s for s in terraform_job["steps"] 
            if s["name"] == "Terraform Validate"
        ]
        assert len(validate_steps) == 1

    def test_yaml_validation_job_exists(self, workflow):
        """Test that YAML validation job exists.
        
        Validates: Requirements 20.2
        """
        assert "yaml-validate" in workflow["jobs"]
        yaml_job = workflow["jobs"]["yaml-validate"]
        
        # Check for YAML validation step
        validate_steps = [
            s for s in yaml_job["steps"]
            if "Validate YAML" in s["name"]
        ]
        assert len(validate_steps) == 1

    def test_aws_credentials_conditional_for_homelab(self, workflow):
        """Test that AWS credentials are not configured for homelab."""
        terraform_job = workflow["jobs"]["terraform-validate"]
        aws_creds_step = next(
            s for s in terraform_job["steps"]
            if "Configure AWS credentials" in s["name"]
        )
        assert "if" in aws_creds_step
        assert "homelab" in aws_creds_step["if"]

    def test_terraform_plan_skipped_for_homelab(self, workflow):
        """Test that terraform plan is skipped for homelab (no infrastructure)."""
        terraform_job = workflow["jobs"]["terraform-validate"]
        plan_step = next(
            s for s in terraform_job["steps"]
            if s["name"] == "Terraform Plan"
        )
        assert "if" in plan_step
        assert "homelab" in plan_step["if"]


class TestDeploymentWorkflow:
    """Test the deploy.yml workflow configuration."""

    @pytest.fixture
    def workflow(self):
        """Load the deployment workflow."""
        workflow_path = Path(".github/workflows/deploy.yml")
        with open(workflow_path) as f:
            return yaml.safe_load(f)

    def test_workflow_exists(self):
        """Test that deploy.yml exists."""
        assert Path(".github/workflows/deploy.yml").exists()

    def test_manual_trigger_only(self, workflow):
        """Test that workflow is manual trigger only (workflow_dispatch)."""
        assert "workflow_dispatch" in workflow["on"]

    def test_environment_input_supports_prod_and_preprod(self, workflow):
        """Test that environment input supports prod and pre-prod.
        
        Validates: Requirements 20.3, 20.4
        """
        inputs = workflow["on"]["workflow_dispatch"]["inputs"]
        assert "environment" in inputs
        
        env_input = inputs["environment"]
        assert env_input["type"] == "choice"
        assert "prod" in env_input["options"]
        assert "pre-prod" in env_input["options"]

    def test_default_environment_is_prod(self, workflow):
        """Test that default environment is prod."""
        inputs = workflow["on"]["workflow_dispatch"]["inputs"]
        env_input = inputs["environment"]
        assert env_input["default"] == "prod"

    def test_uses_github_secrets(self, workflow):
        """Test that workflow uses GitHub Secrets for credentials.
        
        Validates: Requirements 20.6
        """
        env_vars = workflow["env"]
        assert "${{ secrets.SCW_ACCESS_KEY }}" in str(env_vars)
        assert "${{ secrets.SCW_SECRET_KEY }}" in str(env_vars)
        assert "${{ secrets.SCW_PROJECT_ID }}" in str(env_vars)

    def test_terraform_apply_uses_selected_environment(self, workflow):
        """Test that terraform apply uses selected environment path."""
        terraform_job = workflow["jobs"]["terraform"]
        apply_step = next(
            s for s in terraform_job["steps"]
            if s["name"] == "Terraform Apply"
        )
        assert "${{ github.event.inputs.environment" in apply_step["working-directory"]

    def test_deploys_common_manifests(self, workflow):
        """Test that workflow deploys common manifests."""
        deploy_job = workflow["jobs"]["deploy-mig"]
        common_step = next(
            s for s in deploy_job["steps"]
            if "Common Manifests" in s["name"]
        )
        assert "k8s/common/" in common_step["run"]

    def test_deploys_environment_specific_manifests(self, workflow):
        """Test that workflow deploys environment-specific manifests."""
        deploy_job = workflow["jobs"]["deploy-mig"]
        env_step = next(
            s for s in deploy_job["steps"]
            if "Environment-Specific" in s["name"]
        )
        assert "k8s/environments/" in env_step["run"]
        assert "${{ github.event.inputs.environment" in env_step["run"]

    def test_deploys_argocd_with_environment_path(self, workflow):
        """Test that ArgoCD deployment uses environment-specific path."""
        argocd_job = workflow["jobs"]["deploy-argocd"]
        deploy_step = next(
            s for s in argocd_job["steps"]
            if s["name"] == "Deploy Argo CD"
        )
        assert "k8s/argocd/common/" in deploy_step["run"]
        assert "k8s/argocd/environments/" in deploy_step["run"]
        assert "${{ github.event.inputs.environment" in deploy_step["run"]


class TestDestroyWorkflow:
    """Test the destroy.yml workflow configuration."""

    @pytest.fixture
    def workflow(self):
        """Load the destroy workflow."""
        workflow_path = Path(".github/workflows/destroy.yml")
        with open(workflow_path) as f:
            return yaml.safe_load(f)

    def test_workflow_exists(self):
        """Test that destroy.yml exists."""
        assert Path(".github/workflows/destroy.yml").exists()

    def test_manual_trigger_only(self, workflow):
        """Test that workflow is manual trigger only."""
        assert "workflow_dispatch" in workflow["on"]

    def test_environment_input_supports_all_environments(self, workflow):
        """Test that environment input supports prod, pre-prod, and homelab.
        
        Validates: Requirements 20.5
        """
        inputs = workflow["on"]["workflow_dispatch"]["inputs"]
        assert "environment" in inputs
        
        env_input = inputs["environment"]
        assert env_input["type"] == "choice"
        assert "prod" in env_input["options"]
        assert "pre-prod" in env_input["options"]
        assert "homelab" in env_input["options"]

    def test_requires_confirmation(self, workflow):
        """Test that workflow requires confirmation input."""
        inputs = workflow["on"]["workflow_dispatch"]["inputs"]
        assert "confirm" in inputs
        assert inputs["confirm"]["required"] is True

    def test_terraform_destroy_uses_selected_environment(self, workflow):
        """Test that terraform destroy uses selected environment path."""
        destroy_job = workflow["jobs"]["destroy"]
        destroy_step = next(
            s for s in destroy_job["steps"]
            if s["name"] == "Terraform Destroy"
        )
        # Check working directory in init step
        init_step = next(
            s for s in destroy_job["steps"]
            if s["name"] == "Terraform Init"
        )
        assert "${{ github.event.inputs.environment }}" in init_step["working-directory"]

    def test_aws_credentials_conditional_for_homelab(self, workflow):
        """Test that AWS credentials are not configured for homelab."""
        destroy_job = workflow["jobs"]["destroy"]
        aws_creds_step = next(
            s for s in destroy_job["steps"]
            if "Configure AWS credentials" in s["name"]
        )
        assert "if" in aws_creds_step
        assert "homelab" in aws_creds_step["if"]

    def test_uses_github_secrets(self, workflow):
        """Test that workflow uses GitHub Secrets for credentials.
        
        Validates: Requirements 20.6
        """
        env_vars = workflow["env"]
        assert "${{ secrets.SCW_ACCESS_KEY }}" in str(env_vars)
        assert "${{ secrets.SCW_SECRET_KEY }}" in str(env_vars)
        assert "${{ secrets.SCW_PROJECT_ID }}" in str(env_vars)


class TestHomelabDeploymentWorkflow:
    """Test the deploy-homelab.yml workflow configuration."""

    @pytest.fixture
    def workflow(self):
        """Load the homelab deployment workflow."""
        workflow_path = Path(".github/workflows/deploy-homelab.yml")
        with open(workflow_path) as f:
            return yaml.safe_load(f)

    def test_workflow_exists(self):
        """Test that deploy-homelab.yml exists."""
        assert Path(".github/workflows/deploy-homelab.yml").exists()

    def test_manual_trigger_only(self, workflow):
        """Test that workflow is manual trigger only."""
        assert "workflow_dispatch" in workflow["on"]

    def test_uses_homelab_ip_secret(self, workflow):
        """Test that workflow uses HOMELAB_IP secret."""
        env_vars = workflow["env"]
        assert "${{ secrets.HOMELAB_IP }}" in str(env_vars)

    def test_uses_homelab_environment_path(self, workflow):
        """Test that workflow uses homelab environment path."""
        job = workflow["jobs"]["deploy-homelab"]
        init_step = next(
            s for s in job["steps"]
            if s["name"] == "Terraform Init"
        )
        assert "terraform/environments/homelab" in init_step["working-directory"]

    def test_deploys_common_and_homelab_manifests(self, workflow):
        """Test that workflow deploys common and homelab-specific manifests."""
        job = workflow["jobs"]["deploy-homelab"]
        
        common_step = next(
            s for s in job["steps"]
            if "Common Manifests" in s["name"]
        )
        assert "k8s/common/" in common_step["run"]
        
        homelab_step = next(
            s for s in job["steps"]
            if "Homelab-Specific" in s["name"]
        )
        assert "k8s/environments/homelab/" in homelab_step["run"]

    def test_deploys_argocd_for_homelab(self, workflow):
        """Test that workflow deploys ArgoCD for homelab."""
        job = workflow["jobs"]["deploy-homelab"]
        argocd_step = next(
            s for s in job["steps"]
            if s["name"] == "Deploy Argo CD"
        )
        assert "k8s/argocd/common/" in argocd_step["run"]
        assert "k8s/argocd/environments/homelab/" in argocd_step["run"]


class TestWorkflowIntegration:
    """Integration tests for workflow interactions."""

    def test_all_workflows_use_same_terraform_version(self):
        """Test that all workflows use the same Terraform version."""
        workflow_files = [
            ".github/workflows/validate.yml",
            ".github/workflows/deploy.yml",
            ".github/workflows/destroy.yml",
            ".github/workflows/deploy-homelab.yml",
        ]
        
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
        
        # All workflows should use the same version
        assert len(terraform_versions) == 1
        assert "1.7.0" in terraform_versions

    def test_all_workflows_use_consistent_environment_paths(self):
        """Test that all workflows use consistent environment paths."""
        expected_paths = [
            "terraform/environments/prod",
            "terraform/environments/pre-prod",
            "terraform/environments/homelab",
        ]
        
        workflow_files = [
            ".github/workflows/validate.yml",
            ".github/workflows/deploy.yml",
            ".github/workflows/destroy.yml",
            ".github/workflows/deploy-homelab.yml",
        ]
        
        for workflow_file in workflow_files:
            with open(workflow_file) as f:
                content = f.read()
                # At least one expected path should be present
                assert any(path in content for path in expected_paths)

    def test_all_workflows_reference_new_k8s_structure(self):
        """Test that all workflows reference the new k8s directory structure."""
        workflow_files = [
            ".github/workflows/deploy.yml",
            ".github/workflows/deploy-homelab.yml",
        ]
        
        for workflow_file in workflow_files:
            with open(workflow_file) as f:
                content = f.read()
                # Should reference new structure
                assert "k8s/common/" in content
                assert "k8s/environments/" in content
                assert "k8s/argocd/common/" in content
                assert "k8s/argocd/environments/" in content


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
