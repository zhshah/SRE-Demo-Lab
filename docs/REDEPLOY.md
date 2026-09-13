# Rebuild the Verified Sweden Central Demo

This is the rebuild and handover guide for the lab verified on **2026-09-13**.
Use this checkout, including its local changes, rather than a new unmodified clone
of upstream. The upstream repository does not automatically contain these fixes.
No commit, push, resource deletion, or new deployment is implied by this guide.

Start here when returning to the lab:

| Situation | Action |
|-----------|--------|
| Finished a demo for today | Restore the active scenario, then follow [AKS pause instructions](COSTS.md#recommended-idle-routine). |
| AKS was stopped | Use [Resume an existing lab](#resume-an-existing-lab). Do not redeploy a stopped cluster. |
| Resources were deleted | Use [Fresh deployment](#fresh-deployment). Data and agent history are not restored by IaC. |
| Infrastructure succeeded but a later step failed | Use [Resume a partial deployment](#resume-a-partial-deployment). |
| Public IP or workspace path changed | Run [update-demo-console.ps1](../scripts/update-demo-console.ps1), then reload the HTML. |

## Verified Profile

| Setting | Saved value |
|---------|-------------|
| Subscription | Connectivity Hub - Production / `b28cc86b-8f84-47e5-a38a-b814b44d047e` |
| Tenant | `8d7622f8-d815-4120-b5b8-bee841c23a1c` |
| Location | `swedencentral` |
| Resource group | `Az-SRE-Agent-Demo-MAT-RG` |
| AKS-managed group | `Az-SRE-Agent-Demo-MAT-RG-nodes` |
| AKS / namespace | `aks-srelab` / `pets` |
| Control plane | Free, public API, Calico network policy |
| System pool | One `Standard_D4as_v5`, 32-GiB managed OS disk |
| Workload pool | One `Standard_D2as_v5`, 32-GiB managed OS disk |
| Autoscaling | Disabled on both pools |
| ACR / Key Vault | Basic / Standard, purge protection and seven-day soft-delete retention |
| MongoDB storage | Existing `mongodb-data-pvc`, 8 GiB, StandardSSD_LRS |
| Monitoring | Container Insights, Log Analytics, Application Insights, four one-minute log alerts |
| Optional monitoring | Grafana and managed Prometheus disabled |
| SRE Agent | `sre-srelab`, Review mode, runbooks, custom agents, connectors, scheduled tasks |
| Required tag | `SecurityControl=Ignore` on resources and both groups; this is a lab-specific policy accommodation |

The source of truth is [main.bicepparam](../infra/bicep/main.bicepparam), the
[Bicep modules](../infra/bicep/main.bicep), [application manifest](../k8s/base/application.yaml),
and [SRE configuration](SRE-AGENT-SETUP.md). The two nodes consume six baseline
vCPUs; allow extra quota/capacity for AKS upgrades rather than changing VM sizes
or enabling autoscaling without approval.

The original baseline had two Ready nodes, twelve Ready application pods and a
Bound MongoDB claim. `virtual-worker` deliberately has **zero replicas**. Pending
orders alone do not prove an outage. The public sites use HTTP and demo credentials;
use test data only, not production information.

## Fresh Deployment

Run commands from the repository root in **PowerShell 7**, not Windows PowerShell
5.1. On the original machine the root is:

```powershell
Set-Location 'C:\Zahir_Repository\SRE-Demo-Lab-MAT-MS\azure-sre-agent-sandbox'
```

### 1. Verify local tools

Install Azure CLI, its Bicep compiler, kubectl, PowerShell 7, the curl executable,
and Python with PyYAML. The original successful host used Azure CLI 2.81.0,
Bicep 0.39.26 and Python 3.12.10 ARM64 with PyYAML 6.0.3. These are recorded
versions, not promises that old tools will remain supported forever.

```powershell
az bicep version
python --version
python -c "import yaml; print(yaml.__version__)"
.\scripts\deploy.ps1 -CheckPrerequisitesOnly
.\scripts\test-deployment-safety.ps1
```

If Bicep or PyYAML is missing, install it explicitly, then rerun the checks:

```powershell
az bicep install
python -m pip install --user PyYAML==6.0.3
```

Use the interpreter reported by the prerequisite check if it is not `python`.
The Windows Store `python3` alias can exist on PATH but exit with code 9009.
Runtime selection actually executes `--version`, falls back to working Python,
and tests `import yaml` before creating any Azure resources. A native ARM64
compiler toolchain, Docker daemon, Node.js, and azd are not needed for this recipe.

### 2. Select identity and subscription

```powershell
az login --tenant 8d7622f8-d815-4120-b5b8-bee841c23a1c --use-device-code
az account set --subscription b28cc86b-8f84-47e5-a38a-b814b44d047e
az account show --query '{subscription:id,name:name,tenant:tenantId}' --output table
```

The deploy script explicitly selects and verifies its `-SubscriptionId` too.
The individual recovery/verifier scripts use the current Azure CLI account, so
select the subscription before running them separately. Contributor alone cannot
create role assignments: the deploying identity also needs authorized role-assignment
permissions, for example Owner or Contributor plus User Access Administrator.
Do not grant broader permissions as a workaround for a failed deployment.

### 3. Preview and check blockers

```powershell
.\scripts\deploy.ps1 -WhatIf
```

This compiles the Bicep deployment and requests Azure's what-if analysis. It does
not apply resources or register providers. It can select the local CLI subscription
and request authentication if necessary. Read all proposed changes; an existing
lab need not produce an empty diff. Do not interpret `Ignore`/unexpanded resources
as proof that their configuration is unchanged.

Check before proceeding:

- `Microsoft.App` is registered and exposes `agents@2025-05-01-preview` for the
  target subscription. Missing SRE support now stops deployment; it is no longer
  silently replaced by a core-only lab.
- The two VM SKUs and sufficient DASv5-family/regional quota remain available in
  Sweden Central. Availability verified on the original day is not a capacity reservation.
- Policy accepts the saved tags and public demo endpoints. Retain the tags in IaC,
  not just in the portal.
- The named resource groups do not contain unrelated workloads. Never repurpose
  another team's resource group or subscription.
- A vault with the generated name is not awaiting recovery from an earlier deletion.
  See the Key Vault recovery notes below.
- If the cluster already exists, it is Running and not mid-upgrade, start or stop.
  Restore any active fault and remove its scenario-only objects before redeploying.

If provider registration is needed, this is an explicit subscription change:

```powershell
az provider register --namespace Microsoft.App --subscription b28cc86b-8f84-47e5-a38a-b814b44d047e --wait
```

Do not use `-SkipRbac` or `-SkipSreAgent` to claim the full lab is ready. Those
switches deliberately omit required parts of this profile. Changing region,
resource names, architecture or capacity requires a new review, including the
console's profile-specific reference text.

### 4. Deploy the reviewed profile

```powershell
.\scripts\deploy.ps1 -Location swedencentral -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG -SubscriptionId b28cc86b-8f84-47e5-a38a-b814b44d047e
```

The script prompts for confirmation; `-Yes` is available for an already-approved
noninteractive run. Defaults select the same profile. The original infrastructure
creation took 9 minutes 28 seconds, followed by application/configuration checks;
allow more time for image pulls, IAM propagation and log ingestion on future runs.

The deployment applies scoped RBAC, tags generated Application Insights alerts,
retrieves AKS credentials, applies the baseline, waits for rollouts, validates the
application, configures and verifies SRE Agent, checks telemetry, and refreshes the
offline console's endpoints and repository path. Failures stop the success path.
The console refresh does not execute a fault, submit an order, or clear browser state.

### 5. Acceptance checks

```powershell
.\scripts\validate-deployment.ps1 -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG
.\scripts\verify-sre-agent-configuration.ps1 -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG
.\scripts\verify-telemetry.ps1 -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG -Attempts 1
.\scripts\update-demo-console.ps1
kubectl --context aks-srelab get nodes
kubectl --context aks-srelab get pods,pvc,services -n pets
```

Require successful verifier exit codes, the intended pool sizes, Ready baseline
workloads, a Bound MongoDB claim, assigned public IPs, recent telemetry, and
Review-mode agent configuration. A one-attempt telemetry failure can be ingestion
delay; inspect the output and retry verification, not infrastructure creation.

Open [DEMO-CONSOLE.html](DEMO-CONSOLE.html). Prepare prints the current storefront
and admin URLs. Check product loading and, with test data, a checkout and the
corresponding order behavior. HTTP 200 and green pods alone are insufficient.
For an incident-routing demo, separately confirm a new Azure Monitor alert and a
new SRE Agent incident from the same injection. A successful scenario runner or
configuration verifier is not evidence of end-to-end incident delivery.

## Resume an Existing Lab

First confirm enough time has elapsed since stop: Microsoft recommends waiting
15-30 minutes before starting again. Start may fail if regional capacity is unavailable.

```powershell
.\scripts\set-lab-power.ps1 -Action Status
.\scripts\set-lab-power.ps1 -Action Start
az account set --subscription b28cc86b-8f84-47e5-a38a-b814b44d047e
az aks get-credentials --name aks-srelab --resource-group Az-SRE-Agent-Demo-MAT-RG --subscription b28cc86b-8f84-47e5-a38a-b814b44d047e --context aks-srelab --overwrite-existing
```

Then run the acceptance checks above. Refresh the console and reload the browser;
API hostnames or public endpoints may have changed. Reenable any scheduled tasks,
response plans or alert rules you intentionally paused. Do not automatically
reapply the baseline over a demo you still need to investigate.

## Resume a Partial Deployment

Keep the deployment name and error message. If ARM succeeded but SRE configuration
or telemetry failed, the resources already exist and are billing. Repair the failing
step instead of deleting the lab or rerunning everything.

Select the subscription first, then use the relevant operation:

| Failed stage | Targeted action |
|--------------|-----------------|
| AKS credentials or application rollout | Refresh credentials; inspect the named rollout, events, current fault and existing PVC. Use the console's Restore only when ready to reset. |
| RBAC | Correct the deployer's authorized permissions/policy. Rerun `configure-rbac.ps1` with the **current** SRE identity principal ID, not the old deployment's ID. |
| Agent runbooks, custom agents, connectors or response plan | Rerun `configure-sre-agent.ps1`, then its verifier. |
| Telemetry | Inspect AMA pods/DCR and rerun `verify-telemetry.ps1`; account for ingestion delay. |
| Saved HTML links/path | Run `update-demo-console.ps1`; no infrastructure deployment is needed. |

The original post-configuration failure was recovered with:

```powershell
.\scripts\configure-sre-agent.ps1 -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG
.\scripts\verify-sre-agent-configuration.ps1 -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG
.\scripts\verify-telemetry.ps1 -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG -Attempts 1
```

For an RBAC-only retry, read the principal from the successful deployment's output
using its actual deployment name. Do not reuse saved output after resource recreation:

```powershell
$deploymentName = Read-Host 'Successful infrastructure deployment name'
$agentPrincipalId = az deployment sub show --name $deploymentName --subscription b28cc86b-8f84-47e5-a38a-b814b44d047e --query properties.outputs.sreAgentManagedIdentityPrincipalId.value --output tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($agentPrincipalId)) { throw 'No current agent principal was returned.' }
.\scripts\configure-rbac.ps1 -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG -SreAgentPrincipalId $agentPrincipalId
```

## Fixes Preserved in Source

| Issue or lesson | Durable implementation / rule |
|-----------------|-------------------------------|
| Region/RG mismatch | The Bicep and script defaults select Sweden Central and the named demo group; the script explicitly selects the approved subscription. |
| Unexpected compute cost | Free AKS, one D4as_v5 plus one D2as_v5, 32-GiB OS disks, no autoscaling, no optional Grafana/Prometheus. |
| Demo endpoints disabled by tenant policy | `SecurityControl=Ignore` retained in Bicep resource/group tags, node-pool tags, and the MongoDB StorageClass. Not a production security recommendation. |
| Automatically generated alert lacked the required tag | `deploy.ps1` merges the tag onto generated Application Insights smart-detector alerts. |
| Windows Store Python alias | Executable version probe and working-runtime fallback, plus early PyYAML import check. |
| Connector PUT failed with HTTP 415 | `configure-sre-agent.ps1` uses PowerShell HTTP, explicit `application/json`, structured JSON, and an ARM token kept in memory. Do not return to native inline JSON quoting or print tokens. |
| Native command error looked like success | Explicit Azure CLI exit checks, fail-fast RBAC, guarded AKS credentials, and required verifier exits. |
| Agent permissions were broader than needed | Agent Reader is limited to the managed node group; other management/Kubernetes assignments stay within the lab. No subscription-wide Reader workaround. |
| Deleted Key Vault name blocked rebuild | Purge protection and seven-day retention retained; automatic purge removed. Recover the original vault with authorization, or wait/plan a reviewed rename. Never force-purge to make a retry pass. |
| Image tags could change between deployments | Eight active baseline images are pinned to observed digests. OOM, startup-crash and MongoDB replacement manifests use the same digests. The invalid-image scenario remains deliberately invalid. |
| Fixed HTML addresses/path | Post-deployment console refresh reads current metadata, verifies kubectl's API hostname, and rewrites only embedded data; scenario content and layout are preserved. |
| Fault leftovers survive baseline apply | Explicitly remove scenario-only Deployments/NetworkPolicy using the selected Restore stage. Baseline apply is not a universal delete/reset. |
| `oomkilled` runner argument failed | Use the exact identifier `oom-killed` with named `-ResourceGroupName` and `-Scenario` arguments. The runner automatically restores; use the manual HTML sequence for a paced agent demo. |

## Deliberate Boundaries

- The empty `ag-srelab` action group has no email or webhook receivers. This is
  not notification readiness. The native Azure Monitor connector and Review-mode
  response plan are separate. Configure a receiver only after an authorized
  destination is supplied; save that change in IaC too.
- Outlook email requires portal consent. GitHub PAT integration and Microsoft
  Learn MCP are optional and were not enabled in the verified baseline.
- `-SkipScheduledTasks` skips creation; it does **not** disable existing schedules
  or eliminate SRE Agent always-on charges.
- Image digests reproduce the observed **Linux AMD64** application, not arbitrary
  architectures. `virtual-worker` is deliberately stopped and remains version-tagged;
  synthetic fault images retain their existing tags. Digest pinning is not a security
  update or a guarantee of permanent public-registry availability. MongoDB 4.4 is
  an old demo dependency, not a production recommendation.
- Kubernetes patch versions and node images can advance through the existing stable
  upgrade policy. The observed 1.35.7/AzureLinuxV3 state is evidence, not a promise
  that a future service will accept the same version forever.
- The repository is **not a backup** of MongoDB contents, RabbitMQ queues, agent
  investigation history, portal-only edits, or browser notes/checkpoints. Export
  anything important before deletion. Stop/start can discard ephemeral pod data.
- Keep all modified source plus the new scripts, this guide and the HTML when
  transferring the checkout. Generated deployment outputs, evidence, local Azure
  state and secrets are not substitutes for source and should not be published.

## Validation Record

The initial live deployment passed 32/32 application checks, SRE configuration and
telemetry verifiers, both website HTTP checks, and an audit of required tags and
agent role scopes. The local safety suite now checks failure paths using mocks;
it does not stop/start real AKS. Eight image digests were compared with current Ready
containers and four edited manifests passed Kubernetes client-side dry-run checks.

Additional handover checks on 2026-09-13:

| Check | Result |
|-------|--------|
| Offline deployment safety suite | 49 checks passed, including native failures, target guards, mocked power operations and console data preservation. |
| Local prerequisites | Passed with the installed Python 3.12 ARM64 interpreter and PyYAML. |
| Saved deployment entry point | `deploy.ps1 -WhatIf` passed using the intended subscription, RG and Sweden Central defaults. |
| Infrastructure readiness | Bicep compilation, ARM validation and what-if passed. Two existing AKS DCR-association compiler warnings remain nonblocking. |
| Policy and role review | No deployment-blocking policy error; the inherited enforced deny targets Classic resource types. Existing lab-scoped roles were reviewed, not changed. This is not a full security compliance audit. |
| Live helper discovery | Power `Status` returned Running/Succeeded; console updater `-WhatIf` confirmed current endpoints without writing HTML. |
| Documentation | 26 PowerShell examples parsed and 29 relative links resolved; examples were not executed. |

The structured infrastructure preview contained **0 resource creates, 0 deletes,
13 modifications, 10 unchanged and 1 ignored resource**. Omitted service-populated
properties and unresolved ARM references appear in those modifications; this is
not a no-op guarantee. The ignored resource was the generated Application Insights
smart-detector alert, whose tagging remains a post-deployment step. Review the
next preview before applying it.

Count resource changes from JSON `changes[].changeType`, not `+`/`-` lines in the
pretty-printed preview: property removals are not resource deletions. On this host,
Azure CLI can print a `Bicep CLI is already installed...` status line before JSON;
exclude that known status line before parsing, and fail on any other invalid output.

A new destructive rebuild and every fault's end-to-end agent remediation have
**not** been repeated just to validate this handover. Run the acceptance checks
each time. This is a tested recovery path, not a 100% guarantee against future
Azure quota, policy, permissions, service/API or registry changes.

References: [AKS stop/start](https://learn.microsoft.com/en-us/azure/aks/start-stop-cluster),
[SRE Agent pricing](https://azure.microsoft.com/en-us/pricing/details/sre-agent/),
[cost and shutdown guide](COSTS.md), [scenario console](DEMO-CONSOLE.html).