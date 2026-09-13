# Azure SRE Agent Demo Deployment

## 1. Status

Deployed and verified. The user approved preparation and deployment of this profile.

Local cost/rebuild hardening status: **Validated** on 2026-09-13 using the
azure-validate workflow. This covers local checks and a read-only deployment
preview, not a new deployment or a live stop/start test. The existing lab remains
Running; no resource mutations were performed for the hardening request.

Deployment name: `sre-demo-20260913-151830`.

Infrastructure succeeded in 9 minutes 28 seconds. The initial script stopped during
SRE Agent configuration; the local runtime and connector transport issues were
fixed, and targeted configuration plus both post-deployment verifiers passed.

## 2. Scope

- Source: https://github.com/matthansen0/azure-sre-agent-sandbox
- Deployment recipe: existing PowerShell scripts and subscription-scoped Bicep (Azure CLI).
- Subscription: Connectivity Hub - Production (`b28cc86b-8f84-47e5-a38a-b814b44d047e`).
- Tenant: `8d7622f8-d815-4120-b5b8-bee841c23a1c`.
- Region: `swedencentral` only. Do not substitute another region.
- Resource group: `Az-SRE-Agent-Demo-MAT-RG`.
- AKS-managed node resource group: `Az-SRE-Agent-Demo-MAT-RG-nodes`.
- Required tag on resources and resource groups: `SecurityControl=Ignore`.
- Preserve the upstream application, runbooks, break scenarios, and review-mode incident handling.
- Scope agent management permissions to the lab; grant Reader only on the AKS-managed node group, not the subscription.
- Enable Key Vault purge protection with seven-day soft-delete retention. Never automatically purge an existing deleted vault.

## 3. Cost Profile

- AKS Free control plane; one system node and one workload node.
- System node: `Standard_D4as_v5` (4 vCPUs, 16 GiB), USD 0.184/hour.
- Workload node: `Standard_D2as_v5` (2 vCPUs, 8 GiB), USD 0.092/hour.
- Both SKUs are available without subscription restrictions in Sweden Central.
- Use 32-GiB managed OS disks instead of the larger default disks.
- Disable node autoscaling to prevent break scenarios from increasing compute spend.
- Keep Basic Container Registry, Standard Key Vault, Log Analytics, Application Insights, alerts, and SRE Agent.
- Omit the optional Managed Grafana and managed Prometheus stack.
- VM subtotal: USD 0.276/hour, or USD 201.48 for 730 hours.
- Published SRE Agent always-on baseline: USD 0.40/hour, or USD 292 for 730 hours.
- Combined VM and agent baseline: USD 493.48/month, before disks, load balancer, public IPs, ACR, logs, alerts, and active agent usage. This is not a total-cost cap.
- Do not assume eligibility for SRE Agent trial credits or waived always-on charges.
- Prices are public USD Linux pay-as-you-go estimates retrieved on 2026-09-13, not an account-specific quote.
- Validate the one-node system pool as a dev/test configuration. If Azure requires a larger layout, stop for approval before increasing spend.

## 4. Preparation

- [x] Clone the upstream repository without replacing existing workspace content.
- [x] Verify the active Azure subscription.
- [x] Add a configurable resource-group name to Bicep.
- [x] Compile the initial Bicep change successfully.
- [x] Complete the low-cost parameter profile and deployment script support.
- [x] Verify Microsoft.App is registered and SRE Agent supports Sweden Central.
- [x] Verify compute quota and SKU availability.
- [x] Verify the lab and managed-node group names do not already exist.
- [x] Verify remaining service limits and required permissions through Azure validation.
- [x] Present the final cost and deployment scope for approval; user selected "Yes, prepare and deploy this profile".

## 5. Deployment

- [x] Run Bicep compilation and focused PowerShell validation.
- [x] All validation checks pass:
	- [x] Core validation: Azure CLI, authentication, Bicep build, Azure validate, and what-if via the Bicep validation helper.
	- [x] Optional linting: compiler diagnostics reviewed; two pre-existing nonblocking AKS association warnings.
	- [x] Azure Policy validation for the selected subscription and tagged resources.
	- [x] RBAC assignment scopes and deployer permissions verified.
- [x] Run Azure deployment validation and what-if.
- [x] Deploy infrastructure using the reviewed parameters.
- [x] Configure scoped RBAC, apply the existing Kubernetes application, and configure SRE Agent.

## 6. Verification

- [x] Confirm resource provisioning, region, SKUs, and tags.
- [x] Verify live AKS profile: Sweden Central, Free tier, D4as_v5 system node, D2as_v5 workload node, 32-GiB OS disks, autoscaling disabled.
- [x] Verify the lab group and AKS-managed node group both carry SecurityControl=Ignore.
- [x] Verify AKS nodes and application workloads are healthy.
- [x] Test the storefront endpoint.
- [x] Verify SRE Agent configuration and Container Insights ingestion.
- [x] Record endpoints, cost caveats, and stop/cleanup commands.

## 7. Validation Proof

- Bicep compilation after the resource-group parameter change: succeeded on 2026-09-13.
- Bicep compilation after the low-cost profile changes: succeeded on 2026-09-13.
- PowerShell Parser.ParseFile and AST checks: passed; ResourceGroupName is declared once and is not overwritten.
- Existing compiler warnings: BCP174 and no-unnecessary-dependson in the upstream AKS data-collection association.
- Azure CLI quota helper: 98 regional vCPUs available; 100 DASv5-family vCPUs available. The proposed cluster consumes 6 vCPUs.
- Azure CLI VM SKU query: D2as_v5 and D4as_v5 have no restrictions in Sweden Central.
- Azure provider metadata: Microsoft.App registered; agents supports Sweden Central and API 2025-05-01-preview.
- Azure Resource Graph collision check: neither requested resource group exists in the selected subscription.
- Core validation helper: OVERALL PASS. Azure accepted the one-system-node, one-workload-node Free-tier profile.
- Azure what-if: 24 creates, 0 modifications, 0 deletions.
- Live post-deployment validation: passed on 2026-09-13; see evidence below.

| Check | Command / Tool Run | Result | Timestamp |
|-------|--------------------|--------|-----------|
| Core validation | azure-validate `validate-deployment.ps1 -Scope sub -Location swedencentral -Template infra/bicep/main.bicep -Parameters infra/bicep/main.bicepparam -Subscription b28cc86b-8f84-47e5-a38a-b814b44d047e` | PASS: CLI, authentication, build, Azure validate, what-if | 2026-09-13 |
| Deployer permissions | `az role assignment list --assignee f562a526-c29c-4afa-89c5-9a7770572f85 --include-groups --include-inherited --scope /subscriptions/b28cc86b-8f84-47e5-a38a-b814b44d047e` | PASS: Owner and User Access Administrator | 2026-09-13 |
| Policies | Azure MCP `policy_assignment_list`, scoped `az policy assignment show`, and `az policy definition show --name 8da2b98e-14e4-4533-83c1-4032ce301d38 --management-group 8d7622f8-d815-4120-b5b8-bee841c23a1c` | PASS: enforced deny only affects Classic resources; no policy errors in validation | 2026-09-13 |
| Script syntax | PowerShell `Parser.ParseFile` and ResourceGroupName AST check | PASS for deployment and RBAC scripts | 2026-09-13 |

Original validation completed by: azure-validate skill workflow on 2026-09-13. All required checks passed before the original deployment.

### Local Cost and Rebuild Hardening Validation

The later user request authorized local code/documentation improvements and
read-only checks, not another deployment or a stop/start/delete operation.

| Check | Command / Tool Run | Result | Timestamp |
|-------|--------------------|--------|-----------|
| Offline safety | `scripts/test-deployment-safety.ps1` | PASS: 49 checks; cloud/Kubernetes calls mocked | 2026-09-13 |
| Local prerequisites | `scripts/deploy.ps1 -CheckPrerequisitesOnly` | PASS: PS7, CLI, Bicep, kubectl, curl, working Python and PyYAML | 2026-09-13 |
| Core validation | Same azure-validate Bicep helper and approved scope as above | OVERALL PASS: authentication, compilation, ARM validation and what-if | 2026-09-13 |
| Entry point | `scripts/deploy.ps1 -WhatIf` | PASS with saved subscription, RG and Sweden Central defaults; no provider registration or resource application | 2026-09-13 |
| Structured preview | `az deployment sub what-if --no-pretty-print --output json` with the same template, parameters and subscription | 24 resource records: 0 Create, 0 Delete, 13 Modify, 10 NoChange, 1 Ignore | 2026-09-13 |
| Policy review | Azure MCP `policy_assignment_list`, then the inherited custom deny definition lookup | 27 assignments returned; enforced custom deny targets Classic resources, not this lab. ARM validation found no policy block. Not a full compliance audit. | 2026-09-13 |
| Static role review | AKS/SRE Bicep role assignments and `configure-rbac.ps1` | Existing kubelet, SRE identity and deployer roles reviewed; no subscription-wide agent Reader or live permission changes | 2026-09-13 |
| Image locks | Ready pod image IDs compared with PyYAML-parsed manifests; `kubectl create --dry-run=client --validate=true -o name` | Eight active baseline digests matched; baseline plus three replacement scenarios validated; no manifests applied | 2026-09-13 |
| Power helper | `scripts/set-lab-power.ps1 -Action Status` | Running / Succeeded in the approved scope; no Stop/Start call | 2026-09-13 |
| Console helper | `scripts/update-demo-console.ps1 -WhatIf` | Current API hostname and both site URLs verified; HTML already current and not written | 2026-09-13 |
| Documentation | PowerShell AST parsing and relative link checks | 26 examples parse; 29 local links resolve; no example commands executed | 2026-09-13 |
| Editor diagnostics | Modified PowerShell, YAML and documentation files | No errors reported | 2026-09-13 |
| Patch cleanliness | `git diff --check` | PASS | 2026-09-13 |

The validation helper's text counter reported 6 creates/30 modifications/46 deletes
because it counted nested property deltas. The structured count above is authoritative
for resource changes. The CLI also emitted a known Bicep installation-status line
before JSON; parsing succeeded after excluding that line. Both validation-harness
issues were resolved without changing the deployed resources or external helper.

The preview's modifications include omitted service-populated fields and unresolved
ARM references; they are not proof of a no-op redeployment. The ignored resource is
the generated smart-detector alert. Existing BCP174 and no-unnecessary-dependson
warnings remain in the AKS DCR association. No fresh rebuild, real stop/start,
image repull or complete ten-scenario remediation run was performed.

## Role Assignment Verification

- Static review: verified AKS control-plane/kubelet access, SRE Agent user-assigned identity, and deployer access.
- AKS kubelet receives AcrPull and workspace access; the agent receives lab-scoped management access and cluster-scoped Kubernetes roles.
- Key Vault and telemetry operations use the existing service-specific roles in the RBAC script.
- Agent Reader access is limited to the managed node resource group, not the subscription.
- The deployer has effective Owner and User Access Administrator permissions, plus the provisioned SRE Agent Administrator role on this agent.
- Live `az role assignment list --assignee <agent-principal> --all` verified all nine required role/scope pairs, including node-group Reader and cluster-scoped roles. No agent assignments were found outside the two lab groups.

## Provisioning Evidence

- AKS reports Succeeded and Running on Kubernetes 1.35.7 with Azure Linux V3.
- AKS FQDN: `aks-srelab-tuu2g03m.hcp.swedencentral.azmk8s.io`.
- Both node pools report Succeeded and the expected fixed sizing and tags.
- ACR `acrsrelabixeeyc` is Basic and reports Succeeded.
- SRE Agent managed identity principal: `96aa2702-68bb-4564-b5fd-5e66387c52bb`; lab-scoped base role assignments verified.
- AKS kubelet principal: `0bad5ca2-3dd8-4ca7-8231-1c2f93a4213b`; AcrPull and workspace access verified.
- SRE Agent provisioning reports Succeeded. Its incident response filter is enabled in Review mode.
- Application validation passed 32/32 checks. Independent readiness check confirmed 2 Ready nodes and 12 Ready application pods.
- MongoDB's unchanged 8-GiB claim is Bound to `srelab-managed-csi`, using StandardSSD_LRS and the required tag.
- Resource audit found 27 resources in Sweden Central/global, no optional Grafana or managed Prometheus. Both resource groups and all listed resources carry SecurityControl=Ignore.
- The automatically generated Application Insights smart-detector alert required a tag merge. The deployment script now repeats this step; its extracted tagging block was executed and the stored tag verified.
- `verify-sre-agent-configuration.ps1 -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG`: exit 0; runbooks, custom agents, both connectors, all scheduled tasks, alerts, and response plan verified.
- `verify-telemetry.ps1 -ResourceGroupName Az-SRE-Agent-Demo-MAT-RG -Attempts 1`: exit 0; 2 ready ama-logs pods, DCR association present, 5091 ContainerLogV2 rows and 830 KubePodInventory rows in the check window.
- Storefront and admin endpoints both returned HTTP 200. No break scenario was applied; the lab was left healthy.

## Endpoints and Operations

- Storefront: http://172.160.84.220
- Store administration: http://172.160.85.198
- SRE Agent portal: https://portal.azure.com/#resource/subscriptions/b28cc86b-8f84-47e5-a38a-b814b44d047e/resourceGroups/Az-SRE-Agent-Demo-MAT-RG/providers/Microsoft.App/agents/sre-srelab/overview
- SRE Agent endpoint: https://sre-srelab--b4754f99.62f83535.swedencentral.azuresre.ai
- Resource group: https://portal.azure.com/#resource/subscriptions/b28cc86b-8f84-47e5-a38a-b814b44d047e/resourceGroups/Az-SRE-Agent-Demo-MAT-RG/overview
- Stop/start and confirmed cleanup commands: `docs/COSTS.md`, Sweden Central profile section. No cleanup was run.
- Optional manual step: authorize Outlook in the agent's Settings > Connectors to enable email delivery. Core diagnostics do not require Outlook authorization.
- GitHub PAT integration and Microsoft Learn MCP remain disabled. No secrets were requested or written to source control.
- The two public demo HTTP endpoints do not have TLS or production authentication. Use test data only.

## Local Compatibility Fixes

- Runtime discovery now executes `--version` before selecting Python: the Windows Store python3 alias exits 9009, while the installed Python 3.12 runtime and PyYAML work. Both agent YAML conversions passed using the edited selection block.
- ARM connector creation returned HTTP 415 through the original native CLI body handling. PowerShell HTTP requests with explicit application/json content type and an in-memory ARM token succeeded. Existing scheduled tasks and uploaded runbooks were preserved on retry.
- Configuration failure reporting now precedes the success banner.