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

The target subnet has no internet path, so the image must be mirrored into the
project ECR repository before the ECS service can place a task:

```bash
./build-and-push.sh
```

Then read the running task's private address and publish it as the application
segment:

```bash
terraform -chdir=../terraform output -raw private_access_application_segment_lookup
```
