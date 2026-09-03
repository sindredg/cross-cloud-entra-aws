# Worklogs

One entry per phase, or per work session inside a phase. An entry records what changed, what proved it, and what is still open. Stable instructions belong in the root README or in component documentation instead.

| Entry | Covers |
| --- | --- |
| [`phase-0-readiness.md`](phase-0-readiness.md) | Toolchain and repository readiness |
| [`phase-1-entra-aws-federation.md`](phase-1-entra-aws-federation.md) | SAML federation, SCIM provisioning, first federated access |
| [`phase-2-identity-lifecycle-joiner.md`](phase-2-identity-lifecycle-joiner.md) | Dynamic groups, Joiner workflow, baseline access, SCIM into AWS |
| [`phase-2-lifecycle-workflows-as-code.md`](phase-2-lifecycle-workflows-as-code.md) | Joiner, Mover, and Leaver deployed from Graph JSON |
| [`phase-3-terraform-identity-center.md`](phase-3-terraform-identity-center.md) | Terraform permission sets and account assignments |

## Naming

`phase-<number>-<short-topic>.md`. The prefix sorts the directory in phase order; dates go inside the entry. If a phase needs several entries, keep the prefix and use a more specific topic.

## Structure

Goal, implementation, validation, troubleshooting, next steps. Show the evidence inline where it belongs rather than collecting screenshots at the end, and say what a screenshot proves rather than restating what it shows.

## Safety

Worklogs are published. Redact tenant IDs, application IDs, object IDs, account IDs, SCIM endpoints, tokens, cookies, and personal email addresses. Screenshots that still contain any of those live in [`docs/images/redaction/`](../docs/images/redaction/) and are referenced from `docs/images/` by their final name, so a worklog link goes live the moment the redacted file lands.
