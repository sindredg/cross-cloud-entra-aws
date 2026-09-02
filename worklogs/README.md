# Worklogs

This directory is the chronological journal for **Cross-Cloud Identity with Microsoft Entra Suite and AWS**. Entries should explain what changed, why a choice was made, what was tested, and what remains uncertain. Stable instructions belong in the root README or component documentation instead.

## Naming

Use one focused Markdown file per phase or work session. Prefix the filename with the phase number from [`plan.md`](../plan.md) so the directory sorts in plan order. Keep dates inside the entry, not in the filename:

```text
phase-<number>-<short-topic>.md
```

Examples:

```text
phase-0-readiness.md
phase-1-entra-aws-federation.md
phase-4-aws-network.md
```

If a phase needs several entries, keep the same prefix and use a more specific topic, such as `phase-4-aws-network-egress.md`. Start the entry title with the same phase number.

## Entry template

```markdown
# Short descriptive title

**Date:** YYYY-MM-DD

## Goal

What this session intended to accomplish.

## Changes

What was created, changed, or removed.

## Validation

Commands, screenshots, observations, or test results that demonstrate the outcome.

## Decisions and tradeoffs

Why important choices were made and which alternatives were rejected.

## Next steps

What should happen next, including unresolved questions.
```

## Safety

Worklogs are published documentation. Redact tenant IDs, application IDs, object IDs, project IDs, account details, tokens, cookies, credentials, and secret values. Use descriptive placeholders where context is needed.

Add new entries to this directory; the root README can later link to major milestones without becoming a full chronological index.
