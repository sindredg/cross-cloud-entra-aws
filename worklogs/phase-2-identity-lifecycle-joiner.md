# Phase 2: Identity lifecycle foundation and Joiner

**Date:** 2026-09-02

## Goal

Give a synthetic Joiner baseline Entra access automatically, before any interactive sign-in, and provision it into AWS IAM Identity Center.

## Implementation

Expanded the Graph Bicep group deployment beyond `AWS-Administrators` to add `AWS-Developers`, `AWS-Auditors`, and `CrossCloud-Workforce`. Every rule requires an enabled member account with company `CrossCloud Identity Project`; the three role groups add a department and job title condition on top of that.

![az deployment group create reports no change and flags dynamicGroup as unsupported by what-if](../docs/images/phase-2-01-bicep-group-deploy-no-change.png)

The what-if preview cannot evaluate `dynamicGroup`, which is a v1 extensible resource. The deployment is still idempotent, but the plan step gives no coverage here, so the rules were read back from the portal after each apply.

![Dynamic membership conditions for the AWS developers group](../docs/images/phase-2-02-dynamic-developer-rule.png)

![Dynamic membership conditions for the AWS auditors group](../docs/images/phase-2-03-dynamic-auditor-rule.png)

![Dynamic membership conditions for the cross-cloud workforce group](../docs/images/phase-2-04-workforce-rule.png)

Created the synthetic Joiner with the attributes the lifecycle depends on: company, department, job title, employee ID, hire date, and manager. The account starts disabled, so the workflow has something to enable.

![Synthetic Joiner created with lifecycle attributes and the account disabled](../docs/images/phase-2-05-joiner-persona-attributes.png)

Assigned the three AWS role groups to the IAM Identity Center enterprise application, keeping provisioning scoped to assigned identities.

![AWS role groups assigned to the IAM Identity Center enterprise application](../docs/images/phase-2-06-aws-app-group-assignments.png)

Created the `Cross-Cloud Identity` catalog and the `AP-Cross-Cloud Baseline` access package with a direct-assignment policy and no approval step.

![Access package in the cross-cloud identity catalog](../docs/images/phase-2-07-access-package-catalog.png)

Created the Joiner workflow with two tasks and ran it on demand.

![Joiner workflow tasks: enable user account, then request the access package assignment](../docs/images/phase-2-08-joiner-workflow-tasks.png)

## Validation

The run processed one user with no failed tasks, and both tasks completed.

![Workflow history: one user processed, one successful, zero failed](../docs/images/phase-2-09-joiner-run-summary.png)

![Joiner workflow tasks completed for the synthetic user](../docs/images/phase-2-10-joiner-tasks-completed.png)

The baseline package reached the delivered state without a user sign-in.

![Baseline access package delivered to the synthetic Joiner](../docs/images/phase-2-11-baseline-access-delivered.png)

Dynamic membership then placed the user in `AWS-Developers` and `CrossCloud-Workforce`.

![Joiner group memberships after the attribute fix](../docs/images/phase-2-12-joiner-group-membership.png)

The provisioning service created the user and the role groups in AWS, and IAM Identity Center shows both as SCIM-owned.

![Provisioning log showing the Joiner created in AWSSingleSignon](../docs/images/phase-2-13-scim-provisioning-joiner.png)

![IAM Identity Center users, both created by SCIM](../docs/images/phase-2-14-identity-center-users.png)

![IAM Identity Center groups, all created by SCIM](../docs/images/phase-2-15-identity-center-groups.png)

## Troubleshooting

The workflow ran cleanly, but the dynamic developer group skipped the user. The rule matched `user.jobTitle -eq "Cloud Engineer"` and the stored value was `Cloud  Engineer` with two spaces. Dynamic membership rules compare strings literally and do not normalize whitespace, and the admin center collapses the extra space when it renders the attribute, so the value looked correct in every view. Correcting the attribute resolved the membership.

Relaxing the rule to `-contains "Cloud Engineer"` would also have worked, but it would match unintended titles such as `Senior Cloud Engineer`, so the attribute was fixed instead of the rule.
