variable "gpu_host" {
  description = "IP address of the local GPU machine"
  type        = string
  default     = "192.168.1.96"
}

variable "gpu_user" {
  description = "Username for the GPU machine"
  type        = string
  default     = "jeremie"
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "../../../ssh_key"
}

variable "kubeconfig_local_path" {
  description = "Local path to store kubeconfig"
  type        = string
  default     = "~/.kube/config-gpu-local"
}

variable "k3s_port" {
  description = "K3s API port"
  type        = number
  default     = 6443
}