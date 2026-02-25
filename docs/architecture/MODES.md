# MIG vs Time Slicing Modes

## Introduction

This document provides a comprehensive explanation of MIG (Multi-Instance GPU) and Time Slicing, the two GPU sharing strategies supported by this demonstration project. Understanding the technical differences between these approaches is essential for making informed decisions about GPU infrastructure and for conducting effective demonstrations.

Both MIG and Time Slicing address the same fundamental challenge: how to share expensive GPU resources among multiple workloads when those workloads do not require the full GPU. However, they approach this problem in fundamentally different ways, resulting in distinct characteristics around isolation, performance, flexibility, and management.

## Time Slicing Overview

Time Slicing is a software-level approach to GPU sharing that allows multiple pods to share a single physical GPU by time-multiplexing access to the GPU hardware. The GPU can only execute one workload at a time, so the device plugin rapidly switches between different workloads, giving the illusion of parallel execution.

When a GPU is configured for Time Slicing, the NVIDIA device plugin advertises multiple replicas of the nvidia.com/gpu resource. For example, setting replicas to 4 means that Kubernetes will schedule up to 4 pods that each request one GPU, even though there is only one physical GPU. The device plugin manages access to the physical GPU, ensuring that only one pod can use it at any given moment while rapidly switching between pods.

### How Time Slicing Works

The Time Slicing mechanism operates at the Kubernetes device plugin level without requiring any changes to the GPU hardware itself. The process works as follows:

When a pod requests a GPU resource, the device plugin allocates one of the advertised GPU replicas to that pod. The plugin maintains a queue of pods waiting for GPU access and switches between them based on a time-slicing algorithm. Each pod believes it has exclusive access to a GPU, but in reality, they are sharing time on the same physical device.

The switching happens at the CUDA level, with the driver handling context switches between different GPU contexts belonging to different pods. This switching is designed to be as lightweight as possible, but it does introduce some overhead and latency.

### Time Slicing Characteristics

Time Slicing exhibits several important characteristics that distinguish it from MIG:

The first characteristic is shared memory. All pods sharing a GPU through Time Slicing share the same physical GPU memory. This means that if one pod allocates a large amount of memory, less is available for other pods. This can lead to out-of-memory errors even when the total memory requests of all pods would fit within the physical GPU memory.

The second characteristic is lack of hardware isolation. Because Time Slicing operates at the software level, there is no hardware-enforced isolation between workloads. A misbehaving or runaway workload can consume excessive GPU time, affecting the performance of all other workloads sharing the same GPU.

The third characteristic is contention. When multiple workloads run concurrently on a time-sliced GPU, they compete for GPU compute resources. This can lead to unpredictable performance and latency, particularly for workloads with real-time requirements.

The fourth characteristic is fault propagation. If a workload crashes or encounters a GPU error while using Time Slicing, the GPU may become unstable and affect other workloads sharing the same device. This is a critical consideration for production environments requiring high availability.

### Time Slicing Configuration

Time Slicing is configured through the nvidia-device-plugin-config ConfigMap. The configuration specifies the number of GPU replicas to advertise. Here is an example configuration:

```yaml
version: v1
sharing:
  timeSlicing:
    resources:
      - name: nvidia.com/gpu
        replicas: 4
```

This configuration tells the device plugin to advertise 4 replicas of nvidia.com/gpu, allowing up to 4 pods to be scheduled on the single physical GPU. The replica count can be adjusted based on the expected workload characteristics, but higher replica counts generally lead to more contention.

## MIG Overview

MIG, which stands for Multi-Instance GPU, is a hardware-level feature available on certain NVIDIA GPUs (including the A100, H100, and L4) that allows the GPU to be divided into multiple isolated instances. Each MIG instance has its own dedicated compute resources, memory, and hardware-level isolation from other instances.

Unlike Time Slicing, which is purely a software technique, MIG requires GPU hardware support and must be configured at the hardware level. When MIG is enabled, the GPU's streaming multiprocessors and memory are physically partitioned, creating isolated GPU "mini-devices" that can run independently.

### How MIG Works

MIG operates at the hardware level, dividing the GPU's resources into isolated partitions called MIG instances. Each MIG instance appears to the system as a separate GPU device and can be allocated to workloads independently.

The MIG partitioner DaemonSet is responsible for creating and managing these partitions. When MIG mode is enabled, the partitioner reads the MIG configuration and uses the nvidia-mig-partitioner tool to create the specified instances on the GPU hardware. This is a destructive operation that requires resetting the GPU.

Once MIG instances are created, the NVIDIA device plugin detects them and advertises them as separate GPU resources. Workloads can request specific MIG instances using a special MIG-encoded resource name.

### MIG Characteristics

MIG exhibits several important characteristics that make it attractive for certain cases:

The use first characteristic is hardware isolation. Each MIG instance has dedicated compute resources (streaming multiprocessors) and dedicated memory. This isolation is enforced at the hardware level, ensuring that workloads running on one MIG instance cannot interfere with workloads on another instance.

The second characteristic is guaranteed resources. Because resources are reserved for each MIG instance, workloads receive guaranteed amounts of compute and memory. There is no contention between MIG instances, and performance is predictable and consistent.

The third characteristic is fault isolation. If a workload crashes or encounters an error on one MIG instance, other MIG instances continue operating normally. This is a critical advantage for multi-tenant environments and workloads requiring high availability.

The fourth characteristic is limited flexibility. MIG instances have fixed resource configurations (specific amounts of memory and compute). This means that MIG may not be the best choice if workloads have varying resource requirements that do not match the available MIG profiles.

### MIG Profiles

MIG instances are created from predefined profiles that specify the amount of memory and compute resources for each instance. The available profiles depend on the GPU model. On the L4 GPU used in this demonstration, the following MIG profiles are available:

The mig.1g.6gb profile provides 1 GPU instance (gi) with 1 compute instance (ci) and 6GB of memory. This profile is suitable for small inference workloads or development purposes.

The mig.2g.12gb profile provides 2 GPU instances with 1 compute instance each and 12GB of memory per instance. This profile is suitable for medium-sized workloads that need more memory than the 1g profile provides.

The mig.3g.24gb profile provides 3 GPU instances with 1 compute instance each and 24GB of memory per instance. This profile uses the full GPU memory and is suitable for workloads requiring maximum resources.

### MIG Configuration

MIG is configured through the migstrategy-config ConfigMap. The configuration specifies which MIG profiles to create. Here is an example configuration:

```yaml
version: v1
mig:
  mode: "single"
  config:
    - gi: 1
      ci: 1
      memory: "6GB"
    - gi: 2
      ci: 1
      memory: "12GB"
    - gi: 3
      ci: 1
      memory: "24GB"
```

This configuration creates three MIG instances using the available MIG profiles. The mode "single" indicates that this is a static MIG configuration (as opposed to dynamic MIG which is not covered in this demonstration).

## Comparison

### Isolation

The most significant difference between MIG and Time Slicing is the level of isolation they provide. MIG provides hardware-level isolation with dedicated resources for each partition, while Time Slicing provides only software-level isolation with shared resources.

This difference has practical implications for workload stability and security. MIG workloads are protected from interference by other workloads, making MIG suitable for multi-tenant environments and workloads with strict isolation requirements. Time Slicing workloads can be affected by neighbor workloads, making it more suitable for homogeneous workloads where interference is acceptable.

### Resource Utilization

Time Slicing generally provides better resource utilization than MIG because it does not require reserving fixed amounts of resources. With Time Slicing, any unallocated GPU time or memory can be used by any workload. With MIG, unused resources in one MIG instance cannot be used by workloads in other instances.

However, this flexibility comes at the cost of predictability. MIG workloads have guaranteed resources, while Time Slicing workloads may experience contention and unpredictable performance.

### Flexibility

Time Slicing is more flexible than MIG in terms of resource allocation. The number of replicas can be adjusted freely, allowing fine-tuning of how many workloads can share the GPU. There are no fixed resource boundaries to work within.

MIG is less flexible because MIG instances have fixed resource configurations. Workloads must fit within these predefined profiles or they cannot use MIG. This can lead to wasted resources if workload requirements do not match available profiles.

### GPU Support

Time Slicing works on any NVIDIA GPU with a compatible driver, making it universally available. MIG requires specific GPU hardware (A100, H100, L4, and newer) and may not be available on older or lower-end GPUs.

The L4 GPU used in this demonstration supports both Time Slicing and MIG, making it an ideal platform for comparing both approaches.

### Switching Between Modes

Switching between MIG and Time Slicing requires changes to the GPU configuration and typically involves restarting the GPU operator components. The process is not instantaneous and may require a brief downtime.

In this demonstration, switching between modes is done by applying different ConfigMap configurations:

To switch to Time Slicing, apply the Time Slicing configuration:

```bash
kubectl apply -f k8s/02-timeslicing-config.yaml
```

To switch to MIG, apply the MIG configuration:

```bash
kubectl apply -f k8s/02-mig-config.yaml
```

After applying the configuration, the GPU operator will reconfigure the device plugin to advertise resources according to the new mode.

## Use Case Recommendations

### When to Use Time Slicing

Time Slicing is recommended in the following scenarios:

First, when working with GPUs that do not support MIG. Older GPUs or budget constraints may require Time Slicing as the only option for GPU sharing.

Second, when workloads are homogeneous and can accept resource contention. If all workloads have similar resource requirements and can tolerate variable performance, Time Slicing may be more efficient.

Third, when maximum flexibility is required. If workloads have highly variable resource requirements that do not fit MIG profiles, Time Slicing provides more flexibility.

Fourth, when cost optimization is critical. Time Slicing can pack more workloads onto fewer GPUs, potentially reducing infrastructure costs.

### When to Use MIG

MIG is recommended in the following scenarios:

First, when strict isolation is required. Multi-tenant environments, security-sensitive workloads, and workloads requiring guaranteed resources benefit from MIG's hardware-level isolation.

Second, when workloads need predictable performance. MIG provides consistent, predictable performance without contention from other workloads.

Third, when fault isolation is critical. Workloads that must remain available even if neighbor workloads fail should use MIG.

Fourth, when using supported GPUs. If the infrastructure uses MIG-capable GPUs (A100, H100, L4), MIG should be considered as the primary sharing strategy.

## Demonstration Scenarios

This project includes demonstration scenarios that illustrate the practical differences between MIG and Time Slicing. These scenarios are designed to be performed during presentations to clearly show how each mode behaves.

### Time Slicing Demonstration

In the Time Slicing demonstration, multiple pods are deployed requesting GPU resources. The pods simulate AI inference workloads using the Moshi application. Because Time Slicing is configured, all pods share the same physical GPU.

A key demonstration point involves crashing one of the pods while others are running. Because of the shared nature of Time Slicing, this crash can affect the stability of other pods, demonstrating the lack of isolation.

### MIG Demonstration

In the MIG demonstration, the same workloads are deployed but using MIG instances. Each pod is assigned to a specific MIG instance with dedicated resources.

When one pod is crashed in MIG mode, the other pods continue running unaffected. This demonstrates the fault isolation properties of MIG hardware partitioning.

The demonstration clearly shows that MIG provides better isolation at the cost of flexibility, while Time Slicing provides more flexibility but with potential contention issues.

## Technical Considerations

### Memory Management

In Time Slicing mode, all pods share the same GPU memory pool. This means that memory usage by one pod reduces available memory for other pods. Memory is allocated on a first-come-first-served basis, which can lead to out-of-memory errors even when total requests seem reasonable.

In MIG mode, each MIG instance has dedicated memory. Pods cannot use more memory than is allocated to their MIG instance, and memory usage in one instance does not affect memory availability in other instances.

### Compute Resources

In Time Slicing mode, compute resources are shared among all pods. The NVIDIA driver time-slices between different GPU contexts, but only one pod can execute CUDA code at any moment.

In MIG mode, each MIG instance has dedicated streaming multiprocessors. Multiple MIG instances can execute code in parallel, providing true parallelism rather than time-multiplexed execution.

### Device Discovery

In Time Slicing mode, pods request the generic nvidia.com/gpu resource. The device plugin assigns any available GPU replica to the pod.

In MIG mode, pods can request specific MIG instances using MIG-encoded resource names like nvidia.com/mig.1g.6gb. This allows workloads to request exactly the resources they need.

## Related Documentation

For more information about specific topics, refer to these additional documents:

The docs/architecture/OVERVIEW.md document provides a high-level introduction to the project and its purpose.

The docs/architecture/STRUCTURE.md document describes the project directory structure and file organization.

The docs/architecture/COMPONENTS.md document provides detailed information about individual infrastructure components.

The README.md file contains quick reference information for deploying and using the demonstration infrastructure.
