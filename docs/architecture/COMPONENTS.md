# Component Breakdown

## Overview

This document provides detailed information about each major component in the GPU MIG vs Time Slicing demonstration project. Understanding these components is essential for making modifications, troubleshooting issues, and extending the project's functionality.

The infrastructure consists of several distinct layers working together to create a complete demonstration environment. These layers include cloud infrastructure provisioning, Kubernetes cluster management, GPU operator configuration, monitoring and visualization, and demonstration workloads.

## Cloud Infrastructure

### Scaleway Instance

The foundation of the demonstration is a Scaleway H100-1-80G virtual machine. This instance type was specifically chosen because it meets several important criteria for the demonstration.

The H100-1-80G instance provides a single NVIDIA L4 GPU with 24GB of VRAM. This GPU is based on the Ada Lovelace architecture and offers excellent performance for inference workloads while being more cost-effective than previous-generation GPUs. The 24GB of memory is particularly important because it allows for meaningful MIG partitioning demonstrations.

One critical advantage of the L4 GPU for this project is that it fully supports MIG (Multi-Instance GPU) technology. This enables the demonstration to showcase true hardware-level GPU partitioning, which is the key differentiator between MIG and Time Slicing approaches.

The instance is provisioned in the fr-par-2 availability zone by default, though this can be configured through variables. The provisioning process uses cloud-init to automatically install and configure K3s on first boot.

### SSH Key Management

SSH access to the instance is managed through a dedicated SSH key pair. The public key is injected during instance creation through the Terraform configuration, while the private key is used by operators to access the instance for maintenance and debugging.

The SSH key pair is generated outside of Terraform and stored in the project root directory. The private key (ssh_key) should have appropriate permissions (chmod 400) to work correctly with SSH.

### IP Address Allocation

A public IP address is automatically allocated to the instance through Scaleway's networking infrastructure. This IP address is used for accessing the Kubernetes API, Grafana, Prometheus, and any deployed demonstration applications.

The IP address is output by Terraform after provisioning and can be retrieved using the instance_ip output. This address remains stable for the lifetime of the instance unless explicitly released.

## Kubernetes Cluster

### K3s Distribution

K3s is used as the Kubernetes distribution for this demonstration. K3s is a lightweight, fully conformant Kubernetes distribution that is designed for edge computing, IoT, and situations where a full Kubernetes cluster would be excessive.

K3s was chosen over other Kubernetes distributions for several important reasons. First, K3s has a significantly smaller resource footprint than a standard Kubernetes setup, leaving more resources available for GPU workloads. Second, K3s runs all Kubernetes control plane components in a single binary, making it much easier to set up and manage on a single node. Third, K3s includes embedded components like the container runtime, storage driver, and load balancer, reducing the number of separate services that need to be managed.

The K3s installation is handled through cloud-init during instance provisioning. The configuration ensures that K3s is started automatically on boot and configured to work with the NVIDIA devices.

### Node Configuration

The Kubernetes node is configured to recognize and allocate NVIDIA GPU resources. This involves several components that work together to enable GPU-aware scheduling in Kubernetes.

The node's capacity and allocatable resources are modified by the NVIDIA device plugin to include GPU resources. When the cluster is running in Time Slicing mode, the node will report multiple replicas of the nvidia.com/gpu resource. When running in MIG mode, the node will report MIG-managed GPU instances as separate resources.

## GPU Operator Components

### NVIDIA Device Plugin

The NVIDIA Device Plugin is a Kubernetes component that enables the discovery and allocation of NVIDIA GPUs within a Kubernetes cluster. It runs as a DaemonSet on each node with NVIDIA GPUs and is responsible for advertising GPU resources to the Kubernetes scheduler.

The device plugin is deployed through a DaemonSet that runs with elevated privileges to access GPU hardware. It monitors the state of NVIDIA GPUs on the node and updates the node's capacity and allocatable resources accordingly.

The plugin reads its configuration from a ConfigMap named nvidia-device-plugin-config. This configuration determines whether the plugin operates in Time Slicing mode or MIG mode, and contains the specific settings for each mode.

### Device Plugin Configuration

The device plugin configuration is stored in a ConfigMap within the gpu-operator namespace. This configuration changes depending on which GPU sharing mode is active.

In Time Slicing mode, the configuration specifies the number of GPU replicas to advertise. For example, setting replicas to 4 means that up to 4 pods can request a GPU, with the device plugin time-slicing access to the single physical GPU among them.

In MIG mode, the configuration is handled differently through the MIG partitioner component. The MIG configuration specifies which MIG profiles (gi) and compute instances (ci) should be created on the GPU.

### MIG Partitioner

The MIG partitioner is responsible for creating and managing MIG instances on supported GPUs. It runs as a DaemonSet and modifies the GPU hardware configuration to create isolated MIG partitions.

When MIG mode is enabled, the partitioner reads the MIG configuration from the migstrategy-config ConfigMap and creates the specified MIG instances on the GPU hardware. This is a hardware-level operation that divides the GPU's compute resources and memory into isolated partitions.

The partitioner runs with hostPID and hostNetwork enabled, allowing it to access the GPU hardware directly and execute the nvidia-mig-partitioner command. This operation requires elevated privileges and is essential for MIG functionality.

## Monitoring Stack

### Prometheus

Prometheus is deployed as the metrics collection and storage backend for the monitoring stack. It scrapes metrics from various targets including the Kubernetes API server, kubelet, node-exporter, and DCGM exporter.

The Prometheus deployment consists of several components working together. The Prometheus server itself is responsible for collecting and storing time-series metrics. ServiceMonitors define how Prometheus should discover and scrape metrics from specific services. The kube-state-metrics addon provides metrics about Kubernetes objects like pods, deployments, and services.

Prometheus is configured to scrape metrics at regular intervals and store them locally on the node. The retention period and storage size are configured appropriately for a demonstration environment.

### DCGM Exporter

DCGM (Data Center GPU Manager) Exporter is a key component for GPU monitoring. It runs as a DaemonSet and collects GPU metrics from the NVIDIA GPUs on each node, exposing them in a Prometheus-compatible format.

DCGM Exporter collects a wide range of GPU metrics including utilization, memory usage, temperature, power consumption, and error conditions. These metrics are essential for understanding GPU behavior and comparing MIG versus Time Slicing performance.

The metrics are scraped by Prometheus and stored alongside other system metrics, allowing for correlation between GPU behavior and Kubernetes workload events.

### Grafana

Grafana provides the visualization layer for the monitoring stack. It connects to Prometheus as a data source and provides dashboards for exploring and presenting metrics.

The demonstration includes pre-configured dashboards specifically designed for comparing MIG and Time Slicing behavior. These dashboards visualize GPU utilization, memory usage, pod scheduling, and other metrics relevant to understanding the differences between the two approaches.

Grafana runs on port 30300 and is accessible through the instance IP address. The default credentials are admin/admin, though these should be changed in production environments.

## Demonstration Workloads

### Moshi Application

The Moshi AI chatbot application serves as the demonstration workload for comparing MIG and Time Slicing behavior. This application simulates a realistic AI inference workload that can clearly demonstrate the differences between GPU sharing modes.

The application is deployed in different configurations depending on which GPU sharing mode is being demonstrated. Each configuration is designed to illustrate specific properties of the GPU sharing approach.

### Time Slicing Workload

In Time Slicing mode, the application is deployed with multiple replicas that share a single GPU through time-slicing. This configuration demonstrates how workloads contend for GPU resources when they cannot be fully isolated.

When running in Time Slicing mode, crashing one pod can affect the stability of other pods sharing the same GPU. This demonstrates the lack of isolation in Time Slicing mode.

### MIG Workload

In MIG mode, the application is deployed with pods requesting specific MIG instances. Each pod gets guaranteed access to a dedicated portion of the GPU hardware and memory.

When running in MIG mode, crashing one pod does not affect pods running on other MIG instances. This demonstrates the strong isolation properties of MIG partitioning.

## Networking and Access

### Service Exposure

Services in the cluster are exposed through NodePort services for direct access from outside the cluster. This simple approach was chosen to minimize complexity in the demonstration environment.

Grafana is exposed on port 30300, making it easily accessible for dashboard viewing. Prometheus is exposed on port 30090 for metrics exploration. The K3s API server is available on port 6443 for Kubernetes management operations.

### Ingress Configuration

Additional ingress configurations are available for more sophisticated routing requirements. These include basic authentication and path-based routing for different services.

The ingress configurations use the Kubernetes Ingress resource definition and are typically configured with the nginx-ingress controller for handling HTTP routing.

## Configuration Management

### Terraform State

The Terraform state is stored in an S3 bucket on Scaleway's object storage service. This approach provides several benefits including state persistence across machines, locking to prevent concurrent modifications, and backup capability.

The state is organized by environment, with separate state keys for dev and prod environments. This ensures that changes to one environment do not affect the other.

### Kubernetes ConfigMaps

Kubernetes ConfigMaps are used extensively for managing configuration throughout the cluster. These include the GPU operator configurations, application settings, and monitoring configurations.

ConfigMaps can be updated without restarting pods when using certain configuration patterns, allowing for dynamic configuration changes during demonstrations.

## Related Documentation

For more information about specific topics, refer to these additional documents:

The docs/architecture/OVERVIEW.md document provides a high-level introduction to the project and its purpose.

The docs/architecture/STRUCTURE.md document describes the project directory structure and file organization.

The docs/architecture/MODES.md document provides detailed technical information about MIG and Time Slicing modes.

The README.md file contains quick reference information for common operations.
