# Lifecycle Workflows

This directory holds the historical Joiner definition. Replacement automation follows the [roadmap](../../docs/roadmap.md#access-packages-and-jml).

## Joiner reference

[`reference/joiner.example.json`](reference/joiner.example.json) is the unchanged Joiner definition. The workflow:

1. Enabled a disabled synthetic account.
1. Requested the baseline access package.

It delivered baseline access before first sign-in. See the [Joiner evidence](../../worklogs/phase-2-identity-lifecycle-joiner.md).

> **Note:** This file isn't deployable. It contains tenant placeholders and resolver markers that the removed helpers used to fill in. Review it against current APIs before you reuse it.

The account was enabled before package delivery, so the evidence doesn't show delivery while the account stayed disabled.

## Removed files

| File | Reason |
| --- | --- |
| `deploy.ps1`, `export.ps1`, `common.ps1` | Custom reconciliation framework |
| `workflows/mover.example.json` | Package swap never validated. The tenant Mover ran only token revocation. |
| `workflows/leaver.example.json` | Deployed but never validated |

The files remain in Git history. Closed PRs [#5](https://github.com/sindredg/cross-cloud-entra-aws/pull/5) and [#6](https://github.com/sindredg/cross-cloud-entra-aws/pull/6) aren't the replacement.

## Tenant state

Removing these files changed nothing in the tenant. Ignored `local/` exports remain.

Before you clean up the tenant:

1. Inventory workflows, schedules, packages, policies, resource roles, assignments, and personas.
1. Keep validated baseline and Joiner resources and administrative dependencies.
1. Remove only unused or incomplete resources.

## Replacement criteria

- Define package roles, owners, approval, expiry, and persona outcomes before you write scripts.
- Validate one operation with an isolated synthetic identity, then automate it.
- Automation needs explicit configuration, a read-only preview, repeat-run checks, and failure reporting.
- Keep schedules off until on-demand runs pass.
- Measure workflow completion, package delivery, SCIM propagation, and existing sessions separately.
