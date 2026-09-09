#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication

<#
.SYNOPSIS
Creates or updates Lifecycle Workflows from version-controlled JSON definitions.

.DESCRIPTION
Resolves the display-name placeholders in each definition to tenant object IDs,
then reconciles the workflow in Microsoft Entra ID. The workflow display name is
the identity key.

Microsoft Graph limits what a PATCH can change, so this script uses three paths:

  - No workflow with that display name: POST creates it.
  - Only displayName, description, isEnabled, or isSchedulingEnabled differ:
    PATCH updates it in place.
  - tasks or executionConditions differ: createNewVersion publishes a new
    version, because those properties cannot be patched.

Re-running with no changes makes no write calls.

.PARAMETER Path
A definition file or a directory of them. Defaults to ./local.

.PARAMETER TenantId
Optional tenant to sign in to.

.PARAMETER WhatIf
Reports the action for each definition without writing to the tenant.

.EXAMPLE
./deploy.ps1 -WhatIf
Shows what would change for every definition in ./local.

.EXAMPLE
./deploy.ps1 -Path ./local/joiner.json
Reconciles one workflow.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Path,
    [string] $TenantId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

if (-not $Path) { $Path = Join-Path $PSScriptRoot 'local' }
if (-not (Test-Path $Path)) { throw "Path not found: $Path" }

$definitionFiles = if (Test-Path $Path -PathType Container) {
    Get-ChildItem -Path $Path -Filter '*.json' | Sort-Object Name
}
else {
    Get-Item -Path $Path
}

if (-not $definitionFiles) { throw "No *.json definitions found under $Path." }

Connect-ProjectGraph -TenantId $TenantId

$summary = @()

foreach ($file in $definitionFiles) {
    Write-Host ""
    Write-Host "== $($file.Name)"

    $rawDefinition = Get-Content -Path $file.FullName -Raw
    if ($rawDefinition -match '<[A-Z][A-Z0-9_]*>') {
        throw "$($file.Name) contains example values. Copy it to local/ and replace every <PLACEHOLDER> before deployment."
    }

    $definition = $rawDefinition | ConvertFrom-Json

    foreach ($required in @('category', 'displayName', 'tasks')) {
        if (-not $definition.PSObject.Properties.Name.Contains($required)) {
            throw "$($file.Name) is missing the required property '$required'."
        }
    }

    $resolved = Resolve-PlaceholdersInObject -InputObject $definition
    if (Test-HasUnresolvedPlaceholder -InputObject $resolved) {
        throw "$($file.Name) still contains an unresolved placeholder after resolution."
    }

    $existing = Get-WorkflowByDisplayName -DisplayName $resolved.displayName

    if (-not $existing) {
        if ($PSCmdlet.ShouldProcess($resolved.displayName, 'Create workflow')) {
            $created = Invoke-Graph -Method POST -Uri '/identityGovernance/lifecycleWorkflows/workflows' -Body $resolved
            Write-Host "  Created workflow $($created.id) at version $($created.version)."
            $action = 'created'
        }
        else {
            Write-Host "  Would create this workflow."
            $action = 'would create'
        }
        $summary += [pscustomobject]@{ File = $file.Name; Workflow = $resolved.displayName; Action = $action }
        continue
    }

    if ($existing.category -ne $resolved.category) {
        throw "Workflow '$($resolved.displayName)' exists with category '$($existing.category)'. Category cannot be changed; use a different display name."
    }

    $existingBody = ConvertTo-WorkflowRequestBody -Workflow $existing
    $needsNewVersion = (Get-VersionedShape -Workflow $resolved) -ne (Get-VersionedShape -Workflow $existingBody)

    $patch = [ordered]@{}
    foreach ($property in $script:PatchableWorkflowProperties) {
        if (-not $resolved.PSObject.Properties.Name.Contains($property)) { continue }
        if ($resolved.$property -ne $existing.$property) {
            $patch[$property] = $resolved.$property
        }
    }

    if ($needsNewVersion) {
        # createNewVersion carries the whole workflow, so the patchable fields
        # travel with it and a separate PATCH would be redundant.
        Write-Host "  Tasks or execution conditions changed."
        if ($PSCmdlet.ShouldProcess($resolved.displayName, 'Create new workflow version')) {
            $result = Invoke-Graph -Method POST `
                -Uri "/identityGovernance/lifecycleWorkflows/workflows/$($existing.id)/createNewVersion" `
                -Body @{ workflow = $resolved }
            Write-Host "  Published version $($result.version)."
            $action = 'new version'
        }
        else {
            Write-Host "  Would publish a new version."
            $action = 'would publish new version'
        }
    }
    elseif ($patch.Count -gt 0) {
        Write-Host "  Changed: $($patch.Keys -join ', ')"
        if ($PSCmdlet.ShouldProcess($resolved.displayName, 'Update workflow')) {
            Invoke-Graph -Method PATCH `
                -Uri "/identityGovernance/lifecycleWorkflows/workflows/$($existing.id)" `
                -Body $patch | Out-Null
            Write-Host "  Updated in place."
            $action = 'patched'
        }
        else {
            Write-Host "  Would update in place."
            $action = 'would patch'
        }
    }
    else {
        $action = 'no change'
        Write-Host "  Already matches version $($existing.version)."
    }

    $summary += [pscustomobject]@{ File = $file.Name; Workflow = $resolved.displayName; Action = $action }
}

Write-Host ""
$summary | Format-Table -AutoSize

if ($summary | Where-Object { $_.Action -in @('created', 'new version') }) {
    Write-Host "Run the workflow on demand and confirm its history before enabling scheduling."
}
