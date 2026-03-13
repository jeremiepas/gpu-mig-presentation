#!/usr/bin/env python3
"""
Unit tests for environment-specific Kubernetes manifests.
Tests that prod uses MIG, pre-prod uses Time Slicing with 4 replicas,
and homelab uses Time Slicing with 2 replicas.
"""

import os
import yaml
import unittest
from pathlib import Path


class TestEnvironmentManifests(unittest.TestCase):
    """Test environment-specific manifest configurations."""

    def setUp(self):
        """Set up test fixtures."""
        self.base_path = Path(__file__).parent
        self.prod_path = self.base_path / "prod"
        self.preprod_path = self.base_path / "pre-prod"
        self.homelab_path = self.base_path / "homelab"

    def load_yaml(self, file_path):
        """Load YAML file and return parsed content."""
        with open(file_path, 'r') as f:
            return list(yaml.safe_load_all(f))

    def test_prod_uses_mig_configuration(self):
        """Test that prod environment uses MIG configuration."""
        mig_config_path = self.prod_path / "02-mig-config.yaml"
        self.assertTrue(
            mig_config_path.exists(),
            "MIG config should exist in prod environment"
        )

        docs = self.load_yaml(mig_config_path)
        config_map = next(
            (doc for doc in docs if doc and doc.get('kind') == 'ConfigMap'),
            None
        )
        self.assertIsNotNone(config_map, "ConfigMap not found in MIG config")

        config_data = config_map.get('data', {}).get('config.yaml', '')
        self.assertIn('mig:', config_data, "MIG configuration not found")
        
        # Verify MIG mode is configured
        config_yaml = yaml.safe_load(config_data)
        mig_config = config_yaml.get('mig', {})
        self.assertIsNotNone(mig_config.get('mode'), "MIG mode not configured")

    def test_prod_has_mig_workloads(self):
        """Test that prod environment has MIG-specific workloads."""
        mig_workload_path = self.prod_path / "07-moshi-mig.yaml"
        self.assertTrue(
            mig_workload_path.exists(),
            "MIG workload should exist in prod environment"
        )

    def test_preprod_uses_timeslicing_with_4_replicas(self):
        """Test that pre-prod uses Time Slicing with 4 replicas."""
        timeslicing_config_path = self.preprod_path / "02-timeslicing-config.yaml"
        self.assertTrue(
            timeslicing_config_path.exists(),
            "Time Slicing config should exist in pre-prod environment"
        )

        docs = self.load_yaml(timeslicing_config_path)
        config_map = next(
            (doc for doc in docs if doc and doc.get('kind') == 'ConfigMap'),
            None
        )
        self.assertIsNotNone(
            config_map,
            "ConfigMap not found in Time Slicing config"
        )

        config_data = config_map.get('data', {}).get('config.yaml', '')
        config_yaml = yaml.safe_load(config_data)
        
        replicas = config_yaml.get('sharing', {}).get('timeSlicing', {}).get(
            'resources', [{}]
        )[0].get('replicas')
        
        self.assertEqual(
            replicas, 4,
            "Pre-prod should use 4 GPU replicas for Time Slicing"
        )

    def test_preprod_has_timeslicing_workloads(self):
        """Test that pre-prod has Time Slicing workloads."""
        timeslicing_workload_path = self.preprod_path / "06-moshi-timeslicing.yaml"
        self.assertTrue(
            timeslicing_workload_path.exists(),
            "Time Slicing workload should exist in pre-prod environment"
        )

    def test_homelab_uses_timeslicing_with_2_replicas(self):
        """Test that homelab uses Time Slicing with 2 replicas."""
        timeslicing_config_path = self.homelab_path / "02-timeslicing-config.yaml"
        self.assertTrue(
            timeslicing_config_path.exists(),
            "Time Slicing config should exist in homelab environment"
        )

        docs = self.load_yaml(timeslicing_config_path)
        config_map = next(
            (doc for doc in docs if doc and doc.get('kind') == 'ConfigMap'),
            None
        )
        self.assertIsNotNone(
            config_map,
            "ConfigMap not found in Time Slicing config"
        )

        config_data = config_map.get('data', {}).get('config.yaml', '')
        config_yaml = yaml.safe_load(config_data)
        
        replicas = config_yaml.get('sharing', {}).get('timeSlicing', {}).get(
            'resources', [{}]
        )[0].get('replicas')
        
        self.assertEqual(
            replicas, 2,
            "Homelab should use 2 GPU replicas for Time Slicing"
        )

    def test_homelab_has_local_storage(self):
        """Test that homelab has local storage configuration."""
        local_storage_path = self.homelab_path / "local-storage.yaml"
        self.assertTrue(
            local_storage_path.exists(),
            "Local storage config should exist in homelab environment"
        )

        docs = self.load_yaml(local_storage_path)
        storage_class = next(
            (doc for doc in docs if doc and doc.get('kind') == 'StorageClass'),
            None
        )
        self.assertIsNotNone(
            storage_class,
            "StorageClass not found in local storage config"
        )

    def test_homelab_has_nodeport_ingress(self):
        """Test that homelab uses NodePort configuration."""
        ingress_path = self.homelab_path / "ingress-local.yaml"
        self.assertTrue(
            ingress_path.exists(),
            "Local ingress should exist in homelab environment"
        )

        docs = self.load_yaml(ingress_path)
        nodeport_services = [
            doc for doc in docs
            if doc and doc.get('kind') == 'Service'
            and doc.get('spec', {}).get('type') == 'NodePort'
        ]
        self.assertGreater(
            len(nodeport_services), 0,
            "NodePort services should exist in homelab ingress"
        )

    def test_prod_has_network_policies(self):
        """Test that prod has network policies for security."""
        network_policies_path = self.prod_path / "network-policies.yaml"
        self.assertTrue(
            network_policies_path.exists(),
            "Network policies should exist in prod environment"
        )

        docs = self.load_yaml(network_policies_path)
        network_policies = [
            doc for doc in docs
            if doc and doc.get('kind') == 'NetworkPolicy'
        ]
        self.assertGreater(
            len(network_policies), 0,
            "Network policies should be defined in prod"
        )

    def test_all_environments_have_resource_quotas(self):
        """Test that all environments have resource quotas."""
        for env_name, env_path in [
            ("prod", self.prod_path),
            ("pre-prod", self.preprod_path),
            ("homelab", self.homelab_path)
        ]:
            with self.subTest(environment=env_name):
                quota_files = list(env_path.glob("*quota*.yaml")) + \
                              list(env_path.glob("*resource*.yaml"))
                self.assertGreater(
                    len(quota_files), 0,
                    f"{env_name} should have resource quota configuration"
                )


if __name__ == '__main__':
    unittest.main()
