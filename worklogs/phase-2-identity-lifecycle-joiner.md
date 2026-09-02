# Phase 2: Identity lifecycle foundation and Joiner

**Date:** 2026-09-02

## Goal

Give a synthetic Joiner baseline Entra access automatically, before any interactive sign-in, and provision it toward AWS IAM Identity Center.

## Implementation

1. Expanded the Microsoft Graph Bicep group deployment beyond `AWS-Administrators` to add `AWS-Developers`, `AWS-Auditors`, and `CrossCloud-Workforce`. Each rule requires an enabled member account with company `CrossCloud Identity Project`; the role groups add a department and job title condition.

   ![Dynamic membership conditions for the AWS developers group](../docs/images/phase-2-01-dynamic-developer-rule.png)

2. Assigned the three AWS role groups to the IAM Identity Center enterprise application and kept provisioning scoped to assigned identities.

   ![AWS role groups assigned to the IAM Identity Center enterprise application](../docs/images/phase-2-02-aws-app-group-assignments.png)

3. Created the `AP-Cross-Cloud Baseline` access package in Entitlement Management with a direct-assignment policy and no approval step.

4. Created the Joiner Lifecycle Workflow and ran it on demand for the synthetic user `Even Engineer`. The run enabled the account and requested the baseline access package assignment.

   ![Joiner workflow tasks completed for the synthetic user](../docs/images/phase-2-03-joiner-workflow-completed.png)

5. Confirmed the baseline package assignment reached the delivered state without a user sign-in.

   ![Baseline access package delivered to the synthetic Joiner](../docs/images/phase-2-04-baseline-access-delivered.png)

## Validation

- The expanded dynamic rules compiled and the four groups deployed through Bicep.
- The AWS role groups appear on the enterprise application assignment list.
- Both Joiner workflow tasks completed with no errors.
- The `AP-Cross-Cloud Baseline` assignment for `Even Engineer` shows status Delivered.

## Troubleshooting

The Joiner workflow ran, but the dynamic developer group skipped the user. The rule matched `user.jobTitle -eq "Cloud Engineer"`, and the stored value was `Cloud  Engineer` with two spaces. Dynamic membership rules compare strings literally and do not normalize whitespace, and the admin center collapses the extra space when it renders the attribute, so the value looked correct. Fixing the attribute resolved the membership. Relaxing the rule to `-contains "Cloud Engineer"` would also have worked, but it would match unintended titles such as `Senior Cloud Engineer`, so the attribute was corrected instead.

## Workflow definitions as code

Microsoft Graph Bicep cannot manage Lifecycle Workflows. It supports only `applications`, `appRoleAssignedTo`, `federatedIdentityCredentials`, `groups`, `oauth2PermissionGrants`, `servicePrincipals`, and `users`, so the Bicep pattern used for the dynamic groups does not extend to workflows. The definitions go to the Graph REST API as JSON instead, under `entra/lifecycle-workflows/`.

Two API constraints shaped the deployment script:

- A `PATCH` on a workflow accepts only `displayName`, `description`, `isEnabled`, and `isSchedulingEnabled`. Changing tasks or execution conditions requires `POST .../createNewVersion`. The script compares the two parts separately and picks the matching call.
- Task arguments carry group, access package, and assignment policy object IDs. Committing them would publish tenant identifiers, so the definitions use display-name placeholders such as `${accessPackage:AP-Cross-Cloud Baseline}` that resolve at deployment time. Resolution fails when a name matches no object or more than one, so a rename produces an error rather than a wrong deployment.

Committed definitions set `isSchedulingEnabled` to `false`. Attribute change triggers are only evaluated for scheduled workflows, so the Mover definition runs on demand until scheduling is enabled.

## Next steps

Export the deployed Joiner and reconcile it with the committed definition, deploy the Mover and Leaver definitions, add the Mover and Leaver personas, and verify SCIM provisioning of the Joiner into IAM Identity Center.
