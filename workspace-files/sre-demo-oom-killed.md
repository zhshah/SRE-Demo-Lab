# SRE Demo Desk: Out of memory

Scenario: oom-killed
Scope: Az-SRE-Agent-Demo-MAT-RG / aks-srelab / pets / Sweden Central
Offline runbook. No live status or automatic command execution.

The scenario replaces order-service with a 16Mi memory limit. Its containers may be terminated as they exceed that limit.

## 1. Prepare

Select the approved subscription and cluster, then verify the existing app. Stop if validation fails or an earlier scenario is still active.

Caution: Context commands change your local CLI selection, not Azure resources. Continue only after the API hostname and healthy baseline are confirmed.

### PowerShell / select the lab
```powershell
Set-Location 'C:\Zahir_Repository\SRE-Demo-Lab-MAT-MS\azure-sre-agent-sandbox\scripts'
az account set --subscription b28cc86b-8f84-47e5-a38a-b814b44d047e
kubectl config use-context aks-srelab
kubectl --context aks-srelab config view --minify -o jsonpath='{.clusters[0].cluster.server}'
```
Expected API hostname: aks-srelab-tuu2g03m.hcp.swedencentral.azmk8s.io. The ResourceGroupName parameter alone does not select kubectl's target.

### Current nodes and deployment health
```powershell
kubectl --context aks-srelab get nodes
kubectl --context aks-srelab get deployments,pods,networkpolicies -n pets
& 'C:\Zahir_Repository\SRE-Demo-Lab-MAT-MS\azure-sre-agent-sandbox\scripts\validate-deployment.ps1' -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG
```
Expected baseline: 2 Ready nodes, healthy baseline deployments, and no scenario-only resources. virtual-worker intentionally has 0 replicas. Pod counts can briefly vary during rollout.

## 2. Inject

The scenario replaces order-service with a 16Mi memory limit. Its containers may be terminated as they exceed that limit.

Caution: This changes an existing application resource. Restore by reapplying the baseline, not by deleting the scenario manifest.

### PowerShell / apply oom-killed
```powershell
Get-Date -Format o
kubectl --context aks-srelab apply -f 'C:\Zahir_Repository\SRE-Demo-Lab-MAT-MS\azure-sre-agent-sandbox\k8s\scenarios\oom-killed.yaml'
```
Record the injection time. This command changes the deployed lab; copying it here does not execute it.

## 3. Observe

Keep the fault active while collecting fresh evidence. A pod status alone is not a diagnosis. Compare event and restart times with your injection.

Caution: Old restart counts do not establish a new OOM failure. Look at the last termination reason and timestamps. Previous logs may be unavailable before the first restart.

### Pod status / watch
```powershell
kubectl --context aks-srelab get pods -n pets -l app=order-service -w
```
Ctrl+C stops the watcher only. It does not remove the fault or restore the app.

### Termination reason and limits
```powershell
kubectl --context aks-srelab describe pods -n pets -l app=order-service
```


### Recent namespace events
```powershell
kubectl --context aks-srelab get events -n pets --sort-by=.lastTimestamp
```


### Previous container logs
```powershell
kubectl --context aks-srelab logs -n pets -l app=order-service --previous --tail=60 --prefix=true
```


## 4. Ask SRE

Open sre-srelab, keep the fault active, and begin a scoped investigation. Review the evidence and proposed change before approving any remediation.

Caution: Manual chat is the reliable presenter path. Automatic alert ingestion and incident processing are separate stages and can lag; they are not guaranteed for every scenario.

Scope: subscription b28cc86b-8f84-47e5-a38a-b814b44d047e (Connectivity Hub - Production), resource group Az-SRE-Agent-Demo-MAT-RG, Sweden Central, AKS aks-srelab, namespace pets.

Inspect recent termination reasons, exit codes, memory requests and limits, events, and previous container logs for order-service. Distinguish OOMKilled from an application crash and correlate the evidence with this injection.

Use fresh evidence from the last 10 minutes and distinguish earlier restarts from this demo. Remain in Review mode. Explain root cause, cite the evidence, and propose a minimal fix before any write action. Do not change node counts, VM sizes, autoscaling, permissions, or resources outside this lab. Do not reveal secrets.

## 5. Restore

Reapply the known-good application specification. This restores baseline resource settings and waits for the affected deployments.

Caution: Do not leave intentional failures running unattended. Do not run cleanup concurrently with an investigation you still need.

### PowerShell / scenario-specific recovery
```powershell
kubectl --context aks-srelab apply -f 'C:\Zahir_Repository\SRE-Demo-Lab-MAT-MS\azure-sre-agent-sandbox\k8s\base\application.yaml'
kubectl --context aks-srelab rollout status deployment/order-service -n pets --timeout=300s
```
A successful apply is not a health check. Continue to Verify and confirm application behavior.

## 6. Verify

Check the affected resources, validate the whole application, and exercise the user flow. Old Warning events can remain after a successful recovery.

Caution: Open the storefront and confirm the relevant application flow. For MongoDB, inspect fulfillment and database connectivity, not just the landing page.

### Affected resource state
```powershell
kubectl --context aks-srelab get pods -n pets -l app=order-service
```


### Whole-lab validation
```powershell
& 'C:\Zahir_Repository\SRE-Demo-Lab-MAT-MS\azure-sre-agent-sandbox\scripts\validate-deployment.ps1' -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG
```


On aks-srelab in Az-SRE-Agent-Demo-MAT-RG, verify recovery of the oom-killed demo in pets. Check current readiness, fresh events, the affected service path, and any remaining scenario-only resources. Report residual issues without making changes.

## Presenter notes

No notes recorded.

## Checkpoints (presenter-entered, not live telemetry)
- [ ] Baseline confirmed
- [ ] Fault applied manually
- [ ] Fresh evidence captured
- [ ] Investigation reviewed
- [ ] Cleanup performed
- [ ] Recovery verified

## Reference
https://github.com/matthansen0/azure-sre-agent-sandbox
