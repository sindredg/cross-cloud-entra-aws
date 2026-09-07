# Shared helpers for exporting and deploying entitlement management definitions.
# Dot-source this file; do not run it directly.

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot '..' 'graph-common.ps1')

# Reading groups and applications is needed to turn a display name into the
# originId entitlement management stores for a resource.
$script:GraphScopes = @(
    'EntitlementManagement.ReadWrite.All'
    'Group.Read.All'
    'Application.Read.All'
)

# Origin systems this project uses. Each one resolves a display name to an
# object ID differently, so the set is closed on purpose.
$script:SupportedOriginSystems = @('AadGroup', 'AadApplication')

# ---------------------------------------------------------------------------
# Resolving display names
# ---------------------------------------------------------------------------
#
# Committed definitions name every object. Nothing here writes an object ID to
# a file, which is what keeps a tenant identifier out of the repository, and it
# also makes an export usable as an input without editing.

$script:ResolverCache = @{}

function Resolve-UniqueByDisplayName {
    <#
    .SYNOPSIS
    Returns the single directory object with this display name, or throws.
    #>
    param(
        [Parameter(Mandatory)] [string] $Collection,
        [Parameter(Mandatory)] [string] $DisplayName,
        [Parameter(Mandatory)] [string] $Kind
    )

    $key = "$Collection`:$DisplayName"
    if ($script:ResolverCache.ContainsKey($key)) { return $script:ResolverCache[$key] }

    $query = New-GraphQuery @{
        '$filter' = "displayName eq '$(ConvertTo-ODataLiteral $DisplayName)'"
        '$select' = 'id,displayName'
    }
    $found = @(Invoke-GraphCollection -Uri "/$Collection$query")

    if ($found.Count -eq 0) { throw "No $Kind found with display name '$DisplayName'." }
    if ($found.Count -gt 1) { throw "Display name '$DisplayName' matches $($found.Count) $Kind objects. Display names must be unique for this to resolve." }

    $script:ResolverCache[$key] = $found[0].id
    $found[0].id
}

function Resolve-ResourceOriginId {
    <#
    .SYNOPSIS
    Returns the originId entitlement management uses for a resource.
    .DESCRIPTION
    A group's originId is its own object ID. An application's is the object ID
    of its service principal, not of the application registration; using the
    application object here is the mistake that produces an empty catalog and no
    error.
    #>
    param(
        [Parameter(Mandatory)] [string] $OriginSystem,
        [Parameter(Mandatory)] [string] $DisplayName
    )

    switch ($OriginSystem) {
        'AadGroup' { Resolve-UniqueByDisplayName -Collection 'groups' -DisplayName $DisplayName -Kind 'group' }
        'AadApplication' { Resolve-UniqueByDisplayName -Collection 'servicePrincipals' -DisplayName $DisplayName -Kind 'service principal' }
        default { throw "Unsupported origin system '$OriginSystem'. Supported: $($script:SupportedOriginSystems -join ', ')." }
    }
}

# ---------------------------------------------------------------------------
# Reading entitlement management objects
# ---------------------------------------------------------------------------

function Get-CatalogByDisplayName {
    param([Parameter(Mandatory)] [string] $DisplayName)

    $query = New-GraphQuery @{ '$filter' = "displayName eq '$(ConvertTo-ODataLiteral $DisplayName)'" }
    $found = @(Invoke-GraphCollection -Uri "/identityGovernance/entitlementManagement/catalogs$query")

    if ($found.Count -eq 0) { return $null }
    if ($found.Count -gt 1) { throw "Display name '$DisplayName' matches $($found.Count) catalogs. Catalog display names must be unique." }
    $found[0]
}

function Get-AccessPackageByDisplayName {
    <#
    .SYNOPSIS
    Returns the access package with this display name inside a catalog.
    .DESCRIPTION
    Display names are unique per catalog rather than per tenant, so a match in
    another catalog is not this package and is reported rather than reused.
    #>
    param(
        [Parameter(Mandatory)] [string] $DisplayName,
        [Parameter(Mandatory)] [string] $CatalogId
    )

    $query = New-GraphQuery @{
        '$filter' = "displayName eq '$(ConvertTo-ODataLiteral $DisplayName)'"
        '$expand' = 'assignmentPolicies'
    }
    $found = @(Invoke-GraphCollection -Uri "/identityGovernance/entitlementManagement/accessPackages$query")
    $inCatalog = @($found | Where-Object { $_.catalogId -eq $CatalogId })

    if ($inCatalog.Count -gt 1) { throw "Display name '$DisplayName' matches $($inCatalog.Count) access packages in this catalog." }
    if ($inCatalog.Count -eq 1) { return $inCatalog[0] }

    if ($found.Count -gt 0) {
        Write-Warning "An access package named '$DisplayName' exists in a different catalog. It is left alone; this definition creates its own."
    }
    $null
}

function Get-CatalogResource {
    <#
    .SYNOPSIS
    Returns a catalog resource with its roles and scopes, or null.
    #>
    param(
        [Parameter(Mandatory)] [string] $CatalogId,
        [Parameter(Mandatory)] [string] $OriginId
    )

    $query = New-GraphQuery @{
        '$filter' = "originId eq '$(ConvertTo-ODataLiteral $OriginId)'"
        '$expand' = 'roles,scopes'
    }
    $found = @(Invoke-GraphCollection -Uri "/identityGovernance/entitlementManagement/catalogs/$CatalogId/resources$query")
    if ($found.Count -eq 0) { return $null }
    $found[0]
}

function Get-ResourceRoleScope {
    param([Parameter(Mandatory)] [string] $AccessPackageId)

    $query = New-GraphQuery @{ '$expand' = 'role,scope' }
    @(Invoke-GraphCollection -Uri "/identityGovernance/entitlementManagement/accessPackages/$AccessPackageId/resourceRoleScopes$query")
}

# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------

function Get-DeclaredPropertyDrift {
    <#
    .SYNOPSIS
    Lists the declared properties whose tenant value differs.
    .DESCRIPTION
    Only properties the definition states are compared. Graph returns many
    read-only and defaulted properties on these objects, and a definition that
    had to state every one of them would break on the next service change and
    would say nothing about intent. Anything the file does not mention is the
    tenant's business.
    #>
    param(
        [Parameter(Mandatory)] [AllowNull()] $Declared,
        [Parameter(Mandatory)] [AllowNull()] $Actual,
        [string] $Path = ''
    )

    $drift = @()
    $label = if ($Path) { $Path } else { '(root)' }

    if ($Declared -is [hashtable]) { $Declared = [pscustomobject]$Declared }
    if ($Actual -is [hashtable]) { $Actual = [pscustomobject]$Actual }

    if ($null -eq $Declared) {
        if ($null -ne $Actual) { $drift += "$label declared null, tenant has '$Actual'" }
        return $drift
    }

    if ($Declared -is [System.Collections.IEnumerable] -and $Declared -isnot [string]) {
        $declaredItems = @($Declared)
        $actualItems = @($Actual)
        if ($declaredItems.Count -ne $actualItems.Count) {
            $drift += "$label declared $($declaredItems.Count) item(s), tenant has $($actualItems.Count)"
            return $drift
        }
        for ($i = 0; $i -lt $declaredItems.Count; $i++) {
            $drift += Get-DeclaredPropertyDrift -Declared $declaredItems[$i] -Actual $actualItems[$i] -Path "$label[$i]"
        }
        return $drift
    }

    if ($Declared -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Declared.PSObject.Properties) {
            $childPath = if ($Path) { "$Path.$($property.Name)" } else { $property.Name }
            $actualProperty = if ($null -eq $Actual) { $null } else { $Actual.PSObject.Properties[$property.Name] }
            if ($null -eq $actualProperty) {
                $drift += "$childPath is not set in the tenant"
                continue
            }
            $drift += Get-DeclaredPropertyDrift -Declared $property.Value -Actual $actualProperty.Value -Path $childPath
        }
        return $drift
    }

    # Scalars. Compare as text so that a bool from JSON and a bool from Graph,
    # or an int and its string form, do not read as a difference.
    if ([string]$Declared -ne [string]$Actual) {
        $drift += "$label declared '$Declared', tenant has '$Actual'"
    }
    $drift
}
