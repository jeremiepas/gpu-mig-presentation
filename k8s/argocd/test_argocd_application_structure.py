#!/usr/bin/env python3
"""
Property Test: ArgoCD Application Structure
Validates Requirements: 4.3, 4.4, 4.5

Property 6: ArgoCD Application Structure
- Each environment has one application for common-infrastructure
- Each environment has one application for environment-specific manifests
- All applications have automated sync enabled
- All applications have self-heal enabled
- Applications reference correct paths (k8s/common/ and k8s/environments/{env}/)
"""

import sys
from pathlib import Path
import yaml


def test_argocd_application_structure():
    """Test that ArgoCD applications are correctly structured"""
    argocd_path = Path(__file__).parent
    k8s_path = argocd_path.parent
    
    environments = ['prod', 'pre-prod', 'homelab']
    
    # Test 1: Verify ArgoCD directory structure exists
    common_dir = argocd_path / 'common'
    assert common_dir.exists(), "k8s/argocd/common/ directory does not exist"
    
    environments_dir = argocd_path / 'environments'
    assert environments_dir.exists(), "k8s/argocd/environments/ directory does not exist"
    
    # Test 2: Verify common ArgoCD manifests exist
    required_common_files = [
        '00-namespace.yaml',
        '01-argocd-install.yaml',
        '04-argocd-appproject.yaml'
    ]
    
    for filename in required_common_files:
        common_file = common_dir / filename
        assert common_file.exists(), \
            f"Required common ArgoCD manifest '{filename}' not found"
    
    # Test 3: Verify each environment has applications.yaml
    for env in environments:
        env_dir = environments_dir / env
        assert env_dir.exists(), \
            f"Environment directory 'k8s/argocd/environments/{env}/' does not exist"
        
        app_file = env_dir / 'applications.yaml'
        assert app_file.exists(), \
            f"applications.yaml not found for environment '{env}'"
    
    # Test 4: Verify application structure for each environment
    for env in environments:
        app_file = environments_dir / env / 'applications.yaml'
        
        with open(app_file, 'r') as f:
            docs = list(yaml.safe_load_all(f))
        
        # Should have exactly 2 applications
        assert len(docs) == 2, \
            f"Environment '{env}' should have exactly 2 applications, found {len(docs)}"
        
        # Extract application names
        app_names = [doc['metadata']['name'] for doc in docs]
        
        # Test 4.1: Verify common-infrastructure application exists
        assert 'common-infrastructure' in app_names, \
            f"Environment '{env}' missing 'common-infrastructure' application"
        
        # Test 4.2: Verify environment-specific application exists
        env_specific_name = f"{env}-specific" if env != 'homelab' else 'homelab-specific'
        assert env_specific_name in app_names, \
            f"Environment '{env}' missing '{env_specific_name}' application"
        
        # Test 4.3: Verify application configurations
        for doc in docs:
            app_name = doc['metadata']['name']
            
            # Verify environment label
            assert 'labels' in doc['metadata'], \
                f"Application '{app_name}' in '{env}' missing labels"
            assert doc['metadata']['labels'].get('environment') == env, \
                f"Application '{app_name}' in '{env}' has incorrect environment label"
            
            # Verify project
            assert doc['spec']['project'] == 'gpu-demo', \
                f"Application '{app_name}' in '{env}' not using 'gpu-demo' project"
            
            # Verify source path
            expected_path = 'k8s/common' if app_name == 'common-infrastructure' \
                else f'k8s/environments/{env}'
            assert doc['spec']['source']['path'] == expected_path, \
                f"Application '{app_name}' in '{env}' has incorrect path: " \
                f"expected '{expected_path}', got '{doc['spec']['source']['path']}'"
            
            # Verify automated sync policy (Requirement 4.5)
            assert 'syncPolicy' in doc['spec'], \
                f"Application '{app_name}' in '{env}' missing syncPolicy"
            assert 'automated' in doc['spec']['syncPolicy'], \
                f"Application '{app_name}' in '{env}' missing automated sync"
            
            # Verify prune enabled
            assert doc['spec']['syncPolicy']['automated']['prune'] is True, \
                f"Application '{app_name}' in '{env}' does not have prune enabled"
            
            # Verify self-heal enabled (Requirement 4.5)
            assert doc['spec']['syncPolicy']['automated']['selfHeal'] is True, \
                f"Application '{app_name}' in '{env}' does not have selfHeal enabled"
            
            # Verify destination
            assert doc['spec']['destination']['server'] == 'https://kubernetes.default.svc', \
                f"Application '{app_name}' in '{env}' has incorrect destination server"
    
    # Test 5: Verify common manifests are valid YAML
    for filename in required_common_files:
        common_file = common_dir / filename
        try:
            with open(common_file, 'r') as f:
                list(yaml.safe_load_all(f.read()))
        except yaml.YAMLError as e:
            raise AssertionError(f"Invalid YAML in {filename}: {e}")
    
    # Test 6: Verify AppProject exists and has correct configuration
    appproject_file = common_dir / '04-argocd-appproject.yaml'
    with open(appproject_file, 'r') as f:
        appproject = yaml.safe_load(f)
    
    assert appproject['kind'] == 'AppProject', \
        "04-argocd-appproject.yaml does not contain an AppProject"
    assert appproject['metadata']['name'] == 'gpu-demo', \
        "AppProject name is not 'gpu-demo'"
    
    print("✓ Property 6: ArgoCD Application Structure - PASSED")
    print(f"  - ArgoCD directory structure exists")
    print(f"  - Common ArgoCD manifests present ({len(required_common_files)} files)")
    print(f"  - All {len(environments)} environments have applications.yaml")
    print(f"  - Each environment has 2 applications (common + env-specific)")
    print(f"  - All applications have correct paths")
    print(f"  - All applications have automated sync enabled")
    print(f"  - All applications have self-heal enabled")
    print(f"  - All applications have correct environment labels")
    print(f"  - AppProject 'gpu-demo' exists with correct configuration")
    return True


if __name__ == "__main__":
    try:
        test_argocd_application_structure()
        sys.exit(0)
    except AssertionError as e:
        print(f"✗ Property Test FAILED: {e}", file=sys.stderr)
        sys.exit(1)
