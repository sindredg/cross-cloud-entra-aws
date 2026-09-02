# Phase 3: Terraform AWS foundation and permission sets

**Date:** 2026-09-02

## Goal

Manage IAM Identity Center permission sets and their account assignments with Terraform, while SCIM keeps ownership of the groups and their members.

## Implementation

1. Added the root Terraform configuration with pinned versions (`terraform ~> 1.15.0`, `aws ~> 6.60.0`), validated variables for region, name prefix, and environment, and a provider that uses the `cross-cloud-admin` SSO profile.

2. Added an `identity_center` module that creates one permission set per role, attaches an AWS managed policy to each, looks up the SCIM-provisioned group by display name, and assigns the group and permission set to the current account.

3. Configured three roles: `crosscloud-Administrator` (`AdministratorAccess`, one-hour session), `crosscloud-Developer` (`PowerUserAccess`, four-hour session), and `crosscloud-Auditor` (`SecurityAudit`, four-hour session).

4. Ran `terraform apply` with temporary SSO credentials.

   ![Terraform apply creates the permission sets and reports the assigned groups](../docs/images/phase-3-01-terraform-apply.png)

5. Confirmed the group-to-permission-set assignments in the AWS console.

   ![IAM Identity Center account assignments for the three role groups](../docs/images/phase-3-02-group-permission-assignments.png)

## Validation

- `terraform apply` added nine resources with no changes or deletions.
- The `assigned_group_names` and `permission_set_names` outputs list the three roles.
- The AWS account shows `AWS-Administrators`, `AWS-Developers`, and `AWS-Auditors` mapped to their permission sets.
- The group lookups resolved without Terraform creating or mutating any user or group membership.

## Plan reconciliation

Closing Phase 3 exposed Phase 0 items that were never blocking work in progress. The plan now records each one where it is actually needed:

| Item | Outcome |
| --- | --- |
| AWS Budget and cost anomaly alerts | Removed. ADR-015 records the cost-control decision. |
| Bootstrap permission set | Removed from AWS. The Terraform-managed administrator path is the only administrative route. |
| DNS domain, certificate path, public host names | Moved to Phase 7, which registers the applications that depend on them. |
| Windows 11 device and Global Secure Access client | Moved to Phase 9, which installs the connector. |
| PowerShell 7, Microsoft Graph modules, `jq` | Moved to Phase 2, which needs them for Lifecycle Workflow payloads. |
| Fargate CPU architecture decision | Moved to Phase 6, which builds the first image. |
| CIDR and feature-flag variables | Moved to Phase 4, which introduces the network. |
| `scripts/check-prereqs.sh` | Reference removed. The script belongs to an unrelated repository and was never committed here. |

Worklog filenames now carry the phase number so the directory sorts in plan order.

## Next steps

Phase 4 has no unmet prerequisite and can start. Before it does, Phase 2 still needs the Lifecycle Workflow definitions exported to version-controlled JSON, the Mover and Leaver workflows created with scheduling disabled, and SCIM provisioning of the Joiner verified in IAM Identity Center.
