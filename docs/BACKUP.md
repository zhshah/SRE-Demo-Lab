# Backup and Restore

Backup destination: [zhshah/SRE-Demo-Lab](https://github.com/zhshah/SRE-Demo-Lab).
Prepared on 2026-09-13. The destination is public, not private.

## Saved Contents

The backup retains the upstream Git history and all developed source, deployment
fixes, image locks, manifests, SRE runbooks/configuration, cost and recovery guides,
offline HTML console, media, and local scenario evidence. Reviewed records normally
excluded by Git are included explicitly:

- [Deployment plan and verification history](../.azure/deployment-plan.md)
- [Validation workflow status](../.azure/validate-status.json)
- [Compiled ARM snapshot](../infra/bicep/main.json), with Bicep remaining authoritative
- [Scenario evidence JSON](../evidence/scenario-oom-killed-20260913-155848.json)
- [Deployment outputs snapshot](../backup/deployment-outputs.redacted.json)
- [Workspace file manifest](../backup/workspace-manifest.json)

The two files originally outside the Git checkout are preserved without changing
their originals:

| Original workspace file | Saved location |
|-------------------------|----------------|
| Repository URL note | [workspace-files/Repo URL.txt](../workspace-files/Repo%20URL.txt) |
| Exported OOM presenter runbook | [workspace-files/sre-demo-oom-killed.md](../workspace-files/sre-demo-oom-killed.md) |

## Public Data Handling

The saved deployment output contains a live Application Insights telemetry
connection string. In the public snapshot, only
`appInsightsConnectionString.value` is replaced with a redaction marker. The
original output remains unchanged and ignored locally. A deployment generates
fresh output; do not copy the redacted snapshot into the live output location.

An exact local ZIP was also verified against SHA-256 hashes for all **112 original
workspace files**, including ignored files and hidden Git metadata. It is retained
outside this Git repository and is not uploaded publicly. This preserves the
unredacted original state. Git history is transferred normally, rather than
publishing local Git configuration, credential references, reflogs, or hooks.

The public source deliberately retains this lab's resource names, Azure identifiers,
URLs and reviewed evidence. Do not mistake a public repository for private storage.
Credential, kubeconfig and environment-file ignore rules remain enabled for future work.

## Restore

Clone this repository and follow [REDEPLOY.md](REDEPLOY.md). Run the prerequisite
and offline safety checks, select the approved Azure identity/subscription, review
the what-if result, then deploy only after approving the cost and proposed changes.
Deployment refreshes the console's local path and live endpoints.

Saved outputs and evidence describe the original deployment. They do not prove
current live health. A source backup does not restore MongoDB contents, RabbitMQ
queues, agent investigation history, portal-only changes, browser notes, or Azure
and GitHub sign-in sessions. Future quota, policy, capacity and service changes
still require the documented preflight and acceptance checks.