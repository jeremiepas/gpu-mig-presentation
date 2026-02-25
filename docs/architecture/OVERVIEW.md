# Project Overview

## Introduction

This project demonstrates the differences between NVIDIA MIG (Multi-Instance GPU) and Time Slicing GPU sharing strategies on a Scaleway L4-24GB GPU instance. It provides a complete infrastructure-as-code setup using Terraform and Kubernetes to deploy a demonstration environment for comparing these two GPU allocation methods.

The project is designed for technical presentations and educational purposes, allowing users to observe real-world behavior differences between MIG and Time Slicing in a controlled Kubernetes environment.

## Purpose and Goals

The primary purpose of this infrastructure is to provide a hands-on demonstration environment that showcases the fundamental differences between MIG and Time Slicing GPU allocation strategies. This demonstration is particularly valuable for engineering teams, decision-makers, and anyone interested in understanding how to optimally utilize expensive GPU resources in a cloud environment.

The project aims to achieve several specific goals that make it valuable for GPU infrastructure education and evaluation. First, it provides a practical, reproducible environment where users can experiment with both GPU sharing modes without requiring extensive manual setup. Second, it includes comprehensive monitoring through Prometheus and Grafana, allowing participants to observe resource utilization patterns and performance characteristics in real time. Third, the infrastructure is fully automated through Terraform and Kubernetes manifests, enabling consistent deployments across different environments. Finally, the demonstration includes specific workload scenarios that clearly illustrate the isolation properties of MIG versus the contention issues that can arise with Time Slicing.

## Technical Stack

The infrastructure relies on a carefully selected combination of cloud services and open-source technologies that work together to create a cohesive GPU demonstration platform. Each component plays a specific role in enabling the overall functionality of the project.

The cloud infrastructure is built on Scaleway, a European cloud provider that offers GPU instances at competitive pricing. The project uses the H100-1-80G instance type, which provides a single NVIDIA L4 GPU with 24GB of VRAM. This instance type was chosen because it supports both MIG and Time Slicing modes, making it ideal for comparative demonstrations.

For container orchestration, the project uses K3s, a lightweight Kubernetes distribution that is particularly well-suited for single-node demonstration environments. K3s requires significantly less resources than a full Kubernetes cluster while providing all the essential Kubernetes APIs needed for the demonstration workloads.

The NVIDIA GPU Operator is deployed to manage GPU resources within the Kubernetes cluster. This operator handles the installation and configuration of NVIDIA device drivers, the container runtime hook, and the device plugin that enables Kubernetes to discover and allocate GPU resources. The GPU Operator also provides the mechanism for switching between MIG and Time Slicing modes.

Monitoring is provided by Prometheus for metrics collection and Grafana for visualization. These tools work together to capture GPU utilization metrics, Kubernetes resource metrics, and custom application metrics, providing a comprehensive view of system behavior during demonstrations.

## Use Cases

This demonstration infrastructure serves multiple use cases that benefit different stakeholders within an organization. Understanding these use cases helps in planning effective demonstrations and maximizing the value derived from the infrastructure.

For engineering teams, the project provides a sandbox environment for testing GPU workloads and understanding how different Kubernetes configurations affect GPU allocation and performance. Engineers can deploy their own workloads, modify the existing manifests, and observe how the GPU operator responds to different resource requests.

For technical presenters and educators, the infrastructure offers a ready-made demonstration environment that clearly illustrates complex GPU concepts. The included Grafana dashboards are specifically designed to visualize the differences between MIG and Time Slicing behavior, making it easy to explain these concepts to non-technical audiences.

For decision-makers, the demonstration provides the information needed to make informed choices about GPU infrastructure strategy. By observing real-world behavior rather than just reading documentation, stakeholders can better understand the trade-offs between MIG and Time Slicing and choose the approach that best fits their organization's needs.

## Key Features

The project includes several key features that distinguish it from a basic GPU Kubernetes setup and make it particularly valuable for demonstration purposes.

The infrastructure supports seamless switching between MIG and Time Slicing modes through Kubernetes ConfigMaps. This allows presenters to transition between modes quickly during a demonstration without requiring significant reconfiguration or cluster downtime.

Pre-configured Grafana dashboards provide visual comparisons of GPU behavior under different modes. These dashboards include metrics such as GPU utilization, memory usage, pod scheduling behavior, and workload performance, making it easy to observe and explain differences between the two modes.

The demonstration workloads include the Moshi AI chatbot application deployed in multiple configurations. This application is designed to simulate realistic GPU usage patterns and clearly demonstrate the isolation properties of MIG when compared to Time Slicing.

Automated CI/CD pipelines using GitHub Actions ensure that the infrastructure can be deployed consistently and reliably. These pipelines handle both the Terraform provisioning and Kubernetes manifest deployment, reducing the potential for human error during setup.

## Architecture Overview

The overall architecture follows a straightforward design that prioritizes simplicity and clarity for demonstration purposes. A single GPU node running K3s serves as the foundation, with all Kubernetes components deployed as pods on this node.

The GPU node is provisioned through Terraform, which creates the Scaleway instance, configures networking, and applies initial cloud-init configuration to set up K3s. Once the node is running, Kubernetes manifests are applied to deploy the GPU operator, monitoring stack, and demonstration workloads.

All services are exposed through NodePort or Ingress configurations, allowing easy access from outside the cluster. Grafana runs on port 30300, Prometheus on port 30090, and the K3s API is available on port 6443.

## Cost Considerations

Running GPU infrastructure involves significant costs, and this project is designed with cost awareness in mind. The H100-1-80G instance on Scaleway costs approximately 0.85 euros per hour, making it important to destroy resources when not in use.

The project includes detailed cleanup instructions and a GitHub Actions workflow for resource destruction. For a typical demonstration session including setup time and the presentation, the total cost is approximately 0.78 euros, making it an economical choice for educational purposes.

## Next Steps

To get started with this project, review the README.md file in the project root for initial setup instructions. The quick start guide in docs/QUICKSTART.md provides additional context for working with the Documentation Agent if you need help exploring or documenting the codebase.

For deploying the infrastructure, refer to the deployment section in this documentation or the AGENTS.md file which contains detailed command references for Terraform and Kubernetes operations.
