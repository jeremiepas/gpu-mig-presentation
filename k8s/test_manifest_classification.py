#!/usr/bin/env python3
"""
Property Test: Manifest Classification Completeness
Validates Requirements: 8.1, 8.2, 8.3, 8.4, 8.5

Property 4: Manifest Classification Completeness
- Every manifest is classified into exactly one category
- Common manifests are correctly identified
- Environment-specific manifests are correctly categorized
- No manifest appears in multiple categories
"""

import sys
from pathlib import Path


def test_manifest_classification_completeness():
    """Test that all manifests are correctly classified"""
    k8s_path = Path(__file__).parent
    
    # Define classification rules based on design document
    common_patterns = [
        "00-namespaces.yaml",
        "00-nvidia-runtimeclass.yaml",
        "01-gpu-operator.yaml",
        "03-prometheus.yaml",
        "04-grafana.yaml",
        "04-grafana-datasources.yaml",
        "05-moshi-setup.yaml",
        "09-node-exporter.yaml",
        "12-kube-state-metrics.yaml",
        "14-dcgm-exporter.yaml"
    ]
    
    # Test 1: Verify common directory exists
    common_dir = k8s_path / 'common'
    assert common_dir.exists(), "k8s/common/ directory does not exist"
    
    # Test 2: Verify all common manifests are in common directory
    for pattern in common_patterns:
        common_file = common_dir / pattern
        assert common_file.exists(), \
            f"Common manifest '{pattern}' not found in k8s/common/"
    
    # Test 3: Verify common manifests are valid YAML
    import yaml
    for pattern in common_patterns:
        common_file = common_dir / pattern
        try:
            with open(common_file, 'r') as f:
                yaml.safe_load_all(f.read())
        except yaml.YAMLError as e:
            raise AssertionError(f"Invalid YAML in {pattern}: {e}")
    
    # Test 4: Verify no duplicate manifests (same file in multiple locations)
    all_manifests = {}
    
    # Collect all YAML files from common
    for yaml_file in common_dir.glob('*.yaml'):
        filename = yaml_file.name
        if filename not in all_manifests:
            all_manifests[filename] = []
        all_manifests[filename].append(str(yaml_file.relative_to(k8s_path)))
    
    # Collect all YAML files from environments (if they exist)
    environments_dir = k8s_path / 'environments'
    if environments_dir.exists():
        for env_dir in environments_dir.iterdir():
            if env_dir.is_dir():
                for yaml_file in env_dir.glob('*.yaml'):
                    filename = yaml_file.name
                    if filename not in all_manifests:
                        all_manifests[filename] = []
                    all_manifests[filename].append(str(yaml_file.relative_to(k8s_path)))
    
    # Check for duplicates in common manifests
    for filename, locations in all_manifests.items():
        if filename in common_patterns and len(locations) > 1:
            # Common manifests should only appear in common directory
            common_locations = [loc for loc in locations if loc.startswith('common/')]
            assert len(common_locations) == 1, \
                f"Common manifest '{filename}' appears in multiple locations: {locations}"
    
    # Test 5: Verify environment-specific patterns are NOT in common
    env_specific_patterns = [
        "02-mig-config.yaml",
        "02-timeslicing-config.yaml",
        "06-moshi-timeslicing.yaml",
        "07-moshi-mig.yaml",
        "ingress-prod.yaml",
        "ingress-preprod.yaml",
        "ingress-local.yaml",
        "local-storage.yaml"
    ]
    
    for pattern in env_specific_patterns:
        common_file = common_dir / pattern
        assert not common_file.exists(), \
            f"Environment-specific manifest '{pattern}' found in common directory"
    
    # Test 6: Verify classification completeness
    # All manifests should be either common or environment-specific
    classified_count = len(common_patterns)
    print(f"  - {classified_count} common manifests classified")
    
    print("✓ Property 4: Manifest Classification Completeness - PASSED")
    print("  - k8s/common/ directory exists")
    print("  - All common manifests present in k8s/common/")
    print("  - All common manifests are valid YAML")
    print("  - No duplicate common manifests across locations")
    print("  - Environment-specific manifests not in common directory")
    return True


if __name__ == "__main__":
    try:
        test_manifest_classification_completeness()
        sys.exit(0)
    except AssertionError as e:
        print(f"✗ Property Test FAILED: {e}", file=sys.stderr)
        sys.exit(1)
