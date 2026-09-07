# Cross-Cloud Identity with Microsoft Entra Suite and AWS planning decisions

Record decisions as Decision, Why, and Alternatives with documentation links. Keep superseded entries as history, not current implementation requirements.

Current scope: [lifecycle and Private Access](#adr-016-focus-on-lifecycle-and-private-access), a [minimal footprint for one private target](#adr-017-size-infrastructure-for-one-private-target), and [Grafana as that target](#adr-020-reuse-grafana-from-the-iam-lab-as-the-private-target-without-its-access-layers). Existing federation, SCIM, and permission sets remain in use.

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

**Status:** Superseded by [ADR-017](#adr-017-size-infrastructure-for-one-private-target)
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

**Status:** Superseded by [ADR-017](#adr-017-size-infrastructure-for-one-private-target)
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

**Status:** Superseded by [ADR-017](#adr-017-size-infrastructure-for-one-private-target)
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

**Status:** Superseded by [ADR-016](#adr-016-focus-on-lifecycle-and-private-access)
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

Validation scope is narrowed by [ADR-016](#adr-016-focus-on-lifecycle-and-private-access): AWS and private-access entitlements replace custom protocol-application roles.

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

**Status:** Superseded by [ADR-017](#adr-017-size-infrastructure-for-one-private-target)
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

## ADR-016: Focus on lifecycle and Private Access

**Status:** Accepted
**Date:** 2026-09-04

### Decision

Demonstrate Joiner, Mover, and Leaver automation across Entra, AWS IAM Identity Center, and one Private Access destination. Retain the existing SAML federation and SCIM integration as supporting infrastructure. Remove the planned `saml-web`, `oidc-web`, `oauth-api`, protocol inspectors, and standalone Conditional Access showcase.

Keep MFA, existing Conditional Access policies, credential hygiene, and private network boundaries. Policy changes required for Private Access remain in scope. ID Protection, Verified ID, and custom Logic App extensions are not required. Completed work remains evidence; only future phases are resequenced.

### Why

Federation is already demonstrated here; OIDC, OAuth, and Conditional Access have been covered in other projects. Lifecycle outcomes and private application access add distinct evidence without maintaining duplicate applications.

### Alternatives

- Keep the protocol-comparison platform. Rejected as duplicate scope with additional compute and networking.
- Show lifecycle tasks without a resource-access outcome. Rejected: [Lifecycle Workflows](https://learn.microsoft.com/en-us/entra/id-governance/what-are-lifecycle-workflows) and [per-app Private Access](https://learn.microsoft.com/en-us/entra/global-secure-access/how-to-configure-per-app-access) together make provisioning, access change, and removal observable.

## ADR-017: Size infrastructure for one private target

**Status:** Accepted
**Date:** 2026-09-04

### Decision

Plan one private AWS application and one supported Windows Server connector. The initial test footprint need not provide high availability; record that limitation rather than presenting it as production-ready.

Do not mandate a shared ECS platform, public ALB, internal ALB, two-AZ deployment, purchased domain, or NAT gateway. Approve the necessary outbound connectivity, private destination addressing, transport, and no-public-inbound management path before deployment. AWS service endpoints are not a replacement for connector connectivity to Microsoft.

Keep architecture-level modules where justified, inputs in private configuration, and derived values in locals. No one-resource wrapper modules are required. Confirm licence and client/connector prerequisites before starting paid hosts. This replaces the fixed topology and prerequisite assumptions in ADR-002, ADR-003, ADR-007, and ADR-012.

### Why

The target exists to prove governed private reachability. A single target and a single connector are enough to demonstrate it.

### Alternatives

- Preserve the full [Fargate platform](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_types.html) with a shared cluster and load balancers. Rejected as breadth this project does not need.
- Put the application on a public endpoint. Rejected because it defeats the private-access boundary.
- Run the connector in a Linux container. Rejected: use a supported host per [Microsoft connector setup](https://learn.microsoft.com/en-us/entra/global-secure-access/tutorial-private-access-connector-setup).

## ADR-019: Run the private target on ARM Fargate behind interface endpoints

**Status:** Accepted
**Date:** 2026-09-04

**Supersedes:** the ADR-017 decision to defer the hosting model selection.

### Decision

Run the private application target as a single ARM64 Fargate task, and the Microsoft Entra private network connector on a `t3.xlarge` Windows Server 2022 instance, in one VPC with two single-AZ subnets:

- The connector subnet routes to an internet gateway. The connector holds a public address for outbound registration and tunnel traffic, and its security group declares no ingress rule.
- The target subnet has a route table with no entry beyond the VPC-local route and the S3 gateway endpoint. The task takes no public address, and its security group admits the application port only from the connector's security group.

The task pulls its image through `ecr.api`, `ecr.dkr`, and `logs` interface endpoints plus the free S3 gateway endpoint, so nothing in the target tier needs an internet path. Publish the running task's private address as an IP-address application segment on TCP 80. Administer the connector through SSM Fleet Manager. Create the connector's EC2 key pair outside Terraform so no private key material enters state. `enable_private_access` gates the whole footprint, so a test window ends by setting it to `false` and applying.

No NAT gateway or load balancer is deployed. The footprint is single-AZ and is not highly available.

### Why

The target exists to prove governed private reachability, and a container platform is worth demonstrating alongside it. ARM64 is the architecture the ARM64 workstation builds natively, so the image needs no cross-compilation.

The endpoints are what keep the design honest. The connector's outbound allowlist is a set of wildcard FQDNs, including `*.msappproxy.net` and `*.servicebus.windows.net`, so endpoints cannot carry the connector's traffic and its subnet must be routed. The target's traffic is only ECR and CloudWatch Logs, which endpoints serve exactly, so the target subnet keeps an empty route table and its isolation stays a routing property rather than an absence of a public address.

### Alternatives

- Run the target on EC2 with a health response served from the AMI's Python build. Rejected: it removes the container platform from the project.
- Give the Fargate task a public address in the routed subnet and pull from ECR over the internet gateway. Rejected: it contradicts the Phase 4 criterion that the target hold no public address, and it moves isolation onto the security group alone.
- Reach ECR through a NAT gateway. Rejected: it gives the target a general internet path it has no use for.
- Reach the connector over RDP from a permitted address. Rejected: [Fleet Manager Remote Desktop](https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-rdp.html) gives the interactive session that connector registration needs without an inbound rule.
- Publish the target by FQDN. Deferred: an FQDN segment needs Private DNS configured in Global Secure Access, which adds a second failure mode to the first reachability test. Revisit once the IP segment works.

## ADR-020: Reuse Grafana from the IAM lab as the private target, without its access layers

**Status:** Accepted
**Date:** 2026-09-04

### Decision

Use Grafana OSS as the private application target, adapted from the existing Grafana IAM lab. Take only the Grafana container. Do not carry over Caddy, the SCIM bridge, or the Entra OIDC configuration.

Run Grafana with anonymous viewer access and the login form disabled, so the target authenticates nobody and holds no credentials. Pin the image tag and mirror it into the project ECR repository. Persist nothing: the task's Grafana database is ephemeral and is recreated with each test window.

### Why

A real application is better evidence than a static health page. An assigned identity landing on a working Grafana instance, and an unassigned one failing to resolve it at all, demonstrates the access boundary more convincingly than an HTTP 200.

The three layers of the source lab do not all transfer:

- Caddy exists to obtain and renew a public Let's Encrypt certificate against a public DNS label. A Private Access destination has no public record and cannot answer an ACME HTTP-01 challenge, so Caddy has no function here.
- The OIDC and SCIM layers are the scope ADR-016 removed from this project as already covered elsewhere. The Grafana lab is where they are covered.

Removing Grafana's own authentication is the point rather than a shortcut. If Grafana authenticated its users, a successful sign-in would prove Grafana's configuration works, not that Private Access allowed the session. With anonymous access, reachability is the only variable, and Entra holds the entire access decision. It also keeps every credential out of the image, the task definition, and Terraform state.

### Alternatives

- Serve a static page from nginx or the AMI's Python build. Rejected: a weaker demonstration, and the Grafana lab already provides a working application.
- Carry the whole compose stack across, including Caddy and the SCIM bridge. Rejected: Caddy cannot function without a public endpoint, and the SCIM bridge duplicates provisioning this project already performs against IAM Identity Center.
- Keep Grafana's Entra OIDC sign-in behind Private Access. Rejected: it re-imports the scope ADR-016 removed, and it confuses which layer made the access decision.
- Persist the Grafana database on EFS. Rejected: the target holds no state worth keeping between test windows, and it would add a mount target and a second security group to a footprint that is torn down regularly.

## ADR-021: Use an Entra-joined VM as the Private Access test client

**Status:** Accepted
**Date:** 2026-09-05

### Decision

Test Microsoft Entra Private Access from an Entra-joined Windows 11 VM rather than from the project workstation.

### Why

The Global Secure Access client needs a user token, which needs a Primary Refresh Token. A device that is only Entra registered, signed into Windows with a personal Microsoft account, never issues one. The client fails with `AADSTS9002341: User is required to permit SSO`, retries every 60 seconds, and never receives a forwarding profile. It reports only `Signed out`, which does not point at the cause.

The workstation is Windows 11 Home, and Home cannot be Entra joined at all: join requires Pro, Enterprise or Education. No configuration change could fix it. The portal lists Microsoft Entra joined as a system requirement for both the x64 and Arm64 clients.

A joined VM obtains a PRT at Windows sign-in and acquires tokens silently. It also improves the evidence: the VM sits in Azure with no network path to the AWS VPC, so a successful request proves the tunnel carried it.

### Alternatives

- Upgrade the workstation to Windows 11 Pro. Rejected as a licence purchase to work around a test-client constraint.
- Rely on Entra registered support. Rejected: the [client install requirements](https://learn.microsoft.com/entra/global-secure-access/how-to-install-windows-client) list registered devices as supported in preview, but a registered device with a consumer Windows sign-in cannot produce the PRT the client needs, so the path does not work in this configuration.
- Test from the connector host. Rejected: it reaches the target directly over the VPC and would prove nothing about Private Access.

## ADR-022: Manage entitlement management objects as Graph JSON

**Status:** Accepted
**Date:** 2026-09-07

### Decision

Declare the access package catalog, the access packages, their resource roles, and their assignment policies as JSON under `entra/access-packages/`, deployed through the Microsoft Graph REST API by a script that reconciles rather than recreates. Name every object; never commit an object ID.

### Why

The Lifecycle Workflow definitions already reference access packages by display name and resolve them to IDs at deployment time. Until now those packages existed only in the portal, so the workflows were reproducible and the objects they act on were not. A reader could not tell what `AP-Cross-Cloud Baseline` contained, and the Mover's package swap could not be deployed at all because its second package did not exist.

Graph Bicep cannot manage these resources. It supports only `applications`, `appRoleAssignedTo`, `federatedIdentityCredentials`, `groups`, `oauth2PermissionGrants`, `servicePrincipals`, and `users`, which is the same limit that sent the workflows to REST in the first place. Extending the pattern already used for workflows keeps one approach for Entra objects instead of two.

The reconcile compares only the properties a definition states. Graph returns many read-only and defaulted properties on these objects; a definition that had to mirror all of them would break on the next service change and would say nothing about intent.

It never deletes. Removing a resource role or an assignment policy revokes access from every live assignment, so extras are reported and left in place for a human to remove deliberately.

### Alternatives

- Keep creating packages in the portal. Rejected: it leaves the object at the centre of the Joiner, Mover, and Leaver story undocumented, and it was already blocking the Mover.
- Use the `Microsoft.Graph.Identity.Governance` PowerShell cmdlets instead of raw REST. Rejected: the cmdlets wrap the same [entitlement management API](https://learn.microsoft.com/graph/api/resources/entitlementmanagement-overview) and would add a second large module dependency to a repository that already speaks to Graph directly.
- Use Terraform with the AzureAD provider. Rejected: the provider does not cover entitlement management, and splitting Entra objects across two tools for one feature would cost more than it saves.
- Let the reconcile delete undeclared roles and policies. Rejected: a file comparison is not enough justification for revoking live access. See the [resource role scope API](https://learn.microsoft.com/graph/api/accesspackage-post-resourcerolescopes?view=graph-rest-1.0), which delivers a role to every current and future assignment.

## ADR-023: Grant the private application through an access package, not a group

**Status:** Accepted
**Date:** 2026-09-07

### Decision

Assign the Global Secure Access application for the private AWS target through an access package rather than directly to the AWS role groups. Remove the direct group assignments Phase 5 created.

### Why

Phase 5 assigned the application to `AWS-Administrators`, `AWS-Auditors`, and `AWS-Developers`. That proved the tunnel works, and it also made every role equivalent: there was no identity that could be refused, so the phase demonstrated reachability rather than a boundary, and its denial exit criterion could not be met at all.

Granting through a package separates the two entitlements that a role change should move. AWS role access stays attribute-driven, because the role groups are dynamic and no package can add a member to a dynamic group. Private application access becomes governed, requested by a workflow task and removable by one. The Mover then has something to swap and the Leaver has something to remove, and the same attribute change moves both halves through two mechanisms that know nothing about each other.

It also produces the denial case for free: before promotion the worker holds no entitlement to the application, so the request fails at the Global Secure Access edge before any packet approaches AWS.

### Alternatives

- Keep the direct group assignments and add the package alongside. Rejected: two grant paths mean the package can be removed with no observable effect, which is worse evidence than no package at all.
- Put the AWS role groups in the access package instead. Rejected: they are dynamic groups, whose membership is computed from user attributes. Entitlement management cannot add a member to one. See [dynamic membership rules](https://learn.microsoft.com/entra/identity/users/groups-dynamic-membership).
- Use a Conditional Access policy to gate the application by group. Rejected: it would move the decision to a second control plane and would not give the Leaver an assignment to remove.

## ADR-024: Measure lifecycle delays from Graph and the AWS API, not from the portal

**Status:** Accepted
**Date:** 2026-09-07

### Decision

Record lifecycle timings from `identityGovernance/lifecycleWorkflows` task processing results and from the IAM Identity Store API, through `entra/lifecycle-workflows/run.ps1` and `scripts/watch-identity-center-membership.sh`. Do not report a delay read off a console refresh.

### Why

The project claims measured access-removal delays. The portal reports a run as a pass or fail count, which supports "it worked" and not "it took this long". Graph records `startedDateTime` and `completedDateTime` per task, which is the authoritative number and costs nothing to read.

The AWS half needs its own measurement because it happens through a chain nothing reports on end to end: an attribute changes, dynamic membership recomputes, SCIM provisions the change. The Identity Store API exposes no enabled or disabled flag for a user, so a disabled account is observed as the loss of its group memberships. That is also the state that matters, since permission sets are assigned to groups.

Keeping the two measurements in separate tools reflects that they are separate delays in series rather than one number.

### Alternatives

- Read timings from the workflow history blade. Rejected: it rounds, it does not expose per-task start times, and a screenshot of it is not a measurement.
- Use Entra audit logs as the source. Rejected: they are authoritative but arrive with their own ingestion delay, which would be measured along with the thing being measured.
- Poll `DescribeUser` for a disabled flag. Rejected: the [Identity Store API](https://docs.aws.amazon.com/singlesignon/latest/IdentityStoreAPIReference/API_DescribeUser.html) returns no such attribute, and group membership is the property that actually carries access.
