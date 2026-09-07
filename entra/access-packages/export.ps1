#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication

<#
.SYNOPSIS
Reads an access package out of the tenant as a deployable definition.

.DESCRIPTION
Writes the package, the resource roles it delivers, and its assignment policies
in the shape deploy.ps1 consumes. Everything is named rather than identified, so
the export contains no tenant object ID and can be deployed straight back
without editing. Server-assigned properties are dropped.

Exports land in local/, which is not committed. To update a committed template,
diff the export against it and put the <PLACEHOLDER> tokens back.

.PARAMETER DisplayName
The access package to read.

.PARAMETER Catalog
The catalog holding it. Needed only when the same package name exists in more
than one catalog.

.EXAMPLE
./export.ps1 -DisplayName 'AP-Cross-Cloud Elevated'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $DisplayName,
    [string] $Catalog,
    [string] $OutFile,
    [string] $TenantId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

# Graph assigns these; a create request that carries them is rejected.
$serverAssignedPolicyProperties = @(
    'id'
    'createdDateTime'
    'modifiedDateTime'
    'accessPackage'
    'catalog'
    'customExtensionHandlers'
    'customExtensionStageSettings'
    'verifiableCredentialSettings'
)

Connect-ProjectGraph -Scopes $script:GraphScopes -TenantId $TenantId

$query = New-GraphQuery @{
    '$filter' = "displayName eq '$(ConvertTo-ODataLiteral $DisplayName)'"
    '$expand' = 'assignmentPolicies,catalog'
}
$found = @(Invoke-GraphCollection -Uri "/identityGovernance/entitlementManagement/accessPackages$query")

if ($Catalog) { $found = @($found | Where-Object { $_.catalog.displayName -eq $Catalog }) }
if ($found.Count -eq 0) { throw "No access package found with display name '$DisplayName'$(if ($Catalog) { " in catalog '$Catalog'" })." }
if ($found.Count -gt 1) {
    $catalogs = ($found | ForEach-Object { "'$($_.catalog.displayName)'" }) -join ', '
    throw "'$DisplayName' exists in $($found.Count) catalogs ($catalogs). Pass -Catalog to choose one."
}
$package = $found[0]

# Role scopes name a role by originId. The catalog resources carry both the
# role names and the resource they belong to, so one read maps the whole set.
$catalogResources = @(Invoke-GraphCollection -Uri "/identityGovernance/entitlementManagement/catalogs/$($package.catalogId)/resources$(New-GraphQuery @{ '$expand' = 'roles' })")
$roleIndex = @{}
foreach ($resource in $catalogResources) {
    foreach ($role in @($resource.roles)) {
        $roleIndex[$role.originId] = [pscustomobject]@{
            originSystem = $resource.originSystem
            resource     = $resource.displayName
            role         = $role.displayName
        }
    }
}

$resourceRoles = @()
foreach ($roleScope in (Get-ResourceRoleScope -AccessPackageId $package.id)) {
    $originId = $roleScope.role.originId
    if ($roleIndex.ContainsKey($originId)) {
        $resourceRoles += $roleIndex[$originId]
    }
    else {
        Write-Warning "Role '$($roleScope.role.displayName)' ($originId) is not in the catalog listing; exported without a resource name."
        $resourceRoles += [pscustomobject]@{
            originSystem = $roleScope.role.originSystem
            resource     = '<RESOURCE_DISPLAY_NAME>'
            role         = $roleScope.role.displayName
        }
    }
}

$policies = @()
foreach ($policy in @($package.assignmentPolicies)) {
    $shaped = [ordered]@{}
    foreach ($property in $policy.PSObject.Properties) {
        if ($property.Name -in $serverAssignedPolicyProperties) { continue }
        if ($property.Name -like '*@odata.*') { continue }
        $shaped[$property.Name] = $property.Value
    }
    $policies += [pscustomobject]$shaped
}

$definition = [ordered]@{
    type               = 'accessPackage'
    catalog            = $package.catalog.displayName
    displayName        = $package.displayName
    description        = $package.description
    isHidden           = [bool]$package.isHidden
    resourceRoles      = $resourceRoles
    assignmentPolicies = $policies
}

if (-not $OutFile) {
    $safeName = ($DisplayName -replace '[^A-Za-z0-9\-]', '-').ToLowerInvariant()
    $OutFile = Join-Path $PSScriptRoot 'local' "$safeName.json"
}
$directory = Split-Path -Parent $OutFile
if ($directory -and -not (Test-Path $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }

$definition | ConvertTo-Json -Depth 20 | Set-Content -Path $OutFile -Encoding utf8
Write-Host "Wrote $OutFile"
Write-Host "$($resourceRoles.Count) resource role(s), $($policies.Count) assignment policy(ies)."
