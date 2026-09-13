# Phase 2: Lifecycle Workflows as version-controlled Graph JSON

**Date:** 2026-09-03

> **Historical:** The helpers and Mover and Leaver templates described here were removed on 2026-09-10. See the [Lifecycle Workflows reference](../entra/lifecycle-workflows/README.md) and [ADR-023](../decisions.md#adr-023-validate-access-packages-and-jml-before-automating).

**Goal:** Deploy the Joiner, Mover, and Leaver workflows from repository files, with no tenant object IDs committed.

## Why not Bicep

Graph Bicep supports only `applications`, `appRoleAssignedTo`, `federatedIdentityCredentials`, `groups`, `oauth2PermissionGrants`, `servicePrincipals`, and `users`. Lifecycle Workflows aren't on the list, so the definitions went to the Graph REST API as JSON.

## Steps

1. Install the Graph module and connect with the workflow, group, and entitlement management scopes.

   ![Microsoft.Graph.Authentication 2.39.0 installed](../docs/images/phase-2-16-graph-module-installed.png)

   ![Connect-MgGraph with the workflow, group, and entitlement management scopes](../docs/images/phase-2-17-graph-connect-scopes.png)

1. Commit definitions with `<PLACEHOLDER>` names and `${group:...}`, `${accessPackage:...}`, and `${accessPackagePolicy:...}` markers. The deploy script:
   - Refuses files that still contain `<PLACEHOLDER>`.
   - Resolves IDs at deploy time.
   - Fails if a name matches zero or several objects.

   ![Committed joiner definition with placeholders and the time-based hire date trigger](../docs/images/phase-2-18-joiner-definition.png)

1. Compare the tenant with the file and pick a write path. `PATCH` accepts only four properties, so task changes need `createNewVersion`.

   | Situation | Action |
   | --- | --- |
   | Workflow doesn't exist | `POST` |
   | Only `displayName`, `description`, `isEnabled`, or `isSchedulingEnabled` differ | `PATCH` |
   | `tasks` or `executionConditions` differ | `createNewVersion` |
   | Nothing differs | No write |

## Validation

The validated Joiner matched its file, so `-WhatIf` planned no write.

![deploy.ps1 -WhatIf reports the joiner already matches version 1](../docs/images/phase-2-19-joiner-whatif-no-change.png)

Every definition set `isSchedulingEnabled` to `false`. `-WhatIf` made no write calls.

![deploy.ps1 -WhatIf plans the leaver creation](../docs/images/phase-2-20-leaver-whatif-create.png)

![The leaver workflow is created at version 1](../docs/images/phase-2-21-leaver-created.png)

![Leaver tasks: cancel pending requests, remove assignments, revoke tokens, disable account](../docs/images/phase-2-22-leaver-tasks.png)

All three workflows existed in the tenant with scheduling off.

![Joiner, Mover, and Leaver listed in Lifecycle Workflows](../docs/images/phase-2-25-workflows-deployed.png)

![Mover tasks after the trigger fix](../docs/images/phase-2-26-mover-tasks.png)

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `400 BAD_REQUEST: Multiple trigger attributes are not allowed` | `attributeChangeTrigger` accepts one attribute | Trigger on `jobTitle` only, which the role groups use |

![Graph rejects the mover create because it declares two trigger attributes](../docs/images/phase-2-23-mover-trigger-rejected.png)

![The mover workflow is created at version 1](../docs/images/phase-2-24-mover-created.png)

## Limits

- The deployed Mover ran only token revocation. The package swap needed an elevated package that didn't exist.
- The Leaver was deployed but never run.
