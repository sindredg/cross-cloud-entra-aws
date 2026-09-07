# Access packages as code

Catalogs, access packages, resource roles, and assignment policies as Microsoft Graph JSON, plus the scripts that export and deploy them.

The Lifecycle Workflows in [`../lifecycle-workflows/`](../lifecycle-workflows/) reference access packages by display name and resolve them to IDs at deployment time. Until those packages existed only in the portal, the workflow definitions were reproducible and the objects they act on were not. These definitions close that gap.

Microsoft Graph Bicep does not manage entitlement management, for the same reason it does not manage Lifecycle Workflows: it supports only `applications`, `appRoleAssignedTo`, `federatedIdentityCredentials`, `groups`, `oauth2PermissionGrants`, `servicePrincipals`, and `users`. See ADR-022.

## Layout

```text
packages/*.example.json   Committed templates. Placeholders, never object IDs.
local/                    Your filled-in definitions and raw exports. Git-ignored.
deploy.ps1                Reconciles catalogs and packages. Defaults to local/.
export.ps1                Reads a package from the tenant into local/.
common.ps1                Shared helpers. Dot-sourced, not run directly.
```

Graph request plumbing lives in [`../graph-common.ps1`](../graph-common.ps1), which the lifecycle-workflow scripts share.

## Definitions

Every file declares a `type`, and every object is named rather than identified:

| File | Type | What it declares |
| --- | --- | --- |
| `catalog.example.json` | `catalog` | The catalog that holds the project's governed resources |
| `baseline.example.json` | `accessPackage` | The entitlement a Joiner receives from the hire date |
| `elevated.example.json` | `accessPackage` | The entitlement a Mover receives on promotion, delivering the private application |

Deploy order is not the file order: catalogs are always reconciled first, because a package cannot be created before the catalog that holds it.

### Why baseline delivers no resource role

`AWS-Administrators`, `AWS-Developers`, `AWS-Auditors`, and `CrossCloud-Workforce` are dynamic groups. Membership is computed from user attributes, so nothing can add a member to them, an access package included. AWS role access therefore stays attribute-driven, and the baseline package is the governed record that the Joiner ran and the object the Leaver removes. The elevated package does deliver a resource, because the Global Secure Access application is an ordinary enterprise application and can be assigned.

### Resource roles

```json
"resourceRoles": [
  { "originSystem": "AadApplication", "resource": "Grafana-AWS", "role": "Default Access" }
]
```

`originSystem` is `AadGroup` or `AadApplication`. The deployment resolves `resource` to the object entitlement management calls the resource origin: a group's own object ID, or, for an application, **the object ID of its service principal** rather than of the application registration. Naming the wrong one of those two produces an empty catalog and no error.

If the named role does not exist, the error lists the role names the resource actually has, which is quicker than reading them out of the portal.

## Placeholders

`<UPPER_SNAKE>` marks a value you must supply. `deploy.ps1` refuses any file that still contains one, so a template cannot reach the tenant by accident:

```text
<CATALOG_DISPLAY_NAME>
<BASELINE_ACCESS_PACKAGE_DISPLAY_NAME>
<ELEVATED_ACCESS_PACKAGE_DISPLAY_NAME>
<DIRECT_ASSIGNMENT_POLICY_DISPLAY_NAME>
<PRIVATE_APP_DISPLAY_NAME>
<PRIVATE_APP_ROLE_DISPLAY_NAME>
```

There is no second placeholder kind here. The lifecycle-workflow definitions need `${accessPackage:...}` markers because a task argument stores an ID; an access package definition names its resources directly, so an export is already deployable.

## Prerequisites

- PowerShell 7 and `Microsoft.Graph.Authentication`.
- Identity Governance Administrator, or Access package manager on the catalog, which is the least privileged option.
- Delegated scopes `EntitlementManagement.ReadWrite.All`, `Group.Read.All`, and `Application.Read.All`. The scripts request them on connect.

## Deploy

Copy the templates, fill in every `<PLACEHOLDER>`, and keep the result in `local/`:

```bash
cp entra/access-packages/packages/catalog.example.json entra/access-packages/local/catalog.json
cp entra/access-packages/packages/elevated.example.json entra/access-packages/local/elevated.json
```

Review the plan first. `-WhatIf` makes no write calls:

```bash
pwsh ./entra/access-packages/deploy.ps1 -WhatIf
```

Then apply:

```bash
pwsh ./entra/access-packages/deploy.ps1
```

### What the reconcile does

| Situation | Action |
| --- | --- |
| No catalog or package with that display name | `POST` creates it |
| A declared property differs | `PATCH` the catalog or package, `PUT` the policy |
| A declared resource role is not delivered | Adds the resource to the catalog if needed, then adds the role |
| The tenant has a role or policy the definition does not declare | Reported as a warning. Nothing is removed |
| Nothing differs | No write call |

Only the properties a definition states are compared. Graph returns many read-only and defaulted properties on these objects; a definition that had to mirror all of them would break on the next service change and would say nothing about intent.

The reconcile never deletes. Removing a resource role or an assignment policy revokes access from every live assignment, which is not a decision a file comparison should make on its own. Extras are reported so you can remove them deliberately.

An assignment policy is replaced with `PUT` rather than patched, because that is the only update Graph offers on the resource.

### Adding a resource is asynchronous

Adding a resource to a catalog is a request, not a write. `deploy.ps1` posts the request and then polls the catalog for up to two minutes for the resource to appear. If it times out, the request itself is usually still in flight; check it in the portal before re-running.

## Export

After editing a package in the portal, pull the change back:

```bash
pwsh ./entra/access-packages/export.ps1 -DisplayName 'AP-Cross-Cloud Elevated'
```

Exports land in `local/`. Because the definition format names objects rather than identifying them, an export contains no tenant object ID and can be deployed straight back. Server-assigned policy properties are stripped so the result is a valid request body. To update a committed template, diff the export against it and put the `<PLACEHOLDER>` tokens back before staging.

Pass `-Catalog` when the same package name exists in more than one catalog.

## Direct assignment

Both templates use a policy that no user can request:

```json
"allowedTargetScope": "notSpecified",
"specificAllowedTargets": [],
"requestApprovalSettings": { "isApprovalRequiredForAdd": false }
```

This is what the portal calls *None (administrator direct assignments only)*. Assignment comes from a Lifecycle Workflow task, which is the point: the entitlement arrives because the workflow ran, not because anyone asked for it. If your tenant reports a different `allowedTargetScope` for an existing policy, `deploy.ps1` shows it as drift rather than failing, so run `-WhatIf` against an existing package before applying.
