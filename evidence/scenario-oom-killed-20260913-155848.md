# Scenario Report: oom-killed

- Status: **passed**
- Resource group: `Az-SRE-Agent-Demo-MAT-RG`
- Started: 2026-09-13T12:58:48.0599841Z
- Finished: 2026-09-13T13:00:09.7224240Z

## Lifecycle

| Stage | Status | Detail |
| --- | --- | --- |
| baseline | running |  |
| baseline | passed |  |
| fault-injection | running |  |
| fault-injection | passed |  |
| fault-observation | running |  |
| fault-observation | passed |  |
| alert | not-observed | External Azure Monitor/SRE Agent trigger evidence was not supplied. |
| investigation | not-observed | Run the SRE Agent prompt separately and attach evidence if available. |
| approval | not-observed | No remediation approval event was supplied. |
| restore | running |  |
| restore | passed |  |
| recovery | running |  |
| recovery | passed |  |

Alert, investigation, and approval are marked not-observed unless external evidence is supplied.

