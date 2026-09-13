<#
.SYNOPSIS
    Refresh the offline console's environment from the deployed Sweden Central lab.
.DESCRIPTION
    Reads Azure and Kubernetes metadata, then updates local embedded JSON only.
    Does not change cloud resources, submit orders, or reset browser notes/checkpoints.
    Refresh AKS credentials before running. Use -WhatIf to preview the local write.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidatePattern('^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')]
    [string]$SubscriptionId = 'b28cc86b-8f84-47e5-a38a-b814b44d047e',

    [ValidatePattern('^[a-zA-Z0-9_.()-]{1,90}$')]
    [string]$ResourceGroupName = 'Az-SRE-Agent-Demo-MAT-RG',

    [string]$ConsolePath = (Join-Path $PSScriptRoot '../docs/DEMO-CONSOLE.html')
)

$ErrorActionPreference = 'Stop'

function Update-ConsoleEnvironment {
    param([string]$Html, [System.Collections.IDictionary]$Environment)

    $dataMatch = [regex]::Match($Html, '(?s)<script\b[^>]*\bid="demo-data"[^>]*>(?<data>.*?)</script>')
    if (-not $dataMatch.Success) { throw 'The console JSON data block was not found.' }
    $data = ConvertFrom-Json -InputObject $dataMatch.Groups['data'].Value -AsHashtable -Depth 100
    if (-not $data.environment -or $data.scenarios.Count -ne 10) { throw 'Unexpected console data structure.' }
    $changed = $false
    foreach ($entry in $Environment.GetEnumerator()) {
        if (-not $data.environment.Contains($entry.Key)) { throw "Unknown environment field: $($entry.Key)" }
        if ($data.environment[$entry.Key] -cne $entry.Value) {
            $data.environment[$entry.Key] = $entry.Value
            $changed = $true
        }
    }
    if (-not $changed) { return $Html }
    $json = ConvertTo-Json -InputObject $data -Depth 100 -EscapeHandling EscapeHtml
    $group = $dataMatch.Groups['data']
    return $Html.Substring(0, $group.Index) + "`n$json`n  " + $Html.Substring($group.Index + $group.Length)
}

$accountRaw = az account show --subscription $SubscriptionId --output json --only-show-errors
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the requested Azure subscription.' }
$account = ($accountRaw | Out-String) | ConvertFrom-Json
if ($account.id -ne $SubscriptionId) { throw 'Azure subscription mismatch.' }

$clusterRaw = az aks show --name aks-srelab --resource-group $ResourceGroupName `
    --subscription $SubscriptionId --output json --only-show-errors
if ($LASTEXITCODE -ne 0) { throw 'Cannot read aks-srelab.' }
$cluster = ($clusterRaw | Out-String) | ConvertFrom-Json
if ($cluster.location -ne 'swedencentral' -or $cluster.powerState.code -ne 'Running' -or -not $cluster.fqdn) {
    throw 'The console requires the running Sweden Central lab and a public API hostname.'
}
$server = kubectl --context aks-srelab config view --minify -o 'jsonpath={.clusters[0].cluster.server}'
if ($LASTEXITCODE -ne 0 -or -not $server -or ([uri]$server).Host -ne $cluster.fqdn) {
    throw 'kubectl context does not match this Azure cluster. Refresh AKS credentials before updating the console.'
}

$urls = @{}
foreach ($serviceName in @('store-front', 'store-admin')) {
    $serviceRaw = kubectl --context aks-srelab get service $serviceName -n pets --output json --request-timeout=20s
    if ($LASTEXITCODE -ne 0) { throw "Cannot read Service/$serviceName." }
    $service = ($serviceRaw | Out-String) | ConvertFrom-Json
    $ingress = @($service.status.loadBalancer.ingress)
    if ($ingress.Count -eq 0 -or [string]::IsNullOrWhiteSpace($ingress[0].ip)) {
        throw "Service/$serviceName has no public IP yet. Rerun after LoadBalancer provisioning finishes."
    }
    $urls[$serviceName] = "http://$($ingress[0].ip)"
}

$agentId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.App/agents/sre-srelab"
$agentRaw = az resource show --ids $agentId --api-version 2025-05-01-preview --output json --only-show-errors
if ($LASTEXITCODE -ne 0) { throw 'Cannot read sre-srelab. No console changes were made.' }
$agent = ($agentRaw | Out-String) | ConvertFrom-Json
if ($agent.properties.provisioningState -ne 'Succeeded') { throw 'SRE Agent is not provisioned successfully yet.' }

$environment = @{
    subscriptionId = $SubscriptionId
    subscriptionName = $account.name
    resourceGroup = $ResourceGroupName
    nodeGroup = $cluster.nodeResourceGroup
    repoPath = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
    apiHost = $cluster.fqdn
    storeUrl = $urls['store-front']
    adminUrl = $urls['store-admin']
    agentUrl = 'https://portal.azure.com/#view/Microsoft_Azure_PaasServerless/AgentFrameBlade.ReactView/id/' + [uri]::EscapeDataString($agentId)
}
$html = Get-Content -LiteralPath $ConsolePath -Raw
$updatedHtml = Update-ConsoleEnvironment -Html $html -Environment $environment
if ($updatedHtml -ceq $html) {
    Write-Host 'The offline console environment is already up to date.'
}
elseif ($PSCmdlet.ShouldProcess($ConsolePath, 'Update saved lab URLs, API hostname and local repository path')) {
    Set-Content -LiteralPath $ConsolePath -Value $updatedHtml -Encoding utf8NoBOM -NoNewline
}
[pscustomobject]@{ Storefront = $urls['store-front']; Admin = $urls['store-admin']; ApiHost = $cluster.fqdn }