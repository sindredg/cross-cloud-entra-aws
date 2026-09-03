# Cross-Cloud Identity with Microsoft Entra Suite and AWS

Workforce lifecycle automation and identity-based access to a private AWS application. Follow a synthetic worker from baseline access before first sign-in, through a role change, to offboarding across Entra and AWS IAM Identity Center.

## Scope

- **Lifecycle:** reusable Joiner, Mover, and Leaver definitions; access packages; attribute-driven groups; SCIM; and measured access-removal delays.
- **Private Access:** one private target, a Private Network Connector, and per-app access governed through an access package.
- **Supporting infrastructure:** the existing IAM Identity Center federation and Terraform-managed permission sets remain in use.

No additional SAML application, OIDC/OAuth demo apps, protocol inspectors, or standalone Conditional Access showcase. Existing MFA and Conditional Access protections remain; only changes required for Private Access belong in scope. ID Protection, Verified ID, and custom Logic App extensions are not required deliverables.

## Target architecture

```mermaid
flowchart LR
    Worker["Synthetic worker<br/>Joiner · Mover · Leaver"]
    Client["Test device<br/>Global Secure Access client"]

    subgraph Entra["Microsoft Entra"]
        Lifecycle["Lifecycle Workflows"]
        Attributes["Account and role attributes"]
        Groups["Dynamic AWS role groups"]
        Packages["Access packages<br/>Governed app assignment"]
        PrivateAccess["Entra Private Access<br/>Per-app assignment"]
    end

    subgraph AWS["AWS"]
        IdentityCenter["IAM Identity Center<br/>Permission sets"]
        Connector["Windows Server connector<br/>Approved outbound connectivity"]
        Target["One private application<br/>Hosting selected after cost review"]
    end

    Worker --> Lifecycle
    Lifecycle --> Attributes
    Attributes --> Groups
    Groups -->|"SCIM membership"| IdentityCenter
    Lifecycle -->|"Assignment / removal tasks"| Packages
    Packages -->|"Governed access"| PrivateAccess
    Client --> PrivateAccess
    Connector -->|"Connector-initiated outbound tunnel"| PrivateAccess
    Connector -->|"Private application port"| Target
```

The diagram shows the planned access boundaries, not a deployed private-access service. Existing Entra federation provides AWS sign-in. SCIM owns workforce users and AWS group memberships; Terraform owns permission sets and account assignments. Application reachability is tested separately from application authentication and existing-session termination.

## Implemented

| Phase | Outcome | Evidence |
| --- | --- | --- |
| 1 | Entra federation, SCIM provisioning, and temporary AWS console/CLI credentials | [worklog](worklogs/phase-1-entra-aws-federation.md) |
| 2 | Dynamic groups and a synthetic Joiner receiving baseline access before first sign-in | [worklog](worklogs/phase-2-identity-lifecycle-joiner.md) |
| 2 | Reusable Graph JSON workflow deployment; tenant values kept in ignored local copies | [worklog](worklogs/phase-2-lifecycle-workflows-as-code.md) |
| 3 | Three Terraform-managed permission sets and account assignments | [worklog](worklogs/phase-3-terraform-identity-center.md) |

These are implemented outcomes, not a claim that all Phase 2 exit criteria are complete.

## Remaining work

| Phase | Scope |
| --- | --- |
| 0–2 | Close readiness gaps, finish the synthetic-identity bootstrap, and capture Joiner timing evidence |
| 4 | Confirm licences and device readiness; approve the minimum topology, spend limit, and test window |
| 5 | Deploy one private target and only its required AWS network/hosting resources |
| 6 | Register the connector and validate governed Private Access allow/deny paths |
| 7 | Validate Mover changes across AWS and private-access entitlements |
| 8 | Validate Leaver behavior, existing sessions, evidence, and teardown |

The revised future phases replace the former container-platform and protocol-demo sequence. See [plan.md](plan.md) for checklists and [decisions.md](decisions.md) for the scope change.

## Cost and prerequisites

No credits or free-tier coverage are assumed. Before provisioning, confirm Entra licence validity, supported client/connector hosts, administrative access, and an approved cost estimate. Choose EC2 or Fargate for the target after comparing total cost; neither an ALB nor a shared container platform is mandatory.

Run billable infrastructure only during agreed test windows and check spend afterward. Include outbound networking, Windows compute, storage, and logs in the estimate. Stopped EC2 instances can still incur storage charges; cleanup must cover more than compute. See [AWS VPC pricing](https://aws.amazon.com/vpc/pricing/) and [EC2 stop/start billing](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/how-ec2-instance-stop-start-works.html).

Terraform provisions AWS; Graph Bicep handles supported Entra resources; PowerShell deploys Graph JSON where needed. Keep examples generic, deployment values in ignored local files, and credentials outside the repository and Terraform inputs.
