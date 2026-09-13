// =============================================================================
// Bicep Parameters File - SRE Agent Sandbox
// =============================================================================
// Preview/deploy the saved Sweden Central profile with scripts/deploy.ps1.
// =============================================================================

using 'main.bicep'

// Core parameters are passed by scripts/deploy.ps1 via --parameters

param location = 'swedencentral'
param resourceGroupName = 'Az-SRE-Agent-Demo-MAT-RG'

// Observability stack (Grafana + Prometheus)
param deployObservability = false

// Baseline alert rules
param deployAlerts = true

// Deploy Azure SRE Agent (programmatic deployment now supported)
param deploySreAgent = true

// Default action group for incident routing (add webhook at deploy time)
param deployActionGroup = true

// AKS Configuration - cost-optimized for demo
param aksSkuTier = 'Free'
param enableNodeAutoScaling = false
param nodeOsDiskSizeGB = 32
param systemNodeVmSize = 'Standard_D4as_v5'
param userNodeVmSize = 'Standard_D2as_v5'
param systemNodeCount = 1
param userNodeCount = 1

// Tags
param tags = {
  workload: 'sre-agent-demo'
  environment: 'sandbox'
  managedBy: 'bicep'
  purpose: 'demonstration'
  costCenter: 'demo-lab'
  SecurityControl: 'Ignore'
}
