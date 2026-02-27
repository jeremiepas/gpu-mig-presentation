{ config, pkgs, ... }:

{
  imports = [
    # Hardware configuration
    ./hardware-configuration.nix
  ];

  # Boot configuration
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  # Enable OpenSSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  # Networking
  networking.firewall.enable = false; # Open all ports - security not a concern
  networking.hostName = "gpu-k3s-node";

  # Timezone
  time.timeZone = "Europe/Paris";

  # Internationalization
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
  };

  # Package management
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Install packages
  environment.systemPackages = with pkgs; [
    # Core utilities
    vim
    git
    curl
    wget
    htop
    tmux
    tree
    jq
    unzip

    rsync
    zip

    # Build tools
    build-essential
    gcc
    make
    pkg-config

    # Cloud tools
    scaleway-cli

    # Kubernetes tools
    kubectl
    k3s
    helm
    kubectx
    k9s

    # Docker tools
    docker
    docker-compose
    containerd
    docker-rootless
    nerdctl
    ctr
    crictl

    # NVIDIA tools
    nvidia-container-toolkit
    nvidia-container-runtime
    nvidia-utils
    nvidia-settings
    cudaPackages.nsight_systems
    nvtop
    gpustat
    gpu-burn

    # Python
    python3
    python3Packages.pip
    python3Packages.virtualenv

    # Misc
    nettools
    iproute2
    iputils
    dnsutils
    netcat
    socat
    iptables
    bridge-utils
  ];

  # NVIDIA Driver configuration
  services.xserver = {
    enable = false;
    videoDrivers = [ "nvidia" ];
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.nvidia-container-toolkit.enable = true;
  hardware.nvidia-container-toolkit.mount-nvidia-executables = true;

  nixpkgs.config.allowUnfreePackages = [ "nvidia-x11" "nvidia-settings" ];

  # Enable Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
    daemon.settings = {
      # Open all ports - security not a concern
      iptables = false;
      ip6tables = false;
    };
    daemon.extraOptions = [
      "--default-runtime=nvidia"
      "--experimental=true"
      "--storage-driver=overlay2"
    ];
  };

  # NVIDIA Container Runtime
  virtualisation.containerd = {
    enable = true;
    nvidiaContainerRuntime.enable = true;
  };

  # K3s configuration
  services.k3s = {
    enable = true;
    package = pkgs.k3s;
    # Enable K3s on startup
    enableServiceCrd = true;
    # Extra args for GPU support
    extraFlags = [
      "--docker"
      "--disable=traefik"
      "--disable=servicelb"
      "--write-kubeconfig-mode=644"
    ];
  };

  # Enable GPU operator helpers
  environment.etc = {
    "docker/daemon.json".text = ''
      {
        "runtimes": {
          "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
          }
        },
        "default-runtime": "nvidia",
        "storage-driver": "overlay2",
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "10m",
          "max-file": "3"
        },
        "iptables": false,
        "ip6tables": false,
        "bridge": "none"
      }
    '';

    "nvidia-container-runtime/config.toml".text = ''
      [nvidia-container-cli]
      root = "/run/nvidia/driver"
      path = "/usr/bin/nvidia-container-cli"
      environment = [
        "NVIDIA_VISIBLE_DEVICES=all",
        "NVIDIA_DRIVER_CAPABILITIES=all"
      ]
      debug = "/var/log/nvidia-container-runtime.log"

      [nvidia-container-runtime]
      runc = "/usr/bin/runc"
      migrate-from-docker = true
    '';

    "rancher/k3s/agent/etc/containerd/config.toml.tmpl".text = ''
      {{ template "base" . }}

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
        privileged_without_host_devices = false
        runtime_engine = ""
        runtime_root = ""
        runtime_type = "io.containerd.runc.v2"
    '';
  };

  # Create startup script for Docker images pre-pull
  systemd.services.prepull-docker-images = {
    description = "Pre-pull Docker images for GPU workloads";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${
          pkgs.writeScriptBin "prepull-images.sh" ''
            #!/bin/bash
            set -e

            echo "=== Pre-pulling Docker images ==="

            # Wait for Docker to be ready
            until docker info > /dev/null 2>&1; do
              echo "Waiting for Docker..."
              sleep 5
            done

            # GPU Operator and monitoring
            docker pull nvcr.io/nvidia/k8s/driver:12.4.0
            docker pull nvcr.io/nvidia/k8s/container-toolkit:v1.14.1
            docker pull nvcr.io/nvidia/cloud-native/k8s-device-plugin:v1.14.1
            docker pull nvcr.io/nvidia/k8s/dcgm-exporter:3.1.8-3.1.0-ubuntu22.04
            docker pull nvcr.io/nvidia/gpu-operator:v23.9.0

            # Prometheus and Grafana
            docker pull prom/prometheus:v2.47.0
            docker pull prom/node-exporter:v1.6.1
            docker pull grafana/grafana:10.2.0
            docker pull grafana/loki:2.9.0
            docker pull grafana/promtail:2.9.0

            # NVIDIA CUDA images
            docker pull nvcr.io/nvidia/cuda:12.2.2-runtime-ubuntu22.04
            docker pull nvcr.io/nvidia/cuda:12.2.2-devel-ubuntu22.04
            docker pull nvcr.io/nvidia/cuda:12.2.2-base-ubuntu22.04

            # ML frameworks
            docker pull nvidia/cuda:12.2.0-runtime-ubuntu22.04
            docker pull nvidia/cuda:12.2.0-devel-ubuntu22.04
            docker pull tensorflow/tensorflow:latest-gpu
            docker pull pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime
            docker pull pytorch/pytorch:2.1.0-cuda12.1-cudnn8-devel

            # Kubernetes core
            docker pull rancher/mirrored-coreos-etcd:v3.5.9
            docker pull rancher/mirrored-library-busybox:1.36
            docker pull rancher/mirrored-library-traefik:2.10.4
            docker pull rancher/klipper-lb:v0.4.0
            docker pull rancher/mirrored-metrics-server:v0.6.3

            # Kube-state-metrics
            docker pull registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.0

            # Moshi demo workloads
            docker pull moshi4/llava-1.5-7b-hf:latest
            docker pull moshi4/llava-1.5-7b-delta
            docker pull:latest ghcr.io/huggingface/text-generation-inference:latest

            # Storage
            docker pull rancher/local-path-provisioner:v0.0.24

            # Utility images
            docker pull curlimages/curl:latest
            docker pull busybox:latest
            docker pull alpine:latest

            # GPU burn test
            docker pull uogbuji/gpu_burn:latest

            echo "=== Docker images pre-pulled successfully ==="
          ''
        }/bin/prepull-images.sh";
    };
  };

  # Enable automatic updates
  system.autoUpgrade = {
    enable = true;
    channel = "https://nixos.org/channels/nixos-23.11";
  };

  # User configuration
  users.users.root = {
    openssh.authorizedKeys.keys = [
      # Add your SSH public key here
    ];
  };

  # Swap file
  swapDevices = [ ];

  # Systemd services
  systemd.services = {
    # Enable Docker on boot
    docker = { wantedBy = [ "multi-user.target" ]; };
  };

  # Open all ports (security not a concern)
  networking.firewall.trustedInterfaces = [ "eth0" ];
  networking.firewall.allowAll = true;

  # Initialize NixOS
  system.stateVersion = "23.11";
}
