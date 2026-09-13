# Historical private application target

This directory still contains the previous anonymous target, not the planned SSO/monitoring service. See the [roadmap](../docs/roadmap.md) and [ADR-023](../decisions.md#adr-023-build-an-aws-operations-lab-with-governed-workforce-access). Its image and Terraform are preserved for reference; the new API, RDS, and Grafana configuration are not implemented yet.

Grafana OSS, published through Microsoft Entra Private Access and reachable only
from the private network connector.

The image is a pinned `grafana/grafana-oss` with anonymous viewer access and the
login form disabled. Grafana performs no authentication of its own: the access
decision belongs to Private Access, and an assigned identity reaching the
dashboard is the evidence that it worked. Nothing secret is baked into the image
or the task definition.

Adapted from the Grafana IAM lab, minus Caddy and the SCIM bridge. Caddy exists
to obtain a public Let's Encrypt certificate, which a destination with no public
DNS record cannot do; the OIDC and SCIM layers are the duplicate scope ADR-016
removed from this project. See ADR-020.

## Previous deployment procedure

This procedure is historical. It read both the repository URL and the running
task's private address from the combined Terraform root, which no longer exists:
the [identity root](../terraform/README.md) owns retained access only, and the
lab root that will own images and tasks is not implemented yet.

The target subnet had no internet path, so the image had to be mirrored into the
project ECR repository before the ECS service could place a task. The helper now
takes that repository explicitly and fails before login if it is missing:

```bash
ECR_REPOSITORY_URL='<existing-ecr-repository-url>' ./build-and-push.sh
```

The running task's private address was then published as an IP application
segment. The planned replacement puts the service behind an internal ALB with a
stable private hostname, so there is no task IP to republish.
