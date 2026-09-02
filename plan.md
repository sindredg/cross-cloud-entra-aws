# Cross-Cloud Identity with Microsoft Entra Suite and AWS implementation plan

This plan builds the project in small, verifiable phases. Lifecycle Workflows provide a continuous Joiner, Mover, and Leaver storyline: a synthetic identity receives baseline access before first sign-in, changes access as the platform grows, and is deprovisioned during final validation. Complete one phase at a time. Update a phase to `Done` only after its exit criteria pass and its worklog contains no sensitive identifiers.

## Status

| Phase | Scope | Status |
| --- | --- | --- |
| 0 | Prerequisites and environment readiness | Ongoing |
| 1 | Entra federation and IAM Identity Center access | Done |
| 2 | Identity lifecycle foundation and Joiner | Ongoing |
| 3 | Terraform AWS foundation and permission sets | Done |
| 4 | AWS network | Planned |
| 5 | Shared container platform | Planned |
| 6 | First ECS service | Planned |
| 7 | Public protocol applications and Mover | Planned |
| 8 | Private ECS application | Planned |
| 9 | Entra Private Access connector | Planned |
| 10 | Entra Suite controls | Planned |
| 11 | Leaver, end-to-end validation, and publication | Planned |

## JML progression

| Phase | Identity state | Evidence |
| --- | --- | --- |
| Phases 1–2 | Joiner | Automated access-package assignment, group membership, SCIM provisioning, and workflow history |
| Phases 3–6 | Active worker | IAM Identity Center permission-set access and platform authorization baseline |
| Phase 7 | Mover | Old entitlement removal, new entitlement assignment, changed claims, and changed AWS access |
| Phases 8–10 | Governed worker | Private Access and Entra Suite policy decisions |
| Phase 11 | Leaver | Package removal, token revocation, account disablement, SCIM deprovisioning, and session-containment evidence |

## Rules for every phase

- Prefer temporary credentials from IAM Identity Center.
- Review recurring cost before applying a resource that bills while idle.
- Run `terraform fmt`, `terraform validate`, and a reviewed `terraform plan` before each apply.
- Keep secret values out of Terraform, Bicep, state inputs, user data, logs, screenshots, and worklogs.
- Keep raw tokens and SAML assertions out of persistent logs.
- Stop when an unexpected permission, replacement, deletion, or public-access change appears.
- Record decisions and redacted evidence in `worklogs/`.

## Security and efficiency reviews

Security controls are evaluated in context when they materially increase recurring cost, operational friction, or iteration time. Record the following before retaining, changing, or removing such a control:

- Threat and likely impact.
- Risk reduction provided by the control.
- Cost and implementation friction.
- Effect on the project's learning objectives.
- Available compensating controls.
- Rollback and validation method.

Secret exclusion from version control, protection against public management exposure, and the prohibition on persistent raw-token logging remain baseline requirements. Other defense-in-depth controls can be adjusted through a documented decision.

## Phase 0: Prerequisites and environment readiness

**Status:** Ongoing

No workload infrastructure is provisioned in this phase. It establishes the documentation baseline, confirms prerequisites, and puts cost controls in place before the first billable workload resource.

### Documentation baseline

- [x] Select a descriptive project title.
- [x] Define the target architecture, public and private application paths, and tool boundaries.
- [x] Define JML as the continuous validation storyline.
- [x] Write the root README, the phased plan, and the decision log.
- [x] Create worklog conventions and repository hygiene rules for state, credentials, tokens, and local parameters.

### AWS account readiness

- [x] Confirm the existing administrative sign-in works and remains available as a rollback path.
- [x] Enable an IAM Identity Center organization instance.
- [x] Use `eu-north-1` as the project region.
- [x] Decide the cost-control approach before any workload is provisioned; ADR-015 records why this project reviews cost per phase instead of creating an AWS Budget.

### Microsoft cloud readiness

- [x] Confirm a Microsoft Entra tenant is available for project use.
- [x] Start the Microsoft Entra Suite trial, or confirm equivalent individual licences.
- [ ] Record the trial start date and expiry so licence-dependent phases are sequenced before it lapses.
- [x] Confirm licences can be assigned to the synthetic test users; the Phase 2 Joiner run exercised governance licensing.
- [ ] Confirm a dedicated administrative identity protected by MFA.
- [ ] Confirm the least-privileged role assignments the plan requires, including Lifecycle Workflows Administrator, Identity Governance Administrator, Application Administrator, Conditional Access Administrator, and Global Secure Access Administrator.
- [ ] Confirm a verified tenant domain, or accept the default `onmicrosoft.com` domain for synthetic user principal names.
- [x] Confirm an Azure subscription for Microsoft Graph Bicep deployments; the optional custom task extension can reuse it.

### Naming

- [x] Choose the resource name prefix and the environment tag value; `terraform/variables.tf` sets `crosscloud` and `project`.

DNS, certificate, and public host-name decisions moved to Phase 7, which registers the Entra applications that depend on them. They do not block Phases 4 through 6.

### Test device

Windows 11 and Global Secure Access client checks moved to Phase 9, the phase that installs the connector.

### Local workstation toolchain

- [x] Install Git.
- [x] Install Terraform and record the version; Phase 3 pins the project version.
- [x] Install AWS CLI v2.
- [x] Enable Docker with BuildKit and confirm it is reachable from the working shell.
- [x] Install the Azure CLI.
- [x] Install Bicep through Azure CLI.
- [x] Record every installed version so the worklog documents a reproducible toolchain.

PowerShell 7, the Microsoft Graph modules, and `jq` moved to Phase 2, which needs them to export and deploy Lifecycle Workflow payloads.

### Build architecture

- [x] Record the workstation CPU architecture; the Phase 0 worklog records Linux ARM64.

The Fargate CPU architecture decision moved to Phase 6, the phase that builds the first container image.

### Repository

- [x] Remove the superseded Google Cloud draft from `terraform/`, per ADR-013.
- [x] Make the initial commit of the planning baseline.
- [x] Create the remote and confirm the security workflow runs.
- [x] Confirm the secret-scanning job passes on the full history.

**Exit criteria:** Every remaining prerequisite is confirmed by a recorded command or portal check, the cost-control approach and region are recorded, the toolchain is installed and versioned, and no workload infrastructure has been provisioned. Nothing left in this phase blocks Phase 4.

## Phase 1: Entra federation and IAM Identity Center access

**Status:** Done

- [x] Enable IAM Identity Center for the AWS account.
- [x] Configure Microsoft Entra ID as the external SAML identity provider.
- [x] Enable SCIM provisioning and keep its endpoint and token outside the repository.
- [x] Deploy an attribute-driven administrative Entra group with Microsoft Graph Bicep.
- [x] Provision the administrative group to IAM Identity Center.
- [x] Create and assign a one-hour bootstrap permission set.
- [x] Configure the `cross-cloud-admin` AWS CLI SSO profile.
- [x] Verify federated console and CLI access with temporary credentials.
- [x] Keep deployment-specific identifiers out of published evidence.

**Exit criteria:** Federated console and CLI access work with temporary credentials, SCIM provisioning is enabled with its secrets held outside the repository, and the previous administrative path remains recoverable.

## Phase 2: Identity lifecycle foundation and Joiner

**Status:** Ongoing

- [ ] Install PowerShell 7 and the required Microsoft Graph modules, moved from Phase 0.
- [ ] Install `jq` for reading Graph responses, moved from Phase 0.
- [ ] Define reusable synthetic Joiner, Mover, and Leaver personas with no real personal data.
- [ ] Include the required lifecycle attributes, such as manager, department, job title, hire date, and leave date.
- [ ] Create an idempotent Graph bootstrap path for the synthetic identities; Lifecycle Workflows do not create the source identity.
- [x] Create baseline security groups and an Entitlement Management catalog.
- [x] Create a baseline access package with a direct-assignment policy and no approval requirement.
- [x] Add a documented, idempotent deployment path that creates or updates a workflow from a version-controlled JSON payload; see `entra/lifecycle-workflows/`.
- [x] Keep tenant object IDs out of the committed definitions by resolving groups, access packages, and assignment policies from display names at deployment time.
- [ ] Export the deployed Joiner from Microsoft Graph and reconcile `workflows/joiner.example.json` with the workflow that Phase 2 validated.
- [ ] Deploy the Mover and Leaver definitions with scheduling disabled until their on-demand tests pass.
- [x] Configure the Joiner workflow to assign the baseline package automatically before first sign-in.
- [x] Run the Joiner workflow on demand for one synthetic user.
- [ ] Verify workflow history, package assignment, direct group membership, and SCIM provisioning without signing in as the test user.
- [ ] Record timestamps needed to measure downstream provisioning delay.

**Exit criteria:** A synthetic Joiner receives baseline Entra access and is provisioned to IAM Identity Center without self-service interaction, committed identifiers, or an interactive user sign-in.

## Phase 3: Terraform AWS foundation and permission sets

**Status:** Done

- [x] Add pinned Terraform and AWS provider versions.
- [x] Configure the AWS provider to use the `cross-cloud-admin` SSO profile or ambient temporary credentials.
- [x] Add validated variables for region, name prefix, and environment; Phase 4 adds the network CIDRs and feature flags.
- [x] Derive names, tags, and service maps in `locals.tf`.
- [x] Add a placeholder-only `terraform.tfvars.example`.
- [x] Keep local state and private tfvars ignored.
- [x] Add an architecture-level `identity_center` module for permission sets and group-to-account assignments.
- [x] Import the bootstrap permission set into Terraform or replace it, validate the new access path, and then remove the unmanaged bootstrap resource.
- [x] Look up SCIM-provisioned groups by stable display name; do not create users or group memberships with Terraform.
- [x] Add compact outputs that do not expose credentials or deployment-specific IDs.
- [x] Initialize, format, validate, and review the plan before applying the Identity Center resources.

**Exit criteria:** Terraform authenticates with temporary credentials, the synthetic Joiner inherits the intended AWS permission set through a SCIM-managed group, and Terraform does not own workforce identities.

## Phase 4: AWS network

**Status:** Planned

- [ ] Add validated CIDR and feature-flag variables, moved from Phase 3.
- [ ] Create a `network` module with a VPC across two Availability Zones.
- [ ] Create public subnets for public load-balancer nodes.
- [ ] Create private subnets for Fargate tasks and the connector EC2 host.
- [ ] Add an internet gateway and explicit route tables.
- [ ] Compare one NAT gateway with the required VPC endpoints before selecting the project egress design.
- [ ] Document availability and recurring-cost tradeoffs.
- [ ] Enable VPC Flow Logs with short retention if the cost is acceptable.
- [ ] Apply only the reviewed network plan.

**Exit criteria:** Public and private routing behaves as documented, no workload has been deployed, and no unintended inbound path exists.

## Phase 5: Shared container platform

**Status:** Planned

- [ ] Create the ECS cluster.
- [ ] Create ECR repositories with image scanning and lifecycle rules.
- [ ] Create CloudWatch log groups with short retention.
- [ ] Create ECS task-execution and workload roles with narrow trust policies.
- [ ] Create Secrets Manager containers without secret versions.
- [ ] Add repository and log outputs needed by the application build process.

**Exit criteria:** The shared platform exists, IAM policies are reviewed, and no application task is running.

## Phase 6: First ECS service

**Status:** Planned

- [ ] Decide the Fargate CPU architecture, either matching the ARM64 workstation or cross-building, and record the decision before the first image build. Moved from Phase 0.
- [ ] Build a minimal health application as a container.
- [ ] Push an immutable image tag to ECR.
- [ ] Create one reusable `ecs_service` module.
- [ ] Run one Fargate task in private subnets without a public IP.
- [ ] Add health checks, deployment rollback, and CloudWatch logging.
- [ ] Confirm the task receives only its required IAM role.

**Exit criteria:** One healthy service deploys and rolls back predictably, and its logs contain no credentials or raw tokens.

## Phase 7: Public protocol applications and Mover

**Status:** Planned

- [ ] Register or designate a DNS domain for the public application host names, moved from Phase 0.
- [ ] Decide between a Route 53 hosted zone and delegation from an external registrar, moved from Phase 0.
- [ ] Confirm the AWS Certificate Manager public certificate path with DNS validation, moved from Phase 0.
- [ ] Reserve the host names for `saml-web`, `oidc-web`, `oauth-api`, and `private-web` before registering the Entra applications, moved from Phase 0.
- [ ] Create the `entra/` structure for Graph Bicep, Graph payloads, and idempotent cleanup automation.
- [ ] Create scenario-level application definitions for SAML, OIDC, and OAuth.
- [ ] Derive scope and app-role GUIDs instead of committing tenant-specific values.
- [ ] Resolve generated application IDs at deployment time and store secret values out of band.
- [ ] Create one public Application Load Balancer with HTTPS.
- [ ] Reuse the ECS service module for `saml-web`, `oidc-web`, and `oauth-api`.
- [ ] Route by host name or path with separate target groups.
- [ ] Add safe protocol-inspector views to each application.
- [ ] Decode claims and protocol messages in the active session only.
- [ ] Redact authorization headers, cookies, codes, assertions, and refresh tokens from logs.
- [ ] Add correlation IDs across ALB and application events.
- [ ] Map access-package groups and app roles to application authorization decisions.
- [ ] Change the Mover persona's authoritative attributes.
- [ ] Run the Mover workflow to remove the old package and assign the new package without user interaction.
- [ ] Compare new claims and AWS access with the previous state; test existing sessions separately.

**Exit criteria:** All three services show redacted protocol timelines, and the Mover produces documented changes to newly issued claims, application authorization, and AWS access.

## Phase 8: Private ECS application

**Status:** Planned

- [ ] Reuse the ECS service module for `private-web`.
- [ ] Create an internal Application Load Balancer.
- [ ] Allow inbound traffic only from the connector security group.
- [ ] Confirm the service has no public IP or public load-balancer path.
- [ ] Verify access from an authorized VPC source and denial from the internet.

**Exit criteria:** `private-web` is reachable inside the VPC and has no direct public route.

## Phase 9: Entra Private Access connector

**Status:** Planned

- [ ] Confirm a Windows 11 device is available for the Global Secure Access client and is not blocked by an existing management policy. Moved from Phase 0.
- [ ] Create a `private_access_connector` module for a Windows Server EC2 host.
- [ ] Place the host in a private subnet without a public IP.
- [ ] Grant outbound access required by Microsoft and access to the internal load balancer only.
- [ ] Use Systems Manager or another reviewed administrative path.
- [ ] Provision the host without enrollment credentials in Terraform or EC2 user data.
- [ ] Install and register the connector through a documented interactive step.
- [ ] Move the connector into a dedicated project connector group.
- [ ] Publish `private-web` as a per-app Private Access destination.
- [ ] Assign access through the governed pilot group.

**Exit criteria:** The connector is healthy, reaches `private-web`, exposes no inbound management port, and permits only the governed pilot identity through Private Access.

## Phase 10: Entra Suite controls

**Status:** Planned

- [ ] Create Conditional Access in report-only mode with an emergency-account exclusion.
- [ ] Validate the Global Secure Access client route and access decision.
- [ ] Add expiration and an access review to a non-baseline governed entitlement.
- [ ] Validate Lifecycle Workflow run, user, and task-processing reports through Microsoft Graph.
- [ ] Add a risk-based ID Protection scenario that does not require manufacturing unsafe activity.
- [ ] Add a Verified ID scenario after the core flows are stable.
- [ ] Add a custom task extension and Azure Logic App only if the downstream AWS automation justifies the extra control plane.

**Exit criteria:** Each enabled Suite capability has a safe test, a rollback path, and redacted evidence.

## Phase 11: Leaver, end-to-end validation, and publication

**Status:** Planned

- [ ] Run the Leaver workflow to remove all access-package assignments, revoke refresh tokens, and disable the synthetic user.
- [ ] Confirm SCIM deprovisioning and denial of new IAM Identity Center and application sessions.
- [ ] Test already-issued Entra and AWS sessions separately from new authentication attempts.
- [ ] If implemented, validate immediate AWS containment and its rollback path without relying only on session expiry.
- [ ] Test SAML, OIDC, OAuth, and Private Access at their documented lifecycle checkpoints.
- [ ] Match browser, application, ALB, Entra, and Global Secure Access events with correlation IDs.
- [ ] Run formatting, validation, linting, and secret scanning in CI.
- [ ] Test Terraform create, destroy, and create in the project account.
- [ ] Run the Entra cleanup path and confirm Graph resources are removed.
- [ ] Review screenshots and worklogs for identifiers and credentials.
- [ ] Replace planning warnings with final deployment guidance.
- [ ] Destroy billable resources that are not needed after validation.

**Exit criteria:** A new engineer can reproduce the project safely, trace one synthetic identity from Joiner through Mover to Leaver, inspect the protocol and provisioning evidence, and remove all created resources.

## Change control

When a phase changes:

1. Update its checklist and status in this file.
2. Record the reason in the current worklog.
3. Add or supersede an entry in `decisions.md` when a technical or scope decision changes.
4. Update the architecture diagram if a boundary changes.
5. Do not mark the phase `Done` until its exit criteria pass.
