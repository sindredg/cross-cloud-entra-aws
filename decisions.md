# Architecture decisions

Each record states the decision, why, and the alternatives. Superseded records stay short as history.

| ADR | Decision | Status |
| --- | --- | --- |
| [001](#adr-001-build-the-project-in-verified-phases) | Build in verified phases | Accepted |
| [002](#adr-002-use-aws-ecs-with-fargate-for-application-containers) | ECS Fargate for protocol apps | Superseded |
| [003](#adr-003-keep-one-vm-for-the-entra-private-access-connector) | One connector VM | Superseded |
| [004](#adr-004-split-provisioning-by-platform-boundary) | Split provisioning by platform | Accepted |
| [005](#adr-005-use-iam-identity-center-for-human-aws-access) | IAM Identity Center for human access | Accepted |
| [006](#adr-006-use-local-terraform-state) | Local Terraform state | Accepted |
| [007](#adr-007-use-architecture-level-terraform-modules) | Architecture-level modules | Superseded |
| [008](#adr-008-inspect-tokens-without-persisting-credentials) | Token inspector views | Superseded |
| [009](#adr-009-use-a-descriptive-project-title) | Descriptive project title | Accepted |
| [010](#adr-010-use-jml-as-the-project-storyline) | JML as the storyline | Accepted |
| [011](#adr-011-federate-entra-id-with-iam-identity-center-and-provision-through-scim) | SAML federation and SCIM | Accepted |
| [012](#adr-012-treat-prerequisites-as-phase-0) | Prerequisites as Phase 0 | Superseded |
| [013](#adr-013-remove-the-google-cloud-draft) | Remove the Google Cloud draft | Accepted |
| [014](#adr-014-evaluate-security-controls-proportionately) | Proportionate security controls | Accepted |
| [016](#adr-016-focus-on-lifecycle-and-private-access) | Focus on lifecycle and Private Access | Accepted |
| [017](#adr-017-size-infrastructure-for-one-private-target) | One private target | Historical |
| [019](#adr-019-run-the-private-target-on-arm-fargate-behind-interface-endpoints) | ARM Fargate target behind endpoints | Historical |
| [020](#adr-020-reuse-grafana-as-an-anonymous-private-target) | Anonymous Grafana target | Historical |
| [021](#adr-021-use-an-entra-joined-vm-as-the-private-access-test-client) | Entra-joined test client | Accepted |
| [022](#adr-022-stop-rebuilding-the-private-aws-footprint) | Stop rebuilding the AWS footprint | Accepted |
| [023](#adr-023-validate-access-packages-and-jml-before-automating) | Validate packages and JML before automating | Accepted |
| [024](#adr-024-separate-the-identity-terraform-root) | Separate the identity Terraform root | Accepted |

## ADR-001: Build the project in verified phases

**Status:** Accepted | **Date:** 2026-09-01

**Decision:** Build one phase at a time. Meet the exit criteria and write a redacted worklog before you start the next phase.

**Why:** Small phases limit cost and security mistakes and make failures easier to isolate.

| Alternative | Why not |
| --- | --- |
| Build everything in one pass | Mixes identity, network, and compute failures in one plan. See [Terraform core workflow](https://developer.hashicorp.com/terraform/intro/core-workflow). |
| Use Terraform workspaces as phases | Workspaces separate state, not delivery order. See [workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces). |

## ADR-002: Use AWS ECS with Fargate for application containers

**Status:** Superseded by [ADR-017](#adr-017-size-infrastructure-for-one-private-target) | **Date:** 2026-09-01

**Decision:** Run the planned protocol demo apps as Linux containers on ECS Fargate.

## ADR-003: Keep one VM for the Entra Private Access connector

**Status:** Superseded by [ADR-017](#adr-017-size-infrastructure-for-one-private-target) | **Date:** 2026-09-01

**Decision:** Run the private network connector on one Windows Server EC2 instance. Microsoft supports the connector only as a [Windows Server agent](https://learn.microsoft.com/en-us/entra/global-secure-access/concept-connectors), not a container.

## ADR-004: Split provisioning by platform boundary

**Status:** Accepted | **Date:** 2026-09-01 | **Amended by:** [ADR-023](#adr-023-validate-access-packages-and-jml-before-automating)

**Decision:**

- Terraform for AWS.
- Microsoft Graph Bicep for supported Entra resources.
- Idempotent Graph or PowerShell automation for Entra resources that Bicep doesn't support.
- Portals only for bootstrap, consent, connector enrollment, and validation.

**Why:** Each tool stays in its strongest control plane. Tenant configuration stays out of AWS Terraform state.

| Alternative | Why not |
| --- | --- |
| Terraform for AWS and Entra in one state | Couples lifecycles and widens the sensitive state boundary. |
| Bicep for every Entra resource | Graph Bicep supports a [limited resource set](https://learn.microsoft.com/en-us/graph/templates/bicep/limitations). |
| Portal only | Hard to review, reproduce, and clean up. |

## ADR-005: Use IAM Identity Center for human AWS access

**Status:** Accepted | **Date:** 2026-09-01

**Decision:** Protect root with MFA and create no root access keys. Use IAM Identity Center temporary credentials for console and CLI access. Keep the existing IAM user until the new path is tested.

**Why:** Temporary credentials reduce leaked-key risk. A tested replacement before removal prevents lockout.

| Alternative | Why not |
| --- | --- |
| Use root daily | Against [root user best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html). |
| Keep long-lived IAM access keys | AWS recommends [temporary credentials](https://docs.aws.amazon.com/singlesignon/latest/userguide/howtogetcredentials.html). |
| Delete the IAM user immediately | Removes the recovery path before the new one works. |

## ADR-006: Use local Terraform state

**Status:** Accepted | **Date:** 2026-09-01

**Decision:** Keep Terraform state on the trusted workstation. Ignore state, plans, and private variable files. Keep secrets out of Terraform.

**Why:** This is a single-user lab. A remote backend adds bootstrap resources before they're needed.

| Alternative | Why not |
| --- | --- |
| [S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3) | Deferred until collaboration or recovery requires it. |
| [HCP Terraform](https://developer.hashicorp.com/terraform/cloud-docs) | Adds another service and access boundary. |

## ADR-007: Use architecture-level Terraform modules

**Status:** Superseded by [ADR-017](#adr-017-size-infrastructure-for-one-private-target) | **Date:** 2026-09-01

**Decision:** Create modules only for coherent units, keep deployment inputs in private tfvars, and derive names in locals. ADR-017 keeps this guidance without the fixed module list.

## ADR-008: Inspect tokens without persisting credentials

**Status:** Superseded by [ADR-016](#adr-016-focus-on-lifecycle-and-private-access) | **Date:** 2026-09-01

**Decision:** Add session-only token inspector views to the protocol apps and never log raw tokens. ADR-016 removed the protocol apps.

## ADR-009: Use a descriptive project title

**Status:** Accepted | **Date:** 2026-09-01

**Decision:** Give the project a title that names Microsoft Entra, AWS, and the identity focus. Use short, neutral resource prefixes instead of the title.

**Why:** Readers understand the scope without context, and resource names stay within provider limits.

## ADR-010: Use JML as the project storyline

**Status:** Accepted | **Date:** 2026-09-01 | **Refined by:** [ADR-023](#adr-023-validate-access-packages-and-jml-before-automating)

**Decision:** Create synthetic identities early and carry them through Joiner, Mover, and Leaver scenarios. The Joiner workflow assigns a baseline access package before first sign-in, with no user request or approval.

**Why:** JML connects governance to observable AWS authorization outcomes.

| Alternative | Why not |
| --- | --- |
| One [Lifecycle Workflow](https://learn.microsoft.com/en-us/entra/id-governance/what-are-lifecycle-workflows) at the end | Shows a feature, not a lifecycle. |
| Users request their baseline package | Baseline access must exist before first sign-in. |
| Attribute-based automatic assignment | Deferred. Workflow runs give clearer task history. |

## ADR-011: Federate Entra ID with IAM Identity Center and provision through SCIM

**Status:** Accepted | **Date:** 2026-09-01

**Decision:** Use Entra ID as the SAML identity provider for IAM Identity Center. Provision users and group memberships through SCIM. Manage permission sets and account assignments with Terraform. Never manage SCIM-owned identities with Terraform or Identity Store APIs.

**Why:** One workforce lifecycle across both clouds, temporary credentials, and one source of truth.

| Alternative | Why not |
| --- | --- |
| IAM users | Long-lived credentials bypass the lifecycle. |
| Separate Identity Center directory users | Duplicate administration. |
| Manage SCIM users with AWS APIs | Causes drift. See [automatic provisioning](https://docs.aws.amazon.com/singlesignon/latest/userguide/provision-automatically.html). |
| SAML without SCIM | Authenticates but doesn't provision. See [external identity providers](https://docs.aws.amazon.com/singlesignon/latest/userguide/manage-your-identity-source-idp.html). |

## ADR-012: Treat prerequisites as Phase 0

**Status:** Superseded by [ADR-017](#adr-017-size-infrastructure-for-one-private-target) | **Date:** 2026-09-01

**Decision:** Confirm accounts, licenses, region, DNS, certificates, budget alerts, and tooling as a numbered phase. Phase 3 later moved each item to the phase that needed it.

## ADR-013: Remove the Google Cloud draft

**Status:** Accepted | **Date:** 2026-09-01

**Decision:** Delete the Google Cloud Terraform draft instead of adapting it. Write AWS Terraform from an empty directory.

**Why:** It targeted a different provider and design, and it confused which configuration was authoritative.

## ADR-014: Evaluate security controls proportionately

**Status:** Accepted | **Date:** 2026-09-01

**Decision:** Before you keep, change, or remove a costly control, record the threat, risk reduction, friction, compensating controls, and rollback path.

These stay mandatory:

- Root MFA and no root access keys
- No committed secrets
- No public management ports
- Reviewed IAM changes
- No persistent raw-token logging

**Why:** Show informed risk decisions, not just defaults.

| Alternative | Why not |
| --- | --- |
| Every production control | Not a production service. See the [Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html). |
| Remove any slow control | Speed alone doesn't justify credential exposure or lockout. |
| Undocumented exceptions | Readers can't tell a decision from an omission. |

## ADR-016: Focus on lifecycle and Private Access

**Status:** Accepted | **Date:** 2026-09-04 | **Refined by:** [ADR-022](#adr-022-stop-rebuilding-the-private-aws-footprint), [ADR-023](#adr-023-validate-access-packages-and-jml-before-automating)

**Decision:** Demonstrate JML across Entra, IAM Identity Center, and one Private Access destination. Remove the planned protocol apps, token inspectors, and standalone Conditional Access showcase. Keep MFA, existing Conditional Access, and credential hygiene.

**Why:** Other projects already cover OIDC, OAuth, and Conditional Access. Lifecycle and private access add distinct evidence.

## ADR-017: Size infrastructure for one private target

**Status:** Historical; footprint destroyed 2026-09-05 | **Date:** 2026-09-04

**Decision:** Build one private AWS target and one supported Windows Server connector, with no high availability. Don't require a shared ECS platform, load balancers, a domain, or a NAT gateway.

**Why:** One target and one connector prove governed private reachability.

## ADR-019: Run the private target on ARM Fargate behind interface endpoints

**Status:** Historical; footprint destroyed 2026-09-05 | **Date:** 2026-09-04

**Decision:**

- One ARM64 Fargate task and one `t3.xlarge` Windows Server 2022 connector in one VPC.
- Connector subnet routes to an internet gateway. The connector has no ingress rule.
- Target subnet has no internet route. The task pulls images through `ecr.api`, `ecr.dkr`, and `logs` interface endpoints and the S3 gateway endpoint.
- Publish the task IP as an application segment on TCP 80.
- Manage the connector through SSM Fleet Manager. Create its key pair outside Terraform.
- No NAT gateway or load balancer. Single AZ.

**Why:** The connector needs wildcard Microsoft FQDNs, so its subnet must be routed. The target only needs ECR and CloudWatch Logs, which endpoints serve, so its isolation is a routing fact.

| Alternative | Why not |
| --- | --- |
| EC2 target | Removes the container platform. |
| Public task IP | Isolation would depend on security groups alone. |
| NAT gateway | Gives the target an internet path it doesn't need. |
| RDP to the connector | [Fleet Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-rdp.html) needs no inbound rule. |
| FQDN segment | Deferred. Adds Private DNS as a second failure mode. |

## ADR-020: Reuse Grafana as an anonymous private target

**Status:** Historical; footprint destroyed 2026-09-05 | **Date:** 2026-09-04

**Decision:** Use a pinned Grafana OSS container with anonymous viewer access and the login form disabled. Drop Caddy, the SCIM bridge, and OIDC from the source lab. Persist nothing.

**Why:** With no app authentication, reachability is the only variable, so Entra makes the entire access decision. Caddy needs a public DNS record, which a private destination doesn't have.

| Alternative | Why not |
| --- | --- |
| Static page | Weaker demonstration. |
| Full compose stack | Caddy can't work privately; the SCIM bridge duplicates Identity Center provisioning. |
| Grafana OIDC sign-in | Hides which layer made the access decision. |
| EFS persistence | No state worth keeping. |

## ADR-021: Use an Entra-joined VM as the Private Access test client

**Status:** Accepted | **Date:** 2026-09-05

**Decision:** Test Private Access from an Entra-joined Windows 11 VM, not the workstation.

**Why:**

- The Global Secure Access client needs a Primary Refresh Token (PRT).
- An Entra-registered device signed in with a personal Microsoft account never gets one. The client fails with `AADSTS9002341` and shows only `Signed out`.
- The workstation runs Windows 11 Home, which can't be Entra joined.
- The Azure VM has no network path to AWS, so a successful request proves the tunnel carried it.

| Alternative | Why not |
| --- | --- |
| Upgrade the workstation to Pro | License purchase to work around a test constraint. |
| Entra-registered device | [Preview support](https://learn.microsoft.com/entra/global-secure-access/how-to-install-windows-client) doesn't produce a PRT in this configuration. |
| Test from the connector host | Reaches the target directly and proves nothing. |

## ADR-022: Stop rebuilding the private AWS footprint

**Status:** Accepted | **Date:** 2026-09-09

**Decision:** Don't rebuild the AWS footprint. Complete lifecycle validation in Entra and IAM Identity Center only. State the unproven claims instead of leaving open checklist items.

**Why:**

- A rebuild costs a Windows host, four interface endpoints, and a Fargate task, plus manual connector registration and segment republishing.
- Phase 5 already proved the core claim: an Azure VM with no route to AWS got `HTTP/1.1 200 OK` from Grafana on an isolated subnet.
- Identity Center, permission sets, and SCIM are free, so JML can finish without new resources.

**Unproven claims:**

- The client-side denial for an unassigned identity. Assignment gating is configured, and Phase 1 observed the mechanism (`AADSTS50105`).
- Application reachability changing across a role move.

## ADR-023: Validate access packages and JML before automating

**Status:** Accepted; validation pending | **Date:** 2026-09-10 | **Amends:** [ADR-004](#adr-004-split-provisioning-by-platform-boundary)

**Decision:**

- Access packages and synthetic Joiner, Mover, and Leaver personas are required outcomes.
- Define package resource roles, ownership, approval, expiry, and recovery first.
- Validate each operation on demand, then automate it.
- Packages govern assigned groups. Dynamic AWS role groups keep attribute-based membership.
- Remove the custom workflow deploy, export, and common helpers and the unvalidated Mover and Leaver templates. Keep the Joiner definition as a reference.
- Repository cleanup makes no tenant changes. Inventory before you remove tenant resources.

**Why:** The old automation deployed workflows but never validated Mover or Leaver outcomes. A small validated replacement is more trustworthy.

| Alternative | Why not |
| --- | --- |
| Drop packages and JML | Governed lifecycle access is the project goal. |
| Patch the old framework or import closed PRs #5 and #6 | Validate operations and failure cases before building automation. |

See the [roadmap](docs/roadmap.md) for acceptance criteria.

## ADR-024: Separate the identity Terraform root

**Status:** Accepted | **Date:** 2026-09-10

**Decision:**

- Move the identity configuration and its state to `terraform/identity/`.
- Keep the `module.identity_center` address, so no `moved` blocks, state moves, or imports are needed.
- Remove the private-target module call, its variables and outputs, and the `enable_private_access` flag.
- Keep `modules/private_access/` as uncalled reference code.

**Why:** One shared state let a teardown delete the permission sets that provide AWS administrative access. Separate state makes that impossible. A plan with zero changes proves the move.

| Alternative | Why not |
| --- | --- |
| One root with a flag and `-target` | Teardown mistakes stay possible. |
| Workspaces | Workspaces vary inputs, not configurations. |
| Migrate to a remote backend at the same time | Don't combine a backend migration with a refactor. |

**Consequences:**

- State is local and per root. Relocate existing state; applying into empty state creates duplicate permission sets.
- `app/build-and-push.sh` takes `ECR_REPOSITORY_URL` explicitly instead of reading Terraform output.
