# Phase 6 runbook: Mover

What to do in the tenant, in order, and what to capture. Write the worklog from the evidence afterwards; this file is the plan, not the record.

## Goal

Change one attribute on the synthetic worker and show the change propagate to two places that never talk to each other: the AWS permission set the worker can assume, and whether the worker can reach a private application inside an AWS VPC.

The move is `Cloud Engineer` to `Cloud Administrator`. Nothing else about the account changes.

| Before | After |
| --- | --- |
| `AWS-Developers`, `CrossCloud-Workforce` | `AWS-Administrators`, `CrossCloud-Workforce` |
| Developer permission set in IAM Identity Center | Administrator permission set |
| `AP-Cross-Cloud Baseline` | `AP-Cross-Cloud Elevated` |
| No entitlement to `Grafana-AWS`, so the tunnel is refused | Entitled, so Grafana answers |

The two halves move for different reasons, which is the point of the phase. The AWS half moves because dynamic group rules recompute from `jobTitle`. The private access half moves because the Mover workflow swaps one access package for another. Neither mechanism knows about the other.

## Preconditions

1. **The AWS footprint is deployed.** Phase 5 destroyed it. `terraform apply`, push the image, and let the ECS service place a task.
2. **The application segment points at the current task address.** A new task gets a new private IP, so the Global Secure Access application segment from Phase 5 is stale. Republish it against the address Terraform reports, and confirm the segment reads `Success`.
3. **The elevated access package exists.** Fill in the templates under `entra/access-packages/packages/` and deploy them, `-WhatIf` first.
4. **`Grafana-AWS` is granted only through the package.** Phase 5 assigned the application directly to `AWS-Administrators`, `AWS-Auditors`, and `AWS-Developers`. Remove those three assignments. While they stand, every role reaches the target and there is no move to observe and no denial to demonstrate. This is the single step most likely to be forgotten; the denial case in step 2 below is what catches it.
5. **The Mover carries all three tasks.** The deployed version has only token revocation. Deploy the full definition and confirm it publishes a new version.
6. **The Mover is enabled.** An on-demand run of a disabled workflow is refused.

## Steps

### 1. Record the starting state

```bash
pwsh ./entra/lifecycle-workflows/run.ps1 -WorkflowDisplayName 'CrossCloud Mover' -UserPrincipalName <worker> -WhatIf
./scripts/watch-identity-center-membership.sh --user <worker> --once
```

The `-WhatIf` run resolves the workflow and the user and writes nothing; it confirms both exist and that the workflow is enabled before anything changes.

Capture: Entra group membership, the access package assignment, and the AWS-side membership the script prints.

### 2. Run the denial case

Sign the test client in as the worker, still a Cloud Engineer, and request Grafana.

This is the Phase 5 exit criterion that was never met. Without it the project shows reachability, not a boundary. Expect the request to fail because no forwarding profile rule covers the segment for an identity with no entitlement to the application, not because the network refused it.

Capture the failure, and capture the client's forwarding profile at the same time: the absence of the rule is the evidence, and it is more convincing than a browser error page.

### 3. Make the move

Change `jobTitle` to `Cloud Administrator`. Change nothing else.

Watch for whitespace. Phase 2 lost time to a job title stored with two spaces, which the admin center renders as one, and dynamic membership compares literally.

### 4. Run the Mover

```bash
pwsh ./entra/lifecycle-workflows/run.ps1 \
  -WorkflowDisplayName 'CrossCloud Mover' \
  -UserPrincipalName <worker> \
  -OutFile ./entra/lifecycle-workflows/local/phase-6-mover-run.md
```

An on-demand run applies every task regardless of the trigger, so this does not prove the `jobTitle` trigger fires. Scheduling is off by design. If you want the trigger itself on the record, enable scheduling and wait for a scheduled pass; say plainly in the worklog which of the two you did.

### 5. Measure the AWS side

```bash
./scripts/watch-identity-center-membership.sh --user <worker> \
  --until AWS-Administrators,CrossCloud-Workforce
```

Start this **before** the group change lands, or it will report that the membership already matches and measure nothing. The delay to report runs from the workflow task completing to the membership arriving, not from when the script started.

Dynamic group evaluation and SCIM provisioning are two separate delays in series. Note both if you can separate them: Entra membership changing is the first, IAM Identity Center reflecting it is the second.

### 6. Confirm the new access

- Sign in to the AWS access portal as the worker; the Administrator permission set should be the one offered.
- Request Grafana from the client again. Expect `200`.
- Take the `ipconfig` and the response in one frame, as Phase 5 did. A screenshot of a Grafana page proves nothing on its own.

Sign out and back in on the client first. Token revocation is a Mover task precisely so the next token carries the new claims, but the client may still hold a valid one.

## Exit criteria

| # | Criterion | Evidence |
| --- | --- | --- |
| 1 | An unentitled identity cannot reach the private target | Failure plus the forwarding profile with no rule for the segment |
| 2 | One attribute change moves the AWS role | Group membership and permission set, before and after |
| 3 | The same change moves the private-access entitlement | Access package assignments, before and after |
| 4 | The entitled identity reaches the target | `200` from the client, with its address in frame |
| 5 | The delay is measured, not asserted | Task timings from `run.ps1`, membership timings from the watch script |

Criterion 1 is Phase 5's unmet exit criterion. Record it here rather than reopening that phase.

## Evidence to capture

Follow the existing naming: `docs/images/phase-6-NN-description.png`.

| Suggested | Shows |
| --- | --- |
| `phase-6-01-starting-state.png` | Membership and package assignment before the move |
| `phase-6-02-denied-no-entitlement.png` | The unentitled request failing |
| `phase-6-03-forwarding-profile-no-rule.png` | No tunnel rule for the segment |
| `phase-6-04-jobtitle-changed.png` | The attribute change |
| `phase-6-05-mover-run-timings.png` | `run.ps1` output |
| `phase-6-06-groups-after.png` | Entra membership after |
| `phase-6-07-identity-center-membership.png` | The AWS side, with the watch script's timestamps |
| `phase-6-08-permission-set-after.png` | Administrator permission set offered |
| `phase-6-09-package-assignments-after.png` | Elevated held, baseline gone |
| `phase-6-10-grafana-reached.png` | `200`, client address in frame |

## Afterwards

Leave the worker as a Cloud Administrator. Phase 7 offboards that account, and offboarding an elevated identity is the more interesting case.

Do not destroy the AWS footprint yet; Phase 7 needs the same target to show access being withdrawn.
