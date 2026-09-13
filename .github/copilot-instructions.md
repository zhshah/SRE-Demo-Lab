# Azure SRE Agent Demo Lab - Copilot Instructions

## Local Checkout Profile

The verified local profile takes precedence over generic upstream examples below.
Read [the rebuild guide](../docs/REDEPLOY.md) before deployment or recovery, and
[the cost guide](../docs/COSTS.md) before shutdown/deletion. Use the current checkout,
not an unmodified upstream clone, to preserve the recorded fixes and offline console.

- Keep Sweden Central, subscription `b28cc86b-8f84-47e5-a38a-b814b44d047e`, RG `Az-SRE-Agent-Demo-MAT-RG`, AKS `aks-srelab`, and its `-nodes` managed group unless the user approves a different scope.
- Retain Free AKS, fixed D4as_v5 + D2as_v5 nodes, 32-GiB OS disks, no autoscaling and no optional Grafana/Prometheus.
- Preserve `SecurityControl=Ignore` in IaC, node-pool/StorageClass tags and generated-alert tagging for this demo. Do not generalize this policy accommodation to production.
- Never automatically purge a deleted Key Vault, broaden agent permissions to the subscription, stop VMSS instances directly, or run a stop/delete operation without user authorization.
- Run `scripts/test-deployment-safety.ps1` after editing deployment helpers. Run `scripts/deploy.ps1 -CheckPrerequisitesOnly` before an Azure preview/deployment.
- Keep observed baseline image digests and deliberate fault settings. `virtual-worker` has zero replicas; the action group has no notification receiver by default.
- Refresh the console with `scripts/update-demo-console.ps1` after endpoint/path changes. Do not mistake its checkpoints or impact icons for live health.
- A fresh destructive rebuild is not required to verify local changes; report precisely which local, dry-run and live checks actually ran.

## Project Overview

This repository contains a fully automated Azure SRE Agent demo lab environment. It deploys:

- **Azure Kubernetes Service (AKS)** with a multi-pod sample e-commerce application
- **Azure Container Registry** for container images
- **Azure Key Vault** for secrets management
- **Observability stack**: Log Analytics, Application Insights, Managed Grafana
- **Breakable scenarios** for demonstrating SRE Agent diagnosis capabilities
- **SRE Agent configuration layer**: Knowledge base runbooks, custom agents, connectors, and scheduled tasks

The app uses in-cluster MongoDB and RabbitMQ with Azure Managed Disk storage.

## Technology Stack

- **Infrastructure as Code**: Bicep (modular templates in `infra/bicep/`)
- **Container Orchestration**: Kubernetes (manifests in `k8s/`)
- **SRE Agent Config**: YAML specs and Markdown runbooks in `sre-config/`
- **Scripting**: PowerShell (deployment scripts in `scripts/`)
- **Dev Environment**: Dev Containers with Azure CLI, kubectl, azd

## Key Directories

```
├── infra/bicep/           # Bicep IaC templates
│   ├── main.bicep         # Main deployment orchestration
│   ├── main.bicepparam    # Parameters file
│   └── modules/           # Modular Bicep templates
├── k8s/
│   ├── base/              # Healthy application manifests
│   └── scenarios/         # Breakable failure scenarios
├── sre-config/            # SRE Agent configuration layer
│   ├── knowledge-base/    # Runbooks uploaded to agent memory
│   ├── agents/            # Custom agent YAML specifications
│   └── connectors/        # MCP connector templates
├── scripts/               # Deployment and management scripts
├── docs/                  # Documentation
└── .devcontainer/         # Dev container configuration
```

## Azure SRE Agent Context

Azure SRE Agent is a Preview feature that provides AI-powered site reliability engineering automation:

- **Supported Regions**: East US 2, Sweden Central, Australia East
- **Firewall Requirement**: Allow `*.azuresre.ai`
- **RBAC Roles**: SRE Agent Admin, Standard User, Reader
- **Key Feature**: Natural language diagnosis and remediation

### SRE Agent Starter Prompts

For AKS issues:
- "Why are pods crashing in the pets namespace?"
- "Show me the health status of my AKS cluster"
- "What's causing high CPU usage on my nodes?"

For general diagnosis:
- "What issues are affecting my application?"
- "Analyze performance metrics and identify bottlenecks"

## Breakable Scenarios

Located in `k8s/scenarios/`:

| File | Issue | SRE Agent Can Diagnose |
|------|-------|----------------------|
| `oom-killed.yaml` | Memory exhaustion | OOMKilled events, memory limits |
| `crash-loop.yaml` | Startup failure | CrashLoopBackOff, exit codes |
| `image-pull-backoff.yaml` | Bad image | Registry/image issues |
| `high-cpu.yaml` | Resource exhaustion | CPU contention |
| `pending-pods.yaml` | Insufficient resources | Scheduling issues |
| `probe-failure.yaml` | Health check failure | Probe configuration |
| `network-block.yaml` | Connectivity issues | Network policies |
| `missing-config.yaml` | ConfigMap reference | Configuration issues |
| `mongodb-down.yaml` | Cascading dependency failure | Dependency tracing, root cause |
| `service-mismatch.yaml` | Silent networking failure | Endpoint/selector analysis |

## Common Operations

### Dev Container Commands
Type `menu` in the terminal to see all available commands. Key shortcuts:
- `deploy` - Deploy infrastructure
- `destroy` - Tear down infrastructure  
- `site` - Show store front URL
- `kgp` - Get pods in pets namespace
- `break-oom`, `break-crash`, `break-image` - Apply scenarios
- `break-mongodb` - Cascading database failure
- `break-service` - Silent networking failure
- `fix-all` - Restore healthy state

### Deploy Infrastructure
```powershell
.\scripts\deploy.ps1 -WhatIf
.\scripts\deploy.ps1
```

### SRE Agent Deployment
SRE Agent is now deployed automatically via Bicep (`Microsoft.App/agents@2025-05-01-preview`).
Set `deploySreAgent = true` in parameters (default). To manage the agent after deployment:
- Portal: https://aka.ms/sreagent/portal
- The deploying user is automatically assigned SRE Agent Administrator role

### Configure SRE Agent (Post-Deployment)

After infrastructure deployment, configure the agent with knowledge base, custom agents, connectors, and scheduled tasks via the dataplane v2 API:

```powershell
# Basic configuration (auto-called by deploy.ps1)
.\scripts\configure-sre-agent.ps1 -ResourceGroupName "rg-srelab-eastus2"

# With GitHub integration
.\scripts\configure-sre-agent.ps1 -ResourceGroupName "rg-srelab-eastus2" -GitHubPat $env:GITHUB_PAT -GitHubRepo "owner/repo"
```

### Apply Breakable Scenario
```bash
kubectl apply -f k8s/scenarios/oom-killed.yaml
```

### Restore Healthy State
```bash
kubectl apply -f k8s/base/application.yaml
```

### Destroy Infrastructure
```powershell
.\scripts\destroy.ps1 -ResourceGroupName "rg-srelab-eastus2"
```

## Important Constraints

1. **SRE Agent Regions**: Only deploy to eastus2, swedencentral, or australiaeast
2. **AKS Networking**: Must NOT be private cluster for SRE Agent access
3. **Authentication**: Use device code auth in dev containers (`az login --use-device-code`)
4. **RBAC**: Some role assignments may fail due to subscription policies - use scripts
5. **No SAS Tokens**: Use Workload Identity instead of connection strings where possible

## Cost Considerations

- **Current VM + SRE Agent subtotal**: ~$16.22/day (~$493.48/730-hour month), excluding supporting resources and active usage.
- **AKS pause** saves ~$0.276 per stopped hour; the ~$0.40/hour agent baseline and retained-resource charges remain.
- **See**: `docs/COSTS.md` for detailed breakdown

## When Helping with This Project

1. **For Bicep changes**: Follow best practices in `infra/bicep/` patterns
2. **For K8s manifests**: Use namespace `pets`, label with `sre-demo: breakable`
3. **For scripts**: Use PowerShell, include error handling, support `-WhatIf`
4. **For docs**: Keep formatting consistent, include code examples
5. **For new scenarios**: Add to `k8s/scenarios/` and update `docs/BREAKABLE-SCENARIOS.md`
6. **For runbooks**: Add `.md` files to `sre-config/knowledge-base/` — auto-discovered by `configure-sre-agent.ps1`
7. **For custom agents**: Add YAML specs to `sre-config/agents/` following existing patterns
