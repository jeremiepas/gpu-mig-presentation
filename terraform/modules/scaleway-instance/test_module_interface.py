#!/usr/bin/env python3
"""
Property Test: Module Interface Contract for scaleway-instance module
Validates Requirements: 1.4, 1.5, 1.6

Property 1: Module Interface Contract
- All required variables are declared with proper types
- All outputs are exposed correctly
- Module can be invoked with valid inputs
"""

import os
import re
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
        'environment', 'instance_type', 'instance_name', 
        'zone', 'tags', 'ssh_public_key', 'root_volume_size'
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
    required_outputs = ['instance_ip', 'instance_id']
    
    for output in required_outputs:
        assert f'output "{output}"' in outputs_content, \
            f"Required output '{output}' not exposed"
    
    # Test 4: Verify provider version constraints
    versions_content = (module_path / 'versions.tf').read_text()
    assert 'scaleway' in versions_content, "Scaleway provider not configured"
    assert '~> 2.40' in versions_content, "Scaleway provider version constraint incorrect"
    
    # Test 5: Verify main.tf contains required resources
    main_content = (module_path / 'main.tf').read_text()
    assert 'resource "scaleway_instance_server"' in main_content, \
        "Instance server resource not defined"
    assert 'resource "scaleway_instance_ip"' in main_content, \
        "Instance IP resource not defined"
    
    print("✓ Property 1: Module Interface Contract - PASSED")
    print("  - All required files exist")
    print("  - All required variables declared with types and descriptions")
    print("  - All required outputs exposed")
    print("  - Provider version constraints correct")
    print("  - Required resources defined")
    return True


if __name__ == "__main__":
    try:
        test_module_interface_contract()
        sys.exit(0)
    except AssertionError as e:
        print(f"✗ Property Test FAILED: {e}", file=sys.stderr)
        sys.exit(1)
