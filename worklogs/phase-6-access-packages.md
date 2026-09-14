# Phase 6: Access packages

**Date:** 2026-09-14

**Goal:** Govern AWS access with a baseline package and a time-limited, approved elevated package.

```mermaid
flowchart LR
    Joiner["Joiner workflow"] --> Base["AP-Cross-Cloud Baseline<br/>no approval, 365 days"]
    Request["Self-request"] --> Approver["AWS-Administrators<br/>approve or deny"] --> Elev["AP-Cross-Cloud Elevated<br/>2 hours"]
    Base -->|"app role User"| App["Identity Center app"]
    Elev -->|"member"| Group["AWS-Elevated-ReadOnly<br/>assigned group"]
    Group -->|"SCIM"| IC["IAM Identity Center"]
    IC --> PS["crosscloud-ElevatedReadOnly<br/>ReadOnlyAccess"]
```

## Package model

| Setting | Baseline | Elevated |
| --- | --- | --- |
| Resource | App role `User` on the Identity Center app | Membership of `AWS-Elevated-ReadOnly` |
| AWS effect | Sign-in scope. Dynamic role groups set the role. | `crosscloud-ElevatedReadOnly`: `ReadOnlyAccess`, 1-hour session |
| Assigned by | Joiner workflow | Self-request in My Access |
| Who can request | Admin direct assignment only | `CrossCloud-Workforce` |
| Approval | None | `AWS-Administrators`, decision within 1 day, justification required |
| Expiry | 365 days | 2 hours, no extension |
| Removed by | Leaver workflow | Expiry, admin removal, or Leaver workflow |

| Object | Owner |
| --- | --- |
| `AWS-Elevated-ReadOnly` | Graph Bicep, `assignedGroups` parameter |
| Permission set and account assignment | [Terraform identity root](../terraform/README.md) |
| Group membership | Elevated package only |
| Catalog, packages, and policies | Entra admin center |

## Steps

1. Deploy the assigned group with Graph Bicep. `main.bicep` takes `assignedGroups` next to the dynamic `groups`.

   ```bash
   az deployment group create --name entra-groups --resource-group <resource-group> --parameters entra/groups/parameters/project.bicepparam --confirm-with-what-if
   ```

   > **Note:** What-if can't evaluate Graph group resources. Confirm the group in the portal after you deploy.

1. Assign the group to the Identity Center enterprise app. SCIM creates the group in AWS.

   ![AWS-Elevated-ReadOnly assigned to the Identity Center app next to the role groups](../docs/images/phase-6-05-app-group-assignments.png)

   ![Provisioning log: AWS-Elevated-ReadOnly created in AWSSingleSignon](../docs/images/phase-6-06-scim-group-created.png)

   ![IAM Identity Center lists AWS-Elevated-ReadOnly, created by SCIM](../docs/images/phase-6-07-identity-center-groups.png)

1. Add `elevated_readonly` to the Terraform identity root. Terraform reads the group by name, so run it after SCIM syncs the group.

   ![terraform plan: 3 to add, 0 to change, 0 to destroy](../docs/images/phase-6-01-terraform-plan-elevated.png)

   ![terraform apply: 3 added](../docs/images/phase-6-02-terraform-apply-elevated.png)

   ![Four Terraform permission sets provisioned, including crosscloud-ElevatedReadOnly](../docs/images/phase-6-03-permission-sets.png)

   ![crosscloud-ElevatedReadOnly carries the ReadOnlyAccess managed policy](../docs/images/phase-6-04-elevated-readonlyaccess.png)

1. Create `AP-Cross-Cloud Elevated` in the `Cross-Cloud Identity` catalog.

   ![Elevated package name, description, and catalog](../docs/images/phase-6-08-elevated-package-basics.png)

   ![Resource role: Member of AWS-Elevated-ReadOnly](../docs/images/phase-6-09-elevated-resource-roles.png)

1. Configure the request policy.

   ![Requests limited to members of CrossCloud-Workforce](../docs/images/phase-6-10-requestor-scope.png)

   ![Self-requests with justification and one approval stage; admin assignment can't be turned off](../docs/images/phase-6-11-request-settings.png)

   ![AWS-Administrators approves within 1 day, with justification](../docs/images/phase-6-12-approver-group.png)

   ![Assignments expire after 2 hours with no extensions](../docs/images/phase-6-13-expiry-two-hours.png)

## Limits

- **Admin assignment can't be turned off.** An administrator can assign the elevated package without approval. The audit log records it as `Administrator directly assigns user to access package`.
- **The approver is a group.** Approval survives an approver leaving, but anyone who matches the `AWS-Administrators` rule can approve.
- **Role-group members also reach the app through their group.** The baseline app role is a governed second path, not the only one.
