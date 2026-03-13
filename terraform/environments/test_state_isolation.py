#!/usr/bin/env python3
"""
Property Test: Environment State Isolation
Validates Requirements: 5.1, 5.5

Property 2: Environment State Isolation
- Each environment has separate state backend configuration
- State keys are unique per environment
- No shared state between environments
"""

import sys
from pathlib import Path


def test_environment_state_isolation():
    """Test that environments maintain separate state"""
    environments_path = Path(__file__).parent
    
    # Test 1: Verify all environment directories exist
    required_envs = ['prod', 'pre-prod', 'homelab']
    for env in required_envs:
        env_path = environments_path / env
        assert env_path.exists(), f"Environment directory '{env}' does not exist"
        assert (env_path / 'main.tf').exists(), f"main.tf missing in {env}"
    
    # Test 2: Verify unique state keys for prod and pre-prod
    state_keys = {}
    
    for env in ['prod', 'pre-prod']:
        main_tf = (environments_path / env / 'main.tf').read_text()
        
        # Extract state key
        if 'backend "s3"' in main_tf:
            lines = main_tf.split('\n')
            for i, line in enumerate(lines):
                if 'key' in line and '=' in line:
                    key_value = line.split('=')[1].strip().strip('"')
                    state_keys[env] = key_value
                    break
    
    # Verify state keys are unique
    assert len(state_keys) == 2, "Not all environments have state keys"
    assert state_keys['prod'] != state_keys['pre-prod'], \
        "Prod and pre-prod share the same state key"
    assert 'prod' in state_keys['prod'], "Prod state key doesn't contain 'prod'"
    assert 'pre-prod' in state_keys['pre-prod'], \
        "Pre-prod state key doesn't contain 'pre-prod'"
    
    # Test 3: Verify homelab uses local backend
    homelab_main = (environments_path / 'homelab' / 'main.tf').read_text()
    assert 'backend "local"' in homelab_main or 'backend "s3"' not in homelab_main, \
        "Homelab should use local backend, not S3"
    
    # Test 4: Verify environment-specific tags
    for env in ['prod', 'pre-prod']:
        main_tf = (environments_path / env / 'main.tf').read_text()
        assert f'environment      = "{env}"' in main_tf, \
            f"Environment tag not set correctly in {env}"
    
    print("✓ Property 2: Environment State Isolation - PASSED")
    print("  - All environment directories exist")
    print("  - Prod and pre-prod have unique S3 state keys")
    print("  - Homelab uses local backend")
    print("  - Environment-specific tags configured")
    return True


if __name__ == "__main__":
    try:
        test_environment_state_isolation()
        sys.exit(0)
    except AssertionError as e:
        print(f"✗ Property Test FAILED: {e}", file=sys.stderr)
        sys.exit(1)
