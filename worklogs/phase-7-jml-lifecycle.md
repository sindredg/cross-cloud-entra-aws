# Phase 7: Joiner, Mover, and Leaver

**Date:** 2026-09-14

**Goal:** Take one synthetic persona through the full lifecycle and measure each access change in Entra and AWS.

```mermaid
flowchart LR
    J["Joiner<br/>Security Analyst"] --> E["Elevation<br/>deny, approve"]
    E --> M["Move<br/>Cloud Engineer"]
    M --> R["Revoke<br/>elevation"]
    R --> L["Leaver<br/>disable first"]
```

## Setup

| Persona attribute | Value |
| --- | --- |
| Name | Joe Joiner, `joe@<tenant>` |
| Company / department / title | `CrossCloud Identity Project` / `Security` / `Security Analyst` |
| Manager | Administrator |
| Hire date | 2026-09-14 |
| Start state | Disabled |

Workflows run on demand, with scheduling off. Task changes were published as new versions through Microsoft Graph `createNewVersion`.

| Workflow | Version | Tasks in order |
| --- | --- | --- |
| `CrossCloud Joiner` | 2 | Request baseline package → Enable account |
| `CrossCloud Mover` | 1 | Revoke refresh tokens |
| `Offboard cross-cloud leaver` | 2 | Disable account → Revoke refresh tokens → Cancel pending requests → Remove all package assignments |

## Joiner

Version 2 requests the package before it enables the account. Version 1 enabled the account first.

![Joiner version 1 enabled first; version 2 requests the package first](../docs/images/phase-7-01-joiner-version-2.png)

| Time (UTC) | Event |
| --- | --- |
| 20:59:10 | Package assignment created. Account still disabled. |
| 20:59:12 | Account enabled |
| 20:59:35 | Added to `AWS-Auditors` and `CrossCloud-Workforce` |
| 21:00:08 | Baseline app role delivered |

![Both Joiner tasks completed in order](../docs/images/phase-7-02-joiner-task-results.png)

![Workflow history: one user processed, no failures](../docs/images/phase-7-03-joiner-workflow-history.png)

![Baseline package delivered to Joe](../docs/images/phase-7-04-baseline-delivered.png)

![Dynamic membership: AWS-Auditors and CrossCloud-Workforce](../docs/images/phase-7-05-joiner-groups.png)

SCIM created Joe in AWS. The first sign-in used MFA and showed only the Auditor role.

![IAM Identity Center lists Joe Joiner, created by SCIM](../docs/images/phase-7-08-identity-center-users.png)

![First sign-in to the Identity Center app with multifactor authentication](../docs/images/phase-7-09-joiner-first-sign-in.png)

![AWS access portal shows crosscloud-Auditor only](../docs/images/phase-7-10-portal-auditor.png)

## Mover

### Elevation

| Time (UTC) | Event |
| --- | --- |
| 21:53:52 | Request 1 submitted |
| 21:57:45 | Request 1 denied |
| 22:00:57 | Request 2 submitted |
| 22:02:03 | Request 2 approved |
| 22:02:16 | Added to `AWS-Elevated-ReadOnly` |

![My Access offers AP-Cross-Cloud Elevated](../docs/images/phase-7-11-myaccess-elevated.png)

![Business justification required on request](../docs/images/phase-7-12-request-justification.png)

![Approver queue shows the pending request](../docs/images/phase-7-13-approval-pending.png)

![Request history: submitted, pending, denied](../docs/images/phase-7-14-request-denied.png)

![Request history: submitted, pending, approved](../docs/images/phase-7-15-request-approved.png)

![Package requests: one delivered, one denied](../docs/images/phase-7-16-elevated-requests.png)

![Elevated assignment delivered with an end date 2 hours after approval](../docs/images/phase-7-17-elevated-assignment.png)

![Joe is the only member of AWS-Elevated-ReadOnly](../docs/images/phase-7-18-elevated-group-member.png)

![AWS access portal shows Auditor and ElevatedReadOnly](../docs/images/phase-7-19-portal-auditor-elevated.png)

### Role change

| Time (UTC) | Event |
| --- | --- |
| 22:17:00 | Department and title set to `Cloud Platform` / `Cloud Engineer` |
| 22:17:24 | `AWS-Auditors` → `AWS-Developers` |
| 22:18:38 | Refresh tokens revoked by the Mover workflow |

![Job information changed to Cloud Engineer in Cloud Platform](../docs/images/phase-7-20-mover-job-change.png)

![Groups after the move: AWS-Developers, with the elevated group kept](../docs/images/phase-7-21-mover-groups.png)

![Mover task: refresh tokens revoked](../docs/images/phase-7-22-mover-revoke-tokens.png)

The elevation survived the role change. Package access and attribute-driven roles are independent.

![AWS access portal shows Developer and ElevatedReadOnly](../docs/images/phase-7-23-portal-developer-elevated.png)

### Revoke elevation

| Time (UTC) | Event |
| --- | --- |
| 22:28:24 | Administrator removes the elevated assignment |
| 22:28:27 | Removed from `AWS-Elevated-ReadOnly` |
| 22:34:06 | SCIM updates the group in AWS |

![Remove access on the elevated assignment](../docs/images/phase-7-24-elevated-remove-access.png)

![Groups after removal: AWS-Developers and CrossCloud-Workforce](../docs/images/phase-7-25-groups-after-revoke.png)

![AWS access portal shows Developer only](../docs/images/phase-7-26-portal-developer-only.png)

## Leaver

Before the run, Joe held an AWS CLI session.

![AWS issues CLI credentials that last until the session expires](../docs/images/phase-7-27-cli-session-issued.png)

![Leaver version 1 disabled last; version 2 disables first](../docs/images/phase-7-28-leaver-version-2.png)

| Time (UTC) | Event |
| --- | --- |
| 22:44:12 | Account disabled |
| 22:44:19 | Refresh tokens revoked |
| 22:44:30 | Baseline assignment removed |
| 22:44:43 | Removed from `AWS-Developers` and `CrossCloud-Workforce` |
| 22:45:03 | New sign-in blocked: `AADSTS50057` |
| 22:45:13 | Identity Center app role removed |
| 22:54:48 | SCIM disables Joe in AWS |

![Disable and revoke complete while cleanup tasks queue](../docs/images/phase-7-29-leaver-task-run.png)

![Leaver workflow history: four tasks, no failures](../docs/images/phase-7-30-leaver-workflow-history.png)

![Audit log from workflow start to app role removal](../docs/images/phase-7-31-leaver-audit-timeline.png)

![Sign-in refused because the account is locked](../docs/images/phase-7-32-sign-in-blocked.png)

![Baseline assignments no longer include Joe](../docs/images/phase-7-33-baseline-removed.png)

![IAM Identity Center shows Joe Joiner disabled](../docs/images/phase-7-34-identity-center-disabled.png)

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| SCIM create fails. The portal shows `UpdateForUnconnectedEntry`; the log shows `400 name: The attribute name is required`. | AWS requires `name.givenName` and `name.familyName`. The persona had no first or last name. | Set the first and last name, then provision on demand. |

![Provision on demand fails with no name attributes in the payload](../docs/images/phase-7-06-scim-name-required.png)

![First and last name set on the persona](../docs/images/phase-7-07-persona-names.png)

## Limits

- **Assigned while disabled, delivered after.** The package assignment started while the account was disabled, but the app role arrived 55 seconds after enablement. The evidence proves delivery before first sign-in, not delivery while disabled.
- **Existing AWS sessions outlive the Leaver.** A session issued before disablement stayed usable after SCIM disabled the user. Role sessions last until the permission set session ends.
- **SCIM lags containment.** AWS deactivation followed Entra disablement by 10 minutes.
- **The 2-hour expiry wasn't observed.** An administrator revoked the elevation instead.
