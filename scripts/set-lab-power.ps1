<#
.SYNOPSIS
    Inspect, stop or start this demo's AKS compute without deleting the lab.
.DESCRIPTION
    Uses AKS stop/start, never direct VM scale set operations. Status is the default.
    Stopping interrupts both websites. Disks, networking, registry, alerts and SRE
    Agent costs remain. See docs/COSTS.md before stopping or deleting resources.
.EXAMPLE
    .\scripts\set-lab-power.ps1 -Action Status
.EXAMPLE
    .\scripts\set-lab-power.ps1 -Action Stop -WhatIf
.EXAMPLE
    .\scripts\set-lab-power.ps1 -Action Stop
.EXAMPLE
    .\scripts\set-lab-power.ps1 -Action Start
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [ValidateSet('Status', 'Stop', 'Start')]
    [string]$Action = 'Status',

    [ValidatePattern('^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')]
    [string]$SubscriptionId = 'b28cc86b-8f84-47e5-a38a-b814b44d047e',

    [ValidatePattern('^[a-zA-Z0-9_.()-]{1,90}$')]
    [string]$ResourceGroupName = 'Az-SRE-Agent-Demo-MAT-RG',

    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9_-]*$')]
    [string]$ClusterName = 'aks-srelab'
)

$ErrorActionPreference = 'Stop'

function Get-LabCluster {
    $raw = az aks show --name $ClusterName --resource-group $ResourceGroupName `
        --subscription $SubscriptionId --output json --only-show-errors
    if ($LASTEXITCODE -ne 0 -or -not $raw) {
        throw 'Cannot read the target AKS cluster. Check login, subscription and resource group.'
    }
    $result = ($raw | Out-String) | ConvertFrom-Json
    $expectedId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ContainerService/managedClusters/$ClusterName"
    if ($result.id -ne $expectedId -or $result.location -ne 'swedencentral') {
        throw 'Cluster identity or location differs from the requested Sweden Central lab. No power operation was attempted.'
    }
    return $result
}

$cluster = Get-LabCluster
if ($Action -ne 'Status') {
    if ($cluster.provisioningState -ne 'Succeeded') {
        throw "Cluster provisioning state is '$($cluster.provisioningState)'. Wait for the existing operation to finish."
    }
    if ($cluster.powerState.code -notin @('Running', 'Stopped')) {
        throw "Unexpected power state '$($cluster.powerState.code)'. Inspect AKS before changing it."
    }
    if (@($cluster.agentPoolProfiles | Where-Object { $_.type -ne 'VirtualMachineScaleSets' }).Count) {
        throw 'AKS stop/start requires VM scale set node pools.'
    }
    $desiredState = if ($Action -eq 'Stop') { 'Stopped' } else { 'Running' }
    if ($cluster.powerState.code -eq $desiredState) {
        Write-Host "Cluster is already $desiredState. No power operation is needed."
    }
    else {
        if ($Action -eq 'Stop') {
            Write-Warning 'Both websites will go offline. Restore demo faults first. SRE Agent, disks and other retained resources continue billing.'
            Write-Warning 'After stopping, allow 15-30 minutes before restarting. Regional capacity can delay a later restart.'
        }
        else {
            Write-Warning 'Starting AKS resumes node compute charges. Do not start within 15-30 minutes of stopping.'
        }
        if ($PSCmdlet.ShouldProcess($cluster.id, "$Action AKS cluster and both node pools")) {
            $operation = $Action.ToLowerInvariant()
            az aks $operation --name $ClusterName --resource-group $ResourceGroupName `
                --subscription $SubscriptionId --output none --only-show-errors
            if ($LASTEXITCODE -ne 0) { throw "AKS $operation failed. Inspect the cluster before retrying." }
            $cluster = Get-LabCluster
            if ($cluster.powerState.code -ne $desiredState -or $cluster.provisioningState -ne 'Succeeded') {
                throw "AKS has not reached $desiredState / Succeeded. Check its status; no follow-up changes were attempted."
            }
        }
    }
}

[pscustomobject]@{
    SubscriptionId    = $SubscriptionId
    ResourceGroup     = $ResourceGroupName
    Cluster           = $ClusterName
    Location          = $cluster.location
    PowerState        = $cluster.powerState.code
    ProvisioningState = $cluster.provisioningState
    NodeResourceGroup = $cluster.nodeResourceGroup
}

if ($Action -eq 'Start' -and $cluster.powerState.code -eq 'Running') {
    Write-Host 'Next: refresh AKS credentials, run deployment/agent/telemetry verification, and rediscover both website URLs. See docs/REDEPLOY.md.'
}