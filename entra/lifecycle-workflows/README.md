# Lifecycle Workflows as code

This directory holds the Joiner, Mover, and Leaver workflow definitions as
Microsoft Graph JSON payloads, plus the scripts that export and deploy them.

Microsoft Graph Bicep cannot manage these resources. It supports only
`applications`, `appRoleAssignedTo`, `federatedIdentityCredentials`, `groups`,
`oauth2PermissionGrants`, `servicePrincipals`, and `users`. The Bicep pattern in
[`entra/groups/`](../groups/) therefore does not extend to Lifecycle Workflows,
and these definitions go to the Graph REST API instead.

## Layout

```text
workflows/*.example.json   Committed definitions. Placeholders, never object IDs.
local/                     Untemplatized exports. Ignored by Git.
export.ps1                 Reads a workflow from the tenant into JSON.
deploy.ps1                 Creates or updates workflows from the JSON.
common.ps1                 Shared Graph helpers. Dot-sourced, not run directly.
```

Only `*.example.json` files are committed and only they are deployed. An export
taken without `-Templatize` lands in `local/`, which Git ignores, because it
carries tenant object IDs.

## Placeholders

Task arguments reference groups and access packages by object ID. Committing
those IDs would put tenant identifiers into published documentation, so the
definitions use display-name placeholders that resolve at deployment time:

| Placeholder | Resolves to |
| --- | --- |
| `${group:AWS-Developers}` | The object ID of that group |
| `${accessPackage:AP-Cross-Cloud Baseline}` | The access package ID |
| `${accessPackagePolicy:AP-Cross-Cloud Baseline\|Direct assignment}` | The assignment policy ID inside that package |

Resolution fails loudly if a display name matches no object or more than one, so
a renamed group produces an error instead of a silently wrong deployment.

The group tasks accept several groups in one argument. Placeholders resolve
inside a comma-separated list, so `"${group:AWS-Developers}, ${group:AWS-Auditors}"`
works.

## Prerequisites

- PowerShell 7 and the `Microsoft.Graph.Authentication` module.
- The Lifecycle Workflows Administrator role, plus Identity Governance
  Administrator to read entitlement management objects.
- Delegated scopes `LifecycleWorkflows-Workflow.ReadWrite.All`, `Group.Read.All`,
  and `EntitlementManagement.Read.All`. The scripts request them on connect.

```bash
pwsh -Command "Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
```

## Deploy

Always review the plan first. `-WhatIf` makes no write calls:

```bash
pwsh ./entra/lifecycle-workflows/deploy.ps1 -WhatIf
```

Then apply:

```bash
pwsh ./entra/lifecycle-workflows/deploy.ps1
```

The workflow display name is the identity key. For each definition the script
picks one of four paths:

| Situation | Action |
| --- | --- |
| No workflow with that display name | `POST` creates it |
| Only `displayName`, `description`, `isEnabled`, or `isSchedulingEnabled` differ | `PATCH` updates it in place |
| `tasks` or `executionConditions` differ | `createNewVersion` publishes a new version |
| Nothing differs | No write call |

The three-way split is forced by the API. A `PATCH` on a workflow accepts only
those four properties. Everything else needs a new version, which is why the
script compares the task list and execution conditions separately.

`category` cannot change after creation. If a definition changes it, the script
stops and tells you to use a different display name.

## Export

After editing a workflow in the portal, pull the change back into Git:

```bash
pwsh ./entra/lifecycle-workflows/export.ps1 -DisplayName 'Onboard cross-cloud joiner' -Templatize
```

The export removes the properties Graph assigns itself (`id`, `version`,
`createdDateTime`, `lastModifiedDateTime`, `deletedDateTime`,
`nextScheduleRunDateTime`, `createdBy`, `lastModifiedBy`, and each task `id`,
`category`, and `executionSequence`) so the result is a valid create body.

`-Templatize` maps every object ID it finds in task arguments back to a
placeholder. Any GUID it cannot map is reported as a warning. Resolve those by
hand before committing, and diff the file before you stage it.

## Scheduling

Every committed definition sets `isSchedulingEnabled` to `false`. Run a workflow
on demand and confirm its history before enabling the schedule, as the project
plan requires.

Two consequences follow from that choice:

- Attribute change triggers are only evaluated for scheduled workflows, so the
  Mover definition runs on demand until scheduling is enabled.
- A time-based trigger such as `employeeHireDate` never fires on its own while
  scheduling is off.

## Definitions

| File | Category | What it does |
| --- | --- | --- |
| `joiner.example.json` | joiner | Enables the account, then requests the baseline access package through its direct-assignment policy |
| `mover.example.json` | mover | Removes the previous access package, requests the new one, and revokes refresh tokens so the next token carries new claims |
| `leaver.example.json` | leaver | Cancels pending requests, removes all access package assignments, revokes refresh tokens, and disables the account so SCIM deprovisions the AWS user |

The Mover and Leaver definitions are the project's intended design and have not
been run yet. The Joiner matches the workflow validated in Phase 2. Replace the
access package and group names with the ones in your catalog before deploying.

## Safety

- Never commit a file from `local/`.
- Never commit a resolved definition. Placeholders only.
- Task arguments are the only place tenant object IDs appear. Execution
  condition rules reference attributes, not IDs, so they are safe to commit.
