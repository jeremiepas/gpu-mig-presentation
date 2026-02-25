# =============================================================================
# GPU Moshi Demo Packer Template Variables
# =============================================================================
# Default values for the GPU Moshi demo image
# Override with -var or .pkrvars.hcl file
# =============================================================================

project_id      = "your-project-id-here"
zone            = "fr-par-2"
image_name      = "gpu-moshi-demo-ubuntu-22.04"
instance_type   = "H100-1-80G"
ssh_username    = "root"
disk_size       = 80
gpu_mode        = "both"
