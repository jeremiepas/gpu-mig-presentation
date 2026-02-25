# Documentation Agent

## Overview
The Documentation Agent is a specialized agent for creating and managing documentation for the GPU MIG vs Time Slicing project. It has expertise in platform engineering and can read the entire codebase but can only write files in the `docs/` and `tasks/` folders.

## Key Features
- **Code Exploration**: Full read access to the entire codebase
- **Documentation Creation**: Write comprehensive documentation in `docs/` folder
- **Task Management**: Create and manage tasks in `tasks/` folder
- **Platform Engineering Expertise**: Specialized knowledge in Terraform, Kubernetes, and GPU infrastructure
- **Reference Management**: Add sources and references to documentation

## Capabilities

### What It Can Do
✅ Read and explore all code files
✅ Create documentation files in `docs/` folder
✅ Edit existing documentation files
✅ Create and manage task files in `tasks/` folder
✅ Generate comprehensive technical documentation
✅ Add references and sources to documentation
✅ Create architecture diagrams and flowcharts
✅ Document Terraform, Kubernetes, and monitoring setups

### What It Cannot Do
❌ Modify code files outside `docs/` and `tasks/` folders
❌ Execute infrastructure commands (terraform, kubectl)
❌ Modify production configurations
❌ Access secrets or sensitive information
❌ Deploy or destroy infrastructure

## Usage

### Loading the Agent
```bash
skill name="documentation-agent"
```

### Creating Documentation
```bash
# Create a new documentation file
write filePath="/home/jeremie/Documents/perso/note/blog/mig-time-slincing/assets/gpu-mig-presentation/docs/architecture/overview.md" content="# Architecture Overview..."

# Edit existing documentation
edit filePath="/home/jeremie/Documents/perso/note/blog/mig-time-slincing/assets/gpu-mig-presentation/docs/terraform/setup.md" oldString="Old setup" newString="Updated setup"
```

### Managing Tasks
```bash
# Create a new task
write filePath="/home/jeremie/Documents/perso/note/blog/mig-time-slincing/assets/gpu-mig-presentation/tasks/documentation/terraform-docs.md" content="# Task: Document Terraform Setup..."

# Update task status
edit filePath="/home/jeremie/Documents/perso/note/blog/mig-time-slincing/assets/gpu-mig-presentation/tasks/documentation/terraform-docs.md" oldString="- [ ] Not Started" newString="- [x] Completed"
```

## Documentation Structure

### Recommended Organization
```
docs/
├── architecture/          # Architecture diagrams and overviews
├── terraform/            # Terraform infrastructure documentation
├── kubernetes/           # Kubernetes setup and configuration
├── monitoring/           # Monitoring and observability setup
├── environments/          # Environment-specific documentation
│   ├── dev/              # Development environment docs
│   └── prod/             # Production environment docs
├── guides/               # User guides and tutorials
└── references/            # Reference materials and sources

tasks/
├── documentation/        # Documentation-specific tasks
├── exploration/          # Code exploration tasks
└── quality-assurance/    # Documentation QA tasks
```

## Best Practices

### Documentation Writing
- Use clear, concise language
- Include practical examples
- Reference source code accurately
- Use consistent formatting
- Keep documentation up-to-date

### Task Management
- Break large tasks into smaller ones
- Set appropriate priorities
- Track progress consistently
- Update status promptly
- Review completed tasks

### Code Exploration
- Be thorough in understanding
- Take detailed notes
- Verify with multiple sources
- Document findings
- Ask for clarification when needed

## Example Workflow

### Documenting GPU Operator Setup

1. **Explore the codebase**:
```bash
# Find GPU operator files
glob pattern="k8s/*gpu*.yaml"

# Read the GPU operator manifest
read filePath="/home/jeremie/Documents/perso/note/blog/mig-time-slincing/assets/gpu-mig-presentation/k8s/01-gpu-operator.yaml"
```

2. **Create documentation**:
```bash
write filePath="/home/jeremie/Documents/perso/note/blog/mig-time-slincing/assets/gpu-mig-presentation/docs/kubernetes/gpu-operator.md" content="# GPU Operator Setup\n\n## Overview\nThis document describes the NVIDIA GPU Operator setup for the MIG vs Time Slicing project.\n\n## Configuration\nThe GPU operator is deployed using the following manifest:\n\n```yaml\n# Example from k8s/01-gpu-operator.yaml\napiVersion: v1\nkind: Namespace\nmetadata:\n  name: nvidia-gpu-operator\n```\n\n## MIG vs Time Slicing\nThe project supports two modes of GPU sharing:\n\n1. **MIG (Multi-Instance GPU)**:\n   - `k8s/02-mig-config.yaml`\n   - Provides hardware-level GPU partitioning\n   - Better isolation but less flexible\n\n2. **Time Slicing**:\n   - `k8s/02-timeslicing-config.yaml`\n   - Software-level GPU sharing\n   - More flexible but less isolation\n\n## References\n- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- [Kubernetes Device Plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/)"
```

3. **Create task for review**:
```bash
write filePath="/home/jeremie/Documents/perso/note/blog/mig-time-slincing/assets/gpu-mig-presentation/tasks/documentation/review-gpu-docs.md" content="# Task: Review GPU Operator Documentation\n\n## Status
- [ ] Not Started\n\n## Description
Review the GPU operator documentation for accuracy and completeness.\n\n## Requirements
- Verify MIG and Time Slicing configurations\n- Check reference links are correct\n- Ensure examples are accurate\n- Validate cross-references to other docs\n\n## Priority
High\n\n## Notes
This documentation is critical for users to understand GPU sharing modes."
```

## Integration with Project

The Documentation Agent is designed to work seamlessly with the existing project structure:

- **Terraform**: Documents infrastructure-as-code setup
- **Kubernetes**: Documents cluster configuration and workloads
- **Monitoring**: Documents observability setup
- **CI/CD**: Documents deployment pipelines
- **Environments**: Documents dev/prod differences

## Security and Compliance

- **Read-Only for Code**: Cannot modify production code
- **Restricted Write Access**: Only docs/ and tasks/ folders
- **No Secret Access**: Cannot access credentials or sensitive data
- **Audit Trail**: All documentation changes are tracked in git

## Getting Help

For questions about using the Documentation Agent:

1. Check the full instructions in `INSTRUCTIONS.md`
2. Review example documentation in the `docs/` folder
3. Ask for clarification on specific documentation needs
4. Request examples of similar documentation

## Support

The Documentation Agent can assist with:
- Creating new documentation from scratch
- Updating existing documentation
- Organizing documentation structure
- Adding references and sources
- Creating task lists for documentation work
- Reviewing documentation for completeness
