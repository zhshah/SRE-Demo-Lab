<#
.SYNOPSIS
    Run dependency-free, offline regression tests for this lab's deployment helpers.
.DESCRIPTION
    Parses PowerShell scripts and tests target defaults, prerequisite failures,
    SRE availability guards, AKS power transitions and console JSON preservation.
    Azure CLI and executable probes are mocked. No cloud resources or files change.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$checks = [System.Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
    $checks.Add($Message)
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Pattern, [string]$Message)
    $failure = $null
    try { & $Action | Out-Null } catch { $failure = $_.Exception.Message }
    Assert-True ($null -ne $failure -and $failure -match $Pattern) $Message
}

$scriptAsts = @{}
foreach ($scriptFile in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1') {
    $tokens = $null
    $errors = $null
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName, [ref]$tokens, [ref]$errors)
    Assert-True (@($errors).Count -eq 0) "PowerShell syntax: $($scriptFile.Name)"
    $scriptAsts[$scriptFile.Name] = $scriptAst
}

$deployAst = $scriptAsts['deploy.ps1']
$defaults = @{
    Location = 'swedencentral'
    ResourceGroupName = 'Az-SRE-Agent-Demo-MAT-RG'
    SubscriptionId = 'b28cc86b-8f84-47e5-a38a-b814b44d047e'
    WorkloadName = 'srelab'
}
foreach ($entry in $defaults.GetEnumerator()) {
    $parameter = @($deployAst.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq $entry.Key })
    Assert-True ($parameter.Count -eq 1 -and $parameter[0].DefaultValue.SafeGetValue() -eq $entry.Value) "Approved default: $($entry.Key)"
}
$selection = @($deployAst.FindAll({ param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -eq 'az' -and $node.Extent.Text -like 'az account set*'
}, $true))
Assert-True ($selection.Count -eq 1 -and $selection[0].Extent.Text -match '\$SubscriptionId') 'Deployment explicitly selects the requested subscription'

$prerequisiteFunction = $deployAst.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-DeploymentPrerequisites'
}, $true)
& {
    . ([scriptblock]::Create($prerequisiteFunction.Extent.Text))
    $probeState = @{ MissingTool = ''; BicepFails = $false; MissingYaml = $false; PythonUsed = $false }
    function Get-Command {
        [CmdletBinding()]
        param([string]$Name, [string]$CommandType)
        if ($Name -eq $probeState.MissingTool) { return }
        $source = switch ($Name) {
            'python3' { 'Invoke-FakePythonAlias' }
            'python' { 'Invoke-FakePython' }
            default { $Name }
        }
        [pscustomobject]@{ Source = $source }
    }
    function az {
        $global:LASTEXITCODE = if ($probeState.BicepFails -and $args[0] -eq 'bicep') { 1 } else { 0 }
        if ($args[0] -notin @('version', 'bicep')) { throw 'Unexpected Azure command in a local prerequisite test.' }
    }
    function kubectl { $global:LASTEXITCODE = 0 }
    function curl { $global:LASTEXITCODE = 0 }
    function Invoke-FakePythonAlias { $global:LASTEXITCODE = 9009 }
    function Invoke-FakePython {
        $probeState.PythonUsed = $true
        $global:LASTEXITCODE = if ($probeState.MissingYaml -and $args[0] -eq '-c') { 1 } else { 0 }
    }
    Test-DeploymentPrerequisites
    Assert-True $probeState.PythonUsed 'Broken Windows Store alias falls back to a working Python runtime'
    $probeState.MissingYaml = $true
    Assert-Throws { Test-DeploymentPrerequisites } 'PyYAML is missing' 'Missing PyYAML fails before deployment'
    $probeState.MissingYaml = $false
    $probeState.BicepFails = $true
    Assert-Throws { Test-DeploymentPrerequisites } 'Bicep is unavailable' 'Native Bicep exit code is checked'
    $probeState.BicepFails = $false
    $probeState.MissingTool = 'kubectl'
    Assert-Throws { Test-DeploymentPrerequisites } "Required tool 'kubectl'" 'Missing kubectl fails before deployment'
    $probeState.MissingTool = ''
    $probeState.MissingYaml = $true
    Test-DeploymentPrerequisites -SkipSreAgent
    Assert-True $true 'Core-only deployment explicitly skips SRE-specific prerequisites'
}

$providerGuard = $deployAst.Find({ param($node)
    $node -is [System.Management.Automation.Language.IfStatementAst] -and
    $node.Clauses[0].Item1.Extent.Text -eq '$deploySreAgent' -and
    $node.Extent.Text -match 'Get-SreAgentProviderStatus'
}, $true)
Assert-True ($null -ne $providerGuard) 'SRE availability guard is present'
& {
    $WhatIf = $true
    $deploySreAgent = $true
    $providerState = [pscustomobject]@{ RegistrationState = 'NotRegistered'; HasAgentsResource = $false; SupportsPreviewApi = $false; DefaultApiVersion = '' }
    function Get-SreAgentProviderStatus { return $providerState }
    function az { throw 'A provider write was attempted in what-if.' }
    $guard = [scriptblock]::Create($providerGuard.Extent.Text)
    Assert-Throws $guard 'not registered' 'What-if does not register providers'
    $providerState.RegistrationState = 'Registered'
    Assert-Throws $guard 'is unavailable' 'Missing SRE support is not silently converted into a core-only deployment'
    $providerState.HasAgentsResource = $true
    $providerState.SupportsPreviewApi = $true
    & $guard
    Assert-True $deploySreAgent 'Available SRE Agent remains enabled'
}

$roleFunction = $scriptAsts['configure-rbac.ps1'].Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Set-RoleAssignment'
}, $true)
& {
    . ([scriptblock]::Create($roleFunction.Extent.Text))
    $roleState = @{ Existing = $true; ListFails = $false; CreateFails = $false; Writes = 0 }
    function az {
        $global:LASTEXITCODE = 0
        if ($args[2] -eq 'list') {
            if ($roleState.ListFails) { $global:LASTEXITCODE = 1; return }
            if ($roleState.Existing) { return '[{"id":"existing-assignment"}]' }
            return '[]'
        }
        if ($args[2] -ne 'create') { throw 'Unexpected RBAC operation.' }
        $roleState.Writes++
        if ($roleState.CreateFails) { $global:LASTEXITCODE = 1; return 'AuthorizationFailed' }
    }
    $assignment = @{ Scope = '/subscriptions/test/resourceGroups/lab'; RoleDefinition = 'Reader'; PrincipalId = 'test-principal'; Description = 'Offline RBAC test' }
    Set-RoleAssignment @assignment
    Assert-True ($roleState.Writes -eq 0) 'Existing role assignments are not recreated'
    $roleState.Existing = $false
    Set-RoleAssignment @assignment
    Assert-True ($roleState.Writes -eq 1) 'Missing assignment is created once'
    $roleState.CreateFails = $true
    Assert-Throws { Set-RoleAssignment @assignment } 'AuthorizationFailed' 'Native RBAC creation errors cannot report success'
    $roleState.ListFails = $true
    Assert-Throws { Set-RoleAssignment @assignment } 'Could not inspect' 'RBAC lookup failures block blind creation attempts'
}

& {
    $WarningPreference = 'SilentlyContinue'
    $powerState = @{ Code = 'Running'; Location = 'swedencentral'; Provisioning = 'Succeeded'; Fail = $false }
    $powerWrites = [System.Collections.Generic.List[string]]::new()
    function az {
        $global:LASTEXITCODE = 0
        $command = $args -join ' '
        if ($command -notmatch '--subscription b28cc86b-8f84-47e5-a38a-b814b44d047e') { throw 'Unscoped AKS call.' }
        if ($command -like 'aks show *') {
            @{
                id = '/subscriptions/b28cc86b-8f84-47e5-a38a-b814b44d047e/resourceGroups/Az-SRE-Agent-Demo-MAT-RG/providers/Microsoft.ContainerService/managedClusters/aks-srelab'
                location = $powerState.Location
                provisioningState = $powerState.Provisioning
                powerState = @{ code = $powerState.Code }
                nodeResourceGroup = 'Az-SRE-Agent-Demo-MAT-RG-nodes'
                agentPoolProfiles = @(@{ type = 'VirtualMachineScaleSets' }, @{ type = 'VirtualMachineScaleSets' })
            } | ConvertTo-Json -Depth 5 -Compress
        }
        elseif ($args[0] -eq 'aks' -and $args[1] -in @('stop', 'start')) {
            $powerWrites.Add($args[1])
            if ($powerState.Fail) { $global:LASTEXITCODE = 1; return }
            $powerState.Code = if ($args[1] -eq 'stop') { 'Stopped' } else { 'Running' }
        }
        else { throw "Unexpected power operation: $command" }
    }
    $powerScript = Join-Path $PSScriptRoot 'set-lab-power.ps1'
    $result = & $powerScript
    Assert-True ($result.PowerState -eq 'Running' -and $powerWrites.Count -eq 0) 'Power helper defaults to read-only status'
    $result = & $powerScript -Action Stop -WhatIf
    Assert-True ($result.PowerState -eq 'Running' -and $powerWrites.Count -eq 0) 'Stop what-if makes no power change'
    $result = & $powerScript -Action Stop -Confirm:$false
    Assert-True ($result.PowerState -eq 'Stopped' -and $powerWrites.Count -eq 1) 'Stop verifies Stopped after the AKS operation'
    $result = & $powerScript -Action Stop -Confirm:$false
    Assert-True ($result.PowerState -eq 'Stopped' -and $powerWrites.Count -eq 1) 'Repeated stop is idempotent'
    $result = & $powerScript -Action Start -Confirm:$false
    Assert-True ($result.PowerState -eq 'Running' -and $powerWrites.Count -eq 2) 'Start verifies Running after the AKS operation'
    $powerState.Location = 'eastus2'
    Assert-Throws { & $powerScript -Action Stop -Confirm:$false } 'identity or location differs' 'Unexpected location blocks power changes'
    $powerState.Location = 'swedencentral'
    $powerState.Provisioning = 'Updating'
    Assert-Throws { & $powerScript -Action Stop -Confirm:$false } 'existing operation' 'An in-progress operation blocks power changes'
    $powerState.Provisioning = 'Succeeded'
    $powerState.Fail = $true
    Assert-Throws { & $powerScript -Action Stop -Confirm:$false } 'AKS stop failed' 'Native stop failures are surfaced'
}

$updaterFunction = $scriptAsts['update-demo-console.ps1'].Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Update-ConsoleEnvironment'
}, $true)
. ([scriptblock]::Create($updaterFunction.Extent.Text))
$html = Get-Content -LiteralPath (Join-Path $repoRoot 'docs/DEMO-CONSOLE.html') -Raw
$dataPattern = '(?s)(<script id="demo-data"[^>]*>)(.*?)(</script>)'
$beforeData = [regex]::Match($html, $dataPattern).Groups[2].Value | ConvertFrom-Json -Depth 100
$updated = Update-ConsoleEnvironment -Html $html -Environment @{ storeUrl = 'http://192.0.2.20'; repoPath = 'C:\Demo Rebuild\repo' }
$afterData = [regex]::Match($updated, $dataPattern).Groups[2].Value | ConvertFrom-Json -Depth 100
Assert-True ($afterData.environment.storeUrl -eq 'http://192.0.2.20') 'Console refresh replaces saved endpoints'
Assert-True ($afterData.environment.repoPath -eq 'C:\Demo Rebuild\repo') 'Console refresh handles repository paths with spaces'
Assert-True (($beforeData.scenarios | ConvertTo-Json -Depth 100 -Compress) -ceq ($afterData.scenarios | ConvertTo-Json -Depth 100 -Compress)) 'All ten scenarios are preserved exactly as data'
Assert-True ([regex]::Replace($html, $dataPattern, '$1$3') -ceq [regex]::Replace($updated, $dataPattern, '$1$3')) 'HTML, styling and executable scripts outside JSON remain byte-for-byte unchanged'
Assert-True ((Update-ConsoleEnvironment -Html $updated -Environment @{ storeUrl = 'http://192.0.2.20' }) -ceq $updated) 'Repeated console refresh is idempotent'
Assert-Throws { Update-ConsoleEnvironment -Html $html -Environment @{ unknownField = 'bad' } } 'Unknown environment field' 'Unknown console metadata fields are rejected'
Assert-Throws { Update-ConsoleEnvironment -Html '<html></html>' -Environment @{} } 'data block was not found' 'Missing console JSON is rejected without writing a file'

$global:LASTEXITCODE = 0
Write-Host "PASS: $($checks.Count) offline deployment safety checks. Azure and Kubernetes operations were mocked; no files or cloud resources changed." -ForegroundColor Green