#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication

<#
.SYNOPSIS
Runs a Lifecycle Workflow on demand and reports what each task did, with timings.

.DESCRIPTION
The portal shows a workflow run as a pass or fail count. That is enough to say a
Joiner worked and not enough to say how long access took to arrive, which is the
claim this project makes. This script activates a workflow for named users,
waits for the run to reach a terminal state, and prints the per-task timings
Graph records, optionally as a Markdown table for a worklog.

Timings come from Graph, not from this script's own clock. The only local
measurement is the interval between activation and the first task starting,
which the summary reports as queue time.

On-demand runs ignore the workflow's execution conditions: every task is applied
to every named user whether or not they match the scope or trigger. That is what
makes it a test tool, and it is also why it needs care against real accounts.

.PARAMETER WorkflowDisplayName
The workflow to run. Display names are unique in this project.

.PARAMETER UserPrincipalName
One to ten users to run it against. Graph rejects more than ten per activation.

.PARAMETER TimeoutSeconds
How long to wait for the run to finish before giving up on it. The run itself
keeps going in the tenant; only the wait stops.

.PARAMETER PollSeconds
Interval between result reads.

.PARAMETER OutFile
Writes the report as Markdown. Defaults to no file.

.EXAMPLE
./run.ps1 -WorkflowDisplayName 'CrossCloud Leaver' -UserPrincipalName ana@contoso.com -WhatIf
Resolves the workflow and the user, then reports what it would activate.

.EXAMPLE
./run.ps1 -WorkflowDisplayName 'CrossCloud Mover' -UserPrincipalName ana@contoso.com -OutFile ./local/mover-run.md
Runs the Mover and writes the timing table for the worklog.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $WorkflowDisplayName,
    [Parameter(Mandatory)] [ValidateCount(1, 10)] [string[]] $UserPrincipalName,
    [ValidateRange(30, 7200)] [int] $TimeoutSeconds = 600,
    [ValidateRange(5, 120)] [int] $PollSeconds = 15,
    [string] $OutFile,
    [string] $TenantId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

# Activating a workflow and resolving a user by principal name need more than
# the deploy scripts do.
$runScopes = @(
    'LifecycleWorkflows-Workflow.ReadWrite.All'
    'User.Read.All'
)

# processingStatus values that mean the run is still moving.
$pendingStatuses = @('queued', 'inProgress')

function Get-UserId {
    param([Parameter(Mandatory)] [string] $PrincipalName)

    $escaped = [uri]::EscapeDataString($PrincipalName)
    try {
        $user = Invoke-Graph -Method GET -Uri "/users/$escaped`?`$select=id,displayName,userPrincipalName,accountEnabled,jobTitle"
    }
    catch {
        throw "No user found with principal name '$PrincipalName'. $($_.Exception.Message)"
    }
    $user
}

function Get-UserProcessingResult {
    <#
    .SYNOPSIS
    Reads the recent user processing results for a workflow.
    .DESCRIPTION
    The collection has no reliable server-side filter for the subject, so the
    caller matches on subject id. Newest first keeps the read short; a tenant
    that rejects the ordering falls back to more pages of the default order.
    #>
    param([Parameter(Mandatory)] [string] $WorkflowId)

    $base = "/identityGovernance/lifecycleWorkflows/workflows/$WorkflowId/userProcessingResults"
    try {
        Invoke-GraphCollection -Uri ($base + (New-GraphQuery @{ '$top' = 100; '$orderby' = 'startedDateTime desc' })) -MaxPages 2
    }
    catch {
        Write-Verbose "The tenant rejected `$orderby on userProcessingResults; reading the default order instead."
        Invoke-GraphCollection -Uri ($base + (New-GraphQuery @{ '$top' = 100 })) -MaxPages 5
    }
}

function Get-Timestamp {
    <#
    .SYNOPSIS
    Reads a Graph date property that may be absent or null.
    #>
    param([Parameter(Mandatory)] [AllowNull()] $Object, [Parameter(Mandatory)] [string] $Name)

    if ($null -eq $Object) { return $null }
    if ($Object.PSObject.Properties.Name -notcontains $Name) { return $null }
    $value = $Object.$Name
    if ($null -eq $value -or $value -eq '') { return $null }
    [datetime]::Parse($value, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal)
}

function Format-Duration {
    param([AllowNull()] [datetime] $Start, [AllowNull()] [datetime] $End)

    if ($null -eq $Start -or $null -eq $End) { return '' }
    $span = $End - $Start
    if ($span.TotalSeconds -lt 0) { return '' }
    if ($span.TotalMinutes -lt 1) { return "{0:0.0}s" -f $span.TotalSeconds }
    "{0:0}m {1:0}s" -f [math]::Floor($span.TotalMinutes), $span.Seconds
}

function Format-Utc {
    param([AllowNull()] $Value)
    if ($null -eq $Value) { return '' }
    ([datetime]$Value).ToString('yyyy-MM-dd HH:mm:ss')
}

# ---------------------------------------------------------------------------

Connect-ProjectGraph -Scopes $runScopes -TenantId $TenantId

$workflow = Get-WorkflowByDisplayName -DisplayName $WorkflowDisplayName
if (-not $workflow) { throw "No workflow found with display name '$WorkflowDisplayName'." }

# Graph refuses to activate a disabled workflow, and the error it returns does
# not say so.
if (-not $workflow.isEnabled) {
    throw "Workflow '$WorkflowDisplayName' is disabled. Enable it before running it on demand."
}

Write-Host "Workflow : $($workflow.displayName) ($($workflow.category), version $($workflow.version))"

$subjects = foreach ($principal in $UserPrincipalName) {
    $user = Get-UserId -PrincipalName $principal
    Write-Host "Subject  : $($user.displayName) <$($user.userPrincipalName)> enabled=$($user.accountEnabled) title='$($user.jobTitle)'"
    $user
}
$subjects = @($subjects)
$subjectIds = @($subjects | ForEach-Object { $_.id })

# Results already present for these subjects. Anything outside this set after
# activation belongs to this run, which is more reliable than comparing the
# tenant's clock with this machine's.
$priorResultIds = @(Get-UserProcessingResult -WorkflowId $workflow.id |
        Where-Object { $_.subject.id -in $subjectIds } |
        ForEach-Object { $_.id })

if (-not $PSCmdlet.ShouldProcess("$($workflow.displayName) for $($UserPrincipalName -join ', ')", 'Run workflow on demand')) {
    Write-Host ""
    Write-Host "Would activate this workflow for $($subjects.Count) user(s). No call was made."
    return
}

$activatedAt = [datetime]::UtcNow
Invoke-Graph -Method POST `
    -Uri "/identityGovernance/lifecycleWorkflows/workflows/$($workflow.id)/activate" `
    -Body @{ subjects = @($subjectIds | ForEach-Object { @{ id = $_ } }) } | Out-Null

Write-Host ""
Write-Host "Activated at $($activatedAt.ToString('yyyy-MM-dd HH:mm:ss')) UTC. Waiting up to $TimeoutSeconds seconds."

$deadline = $activatedAt.AddSeconds($TimeoutSeconds)
$runResults = @()

while ([datetime]::UtcNow -lt $deadline) {
    Start-Sleep -Seconds $PollSeconds

    $runResults = @(Get-UserProcessingResult -WorkflowId $workflow.id |
            Where-Object { $_.subject.id -in $subjectIds -and $_.id -notin $priorResultIds })

    $settled = @($runResults | Where-Object { $_.processingStatus -notin $pendingStatuses })
    $statusLine = if ($runResults) { ($runResults | ForEach-Object { $_.processingStatus }) -join ', ' } else { 'no result yet' }
    Write-Host "  $([datetime]::UtcNow.ToString('HH:mm:ss')) $($settled.Count)/$($subjects.Count) settled ($statusLine)"

    if ($runResults.Count -eq $subjects.Count -and $settled.Count -eq $subjects.Count) { break }
}

if (-not $runResults) {
    throw "No user processing result appeared within $TimeoutSeconds seconds. The run may still be queued; check the workflow history."
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

$taskRows = @()
$userRows = @()

foreach ($result in $runResults) {
    $tasks = @(Invoke-GraphCollection -Uri "/identityGovernance/lifecycleWorkflows/workflows/$($workflow.id)/userProcessingResults/$($result.id)/taskProcessingResults")
    $tasks = @($tasks | Sort-Object { Get-Timestamp -Object $_ -Name 'startedDateTime' })

    $subject = $subjects | Where-Object { $_.id -eq $result.subject.id } | Select-Object -First 1
    $userStart = Get-Timestamp -Object $result -Name 'startedDateTime'
    $userEnd = Get-Timestamp -Object $result -Name 'completedDateTime'

    $userRows += [pscustomobject]@{
        User      = if ($subject) { $subject.userPrincipalName } else { $result.subject.id }
        Status    = $result.processingStatus
        Tasks     = $tasks.Count
        Failed    = @($tasks | Where-Object { $_.processingStatus -eq 'failed' }).Count
        Queued    = Format-Duration -Start $activatedAt -End $userStart
        Duration  = Format-Duration -Start $userStart -End $userEnd
        Completed = Format-Utc $userEnd
    }

    foreach ($task in $tasks) {
        $start = Get-Timestamp -Object $task -Name 'startedDateTime'
        $end = Get-Timestamp -Object $task -Name 'completedDateTime'
        $taskRows += [pscustomobject]@{
            User      = if ($subject) { $subject.userPrincipalName } else { $result.subject.id }
            Task      = $task.task.displayName
            Status    = $task.processingStatus
            Started   = Format-Utc $start
            Completed = Format-Utc $end
            Duration  = Format-Duration -Start $start -End $end
            Elapsed   = Format-Duration -Start $activatedAt -End $end
        }
    }
}

Write-Host ""
$userRows | Format-Table -AutoSize
$taskRows | Format-Table -AutoSize

$failed = @($taskRows | Where-Object { $_.Status -eq 'failed' })
if ($failed) {
    Write-Warning "$($failed.Count) task(s) failed. Read the failure reason in the workflow history before drawing a conclusion from the timings."
}

if ($OutFile) {
    $lines = @()
    $lines += "Workflow ``$($workflow.displayName)`` version $($workflow.version), run on demand at $($activatedAt.ToString('yyyy-MM-dd HH:mm:ss')) UTC."
    $lines += ''
    $lines += '| User | Task | Status | Started (UTC) | Duration | Elapsed since activation |'
    $lines += '| --- | --- | --- | --- | --- | --- |'
    foreach ($row in $taskRows) {
        $lines += "| $($row.User) | $($row.Task) | $($row.Status) | $($row.Started) | $($row.Duration) | $($row.Elapsed) |"
    }

    $directory = Split-Path -Parent $OutFile
    if ($directory -and -not (Test-Path $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $lines | Set-Content -Path $OutFile -Encoding utf8
    Write-Host "Wrote $OutFile"
    Write-Host "It carries user principal names. Redact them before committing."
}
