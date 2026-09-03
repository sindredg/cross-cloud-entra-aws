# Cross-Cloud Identity with Microsoft Entra Suite and AWS planning decisions

This file records accepted project decisions during the planning phase. Add new decisions at the end. If a decision changes, mark the original `Superseded` and link to the replacement instead of deleting history.

Each decision uses this structure:

- Title
- Status and date
- Decision
- Why
- Alternatives with documentation links

## ADR-001: Build the project in verified phases

**Status:** Accepted
**Date:** 2026-09-01

### Decision

Build one phase at a time. Complete the documented exit criteria, write a redacted worklog, and mark the phase `Done` before starting the next phase.

### Why

The project combines unfamiliar AWS access controls, billable networking, Terraform, four applications, and Entra Suite. Small phases limit cost and security mistakes and make failures easier to diagnose.

### Alternatives

- Build the full environment in one pass. Rejected because one plan would mix identity bootstrap, networking, compute, and application failures. See the [Terraform core workflow](https://developer.hashicorp.com/terraform/intro/core-workflow).
- Use Terraform workspaces as implementation phases. Rejected because workspaces separate state instances; they do not model a delivery sequence. See [Terraform workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces).

## ADR-002: Use AWS ECS with Fargate for application containers

**Status:** Accepted
**Date:** 2026-09-01

### Decision

Run `saml-web`, `oidc-web`, `oauth-api`, and `private-web` as Linux containers on Amazon ECS with AWS Fargate. Do not deploy the same applications to multiple clouds.

### Why

Fargate removes application-host VM management while retaining private VPC networking, security groups, load balancer integration, task IAM roles, and container-level deployment behavior. The AWS target also creates a clear cross-cloud story: Microsoft Entra protects AWS workloads.

### Alternatives

- [Google Cloud Run](https://cloud.google.com/run/docs/overview). Rejected after the project changed from a GCP foundation to an AWS learning objective.
- [Amazon ECS on EC2](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_types.html). Rejected because managing container hosts does not add value to the identity scenarios.
- [Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html). Rejected because Kubernetes adds cluster operations that are outside the project goal.

## ADR-003: Keep one VM for the Entra Private Access connector

**Status:** Accepted
**Date:** 2026-09-01

### Decision

Use one private Windows Server EC2 instance for the Microsoft Entra Private Network Connector. Keep all application workloads in Fargate. Do not use Guacamole.

### Why

The connector is a Windows Server service that creates outbound tunnels to Microsoft and needs network access to the private application. It is not an application container. Guacamole would add another remote-access layer and obscure the Global Secure Access client flow.

### Alternatives

- Run the connector as a container. Rejected because Microsoft documents the connector as a Windows Server agent. See [Microsoft Entra private network connectors](https://learn.microsoft.com/en-us/entra/global-secure-access/concept-connectors).
- Use [Apache Guacamole](https://guacamole.apache.org/doc/gug/). Rejected because browser-delivered remote desktop is not required to inspect SAML, OIDC, OAuth, or Private Access.
- Host each application on an EC2 VM. Rejected in favor of [Fargate task networking](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-task-networking.html).

## ADR-004: Split provisioning by platform boundary

**Status:** Accepted
**Date:** 2026-09-01

### Decision

Use Terraform for AWS, Microsoft Graph Bicep for supported Entra application resources, and idempotent Microsoft Graph or PowerShell automation for Entra Suite resources that Bicep does not support. Use portals only for bootstrap, consent, connector enrollment, and validation steps that are unsuitable for automation.

### Why

Each tool remains within its strongest control plane. This split avoids forcing tenant configuration into the AWS Terraform state and avoids pretending that Graph Bicep covers every Entra Suite API.

### Alternatives

- Use Terraform for AWS and Entra in one state. Rejected because it couples separate lifecycles and expands the sensitive state boundary. See the [Microsoft Entra ID Terraform provider](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs).
- Use Bicep for every Entra resource. Rejected because the extension supports a limited resource set and has deployment limitations. See the [Microsoft Graph Bicep overview](https://learn.microsoft.com/en-us/graph/templates/bicep/overview-bicep-templates-for-graph) and [feature limitations](https://learn.microsoft.com/en-us/graph/templates/bicep/limitations).
- Configure everything in the portal. Rejected because manual configuration is difficult to review, reproduce, and clean up.

## ADR-005: Use IAM Identity Center for human AWS access

**Status:** Accepted
**Date:** 2026-09-01

### Decision

Protect the AWS root user with MFA, create no root access keys, and use root only for root-only tasks. Use IAM Identity Center and temporary credentials for normal console and CLI access. Keep the existing IAM user until the replacement access path is tested.

### Why

A staged move to temporary credentials reduces the risk of account lockout and leaked long-lived access keys. Preserving the existing administrative path until both console and CLI federation are verified provides a controlled rollback.

### Alternatives

- Use root for daily work. Rejected by [AWS root-user best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html).
- Continue using a long-lived IAM-user access key. Rejected after safe migration because AWS recommends temporary credentials where possible. See [IAM Identity Center credentials](https://docs.aws.amazon.com/singlesignon/latest/userguide/howtogetcredentials.html).
- Delete the current IAM user immediately. Rejected because access must be tested before removing the existing recovery path.

## ADR-006: Use local Terraform state for the project

**Status:** Accepted
**Date:** 2026-09-01

### Decision

Use local Terraform state on the trusted development machine. Ignore state, plans, and private variable files. Do not put secret values into Terraform inputs or resources.

### Why

This is a single-user learning project rather than a shared infrastructure environment. A remote backend would add bootstrap resources and access policy before the AWS account foundation is established.

### Alternatives

- Use the [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3). Deferred until collaboration, automation, or state recovery requirements justify it.
- Use [HCP Terraform](https://developer.hashicorp.com/terraform/cloud-docs). Rejected for the initial project because it introduces another service and access boundary.

## ADR-007: Use architecture-level Terraform modules

**Status:** Accepted
**Date:** 2026-09-01

### Decision

Create modules for coherent units such as `network`, `ecs_service`, and `private_access_connector`. Keep single-use resources in the root unless they form a meaningful component. Put deployment inputs in private tfvars and derive names, tags, and service mappings in locals.

### Why

This structure provides reuse without hiding the architecture behind one-resource wrappers. It also keeps deployment-specific inputs separate from deterministic values.

### Alternatives

- Wrap every resource in a module. Rejected because it adds indirection without a reusable interface. See [Terraform module composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition).
- Keep every resource in the root module. Rejected because the ECS service pattern is instantiated several times.
- Hard-code names and settings. Rejected in favor of [input variables](https://developer.hashicorp.com/terraform/language/values/variables) and [local values](https://developer.hashicorp.com/terraform/language/values/locals).

## ADR-008: Inspect tokens without persisting credentials

**Status:** Accepted
**Date:** 2026-09-01

### Decision

Add session-only protocol inspector views to the applications. Show decoded headers, claims, SAML XML, validation results, and authorization decisions. Redact authorization headers, cookies, codes, assertions, and refresh tokens from ALB and CloudWatch logs. Never display a refresh token.

### Why

Protocol visibility is a core learning objective, but raw tokens and assertions are bearer credentials. The project must show how the flows work without turning observability into credential storage.

### Alternatives

- Log raw tokens and requests to CloudWatch. Rejected because logs persist and are accessible outside the active session. ALB logs already provide request metadata without full authorization headers or bodies; see [Application Load Balancer access logs](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html).
- Use the OAuth implicit flow so tokens appear in the browser URL. Rejected because Microsoft recommends authorization code with PKCE. See the [Microsoft identity platform authorization-code flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow).
- Hide all token data. Rejected because it would undermine the project's protocol-comparison goal.

## ADR-009: Use a descriptive cross-cloud project title

**Status:** Accepted
**Date:** 2026-09-01

### Decision

Name the project **Cross-Cloud Identity with Microsoft Entra Suite and AWS**. Use neutral, descriptive resource prefixes rather than deriving cloud resource names from the full title.

### Why

The title communicates the platforms and the project's identity focus to a portfolio reader without requiring prior context. Resource names remain short enough for provider limits and reusable deployments.

### Alternatives

- Keep a short generic project name. Rejected because it does not communicate the cross-cloud architecture or Entra Suite scope.
- Include every protocol and governance capability in the title. Rejected because the resulting title would be difficult to scan; the README describes the detailed scope.

## ADR-010: Use JML as the continuous project storyline

**Status:** Accepted
**Date:** 2026-09-01

### Decision

Create synthetic identities early and carry them through Joiner, Mover, and Leaver scenarios as the platform is built. The Joiner workflow automatically assigns a baseline access package through a direct-assignment policy before first sign-in. The test user does not submit a request or complete an approval. Run Mover validation when application roles and AWS access are available, and run Leaver validation during final testing.

### Why

Continuous JML validation connects identity governance to observable application and AWS authorization outcomes. Administrative evidence can validate most phases without repeated interactive sign-ins as the test users.

### Alternatives

- Add one Lifecycle Workflow near the end. Rejected because it would demonstrate an isolated feature rather than an identity lifecycle. See [What are Lifecycle Workflows?](https://learn.microsoft.com/en-us/entra/id-governance/what-are-lifecycle-workflows).
- Require test users to request their baseline package. Rejected because baseline access should exist before first sign-in. Lifecycle Workflows can create the assignment administratively; see [access-package assignment through Lifecycle Workflows](https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-access-package-assignments).
- Use attribute-based automatic assignment for the primary scenario. Deferred because explicit workflow execution provides clearer task history and JML evidence.

## ADR-011: Federate Entra ID with IAM Identity Center and provision through SCIM

**Status:** Accepted
**Date:** 2026-09-01

### Decision

Configure Microsoft Entra ID as the external SAML identity provider for AWS IAM Identity Center. Use the Entra provisioning service and SCIM for workforce users and direct group memberships. Use Terraform for permission sets and group-to-account assignments, but do not use Terraform or AWS Identity Store mutation APIs to manage SCIM-owned identities.

### Why

This design provides one workforce identity lifecycle across Entra and AWS, enables temporary console and CLI credentials, and avoids two competing sources of truth for IAM Identity Center identities.

### Alternatives

- Use IAM users for routine AWS access. Rejected because long-lived credentials bypass the cross-cloud workforce lifecycle.
- Maintain separate users in the IAM Identity Center directory. Rejected because duplicate identity administration weakens the JML scenario.
- Manage SCIM-provisioned users and memberships with AWS APIs or Terraform. Rejected because it can create drift from the external identity provider. See [AWS automatic provisioning considerations](https://docs.aws.amazon.com/singlesignon/latest/userguide/provision-automatically.html).
- Configure SAML without SCIM. Rejected because SAML authenticates the user but does not provision the users and groups IAM Identity Center requires. See [AWS external identity providers](https://docs.aws.amazon.com/singlesignon/latest/userguide/manage-your-identity-source-idp.html).

## ADR-012: Treat prerequisites as Phase 0

**Status:** Accepted
**Date:** 2026-09-01

### Decision

Make prerequisites and environment readiness the first numbered phase. Phase 0 confirms accounts, licences, the AWS region, DNS host names, the certificate path, root protections, the budget alert, and the local toolchain, and records the installed versions. The documentation baseline is a precondition of Phase 0 rather than a phase of its own. No workload infrastructure is provisioned during Phase 0.

### Why

Several later phases depend on facts that are cheap to confirm early and expensive to discover late. A Microsoft Entra Suite trial has a fixed expiry that constrains when the licence-dependent phases can run. SAML assertion consumer service URLs and OIDC redirect URIs depend on host names that must not change after the Entra applications are registered. A budget alert is only useful before the first billable resource exists. Treating these as a numbered phase with exit criteria makes them reviewable instead of assumed.

### Alternatives

- List prerequisites in the README only. Rejected because a prose list has no completion state, no exit criteria, and no worklog evidence.
- Confirm each prerequisite when the phase that needs it begins. Rejected because a missing domain, licence, or role blocks work already in progress, and a trial clock that started too early cannot be recovered.
- Provision a placeholder domain and certificate later. Rejected because renaming a registered Entra application's reply URLs invalidates the protocol evidence the project is built to demonstrate.

## ADR-013: Remove the superseded Google Cloud draft

**Status:** Accepted
**Date:** 2026-09-01

### Decision

The `terraform/` directory contains a Google Cloud draft written before the project adopted AWS. Remove it rather than carrying it forward or adapting it. Phase 3 writes the AWS Terraform configuration from an empty directory.

### Why

The draft targets a different provider, a different compute model, and a Guacamole remote-access design that ADR-003 already rejected. Keeping it invites confusion about which configuration is authoritative and leaves a `terraform validate` job checking code that will never be applied. Nothing in it transfers to the AWS target beyond general module conventions, which ADR-007 already records.

### Alternatives

- Keep the draft on an archive branch. Rejected for a single-user learning repository where the decision log already records why Google Cloud was set aside; see ADR-002.
- Adapt the existing modules to AWS. Rejected because the network, compute, and remote-access designs differ enough that a rewrite is clearer than a translation.

## ADR-014: Evaluate security controls proportionately

**Status:** Accepted
**Date:** 2026-09-01

### Decision

Evaluate a security control when it materially reduces project efficiency, increases recurring cost, or obscures the identity objective. Record the threat, expected risk reduction, operational friction, compensating controls, and rollback path before retaining, changing, or removing it.

Root MFA, no root access keys, no committed secrets, no public management ports, reviewed IAM changes, and no persistent raw-token logging remain baseline requirements. Other defense-in-depth measures can be adjusted when a documented alternative provides sufficient protection for this single-user project.

### Why

A portfolio project should demonstrate informed risk decisions as well as secure defaults. Controls that do not materially reduce the project's credible risks can consume time and cost without improving the identity scenarios.

### Alternatives

- Implement every production control regardless of cost or friction. Rejected because the project is not a production service and some controls would hide the architecture under unrelated operations. See the [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html).
- Remove any control that slows implementation. Rejected because efficiency alone does not justify accepting credential exposure, account lockout, public management access, or irreversible changes.
- Make undocumented exceptions. Rejected because later readers could not distinguish a conscious risk decision from an omission. Use the decision log and the [AWS Well-Architected Cost Optimization Pillar](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html) to record the tradeoff.

## ADR-015: Control cost by phase review instead of an AWS Budget

**Status:** Accepted
**Date:** 2026-09-02

### Decision

Do not create an AWS Budget, billing alert, or cost anomaly detector for this project. Control cost with the per-phase rule: review recurring cost before applying any resource that bills while idle, and destroy billable resources during Phase 11. This decision applies the ADR-014 framework.

- **Threat:** Unnoticed spend from a resource that bills while idle, such as a NAT gateway, an Application Load Balancer, or the connector EC2 host.
- **Risk reduction from a budget:** Low. A budget alert is retrospective. It reports spend that already happened, often a day late, and does not prevent the resource from being created.
- **Cost and friction:** Setup is cheap, but the alert needs a verified notification path and adds a control that no phase exercises.
- **Effect on learning objectives:** None. Cost alerting is not part of the identity scenario the project demonstrates.
- **Compensating controls:** Every billable resource is introduced by a reviewed `terraform plan` in a single account. The phase checklists name each idle-billing resource before it is created. Phase 11 destroys them.
- **Rollback:** Create a budget in the Billing console at any time. No project resource depends on its absence.

### Why

The project is a short-lived, single-account portfolio build where every billable resource is created deliberately through a reviewed plan. The reviewed plan prevents the spend; a budget alert would only report it afterwards.

### Alternatives

- Create an AWS Budget with an email alert. Rejected as retrospective for a project whose spend is already gated by a reviewed `terraform plan`. See [Managing your costs with AWS Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html).
- Enable AWS Cost Anomaly Detection. Rejected because anomaly detection needs a spend baseline that a short project never establishes. See [AWS Cost Anomaly Detection](https://docs.aws.amazon.com/cost-management/latest/userguide/manage-ad.html).
- Track nothing and check the console occasionally. Rejected because it leaves no written rule, which ADR-014 requires for a removed control.
