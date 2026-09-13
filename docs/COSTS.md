# Cost Estimation Guide

This document provides estimated costs for running the Azure SRE Agent Demo Lab.

## Sweden Central Profile in This Checkout

The local parameters target `Az-SRE-Agent-Demo-MAT-RG` in Sweden Central, using
subscription `b28cc86b-8f84-47e5-a38a-b814b44d047e` (Connectivity Hub - Production).
AKS manages its nodes in the separate `Az-SRE-Agent-Demo-MAT-RG-nodes` group.

| Component | Selected Configuration | Public USD Estimate |
|-----------|------------------------|---------------------|
| AKS control plane | Free | $0/hour |
| System pool | 1 x Standard_D4as_v5 | $0.184/hour |
| Workload pool | 1 x Standard_D2as_v5 | $0.092/hour |
| SRE Agent baseline | Always-on flow, excluding active usage | $0.40/hour |
| VM and agent subtotal | 730 hours/month | $493.48/month |

Prices were checked on 2026-09-13. The subtotal is **not the total bill or a spending
cap**: managed disks, Standard Load Balancer, public IPs, Basic ACR, log ingestion,
four one-minute alert rules, Key Vault operations, and active agent usage add costs.
Scheduled agent health checks also consume active usage. Trial discounts are not
assumed; see [current SRE Agent pricing](https://azure.microsoft.com/en-us/pricing/details/sre-agent/).

Both node pools have fixed counts and 32-GiB OS disks. Grafana and managed
Prometheus are disabled; Container Insights, Log Analytics, Application Insights,
alerts, and the SRE Agent remain enabled. This is a non-HA test lab, not a
production configuration. Resources carry `SecurityControl=Ignore` for this demo
environment. Key Vault purge protection is enabled with seven-day soft-delete
retention, so immediate reuse of a deleted vault name can require recovery.

Run from the cloned repository directory:

```powershell
.\scripts\deploy.ps1 -Location swedencentral -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG -Yes
```

Pause and resume AKS compute without deleting the lab:

```powershell
az aks stop --name aks-srelab --resource-group Az-SRE-Agent-Demo-MAT-RG --subscription b28cc86b-8f84-47e5-a38a-b814b44d047e
az aks start --name aks-srelab --resource-group Az-SRE-Agent-Demo-MAT-RG --subscription b28cc86b-8f84-47e5-a38a-b814b44d047e
```

Stopping AKS does **not** stop SRE Agent, scheduled tasks, disk, registry, or other
retained-resource charges. To remove the complete lab, the following command
deletes its resources and data after Azure CLI asks for confirmation. AKS also
removes its managed node group. No cleanup is run automatically.

```powershell
az group delete --name Az-SRE-Agent-Demo-MAT-RG --subscription b28cc86b-8f84-47e5-a38a-b814b44d047e
```

## Recommended Idle Routine

**Stop AKS between demos. Do not stop, resize or delete its VM scale sets directly.**
Those VMSS instances are the AKS nodes, not a second independent compute bill.
AKS Free has no control-plane fee; stopping the cluster deallocates both node pools
through the supported AKS operation.

1. Finish the investigation and use the selected HTML scenario's Restore and Verify.
2. Consider pausing agent scheduled tasks/response plans and log alerts in the portal
    during a long maintenance break. Record what you disable and reenable it before
    the next demo. The power helper deliberately does not alter these settings.
3. Preview, then stop compute. Both websites will be unavailable while stopped.

```powershell
.\scripts\set-lab-power.ps1 -Action Status
.\scripts\set-lab-power.ps1 -Action Stop -WhatIf
.\scripts\set-lab-power.ps1 -Action Stop
```

The last command asks for confirmation and checks for `Stopped` / `Succeeded`.
It never deletes the cluster, PVC or node group. Review mode, closing the agent
page, and `-SkipScheduledTasks` do not stop the SRE Agent's always-on charge.

### What this saves

| Usage pattern | VM compute / 730-hour month | SRE baseline / month | Subtotal, before all other charges |
|---------------|----------------------------|----------------------|-----------------------------------|
| Both running all month | $201.48 | $292.00 | $493.48 |
| AKS runs 176 hours (8 hours x 22 days) | $48.58 | $292.00 | $340.58 |
| AKS runs 40 demo hours | $11.04 | $292.00 | $303.04 |
| AKS stopped for the entire month, agent retained | $0.00 | $292.00 | $292.00 |

Each stopped AKS hour saves about **$0.276** in node compute, or **$6.62 per full
day**. Stopping AKS alone does not make the lab free: the agent baseline is about
**$9.60/day**, and disks, public IPs, load balancing, ACR, logs, alert rules and
agent activity can still charge. Disabling optional automation can reduce active
usage, but do not budget it as eliminating the agent baseline.

A scoped Cost Management query on 2026-09-13 returned **no posted cost rows** for
either lab group. That is not proof of zero charges; the deployment was new and
billing data can lag. These figures use public USD estimates, not an account-specific
invoice. The pricing site advertises trial offers, but eligibility was not verified.

### Resume before the next demo

```powershell
.\scripts\set-lab-power.ps1 -Action Start -WhatIf
.\scripts\set-lab-power.ps1 -Action Start
```

Follow [the resume and acceptance checks](REDEPLOY.md#resume-an-existing-lab)
before presenting. Microsoft recommends **15-30 minutes between stopping and
restarting**. Restart releases/reacquires capacity and can fail during a regional
shortage, so start ahead of the demo. The API IP can change; refresh credentials
and run the console updater rather than trusting saved links. AKS keeps stopped
cluster state for up to 12 months, not indefinitely. Managed disk data is retained,
but ephemeral container data and standalone pods are not a backup.

### Longer breaks and cost controls

- For weeks without demos, removing the SRE Agent or the whole lab saves more than
   stopping AKS alone. Treat deletion as a separate, destructive decision: exported
   runbooks/configuration can be recreated, but learned agent context, live data and
   portal-only settings are not recovered automatically. Use [the rebuild guide](REDEPLOY.md).
- Full resource-group deletion removes the AKS-managed node group as part of AKS
   deletion. Do not independently delete that node group. Confirm completion and
   inspect retained/soft-deleted resources and delayed charges afterward.
- Key Vault purge protection blocks immediate purge. A same-name rebuild may require
   recovering the deleted vault with authorized access. Do not disable protection
   or force a purge to speed up deployment.
- Set budget notifications for **both** lab resource groups. Budgets notify; they
   are not a spending cap and do not stop compute. No notification recipient or
   budget was configured by this change.
- A calendar reminder is the simplest way to avoid leaving the lab running. For
   automation, use an approved scheduler with an identity authorized only to read,
   stop and start this cluster. No scheduled shutdown has been installed here.
- Avoid new reservations, savings-plan commitments, Spot nodes or a smaller system
   pool for this occasional-use demo without a separate assessment. Stop/start gives
   savings without changing the verified application capacity or fault behavior.

Sources: [supported AKS stop/start behavior](https://learn.microsoft.com/en-us/azure/aks/start-stop-cluster)
and [SRE Agent billing](https://azure.microsoft.com/en-us/pricing/details/sre-agent/).

## Historical Upstream Estimates

> **Archive only:** The estimates and SKU/free-tier recommendations below describe the original larger East US 2 configuration using 2024 pricing. Do not use them to size, price or redeploy this checkout; the Sweden Central profile above and [rebuild guide](REDEPLOY.md) take precedence.

## Quick Cost Summary

| Component | Daily Cost | Monthly Cost | Notes |
|-----------|------------|--------------|-------|
| **AKS Control Plane** | ~$2.40 | $73 | Standard tier with SLA |
| **AKS Nodes (System)** | ~$4.70 | ~$140 | 2x Standard_D2s_v5 |
| **AKS Nodes (User)** | ~$7.00 | ~$210 | 3x Standard_D2s_v5 |
| **Container Registry** | ~$0.17 | ~$5 | Basic tier |
| **Log Analytics** | ~$1-2 | ~$30-50 | Based on data ingestion |
| **Application Insights** | ~$0.30-0.70 | ~$10-20 | Based on data volume |
| **Managed Grafana** | ~$2.50 | ~$75 | Standard tier |
| **Azure Monitor (Prometheus)** | ~$0.50 | ~$15 | Based on metrics volume |
| **Azure Monitor log alerts** | Usage-based | Varies | Four 1-minute rules enabled by default |
| **Key Vault** | ~$0.10 | ~$3 | Minimal operations |
| **SRE Agent** | ~$10-13 | ~$292-400 | Base + execution costs |
| **Total (without SRE Agent)** | **~$22-28** | **~$650-850** | |
| **Total (with SRE Agent)** | **~$32-38** | **~$950-1,150** | |

## Detailed Cost Breakdown

### Azure Kubernetes Service (AKS)

#### Control Plane
- **Free Tier**: $0/month (no SLA, limited features)
- **Standard Tier**: $73/month (SLA, recommended for demos)
- **Premium Tier**: $438/month (LTS support)

**Recommendation:** Use Standard tier for demos to have SLA coverage.

#### Node Pools

| Node Pool | VM Size | Count | Unit Cost | Monthly Cost |
|-----------|---------|-------|-----------|--------------|
| System | Standard_D2s_v5 | 2 | $70.08/month | $140.16 |
| User | Standard_D2s_v5 | 3 | $70.08/month | $210.24 |

**Cost-Saving Options:**
- Use `Standard_D2as_v5` (AMD) for ~10% savings
- Reduce node count during non-demo hours
- Use Reserved Instances for 30-55% savings (if running long-term)
- Use Spot instances for non-critical workloads

### Azure Container Registry

| SKU | Storage | Cost | Notes |
|-----|---------|------|-------|
| Basic | 10 GB | $5/month | Sufficient for demos |
| Standard | 100 GB | $20/month | If storing many images |

### Log Analytics Workspace

Cost is based on data ingestion:

| Data Volume | Cost |
|-------------|------|
| First 5 GB/month | Free |
| Additional data | $2.30/GB |

**Expected usage for demo:** 1-3 GB/day = $0-50/month

**Cost-Saving Options:**
- Set retention to 30 days (minimum)
- Filter unnecessary log types
- Use commitment tiers for predictable workloads

### Application Insights

| Component | Pricing |
|-----------|---------|
| Data ingestion | $2.30/GB |
| First 5 GB/month | Free |

**Expected usage for demo:** ~$10-20/month

### Azure Managed Grafana

| Tier | Cost | Features |
|------|------|----------|
| Essential | $0 | Basic dashboards |
| Standard | $75/month | Full features, RBAC |

**Recommendation:** Standard tier for proper demo experience.

### Azure Monitor (Prometheus)

| Component | Pricing |
|-----------|---------|
| Metrics ingestion | $0.18/million samples |
| Query | $0.30/million samples queried |

**Expected usage for demo:** ~$10-20/month

The standard deployment also creates four log search alert rules evaluated every
minute. Alert-rule charges are usage-based and vary by region; check the current
Azure Monitor pricing page when estimating a long-running lab.

### Key Vault

| Operation | Price |
|-----------|-------|
| Secrets operations | $0.03/10,000 |
| Keys operations | $0.03/10,000 |
| Storage | Included |

**Expected usage for demo:** ~$3/month

### Azure SRE Agent

SRE Agent uses Azure AI Units (AAU) billing:

| Component | Calculation | Cost |
|-----------|-------------|------|
| Base compute | 4 AAU × 730 hours × $0.10 | $292/month |
| Execution | Variable based on usage | $30-100/month |

**Total SRE Agent cost:** ~$322-400/month

## Cost Optimization Strategies

### For Development/Testing

1. **Delete when not in use**
   ```powershell
   .\scripts\destroy.ps1
   ```

2. **Scale down nodes**
   ```bash
   az aks nodepool scale --resource-group rg-srelab-eastus2 \
       --cluster-name aks-srelab-dev --name workload --node-count 1
   ```

3. **Use spot instances** for user node pool

4. **Disable optional components**
   - Set `deployObservability = false` to skip Grafana/Prometheus

### For Sustained Usage

1. **Azure Reservations**
   - 1-year: ~31% savings on VMs
   - 3-year: ~53% savings on VMs

2. **Savings Plans**
   - Commit to hourly spend for discounts

3. **Right-size VMs**
   - Monitor actual usage and adjust

## Cost by Deployment Configuration

### Minimal Configuration (~$450/month)
- AKS Standard + 2 nodes
- Basic ACR
- Log Analytics (minimal retention)
- Essential Grafana (free tier)

### Standard Configuration (~$750/month)
- AKS Standard + 4 nodes
- Basic ACR
- Log Analytics
- App Insights
- Standard Grafana

### Full Demo Configuration (~$1,000/month)
- Everything enabled
- Standard Grafana + Prometheus
- Best for comprehensive demos
- Includes SRE Agent costs

## Monitoring Costs

Use Azure Cost Management to track spending:

1. Go to **Cost Management + Billing** in Azure Portal
2. Create a **Budget** with alerts
3. Set up **Cost alerts** at 50%, 75%, 100%
4. Review **Cost analysis** regularly

### Sample Budget Alert

```powershell
# Create budget via CLI
az consumption budget create `
    --budget-name "sre-demo-budget" `
    --amount 500 `
    --time-grain Monthly `
    --category Cost `
    --resource-group rg-srelab-eastus2
```

## Free Tier Resources

Take advantage of Azure Free Tier:

| Service | Free Amount |
|---------|-------------|
| Log Analytics | 5 GB/month ingestion |
| App Insights | 5 GB/month |
| Key Vault | 10,000 operations |
| Managed Grafana | Essential tier (basic features) |

## When to Consider Alternatives

### If cost is critical:
- Use **Azure Container Apps** instead of AKS (~50% cheaper)
- Use **App Service** for simpler demos
- Use **local Kubernetes** (minikube/kind) for development

### If you need more power:
- Scale up VM sizes
- Add more nodes
- Enable zone redundancy

## Summary

| Scenario | Monthly Cost |
|----------|--------------|
| Run demo for 1 hour | ~$2-3 |
| Run demo for 1 day | ~$30-40 |
| Always-on development | ~$750-1,100 |
| With all optimizations | ~$400-500 |

**Recommended approach:** Deploy when needed, destroy after demos, use minimal config for testing.
