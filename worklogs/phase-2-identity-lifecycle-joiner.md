# Phase 2: Identity lifecycle foundation and Joiner

**Date:** 2026-09-02

**Goal:** Give a synthetic Joiner baseline access automatically, before first sign-in, and provision the Joiner into IAM Identity Center.

> **Note:** [Phase 7](phase-7-jml-lifecycle.md) reruns the Joiner with version 2, which requests the package before it enables the account.

```mermaid
flowchart LR
    Joiner["Disabled Joiner<br/>with attributes"] --> WF["Joiner workflow"]
    WF -->|"1 Enable account"| Joiner
    WF -->|"2 Assign package"| Pkg["AP-Cross-Cloud Baseline"]
    Joiner -->|"Attributes match"| Dyn["AWS-Developers<br/>CrossCloud-Workforce"]
    Dyn -->|"SCIM"| IC["IAM Identity Center"]
```

## Steps

1. Add `AWS-Developers`, `AWS-Auditors`, and `CrossCloud-Workforce` to the Graph Bicep deployment. Every rule requires an enabled member with company `CrossCloud Identity Project`. Role groups also match department and job title.

   ![az deployment group create reports no change and flags dynamicGroup as unsupported by what-if](../docs/images/phase-2-01-bicep-group-deploy-no-change.png)

   > **Note:** What-if can't evaluate `dynamicGroup`. Read the rules back from the portal after each deployment.

   ![Dynamic membership conditions for the AWS developers group](../docs/images/phase-2-02-dynamic-developer-rule.png)

   ![Dynamic membership conditions for the AWS auditors group](../docs/images/phase-2-03-dynamic-auditor-rule.png)

   ![Dynamic membership conditions for the cross-cloud workforce group](../docs/images/phase-2-04-workforce-rule.png)

1. Create the Joiner with company, department, job title, employee ID, hire date, and manager. The account starts disabled.

   ![Synthetic Joiner created with lifecycle attributes and the account disabled](../docs/images/phase-2-05-joiner-persona-attributes.png)

1. Assign the three AWS role groups to the Identity Center enterprise app.

   ![AWS role groups assigned to the IAM Identity Center enterprise application](../docs/images/phase-2-06-aws-app-group-assignments.png)

1. Create the `Cross-Cloud Identity` catalog and the `AP-Cross-Cloud Baseline` package with a direct-assignment policy and no approval.

   ![Access package in the cross-cloud identity catalog](../docs/images/phase-2-07-access-package-catalog.png)

1. Create the Joiner workflow and run it on demand.

   ![Joiner workflow tasks: enable user account, then request the access package assignment](../docs/images/phase-2-08-joiner-workflow-tasks.png)

## Validation

The run processed one user. Both tasks succeeded.

![Workflow history: one user processed, one successful, zero failed](../docs/images/phase-2-09-joiner-run-summary.png)

![Joiner workflow tasks completed for the synthetic user](../docs/images/phase-2-10-joiner-tasks-completed.png)

The baseline package was delivered without a user sign-in.

![Baseline access package delivered to the synthetic Joiner](../docs/images/phase-2-11-baseline-access-delivered.png)

Dynamic membership added the user to `AWS-Developers` and `CrossCloud-Workforce`.

![Joiner group memberships after the attribute fix](../docs/images/phase-2-12-joiner-group-membership.png)

SCIM created the user and role groups in Identity Center.

![Provisioning log showing the Joiner created in AWSSingleSignon](../docs/images/phase-2-13-scim-provisioning-joiner.png)

![IAM Identity Center users, both created by SCIM](../docs/images/phase-2-14-identity-center-users.png)

![IAM Identity Center groups, all created by SCIM](../docs/images/phase-2-15-identity-center-groups.png)

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Joiner missing from `AWS-Developers` | Job title stored as `Cloud  Engineer` (two spaces). Rules compare literally, and the portal hides the extra space. | Correct the attribute |

Changing the rule to `-contains "Cloud Engineer"` also works, but it matches titles like `Senior Cloud Engineer`.
