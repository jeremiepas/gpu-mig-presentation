#cloud-config
package_update: true
packages:
  - curl
  - wget
  - jq
  - git
  - python3
  - python3-pip

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    ssh-authorized-keys:
      - ${ssh_public_key}

write_files:
  - path: /etc/rancher/k3s/agent_token
    content: |
      K10f624f385955bec54b01d5917610bbce4ed7b7c8e456732591550484969e8d597::server:40e373ebe2a6e57574308f87803a090c
    owner: root:root
    permissions: '0600'

runcmd:
  # Install K3s agent (connects to master)
  - curl -sfL https://get.k3s.io | K3S_URL="https://${master_ip}:6443" K3S_TOKEN_FILE=/etc/rancher/k3s/agent_token sh -

  # Wait for K3s to be ready
  - sleep 10

  # Enable and start K3s agent
  - systemctl enable k3s-agent
  - systemctl start k3s-agent

  # Create auto-shutdown script for GPU inactivity
  - |
    cat > /usr/local/bin/gpu-auto-shutdown.sh << 'SCRIPT'
    #!/bin/bash
    # GPU Auto-Shutdown Script
    # Monitors GPU usage and shuts down instance after inactivity
    
    TIMEOUT_MINS=$${1:-25}
    CHECK_INTERVAL=60  # Check every minute
    IDLE_THRESHOLD=5   # GPU utilization below 5% = idle
    
    # Log function
    log() {
        echo "[$$(date '+%Y-%m-%d %H:%M:%S')] $$1" | tee /var/log/gpu-auto-shutdown.log
    }
    
    # Get GPU utilization
    get_gpu_util() {
        nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo "0"
    }
    
    # Get active GPU processes
    get_gpu_procs() {
        nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | wc -l
    }
    
    log "Starting GPU auto-shutdown monitor"
    log "Timeout: $$TIMEOUT_MINS minutes of GPU inactivity"
    log "Idle threshold: GPU util < $$IDLE_THRESHOLD%"
    
    while true; do
        GPU_UTIL=$$(get_gpu_util)
        GPU_PROCS=$$(get_gpu_procs)
        
        log "GPU Util: $$GPU_UTIL%, Active Processes: $$GPU_PROCS"
        
        # Check if GPU is idle
        if [ "$$GPU_UTIL" -lt "$$IDLE_THRESHOLD" ] && [ "$$GPU_PROCS" -eq 0 ]; then
            log "GPU is idle. Starting inactivity counter..."
            
            # Count consecutive idle minutes
            IDLE_COUNT=0
            while [ $$IDLE_COUNT -lt $$TIMEOUT_MINS ]; do
                sleep 60
                GPU_UTIL=$$(get_gpu_util)
                GPU_PROCS=$$(get_gpu_procs)
                
                if [ "$$GPU_UTIL" -lt "$$IDLE_THRESHOLD" ] && [ "$$GPU_PROCS" -eq 0 ]; then
                    IDLE_COUNT=$$((IDLE_COUNT + 1))
                    log "GPU idle for $$IDLE_COUNT/$$TIMEOUT_MINS minutes"
                else
                    log "GPU activity detected (util: $$GPU_UTIL%, procs: $$GPU_PROCS). Resetting counter."
                    IDLE_COUNT=0
                    break
                fi
            done
            
            # If still idle after timeout, shutdown
            if [ $$IDLE_COUNT -ge $$TIMEOUT_MINS ]; then
                log "GPU idle for $$TIMEOUT_MINS minutes. Shutting down..."
                sync
                systemctl poweroff
                exit 0
            fi
        else
            log "GPU is active (util: $$GPU_UTIL%, procs: $$GPU_PROCS)"
        fi
        
        sleep $$CHECK_INTERVAL
    done
    SCRIPT
    
  - chmod +x /usr/local/bin/gpu-auto-shutdown.sh

  # Start GPU auto-shutdown monitor in background
  - nohup /usr/local/bin/gpu-auto-shutdown.sh > /var/log/gpu-auto-shutdown.log 2>&1 &

  # Disable cloud-init from re-running
  - touch /etc/cloud/cloud-init-disabled

final_message: |
  GPU Worker setup complete!
  
  - K3s Agent: Running (connected to master: ${master_ip})
  - Auto-shutdown: Enabled (${shutdown_mins} min timeout)
  
  To check status:
    sudo systemctl status k3s-agent
    sudo tail -f /var/log/gpu-auto-shutdown.log
  
  To disable auto-shutdown:
    sudo killall gpu-auto-shutdown.sh
  
  To shutdown manually:
    sudo poweroff
