# Shared helpers for exporting and deploying Lifecycle Workflow definitions.
# Dot-source this file; do not run it directly.

Set-StrictMode -Version Latest

# Properties Microsoft Graph assigns. They must not appear in a create or
# createNewVersion request body, so the export strips them.
$script:ServerAssignedWorkflowProperties = @(
    'id'
    'version'
    'createdDateTime'
    'lastModifiedDateTime'
    'deletedDateTime'
    'nextScheduleRunDateTime'
    'createdBy'
    'lastModifiedBy'
    'executionScope'
    'previewScope'
)

$script:ServerAssignedTaskProperties = @(
    'id'
    'category'
    'executionSequence'
)

# Only these four workflow properties accept a PATCH. Changing anything else
# requires a new workflow version.
$script:PatchableWorkflowProperties = @(
    'displayName'
    'description'
    'isEnabled'
    'isSchedulingEnabled'
)

$script:GraphScopes = @(
    'LifecycleWorkflows-Workflow.ReadWrite.All'
    'Group.Read.All'
    'EntitlementManagement.Read.All'
)

function Connect-ProjectGraph {
    <#
    .SYNOPSIS
    Connects to Microsoft Graph with the least privilege these scripts need.
    #>
    [CmdletBinding()]
    param(
        [string] $TenantId
    )

    $context = Get-MgContext -ErrorAction SilentlyContinue
    if ($context) {
        $missing = $script:GraphScopes | Where-Object { $_ -notin $context.Scopes }
        if (-not $missing) {
            Write-Verbose "Reusing the existing Microsoft Graph connection."
            return
        }
        Write-Verbose "Reconnecting to add missing scopes: $($missing -join ', ')"
    }

    $connectArgs = @{ Scopes = $script:GraphScopes; NoWelcome = $true }
    if ($TenantId) { $connectArgs['TenantId'] = $TenantId }
    Connect-MgGraph @connectArgs
}

function Invoke-Graph {
    <#
    .SYNOPSIS
    Calls Microsoft Graph v1.0 and returns the response as a PSObject.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')] [string] $Method,
        [Parameter(Mandatory)] [string] $Uri,
        [object] $Body
    )

    $requestArgs = @{
        Method     = $Method
        Uri        = "https://graph.microsoft.com/v1.0$Uri"
        OutputType = 'PSObject'
    }
    if ($PSBoundParameters.ContainsKey('Body')) {
        $requestArgs['Body'] = ($Body | ConvertTo-Json -Depth 20 -Compress)
        $requestArgs['ContentType'] = 'application/json'
    }

    Invoke-MgGraphRequest @requestArgs
}

function ConvertTo-ODataLiteral {
    <#
    .SYNOPSIS
    Escapes a string for use inside an OData filter literal.
    #>
    param([Parameter(Mandatory)] [string] $Value)
    $Value -replace "'", "''"
}

# ---------------------------------------------------------------------------
# Placeholder resolution
# ---------------------------------------------------------------------------
#
# Committed workflow definitions carry no tenant object IDs. They use
# placeholders that these functions resolve at deployment time:
#
#   ${group:AWS-Developers}
#   ${accessPackage:AP-Cross-Cloud Baseline}
#   ${accessPackagePolicy:AP-Cross-Cloud Baseline|Direct assignment}
#
# A group placeholder may hold a comma-separated list, because the group tasks
# accept several group IDs in one argument.

$script:PlaceholderPattern = '\$\{(?<kind>group|accessPackage|accessPackagePolicy):(?<name>[^}]+)\}'
$script:ResolverCache = @{}

function Resolve-GroupId {
    param([Parameter(Mandatory)] [string] $DisplayName)

    $key = "group:$DisplayName"
    if ($script:ResolverCache.ContainsKey($key)) { return $script:ResolverCache[$key] }

    $filter = "displayName eq '$(ConvertTo-ODataLiteral $DisplayName)'"
    $response = Invoke-Graph -Method GET -Uri "/groups?`$filter=$([uri]::EscapeDataString($filter))&`$select=id,displayName"
    $found = @($response.value)

    if ($found.Count -eq 0) { throw "No group found with display name '$DisplayName'." }
    if ($found.Count -gt 1) { throw "Display name '$DisplayName' matches $($found.Count) groups. Group display names must be unique for placeholder resolution." }

    $script:ResolverCache[$key] = $found[0].id
    $found[0].id
}

function Get-AccessPackageWithPolicies {
    param([Parameter(Mandatory)] [string] $DisplayName)

    $key = "accessPackageObject:$DisplayName"
    if ($script:ResolverCache.ContainsKey($key)) { return $script:ResolverCache[$key] }

    $filter = "displayName eq '$(ConvertTo-ODataLiteral $DisplayName)'"
    $uri = "/identityGovernance/entitlementManagement/accessPackages?`$filter=$([uri]::EscapeDataString($filter))&`$expand=assignmentPolicies"
    $response = Invoke-Graph -Method GET -Uri $uri
    $found = @($response.value)

    if ($found.Count -eq 0) { throw "No access package found with display name '$DisplayName'." }
    if ($found.Count -gt 1) { throw "Display name '$DisplayName' matches $($found.Count) access packages. Access package display names must be unique for placeholder resolution." }

    $script:ResolverCache[$key] = $found[0]
    $found[0]
}

function Resolve-AccessPackageId {
    param([Parameter(Mandatory)] [string] $DisplayName)
    (Get-AccessPackageWithPolicies -DisplayName $DisplayName).id
}

function Resolve-AccessPackagePolicyId {
    param([Parameter(Mandatory)] [string] $Reference)

    $parts = $Reference -split '\|', 2
    if ($parts.Count -ne 2) {
        throw "Access package policy placeholder must be '<access package>|<policy>'. Got '$Reference'."
    }

    $packageName = $parts[0].Trim()
    $policyName = $parts[1].Trim()
    $package = Get-AccessPackageWithPolicies -DisplayName $packageName
    $policies = @($package.assignmentPolicies)
    $policy = $policies | Where-Object { $_.displayName -eq $policyName }

    if (-not $policy) {
        $available = ($policies | ForEach-Object { "'$($_.displayName)'" }) -join ', '
        throw "Access package '$packageName' has no assignment policy named '$policyName'. Available policies: $available."
    }

    @($policy)[0].id
}

function Resolve-Placeholder {
    <#
    .SYNOPSIS
    Replaces every placeholder in a string with the matching tenant object ID.
    .DESCRIPTION
    Matches are replaced from right to left so that earlier match offsets stay
    valid. A group placeholder may appear inside a comma-separated list, so each
    element resolves independently and the separators are preserved.
    #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Value)

    $result = $Value
    $placeholderMatches = [regex]::Matches($Value, $script:PlaceholderPattern)

    for ($i = $placeholderMatches.Count - 1; $i -ge 0; $i--) {
        $match = $placeholderMatches[$i]
        $kind = $match.Groups['kind'].Value
        $name = $match.Groups['name'].Value.Trim()

        $resolved = switch ($kind) {
            'group' { Resolve-GroupId -DisplayName $name }
            'accessPackage' { Resolve-AccessPackageId -DisplayName $name }
            'accessPackagePolicy' { Resolve-AccessPackagePolicyId -Reference $name }
            default { throw "Unknown placeholder kind '$kind'." }
        }

        $result = $result.Remove($match.Index, $match.Length).Insert($match.Index, $resolved)
    }

    $result
}

function Resolve-PlaceholdersInObject {
    <#
    .SYNOPSIS
    Walks an object graph and resolves every placeholder found in a string value.
    #>
    param([Parameter(Mandatory)] [AllowNull()] $InputObject)

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [string]) {
        return Resolve-Placeholder -Value $InputObject
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        return ,@($InputObject | ForEach-Object { Resolve-PlaceholdersInObject -InputObject $_ })
    }

    if ($InputObject -is [psobject] -and (@($InputObject.PSObject.Properties).Count -gt 0)) {
        $result = [ordered]@{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $result[$property.Name] = Resolve-PlaceholdersInObject -InputObject $property.Value
        }
        return [pscustomobject]$result
    }

    $InputObject
}

function Test-HasUnresolvedPlaceholder {
    param([Parameter(Mandatory)] $InputObject)
    ($InputObject | ConvertTo-Json -Depth 20) -match $script:PlaceholderPattern
}

# ---------------------------------------------------------------------------
# Workflow shaping and comparison
# ---------------------------------------------------------------------------

function ConvertTo-WorkflowRequestBody {
    <#
    .SYNOPSIS
    Removes server-assigned properties so a workflow can be sent back to Graph.
    #>
    param([Parameter(Mandatory)] $Workflow)

    $body = [ordered]@{}
    foreach ($property in $Workflow.PSObject.Properties) {
        if ($property.Name -in $script:ServerAssignedWorkflowProperties) { continue }
        if ($property.Name -like '*@odata.context') { continue }
        if ($property.Name -eq 'tasks') { continue }
        $body[$property.Name] = $property.Value
    }

    $tasks = @()
    foreach ($task in @($Workflow.tasks)) {
        $shaped = [ordered]@{}
        foreach ($property in $task.PSObject.Properties) {
            if ($property.Name -in $script:ServerAssignedTaskProperties) { continue }
            if ($property.Name -like '*@odata.context') { continue }
            $shaped[$property.Name] = $property.Value
        }
        # Graph rejects a null arguments collection; an empty array is correct.
        if (-not $shaped.Contains('arguments') -or $null -eq $shaped['arguments']) {
            $shaped['arguments'] = @()
        }
        $tasks += [pscustomobject]$shaped
    }
    $body['tasks'] = $tasks

    [pscustomobject]$body
}

function Get-WorkflowByDisplayName {
    param([Parameter(Mandatory)] [string] $DisplayName)

    $filter = "displayName eq '$(ConvertTo-ODataLiteral $DisplayName)'"
    $response = Invoke-Graph -Method GET -Uri "/identityGovernance/lifecycleWorkflows/workflows?`$filter=$([uri]::EscapeDataString($filter))"
    $found = @($response.value)

    if ($found.Count -eq 0) { return $null }
    if ($found.Count -gt 1) { throw "Display name '$DisplayName' matches $($found.Count) workflows. Workflow display names must be unique." }

    # The list response omits tasks, so read the full workflow.
    Invoke-Graph -Method GET -Uri "/identityGovernance/lifecycleWorkflows/workflows/$($found[0].id)"
}

function Get-VersionedShape {
    <#
    .SYNOPSIS
    Returns the part of a workflow that can only change through a new version.
    #>
    param([Parameter(Mandatory)] $Workflow)

    $tasks = @(@($Workflow.tasks) | ForEach-Object {
            [ordered]@{
                displayName     = $_.displayName
                description     = $_.description
                isEnabled       = [bool]$_.isEnabled
                continueOnError = [bool]$_.continueOnError
                taskDefinitionId = ([string]$_.taskDefinitionId).ToLowerInvariant()
                arguments       = @(@($_.arguments) |
                        Sort-Object -Property name |
                        ForEach-Object { [ordered]@{ name = $_.name; value = [string]$_.value } })
            }
        })

    [ordered]@{
        executionConditions = $Workflow.executionConditions
        tasks               = $tasks
    } | ConvertTo-Json -Depth 20
}
