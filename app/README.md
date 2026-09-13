# Grafana private target (historical)

This directory holds the Grafana image used for the Phase 4 and 5 Private Access tests. It isn't deployed. See [ADR-020](../decisions.md#adr-020-reuse-grafana-as-an-anonymous-private-target).

## Image

- Pinned `grafana/grafana-oss`.
- Anonymous viewer access; login form disabled.
- No secrets in the image or task definition.
- Adapted from the Grafana IAM lab without Caddy or the SCIM bridge.

Grafana performs no authentication. Private Access makes the access decision, so reaching the dashboard proves that Private Access allowed the session.

## Build and push

The target subnet had no internet route, so the image had to be in ECR before ECS could place a task. Pass the repository URL explicitly:

```bash
ECR_REPOSITORY_URL='<existing-ecr-repository-url>' ./build-and-push.sh
```

The script fails before it signs in if the variable is missing.
