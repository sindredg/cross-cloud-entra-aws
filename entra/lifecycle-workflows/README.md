# Lifecycle Workflows: reference and rebuild scope

Access packages and synthetic Joiner, Mover, and Leaver personas remain required project outcomes. The custom deployment/export framework and unfinished Mover/Leaver templates have been removed from active code. Replacement automation will follow the [governance contract and acceptance criteria](../../docs/roadmap.md#access-packages-and-jml).

## What remains

[`reference/joiner.example.json`](reference/joiner.example.json) preserves the previous Joiner definition unchanged. Its workflow enabled a disabled synthetic account, requested the baseline access package, and was observed delivering baseline access before first interactive sign-in. See the [Joiner evidence](../../worklogs/phase-2-identity-lifecycle-joiner.md).

This is a historical reference, not a deployable configuration. It still contains tenant placeholders, custom resolver markers, and the original exported shape. The removed helpers are no longer available to resolve those markers. It must be reviewed against current APIs and the new access model before reuse.

The evidence does not establish that the account remained disabled until package delivery; the observed task order enabled it first.

## What was removed

- `deploy.ps1`, `export.ps1`, and `common.ps1`: the custom display-name resolution and workflow reconciliation framework.
- `workflows/mover.example.json`: a package-swap definition that was not validated end to end. The historical tenant Mover ran only a token-revocation task.
- `workflows/leaver.example.json`: a deployed definition without a validated Leaver execution.

The removed files remain recoverable from Git history. Historical worklogs retain their original observations, including the limited deployment checks that did pass.

The unmerged access-package tooling from closed PRs [#5](https://github.com/sindredg/cross-cloud-entra-aws/pull/5) and [#6](https://github.com/sindredg/cross-cloud-entra-aws/pull/6) is not imported as the replacement.

## Tenant state is separate

This repository cleanup does not remove access packages, disable workflows, delete personas, or revoke live assignments. Ignored `local/` exports and configuration are preserved.

Before tenant cleanup, inventory project-only workflows, schedules, packages, policies, resource roles, assignments, personas, and administrative dependencies. Retain validated baseline/Joiner resources where they remain useful. Disable or remove only the unused/incomplete resources identified by that inventory, after preserving needed evidence and replacing dependent assignments.

## Replacement criteria

Define package resource roles, owners, approval and expiry policies, and the three persona outcomes before writing scripts. Validate one operation with an isolated synthetic identity, then automate it with explicit configuration, read-only preview, repeat-run checks, failure reporting, and evidence of delivered/revoked access.

Scheduling stays off until on-demand runs and failure handling pass. Workflow completion, package delivery, SCIM propagation, application authorization, and existing-session behavior must be measured separately.
