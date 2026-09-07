# Microsoft Graph primitives shared by the deployment scripts under entra/.
# Dot-source this file; do not run it directly.

Set-StrictMode -Version Latest

function Connect-ProjectGraph {
    <#
    .SYNOPSIS
    Connects to Microsoft Graph with the least privilege the caller needs.
    .DESCRIPTION
    Reuses an existing connection when it already carries every requested scope,
    so running several scripts in one session prompts once.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $Scopes,
        [string] $TenantId
    )

    $context = Get-MgContext -ErrorAction SilentlyContinue
    if ($context) {
        $missing = $Scopes | Where-Object { $_ -notin $context.Scopes }
        if (-not $missing) {
            Write-Verbose "Reusing the existing Microsoft Graph connection."
            return
        }
        Write-Verbose "Reconnecting to add missing scopes: $($missing -join ', ')"
    }

    $connectArgs = @{ Scopes = $Scopes; NoWelcome = $true }
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
        [Parameter(Mandatory)] [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')] [string] $Method,
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

function Invoke-GraphCollection {
    <#
    .SYNOPSIS
    Returns every item of a Graph collection, following @odata.nextLink.
    .DESCRIPTION
    The items are written to the pipeline rather than returned as one array.
    Callers wrap the call in @(), which then counts and indexes correctly for
    zero, one, or many items; returning ",$array" instead would hand them an
    array holding an array.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Uri,
        [int] $MaxPages = 20
    )

    $items = @()
    $next = $Uri
    $page = 0

    while ($next -and $page -lt $MaxPages) {
        # A nextLink is already absolute; Invoke-Graph prepends the service root
        # to anything else.
        $response = if ($next -like 'https://*') {
            Invoke-MgGraphRequest -Method GET -Uri $next -OutputType PSObject
        }
        else {
            Invoke-Graph -Method GET -Uri $next
        }

        $items += @($response.value)
        $next = if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
            $response.'@odata.nextLink'
        }
        else { $null }
        $page++
    }

    if ($next) { Write-Warning "Stopped after $MaxPages pages; the collection at $Uri has more results." }
    $items
}

function ConvertTo-ODataLiteral {
    <#
    .SYNOPSIS
    Escapes a string for use inside an OData filter literal.
    #>
    param([Parameter(Mandatory)] [string] $Value)
    $Value -replace "'", "''"
}

function New-GraphQuery {
    <#
    .SYNOPSIS
    Builds an escaped OData query string from a hashtable of options.
    .EXAMPLE
    New-GraphQuery @{ '$filter' = "displayName eq 'x'"; '$expand' = 'roles' }
    #>
    param([Parameter(Mandatory)] [hashtable] $Options)

    $parts = foreach ($key in ($Options.Keys | Sort-Object)) {
        "$key=$([uri]::EscapeDataString([string]$Options[$key]))"
    }
    '?' + ($parts -join '&')
}
