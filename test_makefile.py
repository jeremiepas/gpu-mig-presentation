#!/usr/bin/env python3
"""
Unit tests for Makefile targets.

Tests verify that Makefile targets correctly handle multi-environment support
and enforce constraints like preventing deploy-scaleway for homelab.

**Validates: Requirements 16.1, 16.2, 16.3, 16.4**
"""

import subprocess
import unittest
from pathlib import Path


class TestMakefileTargets(unittest.TestCase):
    """Test Makefile targets for multi-environment support."""

    def setUp(self):
        """Set up test environment."""
        self.makefile_path = Path("Makefile")
        self.assertTrue(self.makefile_path.exists(), "Makefile must exist")

    def test_init_with_prod_environment(self):
        """Test init target with ENV=prod."""
        # Run make init with dry-run to check command construction
        result = subprocess.run(
            ["make", "-n", "init", "ENV=prod"],
            capture_output=True,
            text=True
        )
        
        # Verify the command uses ENV_NAME variable and terraform init
        self.assertIn("terraform/environments/$ENV_NAME", result.stdout)
        self.assertIn("init", result.stdout)
        self.assertIn("ENV_NAME=${ENV:-prod}", result.stdout)

    def test_init_with_preprod_environment(self):
        """Test init target with ENV=pre-prod."""
        result = subprocess.run(
            ["make", "-n", "init", "ENV=pre-prod"],
            capture_output=True,
            text=True
        )
        
        # Verify the command uses ENV_NAME variable
        self.assertIn("terraform/environments/$ENV_NAME", result.stdout)
        self.assertIn("init", result.stdout)

    def test_init_with_homelab_environment(self):
        """Test init target with ENV=homelab."""
        result = subprocess.run(
            ["make", "-n", "init", "ENV=homelab"],
            capture_output=True,
            text=True
        )
        
        # Verify the command uses ENV_NAME variable
        self.assertIn("terraform/environments/$ENV_NAME", result.stdout)
        self.assertIn("init", result.stdout)

    def test_init_defaults_to_prod(self):
        """Test init target defaults to prod when ENV is not specified."""
        result = subprocess.run(
            ["make", "-n", "init"],
            capture_output=True,
            text=True
        )
        
        # Verify the command defaults to prod environment via ${ENV:-prod}
        self.assertIn("ENV_NAME=${ENV:-prod}", result.stdout)
        self.assertIn("terraform/environments/$ENV_NAME", result.stdout)

    def test_validate_with_prod_environment(self):
        """Test validate target with ENV=prod."""
        result = subprocess.run(
            ["make", "-n", "validate", "ENV=prod"],
            capture_output=True,
            text=True
        )
        
        # Verify the command uses ENV_NAME variable
        self.assertIn("terraform/environments/$ENV_NAME", result.stdout)
        self.assertIn("validate", result.stdout)

    def test_validate_with_preprod_environment(self):
        """Test validate target with ENV=pre-prod."""
        result = subprocess.run(
            ["make", "-n", "validate", "ENV=pre-prod"],
            capture_output=True,
            text=True
        )
        
        # Verify the command uses ENV_NAME variable
        self.assertIn("terraform/environments/$ENV_NAME", result.stdout)
        self.assertIn("validate", result.stdout)

    def test_validate_with_homelab_environment(self):
        """Test validate target with ENV=homelab."""
        result = subprocess.run(
            ["make", "-n", "validate", "ENV=homelab"],
            capture_output=True,
            text=True
        )
        
        # Verify the command uses ENV_NAME variable
        self.assertIn("terraform/environments/$ENV_NAME", result.stdout)
        self.assertIn("validate", result.stdout)

    def test_deploy_scaleway_rejects_homelab(self):
        """Test that deploy-scaleway is NOT used for homelab environment."""
        result = subprocess.run(
            ["make", "-n", "deploy-scaleway", "ENV=homelab"],
            capture_output=True,
            text=True
        )
        
        # Verify error message is present
        self.assertIn("Error", result.stdout)
        self.assertIn("homelab", result.stdout)
        self.assertIn("deploy-homelab", result.stdout)

    def test_deploy_scaleway_accepts_prod(self):
        """Test that deploy-scaleway works with ENV=prod."""
        result = subprocess.run(
            ["make", "-n", "deploy-scaleway", "ENV=prod"],
            capture_output=True,
            text=True
        )
        
        # Verify the command uses ENV_NAME variable and includes terraform commands
        self.assertIn("terraform/environments/$ENV_NAME", result.stdout)
        self.assertIn("terraform -chdir=terraform/environments/$ENV_NAME init", result.stdout)
        self.assertIn("terraform -chdir=terraform/environments/$ENV_NAME apply", result.stdout)

    def test_deploy_scaleway_accepts_preprod(self):
        """Test that deploy-scaleway works with ENV=pre-prod."""
        result = subprocess.run(
            ["make", "-n", "deploy-scaleway", "ENV=pre-prod"],
            capture_output=True,
            text=True
        )
        
        # Verify the command uses ENV_NAME variable and includes terraform commands
        self.assertIn("terraform/environments/$ENV_NAME", result.stdout)
        self.assertIn("terraform -chdir=terraform/environments/$ENV_NAME init", result.stdout)
        self.assertIn("terraform -chdir=terraform/environments/$ENV_NAME apply", result.stdout)

    def test_deploy_prod_convenience_target(self):
        """Test deploy-prod convenience target."""
        result = subprocess.run(
            ["make", "-n", "deploy-prod"],
            capture_output=True,
            text=True
        )
        
        # Verify it uses prod environment
        self.assertIn("production", result.stdout.lower())
        self.assertIn("terraform/environments/$ENV_NAME", result.stdout)

    def test_deploy_preprod_convenience_target(self):
        """Test deploy-preprod convenience target."""
        result = subprocess.run(
            ["make", "-n", "deploy-preprod"],
            capture_output=True,
            text=True
        )
        
        # Verify it uses pre-prod environment
        self.assertIn("pre-prod", result.stdout.lower())
        self.assertIn("terraform/environments/$ENV_NAME", result.stdout)

    def test_deploy_homelab_convenience_target(self):
        """Test deploy-homelab convenience target."""
        result = subprocess.run(
            ["make", "-n", "deploy-homelab"],
            capture_output=True,
            text=True
        )
        
        # Verify it uses homelab environment
        self.assertIn("homelab", result.stdout.lower())
        self.assertIn("terraform/environments/homelab", result.stdout)

    def test_destroy_with_prod_environment(self):
        """Test destroy target with ENV=prod."""
        result = subprocess.run(
            ["make", "-n", "destroy", "ENV=prod"],
            capture_output=True,
            text=True
        )
        
        # Verify the command uses ENV_NAME variable
        self.assertIn("terraform/environments/$ENV_NAME", result.stdout)
        self.assertIn("destroy", result.stdout)

    def test_destroy_with_homelab_environment(self):
        """Test destroy target with ENV=homelab."""
        result = subprocess.run(
            ["make", "-n", "destroy", "ENV=homelab"],
            capture_output=True,
            text=True
        )
        
        # Verify the command uses ENV_NAME variable
        self.assertIn("terraform/environments/$ENV_NAME", result.stdout)
        self.assertIn("destroy", result.stdout)

    def test_status_with_env_variable(self):
        """Test status target uses ENV variable."""
        result = subprocess.run(
            ["make", "-n", "status", "ENV=prod"],
            capture_output=True,
            text=True
        )
        
        # Verify status command is present
        self.assertIn("kubectl get pods", result.stdout)
        self.assertIn("prod", result.stdout.lower())

    def test_clean_target_includes_all_environments(self):
        """Test clean target removes state files for all environments."""
        result = subprocess.run(
            ["make", "-n", "clean"],
            capture_output=True,
            text=True
        )
        
        # Verify clean includes all three environments
        self.assertIn("terraform/environments/prod", result.stdout)
        self.assertIn("terraform/environments/pre-prod", result.stdout)
        self.assertIn("terraform/environments/homelab", result.stdout)

    def test_makefile_phony_targets_declared(self):
        """Test that all main targets are declared as .PHONY."""
        with open(self.makefile_path, 'r') as f:
            content = f.read()
        
        # Check for .PHONY declaration
        self.assertIn(".PHONY:", content)
        
        # Check that key targets are in PHONY
        phony_line = [line for line in content.split('\n') if '.PHONY:' in line][0]
        self.assertIn("init", phony_line)
        self.assertIn("validate", phony_line)
        self.assertIn("deploy-scaleway", phony_line)
        self.assertIn("destroy", phony_line)
        self.assertIn("clean", phony_line)
        self.assertIn("status", phony_line)


class TestMakefileEnvironmentIsolation(unittest.TestCase):
    """Test that Makefile enforces environment isolation."""

    def test_no_hardcoded_dev_references(self):
        """Test that Makefile does not contain hardcoded 'dev' environment references."""
        with open("Makefile", 'r') as f:
            content = f.read()
        
        # Check that old dev references are removed
        self.assertNotIn("terraform/environments/dev", content)

    def test_no_hardcoded_local_references(self):
        """Test that Makefile does not contain hardcoded 'local' environment references."""
        with open("Makefile", 'r') as f:
            content = f.read()
        
        # Check that old local references are removed (except in legacy targets)
        lines = content.split('\n')
        for line in lines:
            # Skip comments and legacy deploy-local targets
            if line.strip().startswith('#') or 'deploy-local:' in line or 'deploy-local-simple:' in line:
                continue
            # Main targets should not reference old 'local' path
            if 'terraform/environments/local' in line and 'clean:' not in line:
                self.fail(f"Found hardcoded 'local' reference in: {line}")


if __name__ == '__main__':
    unittest.main()
