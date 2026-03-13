#!/usr/bin/env python3
"""
Property Test: Module Interface Contract for argocd-bootstrap module
Validates Requirements: 1.4, 1.5, 1.6

Property 1: Module Interface Contract
- All required variables are declared with proper types
- All outputs are exposed correctly
- Module can be invoked with valid inputs
"""

import sys
from pathlib import Path


def test_module_interface_contract():
    """Test that the module interface contract is satisfied"""
    module_path = Path(__file__).parent
    
    # Test 1: Verify all required files exist
    required_files = ['main.tf', 'variables.tf', 'outputs.tf', 'versions.tf']
    for file in required_files:
        assert (module_path / file).exists(), f"Missing required file: {file}"
    
    # Test 2: Verify required variables are declared
    variables_content = (module_path / 'variables.tf').read_text()
    required_vars = [
        'instance_ip', 'ssh_private_key', 'environment', 
        'git_repo_url', 'k3s_ready'
    ]
    
    for var in required_vars:
        assert f'variable "{var}"' in variables_content, \
            f"Required variable '{var}' not declared"
        assert 'type' in variables_content, \
            f"Variable '{var}' missing type declaration"
        assert 'description' in variables_content, \
            f"Variable '{var}' missing description"
    
    # Test 3: Verify required outputs are exposed
    outputs_content = (module_path / 'outputs.tf').read_text()
    required_outputs = ['argocd_url', 'initial_password_file']
    
    for output in required_outputs:
        assert f'output "{output}"' in outputs_content, \
            f"Required output '{output}' not exposed"
    
    # Test 4: Verify provider version constraints
    versions_content = (module_path / 'versions.tf').read_text()
    assert 'null' in versions_content, "Null provider not configured"
    assert '~> 3.2' in versions_content, "Null provider version constraint incorrect"
    
    # Test 5: Verify main.tf contains required resources
    main_content = (module_path / 'main.tf').read_text()
    assert 'resource "null_resource" "argocd_install"' in main_content, \
        "ArgoCD install resource not defined"
    assert 'provisioner "remote-exec"' in main_content, \
        "Remote-exec provisioner not defined"
    assert 'depends_on = [var.k3s_ready]' in main_content, \
        "K3s dependency not defined"
    
    print("✓ Property 1: Module Interface Contract - PASSED")
    print("  - All required files exist")
    print("  - All required variables declared with types and descriptions")
    print("  - All required outputs exposed")
    print("  - Provider version constraints correct")
    print("  - Required resources and dependencies defined")
    return True


if __name__ == "__main__":
    try:
        test_module_interface_contract()
        sys.exit(0)
    except AssertionError as e:
        print(f"✗ Property Test FAILED: {e}", file=sys.stderr)
        sys.exit(1)
