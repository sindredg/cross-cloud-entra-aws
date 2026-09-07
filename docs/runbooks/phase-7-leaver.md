# Phase 7 runbook: Leaver

What to do in the tenant, in order, and what to capture. Write the worklog from the evidence afterwards; this file is the plan, not the record.

## Goal

Offboard the elevated worker Phase 6 promoted, and measure how long each layer of access actually takes to disappear. The interesting result is not that access ends. It is the gap between the layers.

The Leaver runs four tasks:

| Task | Removes |
| --- | --- |
| Cancel pending access package assignment requests | Anything not yet delivered |
| Remove all access package assignments | The elevated entitlement, so the private application |
| Revoke all refresh tokens for user | The ability to obtain a new token |
| Disable user account | The account, which drops it from every dynamic group, which SCIM then removes from AWS |

Note the chain in the last row. Nothing tells AWS to deprovision. The account is disabled, every dynamic rule requires `accountEnabled eq true`, membership is recomputed, and SCIM carries the removal across. Permission sets are assigned to groups, so losing the memberships is what actually ends AWS access.

## What to expect, and why it is worth measuring

Revoking refresh tokens does not invalidate an access token that has already been issued. An existing session can survive until that token expires, which is up to an hour by default. Signed-in AWS console and CLI sessions have their own lifetime on top of that.

So there are at least four different moments:

1. The entitlement is removed in Entra.
2. The group membership is removed in AWS.
3. No new token can be obtained.
4. Every existing session has actually stopped working.

A project that claims offboarding works and only shows (1) has not shown much. Measure each one separately and report the honest numbers, including the one that is slower than you would like. If continuous access evaluation is enabled in the tenant, say so, because it changes (4) substantially.

## Preconditions

1. **Phase 6 is complete and its footprint is still up.** The same target has to be reachable before the Leaver runs, or there is nothing to withdraw.
2. **The worker holds elevated access right now.** Confirm Grafana answers and the Administrator permission set is offered, immediately before starting.
3. **The Leaver is deployed and enabled.** It has been deployed but never run.
4. **`employeeLeaveDateTime` is set.** It is the workflow's trigger attribute. An on-demand run ignores it, but leaving it unset makes the definition incoherent with what you demonstrate.
5. **A second admin account is available.** You are about to disable an account; do not be signed in as it, and do not let it be the only account holding a role you need.

## Steps

### 1. Prove access exists

Capture, in this order and with timestamps:

- Grafana answering from the client.
- The AWS access portal showing the Administrator permission set.
- `./scripts/watch-identity-center-membership.sh --user <worker> --once`.

This is the baseline. Without it the removal evidence has nothing to remove from.

### 2. Start the AWS watch

In a second terminal, before running the workflow:

```bash
./scripts/watch-identity-center-membership.sh --user <worker> --until '' --timeout 3600
```

An empty `--until` waits for every membership to disappear. The Identity Store API exposes no enabled or disabled flag for a user, so losing the memberships is the observable signal, and it is also the one that matters.

### 3. Leave a session open

Before running the workflow, sign in on the client and leave a Grafana tab and an AWS console tab open, and note the time. These are the evidence for the existing-session question in step 6. Do not refresh them yet.

### 4. Run the Leaver

```bash
pwsh ./entra/lifecycle-workflows/run.ps1 \
  -WorkflowDisplayName 'CrossCloud Leaver' \
  -UserPrincipalName <worker> \
  -OutFile ./entra/lifecycle-workflows/local/phase-7-leaver-run.md
```

Run `-WhatIf` first. This is the one workflow in the project that disables an account, and an on-demand run applies every task to every named user regardless of the execution conditions. Read the user it resolved before you let it write.

### 5. Record the Entra side

From the run output: which task ran when, and how long each took. Then confirm in the portal that the access package assignments are gone and the account is disabled.

### 6. Record the session behaviour

Now go back to the tabs from step 3.

- Refresh Grafana through the tunnel. Note the time and whether it still answers.
- Refresh the AWS console. Note the same.
- If either still works, keep checking at intervals and record when it stops. That interval is the result, not a failure.
- Attempt a fresh sign-in as the worker; it should be refused outright.

Distinguish clearly between *cannot get new access* and *existing access has stopped*. They are different claims and only the first is immediate.

### 7. Record the AWS side

The watch from step 2 prints the moment the memberships disappear. Report the delay from the disable task completing, not from when the script started.

### 8. Tear down

Once the evidence is captured:

- `terraform destroy` the AWS footprint.
- Leave the Entra objects in place; they are the artifacts the repository describes and they cost nothing.
- Keep the disabled account rather than deleting it, so the evidence stays reproducible.

## Exit criteria

| # | Criterion | Evidence |
| --- | --- | --- |
| 1 | Access existed immediately before offboarding | Grafana `200`, permission set, AWS membership |
| 2 | The Leaver removes every entitlement | Task timings, package assignments gone, account disabled |
| 3 | AWS access ends without anything targeting AWS | Membership timings from the watch script |
| 4 | No new access can be obtained | Fresh sign-in refused |
| 5 | Existing-session behaviour is measured, not assumed | Timestamped refreshes, with the delay stated plainly |
| 6 | The footprint is destroyed | `terraform destroy` output |

Criterion 5 is the one worth being honest about. A reviewer who knows how token lifetimes work will look for it.

## Evidence to capture

Follow the existing naming: `docs/images/phase-7-NN-description.png`.

| Suggested | Shows |
| --- | --- |
| `phase-7-01-access-before.png` | Grafana and the permission set, before |
| `phase-7-02-leave-date-set.png` | `employeeLeaveDateTime` on the account |
| `phase-7-03-leaver-whatif.png` | The resolved user, before any write |
| `phase-7-04-leaver-run-timings.png` | `run.ps1` output |
| `phase-7-05-assignments-removed.png` | No access package assignments |
| `phase-7-06-account-disabled.png` | The disabled account |
| `phase-7-07-identity-center-membership-gone.png` | The watch script's timestamps |
| `phase-7-08-existing-session.png` | The open tab, refreshed, with the time visible |
| `phase-7-09-signin-refused.png` | A fresh sign-in failing |
| `phase-7-10-terraform-destroy.png` | Teardown |

## Afterwards

Update the root README so the phase table matches reality, and add an ADR if the session-lifetime result changed how you would build this.
