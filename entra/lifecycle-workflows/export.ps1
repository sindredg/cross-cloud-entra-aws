#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication

<#
.SYNOPSIS
Exports a Lifecycle Workflow from Microsoft Entra ID as a deployable JSON file.

.DESCRIPTION
Reads a workflow through Microsoft Graph, removes the properties Graph assigns
itself, and writes the result as JSON. With -Templatize, tenant object IDs in
task arguments are replaced by display-name placeholders so the file is safe to
commit. See README.md for the placeholder syntax.

.PARAMETER DisplayName
Display name of the workflow to export.

.PARAMETER WorkflowId
Object ID of the workflow to export. Use instead of -DisplayName.

.PARAMETER OutFile
Path of the JSON file to write. Defaults to a name derived from the category.

.PARAMETER Templatize
Replaces group, access package, and assignment policy IDs with placeholders.
Required before committing an export.

.PARAMETER TenantId
Optional tenant to sign in to.

.EXAMPLE
./export.ps1 -DisplayName 'Onboard cross-cloud joiner' -Templatize
Writes ./workflows/joiner.example.json with no tenant object IDs.

.EXAMPLE
./export.ps1 -DisplayName 'Onboard cross-cloud joiner'
Writes ./local/joiner.json with the real IDs for inspection. Git ignores local/.
#>
[CmdletBinding(DefaultParameterSetName = 'ByDisplayName')]
param(
    [Parameter(Mandatory, ParameterSetName = 'ByDisplayName')]
    [string] $DisplayName,

    [Parameter(Mandatory, ParameterSetName = 'ById')]
    [string] $WorkflowId,

    [string] $OutFile,

    [switch] $Templatize,

    [string] $TenantId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

Connect-ProjectGraph -TenantId $TenantId

if ($PSCmdlet.ParameterSetName -eq 'ByDisplayName') {
    $workflow = Get-WorkflowByDisplayName -DisplayName $DisplayName
    if (-not $workflow) { throw "No workflow found with display name '$DisplayName'." }
}
else {
    $workflow = Invoke-Graph -Method GET -Uri "/identityGovernance/lifecycleWorkflows/workflows/$WorkflowId"
}

Write-Host "Exporting '$($workflow.displayName)' (category $($workflow.category), version $($workflow.version))."

$body = ConvertTo-WorkflowRequestBody -Workflow $workflow

if ($Templatize) {
    # Build a reverse map from every object ID the workflow references back to a
    # display name, then rewrite the task arguments in place.
    $idToPlaceholder = @{}

    $groups = (Invoke-Graph -Method GET -Uri "/groups?`$select=id,displayName&`$top=999").value
    foreach ($group in @($groups)) {
        $idToPlaceholder[$group.id.ToLowerInvariant()] = "`${group:$($group.displayName)}"
    }

    $packages = (Invoke-Graph -Method GET -Uri "/identityGovernance/entitlementManagement/accessPackages?`$expand=assignmentPolicies&`$top=999").value
    foreach ($package in @($packages)) {
        $idToPlaceholder[$package.id.ToLowerInvariant()] = "`${accessPackage:$($package.displayName)}"
        foreach ($policy in @($package.assignmentPolicies)) {
            $idToPlaceholder[$policy.id.ToLowerInvariant()] = "`${accessPackagePolicy:$($package.displayName)|$($policy.displayName)}"
        }
    }

    $unmapped = @()
    foreach ($task in @($body.tasks)) {
        foreach ($argument in @($task.arguments)) {
            if ($null -eq $argument.value -or $argument.value -isnot [string]) { continue }

            # Group arguments accept a comma-separated list of IDs.
            $parts = $argument.value -split ','
            $rewritten = foreach ($part in $parts) {
                $trimmed = $part.Trim()
                $key = $trimmed.ToLowerInvariant()
                if ($idToPlaceholder.ContainsKey($key)) {
                    $idToPlaceholder[$key]
                }
                else {
                    if ($trimmed -match '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
                        $unmapped += "$($task.displayName): $($argument.name) = $trimmed"
                    }
                    $trimmed
                }
            }
            $argument.value = ($rewritten -join ', ')
        }
    }

    if ($unmapped.Count -gt 0) {
        Write-Warning "These object IDs could not be mapped to a display name. Replace them by hand before committing:"
        $unmapped | ForEach-Object { Write-Warning "  $_" }
    }
}

if (-not $OutFile) {
    $OutFile = Join-Path $PSScriptRoot "local/$($workflow.category).json"
}

$directory = Split-Path -Parent $OutFile
if ($directory -and -not (Test-Path $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$body | ConvertTo-Json -Depth 20 | Set-Content -Path $OutFile -Encoding utf8
Write-Host "Wrote $OutFile"

if (-not $Templatize) {
    Write-Warning "This file may contain tenant object IDs. Keep it out of version control."
}
