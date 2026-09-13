# Azure SRE Agent Demo Lab 🔧

A fully automated Azure environment for demonstrating **Azure SRE Agent** capabilities. Deploy a breakable multi-service application on AKS and let SRE Agent diagnose and fix the issues!

## Clone This Backup

This checkout preserves the Sweden Central deployment fixes and offline presenter
console in [zhshah/SRE-Demo-Lab](https://github.com/zhshah/SRE-Demo-Lab).

```powershell
git clone https://github.com/zhshah/SRE-Demo-Lab.git
Set-Location SRE-Demo-Lab
.\scripts\deploy.ps1 -CheckPrerequisitesOnly
.\scripts\test-deployment-safety.ps1
```

Then follow [the rebuild guide](docs/REDEPLOY.md). See [backup contents and limits](docs/BACKUP.md)
for saved evidence, the redacted output snapshot, and data that a source clone cannot restore.

## 🎯 What This Lab Provides

- **Azure Kubernetes Service (AKS)** with a multi-pod e-commerce demo application
- **10 breakable scenarios** for demonstrating SRE Agent diagnosis
- **Azure SRE Agent** deployed automatically via Bicep for AI-powered diagnostics
- **SRE Agent configuration layer**: Knowledge base runbooks, custom agents, connectors, and scheduled tasks
- **Full observability stack**: Log Analytics, Application Insights, Managed Grafana
- **Working observability views**: Container Insights ingestion verification and an AKS Grafana dashboard
- **Ready-to-use scripts** for deployment and teardown
- **Dev container** for consistent development experience

[![repologbook.com](https://repoanalyticsprod4rquhaw.z19.web.core.windows.net/badges/1MnY7iHYBSlfgcqUa-ct9w.svg)](https://repologbook.com/)

## 🚀 Quick Start

### Prerequisites

- Azure subscription with Owner/Contributor access
- Authorized role-assignment permissions (Contributor alone is not sufficient)
- Azure region supporting SRE Agent: `East US 2`, `Sweden Central`, or `Australia East`
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) installed
- PowerShell 7, Bicep, kubectl, curl, and Python with PyYAML
- [VS Code](https://code.visualstudio.com/) with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) (optional but recommended)

![Menu](media/menu.png)

### Deploy

```powershell
# 1. Check local tools and regression guards (no Azure operations)
.\scripts\deploy.ps1 -CheckPrerequisitesOnly
.\scripts\test-deployment-safety.ps1

# 2. Login to the lab tenant
az login --tenant 8d7622f8-d815-4120-b5b8-bee841c23a1c --use-device-code

# 3. Preview the saved profile, then deploy after reviewing costs
.\scripts\deploy.ps1 -WhatIf
.\scripts\deploy.ps1
```

This checkout defaults to the verified Sweden Central lab, including its explicit
subscription and resource-group name. Read [the rebuild and recovery guide](docs/REDEPLOY.md)
for prerequisites, all recorded fixes, acceptance checks and partial-deployment recovery.
The equivalent explicit deployment command is:

```powershell
.\scripts\deploy.ps1 -Location swedencentral -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG -SubscriptionId b28cc86b-8f84-47e5-a38a-b814b44d047e
```

The profile uses AKS Free tier, two fixed AMD nodes, Basic ACR, and no optional
Grafana/Prometheus stack. See [the local cost profile](docs/COSTS.md#sweden-central-profile-in-this-checkout)
for current estimates and stop/cleanup commands. SRE Agent stays in Review mode.

The standard deployment includes the Azure Monitor automation profile: four
one-minute log alerts, the default action group, and scheduled SRE Agent health
and audit tasks.

Inspect the automation profile with:

```powershell
.\scripts\manage-azure-monitor-profile.ps1 -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG
```

Use [the offline demo console](docs/DEMO-CONSOLE.html) for the paced
Prepare / Inject / Observe / Ask SRE / Restore / Verify sequence. Successful
deployment refreshes its saved URLs and repository path automatically.

> 💡 **Tip**: Type `menu` in the terminal to see all available commands including break scenarios, fix commands, and kubectl shortcuts.

## 💥 Breaking Things (The Fun Part!)

Once deployed, you can break the application using shortcut commands:

```bash
# Out of Memory scenario
break-oom

# CrashLoopBackOff
break-crash

# Image Pull failure
break-image

# See all scenarios
menu
```

To restore:
```bash
fix-all
```

## 🤖 Using SRE Agent

After deployment, `deploy.ps1` automatically configures the SRE Agent with:

- **Knowledge base** — Runbooks for each failure category (pod failures, networking, dependencies, resource exhaustion) plus app architecture and incident report templates
- **Custom agents** — `incident-handler` (alert investigation), `cluster-health-monitor` (proactive checks), and optionally `code-analyzer` (GitHub source code RCA)
- **Connectors** — Azure Monitor and Outlook, plus optional GitHub MCP source-code search
- **Scheduled tasks** — daily health, daily RBAC/cost/network audit, and hourly automation-health checks
- **Incident response** — Azure Monitor platform with an enabled Review-mode AKS response plan

### Getting Started

1. **Open the SRE Agent Portal** — the URL is displayed in deployment output, or visit [sre.azure.com](https://sre.azure.com)
2. **Verify configuration** — check Builder > Agent Canvas, Knowledge Files
3. **Break something** — `break-oom`, `break-crash`, etc.
4. **Ask the agent to investigate** — or let the default response plan handle a matching alert
5. **Ask it to diagnose**:
   - "Why are pods crashing in the pets namespace?"
   - "Run a health check on my cluster"
   - "Trace the dependency chain — what broke first?"

### Adding GitHub Integration

To enable source code analysis and automated issue creation:

```powershell
.\scripts\configure-sre-agent.ps1 `
    -ResourceGroupName "rg-srelab-eastus2" `
    -GitHubPat $env:GITHUB_PAT `
    -GitHubRepo "owner/repo" `
    -GitHubBranch "main"
```

This repository provides infrastructure, Kubernetes manifests, automation, and
runbook context. For application service-code RCA, connect the upstream
`Azure-Samples/aks-store-demo` repository or your fork; that source code is not
vendored here. GitHub issue creation remains reviewable and scoped to the
selected repository and branch, and pull-request writes are prohibited.

See [docs/SRE-AGENT-SETUP.md](docs/SRE-AGENT-SETUP.md) for detailed instructions, or [docs/PROMPTS-GUIDE.md](docs/PROMPTS-GUIDE.md) for a full catalog of prompts to try.

## 💰 Cost Estimate

| Configuration | Daily Cost | Monthly Cost |
|--------------|------------|--------------|
| Current two-node VM compute | ~$6.62 | ~$201.48 / 730 hours |
| SRE Agent always-on baseline | ~$9.60 | ~$292.00 / 730 hours |
| VM + agent subtotal only | ~$16.22 | ~$493.48 / 730 hours |

Disks, networking, registry, logs, alerts and agent activity cost extra. This is not
a total bill or spending cap. [Stop AKS between demos](docs/COSTS.md#recommended-idle-routine)
to stop its node compute charges; do not stop its VMSS instances directly:

```powershell
.\scripts\set-lab-power.ps1 -Action Stop -WhatIf
.\scripts\set-lab-power.ps1 -Action Stop
```

The agent and retained resources continue billing while AKS is stopped. See
[docs/COSTS.md](docs/COSTS.md) for savings estimates, restart caveats and deletion choices.

### Observability

The deployment verifies recent Container Insights records in Log Analytics.
Grafana is disabled in this profile. If explicitly enabled in another reviewed
profile, the deployment also provisions the `SRE Lab - AKS Overview` dashboard.
To remove only that optional dashboard:

```powershell
.\scripts\configure-grafana.ps1 -ResourceGroupName "rg-srelab-eastus2" -Cleanup -ConfirmCleanup
```

Container Insights uses the current `ContainerLogV2` profile and verifies the
monitoring agent, DCR association, log records, and Kubernetes inventory before
deployment is considered ready.

## 🔧 Available Scenarios

| Scenario | Description | SRE Agent Diagnoses |
|----------|-------------|---------------------|
| OOMKilled | Memory limit too low | Memory exhaustion, limit recommendations |
| CrashLoop | App exits immediately | Exit codes, log analysis |
| ImagePullBackOff | Invalid image reference | Registry/image troubleshooting |
| HighCPU | Resource exhaustion | Performance analysis |
| PendingPods | Insufficient cluster resources | Scheduling analysis |
| ProbeFailure | Failing health checks | Probe configuration |
| NetworkBlock | NetworkPolicy blocking traffic | Connectivity analysis |
| MissingConfig | Non-existent ConfigMap | Configuration troubleshooting |
| MongoDBDown | Database offline, cascading failure | Dependency tracing, root cause |
| ServiceMismatch | Wrong Service selector, silent failure | Endpoint/selector analysis |

## 🛠️ Commands Reference

### Deployment Scripts (PowerShell)

> **Note**: These PowerShell scripts deploy to Azure and can be run from the dev container, locally on Windows, or on any system with PowerShell Core installed.

| Command | Description |
|---------|-------------|
| `.\scripts\deploy.ps1` | Deploy the saved Sweden Central profile after confirmation |
| `.\scripts\deploy.ps1 -CheckPrerequisitesOnly` | Check local tools without contacting Azure |
| `.\scripts\test-deployment-safety.ps1` | Run offline regression checks with mocked cloud operations |
| `.\scripts\deploy.ps1 -WhatIf` | Preview what would be deployed |
| `.\scripts\set-lab-power.ps1 -Action Status` | Inspect AKS power state without changes |
| `.\scripts\set-lab-power.ps1 -Action Stop` | Confirm and stop AKS compute; retained resources still charge |
| `.\scripts\set-lab-power.ps1 -Action Start` | Confirm and resume AKS compute |
| `.\scripts\update-demo-console.ps1` | Refresh local HTML addresses and workspace path; no cloud writes |
| `.\scripts\configure-sre-agent.ps1 -ResourceGroupName <rg>` | Configure SRE Agent (KB, agents, connectors) |
| `.\scripts\validate-deployment.ps1 -ResourceGroupName <rg>` | Verify resources and app are healthy |
| `.\scripts\run-demo-scenario.ps1 -ResourceGroupName <rg> -Scenario oom-killed` | Run, restore, and report one scenario lifecycle |
| `.\scripts\run-demo-scenario.ps1 -ResourceGroupName <rg> -Scenario crash-loop` | Run, restore, and report another scenario lifecycle |
| `.\scripts\run-demo-scenario.ps1 -ResourceGroupName <rg> -Scenario image-pull-backoff` | Run, restore, and report yet another scenario lifecycle |
| `.\scripts\destroy.ps1 -ResourceGroupName <rg>` | Tear down all infrastructure |

**Deploy script parameters:**
- `-Location`: Azure region (`eastus2`, `swedencentral`, `australiaeast`) - Default: `swedencentral`
- `-ResourceGroupName`: Default: `Az-SRE-Agent-Demo-MAT-RG`
- `-SubscriptionId`: Default: `b28cc86b-8f84-47e5-a38a-b814b44d047e`
- `-WorkloadName`: Resource prefix - Default: `srelab`
- `-SkipRbac`: Explicitly omit RBAC; not a workaround for full-lab readiness
- `-SkipSreAgent`: Explicitly deploy an incomplete core-only lab
- `-CheckPrerequisitesOnly`: Run local prerequisites and exit before authentication/deployment
- `-EnableMicrosoftLearnMcp`: Enable the credential-free Microsoft Learn MCP connector (disabled by default)
- `-WhatIf`: Preview deployment without making changes
- `-Yes`: Skip confirmation prompts (non-interactive mode)

### Kubernetes Commands (kubectl)

| Command | Description |
|---------|-------------|
| `kubectl apply -f k8s/base/application.yaml` | Deploy healthy application |
| `kubectl apply -f k8s/scenarios/<scenario>.yaml` | Apply a break scenario |
| `kubectl get pods -n pets` | Check pod status |
| `kubectl get events -n pets --sort-by='.lastTimestamp'` | View recent events |

## � SRE Agent Configuration

The `sre-config/` directory contains the SRE Agent configuration layer:

```
sre-config/
├── knowledge-base/              # Runbooks uploaded to agent memory
│   ├── aks-pod-failures.md       # OOM, CrashLoop, ImagePull, Pending, Probe, Config
│   ├── network-connectivity.md   # Network policies, selector mismatches, DNS
│   ├── dependency-failures.md    # MongoDB/RabbitMQ outages, cascading analysis
│   ├── resource-exhaustion.md    # CPU, memory, scheduling, node health
│   ├── app-architecture.md       # Service map, dependencies, monitoring queries
│   └── incident-report-template.md # Structured GitHub issue template
├── agents/                       # Custom agent YAML specifications
│   ├── incident-handler-core.yaml  # Log/metric investigation (no GitHub)
│   ├── incident-handler-full.yaml  # Full investigation + GitHub issues
│   ├── cluster-health-monitor.yaml # Proactive health checks
│   └── code-analyzer.yaml          # Source code RCA (requires GitHub)
└── connectors/
    ├── azure-monitor.yaml         # Azure Monitor incident connector
    └── github-mcp.yaml           # GitHub MCP connector template
```

## 📚 Documentation

- [Rebuild and Recovery Guide](docs/REDEPLOY.md) - verified profile, preserved fixes and acceptance checks
- [Offline Demo Console](docs/DEMO-CONSOLE.html) - presenter runbooks and website-impact icons
- [SRE Agent Setup Guide](docs/SRE-AGENT-SETUP.md) — deployment, RBAC, and configuration
- [Prompts Guide](docs/PROMPTS-GUIDE.md) — prompts, agents, knowledge base, GitHub integration
- [Breakable Scenarios Guide](docs/BREAKABLE-SCENARIOS.md)
- [Cost Estimation](docs/COSTS.md)

## 🤝 Contributing

Contributions welcome! Feel free to open issues or submit PRs.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

**⚠️ Important Notes:**

- SRE Agent is currently in **Preview**
- Only available in **East US 2**, **Sweden Central**, and **Australia East**
- AKS cluster must **NOT** be a private cluster for SRE Agent to access
- Firewall must allow `*.azuresre.ai`
