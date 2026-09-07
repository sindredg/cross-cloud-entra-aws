#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication

<#
.SYNOPSIS
Creates or updates entitlement management objects from version-controlled JSON.

.DESCRIPTION
Reconciles catalogs, access packages, their resource roles, and their assignment
policies. Every object is named, never identified by ID, so a definition carries
no tenant identifier and an export can be fed straight back in.

The reconcile is additive. It creates what is missing and updates what has
drifted on the properties a definition states, and it reports anything the
tenant has that the definition does not. It never deletes: removing a resource
role or a policy revokes access from live assignments, which is not a decision
a file comparison should make on its own.

Only declared properties are compared, so a definition states intent rather than
mirroring every Graph default.

.PARAMETER Path
A definition file or a directory of them. Defaults to ./local.

.PARAMETER TenantId
Optional tenant to sign in to.

.PARAMETER WhatIf
Reports the action for each definition without writing to the tenant.

.EXAMPLE
./deploy.ps1 -WhatIf
Shows what would change for every definition in ./local.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Path,
    [string] $TenantId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

# A resource request is asynchronous. The resource usually appears in a few
# seconds; this is the ceiling before the script gives up on it.
$resourceTimeoutSeconds = 120
$resourcePollSeconds = 5

$script:summary = @()

function Add-Summary {
    param([string] $File, [string] $Object, [string] $Action)
    $script:summary += [pscustomobject]@{ File = $File; Object = $Object; Action = $Action }
}

function Read-Definition {
    param([Parameter(Mandatory)] [System.IO.FileInfo] $File)

    $raw = Get-Content -Path $File.FullName -Raw
    if ($raw -match '<[A-Z][A-Z0-9_]*>') {
        throw "$($File.Name) contains example values. Copy it to local/ and replace every <PLACEHOLDER> before deployment."
    }

    $definition = $raw | ConvertFrom-Json
    if ($definition.PSObject.Properties.Name -notcontains 'type') {
        throw "$($File.Name) is missing the required property 'type'. Use 'catalog' or 'accessPackage'."
    }
    if ($definition.type -notin @('catalog', 'accessPackage')) {
        throw "$($File.Name) declares type '$($definition.type)'. Use 'catalog' or 'accessPackage'."
    }
    $definition
}

function Get-DeclaredSubset {
    <#
    .SYNOPSIS
    Returns the named properties of a definition, skipping any it omits.
    #>
    param([Parameter(Mandatory)] $Definition, [Parameter(Mandatory)] [string[]] $Name)

    $subset = [ordered]@{}
    foreach ($property in $Name) {
        if ($Definition.PSObject.Properties.Name -contains $property) {
            $subset[$property] = $Definition.$property
        }
    }
    [pscustomobject]$subset
}

# ---------------------------------------------------------------------------
# Catalog
# ---------------------------------------------------------------------------

function Set-Catalog {
    param([Parameter(Mandatory)] $Definition, [Parameter(Mandatory)] [string] $FileName)

    $declared = Get-DeclaredSubset -Definition $Definition -Name @('displayName', 'description', 'state', 'isExternallyVisible')
    $existing = Get-CatalogByDisplayName -DisplayName $Definition.displayName

    if (-not $existing) {
        Write-Host "  Catalog '$($Definition.displayName)' does not exist."
        if ($PSCmdlet.ShouldProcess($Definition.displayName, 'Create catalog')) {
            $created = Invoke-Graph -Method POST -Uri '/identityGovernance/entitlementManagement/catalogs' -Body $declared
            Write-Host "  Created catalog $($created.id)."
            Add-Summary -File $FileName -Object "catalog $($Definition.displayName)" -Action 'create'
            return $created
        }
        Write-Host "  Would create this catalog."
        Add-Summary -File $FileName -Object "catalog $($Definition.displayName)" -Action 'create'
        return $null
    }

    $drift = @(Get-DeclaredPropertyDrift -Declared $declared -Actual $existing)
    if (-not $drift) {
        Write-Host "  Catalog already matches."
        Add-Summary -File $FileName -Object "catalog $($Definition.displayName)" -Action 'no change'
        return $existing
    }

    $drift | ForEach-Object { Write-Host "  Drift: $_" }
    if ($PSCmdlet.ShouldProcess($Definition.displayName, 'Update catalog')) {
        Invoke-Graph -Method PATCH -Uri "/identityGovernance/entitlementManagement/catalogs/$($existing.id)" -Body $declared | Out-Null
        Write-Host "  Updated catalog in place."
    }
    else { Write-Host "  Would update this catalog." }
    Add-Summary -File $FileName -Object "catalog $($Definition.displayName)" -Action 'update'
    $existing
}

# ---------------------------------------------------------------------------
# Resource roles
# ---------------------------------------------------------------------------

function Wait-CatalogResource {
    param([Parameter(Mandatory)] [string] $CatalogId, [Parameter(Mandatory)] [string] $OriginId)

    $deadline = [datetime]::UtcNow.AddSeconds($resourceTimeoutSeconds)
    while ([datetime]::UtcNow -lt $deadline) {
        $resource = Get-CatalogResource -CatalogId $CatalogId -OriginId $OriginId
        if ($resource) { return $resource }
        Start-Sleep -Seconds $resourcePollSeconds
    }
    throw "The resource $OriginId did not appear in the catalog within $resourceTimeoutSeconds seconds. Check the resource request in the portal."
}

function Set-ResourceRole {
    <#
    .SYNOPSIS
    Ensures one declared resource role is delivered by an access package.
    #>
    param(
        [Parameter(Mandatory)] $Declared,
        [Parameter(Mandatory)] [string] $CatalogId,
        [Parameter(Mandatory)] [string] $AccessPackageId,
        # A package with no roles yet is the normal case on a first deployment,
        # so an empty collection has to bind.
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $ExistingRoleScopes
    )

    foreach ($required in @('originSystem', 'resource', 'role')) {
        if ($Declared.PSObject.Properties.Name -notcontains $required) {
            throw "A resourceRoles entry is missing the required property '$required'."
        }
    }

    $originId = Resolve-ResourceOriginId -OriginSystem $Declared.originSystem -DisplayName $Declared.resource
    $resource = Get-CatalogResource -CatalogId $CatalogId -OriginId $originId

    if (-not $resource) {
        Write-Host "    Resource '$($Declared.resource)' is not in the catalog."
        if (-not $PSCmdlet.ShouldProcess("$($Declared.resource) -> catalog", 'Add resource to catalog')) {
            Write-Host "    Would add it, then add the '$($Declared.role)' role to the package."
            return [pscustomobject]@{ Action = 'add resource role'; RoleOriginId = $null }
        }
        Invoke-Graph -Method POST -Uri '/identityGovernance/entitlementManagement/resourceRequests' -Body @{
            requestType = 'adminAdd'
            resource    = @{ originId = $originId; originSystem = $Declared.originSystem }
            catalog     = @{ id = $CatalogId }
        } | Out-Null
        $resource = Wait-CatalogResource -CatalogId $CatalogId -OriginId $originId
        Write-Host "    Added resource $($resource.id) to the catalog."
    }

    $roles = @($resource.roles)
    $role = $roles | Where-Object { $_.displayName -eq $Declared.role } | Select-Object -First 1
    if (-not $role) {
        $available = ($roles | ForEach-Object { "'$($_.displayName)'" }) -join ', '
        throw "Resource '$($Declared.resource)' has no role named '$($Declared.role)'. Available roles: $available."
    }

    if (@($ExistingRoleScopes | Where-Object { $_.role.originId -eq $role.originId })) {
        Write-Host "    Role '$($Declared.role)' on '$($Declared.resource)' is already delivered."
        return [pscustomobject]@{ Action = 'no change'; RoleOriginId = $role.originId }
    }

    $scopes = @($resource.scopes)
    $scope = $scopes | Where-Object { $_.isRootScope } | Select-Object -First 1
    if (-not $scope) { $scope = $scopes | Select-Object -First 1 }
    if (-not $scope) { throw "Resource '$($Declared.resource)' has no scope to deliver the role into." }

    # Graph wants the role and scope objects it returned for the catalog
    # resource, not a hand-built pair, so they are passed through as read.
    $body = @{
        role  = @{
            id           = $role.id
            displayName  = $role.displayName
            description  = $role.description
            originSystem = $role.originSystem
            originId     = $role.originId
            resource     = @{ id = $resource.id; originId = $resource.originId; originSystem = $resource.originSystem }
        }
        scope = @{
            id           = $scope.id
            displayName  = $scope.displayName
            description  = $scope.description
            originId     = $scope.originId
            originSystem = $scope.originSystem
            isRootScope  = [bool]$scope.isRootScope
        }
    }

    if ($PSCmdlet.ShouldProcess("$($Declared.role) on $($Declared.resource)", 'Add resource role to access package')) {
        Invoke-Graph -Method POST -Uri "/identityGovernance/entitlementManagement/accessPackages/$AccessPackageId/resourceRoleScopes" -Body $body | Out-Null
        Write-Host "    Added role '$($Declared.role)' on '$($Declared.resource)'."
    }
    else { Write-Host "    Would add role '$($Declared.role)' on '$($Declared.resource)'." }
    [pscustomobject]@{ Action = 'add resource role'; RoleOriginId = $role.originId }
}

# ---------------------------------------------------------------------------
# Assignment policies
# ---------------------------------------------------------------------------

$script:PolicyProperties = @(
    'displayName'
    'description'
    'allowedTargetScope'
    'specificAllowedTargets'
    'expiration'
    'requestorSettings'
    'requestApprovalSettings'
    'reviewSettings'
    'automaticRequestSettings'
    'notificationSettings'
)

function Set-AssignmentPolicy {
    param(
        [Parameter(Mandatory)] $Declared,
        [Parameter(Mandatory)] [string] $AccessPackageId,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $ExistingPolicies
    )

    $body = Get-DeclaredSubset -Definition $Declared -Name $script:PolicyProperties
    $existing = $ExistingPolicies | Where-Object { $_.displayName -eq $Declared.displayName } | Select-Object -First 1

    # The policy carries the package reference on both create and update.
    $body | Add-Member -NotePropertyName 'accessPackage' -NotePropertyValue ([pscustomobject]@{ id = $AccessPackageId })

    if (-not $existing) {
        if ($PSCmdlet.ShouldProcess($Declared.displayName, 'Create assignment policy')) {
            $created = Invoke-Graph -Method POST -Uri '/identityGovernance/entitlementManagement/assignmentPolicies' -Body $body
            Write-Host "    Created policy '$($Declared.displayName)' ($($created.id))."
        }
        else { Write-Host "    Would create policy '$($Declared.displayName)'." }
        return 'create policy'
    }

    $drift = @(Get-DeclaredPropertyDrift -Declared (Get-DeclaredSubset -Definition $Declared -Name $script:PolicyProperties) -Actual $existing)
    if (-not $drift) {
        Write-Host "    Policy '$($Declared.displayName)' already matches."
        return 'no change'
    }

    $drift | ForEach-Object { Write-Host "    Drift: $_" }
    if ($PSCmdlet.ShouldProcess($Declared.displayName, 'Update assignment policy')) {
        # A policy update replaces the whole policy, so the full declared body
        # goes back even for a single changed property.
        Invoke-Graph -Method PUT -Uri "/identityGovernance/entitlementManagement/assignmentPolicies/$($existing.id)" -Body $body | Out-Null
        Write-Host "    Updated policy '$($Declared.displayName)'."
    }
    else { Write-Host "    Would update policy '$($Declared.displayName)'." }
    'update policy'
}

# ---------------------------------------------------------------------------
# Access package
# ---------------------------------------------------------------------------

function Set-AccessPackage {
    param([Parameter(Mandatory)] $Definition, [Parameter(Mandatory)] [string] $FileName)

    if ($Definition.PSObject.Properties.Name -notcontains 'catalog') {
        throw "$FileName is missing the required property 'catalog'."
    }

    $catalog = Get-CatalogByDisplayName -DisplayName $Definition.catalog
    if (-not $catalog) {
        throw "$FileName references catalog '$($Definition.catalog)', which does not exist. Deploy the catalog definition first."
    }

    $declared = Get-DeclaredSubset -Definition $Definition -Name @('displayName', 'description', 'isHidden')
    $existing = Get-AccessPackageByDisplayName -DisplayName $Definition.displayName -CatalogId $catalog.id
    $action = 'no change'

    if (-not $existing) {
        Write-Host "  Access package '$($Definition.displayName)' does not exist in catalog '$($catalog.displayName)'."
        $createBody = $declared.PSObject.Copy()
        $createBody | Add-Member -NotePropertyName 'catalog' -NotePropertyValue ([pscustomobject]@{ id = $catalog.id })

        if (-not $PSCmdlet.ShouldProcess($Definition.displayName, 'Create access package')) {
            Write-Host "  Would create it, with $(@($Definition.resourceRoles).Count) resource role(s) and $(@($Definition.assignmentPolicies).Count) policy(ies)."
            Add-Summary -File $FileName -Object $Definition.displayName -Action 'create'
            return
        }
        $existing = Invoke-Graph -Method POST -Uri '/identityGovernance/entitlementManagement/accessPackages' -Body $createBody
        Write-Host "  Created access package $($existing.id)."
        $action = 'create'
    }
    else {
        $drift = @(Get-DeclaredPropertyDrift -Declared $declared -Actual $existing)
        if ($drift) {
            $drift | ForEach-Object { Write-Host "  Drift: $_" }
            if ($PSCmdlet.ShouldProcess($Definition.displayName, 'Update access package')) {
                Invoke-Graph -Method PATCH -Uri "/identityGovernance/entitlementManagement/accessPackages/$($existing.id)" -Body $declared | Out-Null
                Write-Host "  Updated the access package in place."
            }
            else { Write-Host "  Would update the access package." }
            $action = 'update'
        }
    }

    # Resource roles
    $existingRoleScopes = @(Get-ResourceRoleScope -AccessPackageId $existing.id)
    $declaredRoleOriginIds = @()
    foreach ($declaredRole in @($Definition.resourceRoles)) {
        $result = Set-ResourceRole -Declared $declaredRole -CatalogId $catalog.id -AccessPackageId $existing.id -ExistingRoleScopes $existingRoleScopes
        if ($result.Action -ne 'no change') { $action = 'update' }
        if ($result.RoleOriginId) { $declaredRoleOriginIds += $result.RoleOriginId }
    }

    # Roles the tenant delivers that no definition claims. Reported, never
    # removed: deleting one revokes access from every live assignment.
    foreach ($roleScope in $existingRoleScopes) {
        if ($roleScope.role.originId -notin $declaredRoleOriginIds) {
            Write-Warning "  '$($Definition.displayName)' delivers the role '$($roleScope.role.displayName)' ($($roleScope.role.originSystem)), which this definition does not declare. Nothing was removed; remove it in the portal if it is unwanted."
        }
    }

    # Assignment policies. A package this run just created carries none, and an
    # `if` block that evaluates to @() assigns null rather than an empty array,
    # so the empty case is set up first.
    $existingPolicies = @()
    if ($existing.PSObject.Properties.Name -contains 'assignmentPolicies') {
        $existingPolicies = @($existing.assignmentPolicies)
    }
    foreach ($declaredPolicy in @($Definition.assignmentPolicies)) {
        $result = Set-AssignmentPolicy -Declared $declaredPolicy -AccessPackageId $existing.id -ExistingPolicies $existingPolicies
        if ($result -ne 'no change') { $action = 'update' }
    }

    $declaredPolicyNames = @(@($Definition.assignmentPolicies) | ForEach-Object { $_.displayName })
    foreach ($policy in $existingPolicies) {
        if ($policy.displayName -notin $declaredPolicyNames) {
            Write-Warning "  '$($Definition.displayName)' has policy '$($policy.displayName)', which this definition does not declare. Nothing was removed."
        }
    }

    Add-Summary -File $FileName -Object $Definition.displayName -Action $action
}

# ---------------------------------------------------------------------------

if (-not $Path) { $Path = Join-Path $PSScriptRoot 'local' }
if (-not (Test-Path $Path)) { throw "Path not found: $Path" }

$definitionFiles = if (Test-Path $Path -PathType Container) {
    Get-ChildItem -Path $Path -Filter '*.json' | Sort-Object Name
}
else {
    Get-Item -Path $Path
}

if (-not $definitionFiles) { throw "No *.json definitions found under $Path." }

Connect-ProjectGraph -Scopes $script:GraphScopes -TenantId $TenantId

# A package cannot be created before its catalog, so catalogs go first no matter
# how the files sort.
$definitions = foreach ($file in $definitionFiles) {
    [pscustomobject]@{ File = $file; Definition = (Read-Definition -File $file) }
}
$definitions = @($definitions) | Sort-Object { if ($_.Definition.type -eq 'catalog') { 0 } else { 1 } }, { $_.File.Name }

foreach ($entry in $definitions) {
    Write-Host ""
    Write-Host "== $($entry.File.Name)"

    switch ($entry.Definition.type) {
        'catalog' { Set-Catalog -Definition $entry.Definition -FileName $entry.File.Name | Out-Null }
        'accessPackage' { Set-AccessPackage -Definition $entry.Definition -FileName $entry.File.Name }
    }
}

Write-Host ""
$script:summary | Format-Table -AutoSize

if ($script:summary | Where-Object { $_.Action -ne 'no change' }) {
    Write-Host "Confirm the package in the portal, then run the workflow that assigns it."
}
