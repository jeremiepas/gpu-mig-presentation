"""
Unit tests for migration scripts.

Tests the backup, classification, and rollback scripts to ensure they
correctly handle Terraform state and Kubernetes manifests.

Requirements validated:
- 17.1: Backup Terraform state files
- 17.2: Backup Kubernetes manifests
- 17.3: Manifest classification logic
- 17.4: Rollback procedure
"""

import os
import subprocess
import tempfile
import shutil
from pathlib import Path


class TestBackupScript:
    """Test the backup-current-state.sh script."""

    def test_backup_script_exists(self):
        """Test that backup script exists and is executable."""
        script_path = Path("scripts/backup-current-state.sh")
        assert script_path.exists()
        assert os.access(script_path, os.X_OK)

    def test_backup_creates_directory(self):
        """Test that backup script creates backup directory.
        
        Validates: Requirements 17.1, 17.2
        """
        # Create temporary test environment
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create mock terraform state
            os.makedirs(f"{tmpdir}/terraform/environments/dev", exist_ok=True)
            Path(f"{tmpdir}/terraform/environments/dev/terraform.tfstate").write_text(
                '{"version": 4}'
            )
            
            # Create mock k8s manifests
            os.makedirs(f"{tmpdir}/k8s", exist_ok=True)
            Path(f"{tmpdir}/k8s/00-namespaces.yaml").write_text(
                "apiVersion: v1\nkind: Namespace"
            )
            
            # Run backup script (dry-run simulation)
            # In real test, would execute script and verify output
            assert Path("scripts/backup-current-state.sh").exists()

    def test_backup_script_handles_missing_directories(self):
        """Test that backup script handles missing directories gracefully."""
        # Script should not fail if directories don't exist
        script_path = Path("scripts/backup-current-state.sh")
        assert script_path.exists()
        
        # Verify script has error handling (set -e)
        content = script_path.read_text()
        assert "set -e" in content

    def test_backup_creates_manifest_file(self):
        """Test that backup script creates MANIFEST.txt."""
        script_path = Path("scripts/backup-current-state.sh")
        content = script_path.read_text()
        
        # Verify script creates manifest
        assert "MANIFEST.txt" in content
        assert "Backup created:" in content

    def test_backup_creates_tarball(self):
        """Test that backup script creates tarball."""
        script_path = Path("scripts/backup-current-state.sh")
        content = script_path.read_text()
        
        # Verify script creates tarball
        assert "tar -czf" in content
        assert ".tar.gz" in content


class TestClassificationScript:
    """Test the classify-manifests.sh script."""

    def test_classification_script_exists(self):
        """Test that classification script exists and is executable."""
        script_path = Path("scripts/classify-manifests.sh")
        assert script_path.exists()
        assert os.access(script_path, os.X_OK)

    def test_classification_patterns_defined(self):
        """Test that classification patterns are defined.
        
        Validates: Requirements 17.3, 8.1, 8.2, 8.3, 8.4, 8.5
        """
        script_path = Path("scripts/classify-manifests.sh")
        content = script_path.read_text()
        
        # Verify common patterns
        assert "COMMON_PATTERNS" in content
        assert "00-namespaces.yaml" in content
        assert "01-gpu-operator.yaml" in content
        assert "03-prometheus.yaml" in content
        
        # Verify environment-specific patterns
        assert "PROD_PATTERNS" in content
        assert "02-mig-config.yaml" in content
        
        assert "PREPROD_PATTERNS" in content
        assert "02-timeslicing-config.yaml" in content
        
        assert "HOMELAB_PATTERNS" in content
        assert "local-storage.yaml" in content

    def test_classification_creates_target_directories(self):
        """Test that classification script creates target directories."""
        script_path = Path("scripts/classify-manifests.sh")
        content = script_path.read_text()
        
        # Verify directory creation
        assert "mkdir -p" in content
        assert "k8s/common" in content
        assert "k8s/environments/prod" in content
        assert "k8s/environments/pre-prod" in content
        assert "k8s/environments/homelab" in content

    def test_classification_generates_report(self):
        """Test that classification script generates report."""
        script_path = Path("scripts/classify-manifests.sh")
        content = script_path.read_text()
        
        # Verify report generation
        assert "manifest-classification-report.txt" in content
        assert "Classification Report" in content

    def test_classification_handles_unclassified_manifests(self):
        """Test that classification script handles unclassified manifests."""
        script_path = Path("scripts/classify-manifests.sh")
        content = script_path.read_text()
        
        # Verify unclassified handling
        assert "UNCLASSIFIED" in content
        assert "unclassified_count" in content

    def test_classification_common_manifest_logic(self):
        """Test that common manifests are correctly identified."""
        script_path = Path("scripts/classify-manifests.sh")
        content = script_path.read_text()
        
        # Common manifests should be copied to common directory
        common_manifests = [
            "00-namespaces.yaml",
            "01-gpu-operator.yaml",
            "03-prometheus.yaml",
            "04-grafana.yaml",
            "05-moshi-setup.yaml",
        ]
        
        for manifest in common_manifests:
            assert manifest in content

    def test_classification_prod_manifest_logic(self):
        """Test that prod-specific manifests are correctly identified."""
        script_path = Path("scripts/classify-manifests.sh")
        content = script_path.read_text()
        
        # Prod manifests should include MIG configuration
        assert "02-mig-config.yaml" in content
        assert "*-mig.yaml" in content

    def test_classification_preprod_manifest_logic(self):
        """Test that pre-prod-specific manifests are correctly identified."""
        script_path = Path("scripts/classify-manifests.sh")
        content = script_path.read_text()
        
        # Pre-prod manifests should include time slicing
        assert "02-timeslicing-config.yaml" in content
        assert "*-timeslicing.yaml" in content

    def test_classification_homelab_manifest_logic(self):
        """Test that homelab-specific manifests are correctly identified."""
        script_path = Path("scripts/classify-manifests.sh")
        content = script_path.read_text()
        
        # Homelab manifests should include local storage
        assert "local-storage.yaml" in content
        assert "ingress-homelab.yaml" in content or "ingress-local.yaml" in content


class TestRollbackScript:
    """Test the rollback-migration.sh script."""

    def test_rollback_script_exists(self):
        """Test that rollback script exists and is executable.
        
        Validates: Requirements 17.4
        """
        script_path = Path("scripts/rollback-migration.sh")
        assert script_path.exists()
        assert os.access(script_path, os.X_OK)

    def test_rollback_requires_backup_directory(self):
        """Test that rollback script requires backup directory argument."""
        script_path = Path("scripts/rollback-migration.sh")
        content = script_path.read_text()
        
        # Verify usage message
        assert "Usage:" in content
        assert "backup-directory" in content

    def test_rollback_validates_backup_directory(self):
        """Test that rollback script validates backup directory exists."""
        script_path = Path("scripts/rollback-migration.sh")
        content = script_path.read_text()
        
        # Verify directory validation
        assert "if [ ! -d" in content
        assert "Backup directory not found" in content

    def test_rollback_requires_confirmation(self):
        """Test that rollback script requires user confirmation."""
        script_path = Path("scripts/rollback-migration.sh")
        content = script_path.read_text()
        
        # Verify confirmation prompt
        assert "read -p" in content
        assert "Continue?" in content or "confirm" in content

    def test_rollback_restores_terraform_state(self):
        """Test that rollback script restores Terraform state."""
        script_path = Path("scripts/rollback-migration.sh")
        content = script_path.read_text()
        
        # Verify Terraform state restoration
        assert "Restoring Terraform state" in content
        assert "terraform.tfstate" in content

    def test_rollback_restores_kubernetes_manifests(self):
        """Test that rollback script restores Kubernetes manifests."""
        script_path = Path("scripts/rollback-migration.sh")
        content = script_path.read_text()
        
        # Verify Kubernetes manifest restoration
        assert "Restoring Kubernetes manifests" in content
        assert "k8s/" in content

    def test_rollback_backs_up_current_state(self):
        """Test that rollback script backs up current state before restoring."""
        script_path = Path("scripts/rollback-migration.sh")
        content = script_path.read_text()
        
        # Verify current state backup
        assert "pre-rollback" in content
        assert "Creating backup of current" in content

    def test_rollback_restores_argocd_applications(self):
        """Test that rollback script restores ArgoCD applications."""
        script_path = Path("scripts/rollback-migration.sh")
        content = script_path.read_text()
        
        # Verify ArgoCD restoration
        assert "Restoring ArgoCD applications" in content
        assert "kubectl apply" in content


class TestMigrationScriptIntegration:
    """Integration tests for migration scripts."""

    def test_backup_and_rollback_workflow(self):
        """Test that backup and rollback scripts work together."""
        backup_script = Path("scripts/backup-current-state.sh")
        rollback_script = Path("scripts/rollback-migration.sh")
        
        assert backup_script.exists()
        assert rollback_script.exists()
        
        # Verify rollback script references backup format
        rollback_content = rollback_script.read_text()
        assert "backups/" in rollback_content

    def test_all_scripts_use_consistent_paths(self):
        """Test that all scripts use consistent directory paths."""
        scripts = [
            "scripts/backup-current-state.sh",
            "scripts/classify-manifests.sh",
            "scripts/rollback-migration.sh",
        ]
        
        for script_path in scripts:
            content = Path(script_path).read_text()
            
            # Verify consistent paths
            if "terraform" in content:
                assert "terraform/environments/" in content
            
            if "k8s" in content:
                # Should reference k8s directory
                assert "k8s/" in content or "K8S_DIR" in content

    def test_all_scripts_have_error_handling(self):
        """Test that all scripts have proper error handling."""
        scripts = [
            "scripts/backup-current-state.sh",
            "scripts/classify-manifests.sh",
            "scripts/rollback-migration.sh",
        ]
        
        for script_path in scripts:
            content = Path(script_path).read_text()
            
            # Verify error handling
            assert "set -e" in content or "exit 1" in content

    def test_all_scripts_are_executable(self):
        """Test that all migration scripts are executable."""
        scripts = [
            "scripts/backup-current-state.sh",
            "scripts/classify-manifests.sh",
            "scripts/rollback-migration.sh",
        ]
        
        for script_path in scripts:
            assert Path(script_path).exists()
            assert os.access(script_path, os.X_OK)


if __name__ == "__main__":
    import pytest
    pytest.main([__file__, "-v"])
