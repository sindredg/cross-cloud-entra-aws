# Worklogs

This directory is the chronological journal for **Cross-Cloud Identity with Microsoft Entra Suite and AWS**. Entries should explain what changed, why a choice was made, what was tested, and what remains uncertain. Stable instructions belong in the root README or component documentation instead.

## Naming

Use one focused Markdown file per meaningful phase or work session. Keep dates inside the entry, not in the filename:

```text
short-topic.md
```

If several entries are written on the same date, add a sequence or a more specific topic. Examples:

```text
terraform-foundation.md
oidc-app-registration.md
oidc-login-validation.md
```

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
