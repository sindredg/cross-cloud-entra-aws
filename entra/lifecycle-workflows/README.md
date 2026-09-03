# Lifecycle Workflows as code

Joiner, Mover, and Leaver definitions as Microsoft Graph JSON, plus the scripts that export and deploy them.

Microsoft Graph Bicep cannot manage these resources. It supports only `applications`, `appRoleAssignedTo`, `federatedIdentityCredentials`, `groups`, `oauth2PermissionGrants`, `servicePrincipals`, and `users`, so the pattern in [`entra/groups/`](../groups/) does not extend here. These definitions go to the Graph REST API instead.

## Layout

```text
workflows/*.example.json   Committed templates. Placeholders, never object IDs.
local/                     Your filled-in definitions and raw exports. Git-ignored.
deploy.ps1                 Creates or updates workflows from JSON. Defaults to local/.
export.ps1                 Reads a workflow from the tenant into local/.
common.ps1                 Shared Graph helpers. Dot-sourced, not run directly.
```

Nothing in `local/` is ever committed. It holds tenant object IDs and display names.

## Placeholders

Two kinds, and they do different jobs.

`<UPPER_SNAKE>` marks a value you must supply. `deploy.ps1` refuses any file that still contains one, so a template cannot reach the tenant by accident:

```text
<JOINER_WORKFLOW_DISPLAY_NAME>
<PROJECT_COMPANY_NAME>
<BASELINE_ACCESS_PACKAGE_DISPLAY_NAME>
<DIRECT_ASSIGNMENT_POLICY_DISPLAY_NAME>
```

`${type:name}` marks an object ID that resolves at deployment time. Task arguments reference groups and access packages by ID, and committing those would publish tenant identifiers:

| Placeholder | Resolves to |
| --- | --- |
| `${group:AWS-Developers}` | That group's object ID |
| `${accessPackage:AP-Cross-Cloud Baseline}` | That access package's ID |
| `${accessPackagePolicy:AP-Cross-Cloud Baseline\|Initial Policy}` | That assignment policy's ID inside the package |

Resolution fails if a display name matches no object or more than one, so a rename produces an error rather than a wrong deployment. Group tasks accept several groups in one argument, and placeholders resolve inside a comma-separated list.

## Prerequisites

- PowerShell 7 and `Microsoft.Graph.Authentication`.
- Lifecycle Workflows Administrator, plus Identity Governance Administrator to read entitlement management objects.
- Delegated scopes `LifecycleWorkflows-Workflow.ReadWrite.All`, `Group.Read.All`, and `EntitlementManagement.Read.All`. The scripts request them on connect.

```bash
pwsh -Command "Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
```

## Deploy

Copy a template, fill in every `<PLACEHOLDER>`, and keep the result in `local/`:

```bash
cp entra/lifecycle-workflows/workflows/joiner.example.json entra/lifecycle-workflows/local/joiner.json
```

Review the plan first. `-WhatIf` makes no write calls:

```bash
pwsh ./entra/lifecycle-workflows/deploy.ps1 -WhatIf
```

Then apply:

```bash
pwsh ./entra/lifecycle-workflows/deploy.ps1
```

With no `-Path`, the script reads every `*.json` in `local/`.

The workflow display name is the identity key. For each definition the script picks one of four paths:

| Situation | Action |
| --- | --- |
| No workflow with that display name | `POST` creates it |
| Only `displayName`, `description`, `isEnabled`, or `isSchedulingEnabled` differ | `PATCH` updates it in place |
| `tasks` or `executionConditions` differ | `createNewVersion` publishes a new version |
| Nothing differs | No write call |

The split is forced by the API: `PATCH` on a workflow accepts only those four properties, so the script compares the task list and execution conditions separately.

`category` cannot change after creation. If a definition changes it, the script stops and tells you to use a different display name.

## Export

After editing a workflow in the portal, pull the change back:

```bash
pwsh ./entra/lifecycle-workflows/export.ps1 -DisplayName 'CrossCloud Joiner' -Templatize
```

Exports always land in `local/`. The script strips the properties Graph assigns itself (`id`, `version`, `createdDateTime`, `lastModifiedDateTime`, `deletedDateTime`, `nextScheduleRunDateTime`, `createdBy`, `lastModifiedBy`, and each task `id`, `category`, and `executionSequence`) so the result is a valid create body.

`-Templatize` maps object IDs in task arguments back to `${type:name}` placeholders and warns about any GUID it cannot map. To update a committed template, diff the export against it by hand and put the `<PLACEHOLDER>` tokens back before staging.

## Scheduling and triggers

Every committed definition sets `isSchedulingEnabled` to `false`. Run a workflow on demand and confirm its history before enabling the schedule. Two consequences follow:

- Attribute change triggers are only evaluated for scheduled workflows, so the Mover runs on demand until scheduling is on.
- A time-based trigger such as `employeeHireDate` never fires on its own while scheduling is off.

An `attributeChangeTrigger` accepts exactly one attribute. Declaring two returns `400 BAD_REQUEST: Multiple trigger attributes are not allowed`; covering a second attribute takes a second workflow.

## Definitions

| File | Category | What it does |
| --- | --- | --- |
| `joiner.example.json` | joiner | Enables the account, then requests the baseline access package through its direct-assignment policy |
| `mover.example.json` | mover | Removes the previous access package, requests the new one, and revokes refresh tokens so the next token carries new claims |
| `leaver.example.json` | leaver | Cancels pending requests, removes all access package assignments, revokes refresh tokens, and disables the account so SCIM deprovisions the AWS user |

The Joiner matches the workflow validated in Phase 2. The deployed Mover currently carries only the token revocation task; its access package swap waits on the elevated package that Phase 7 creates. The Leaver has been deployed but not yet run.
