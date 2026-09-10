# Terraform roots, separated by lifecycle

Run Terraform from an explicit root. This directory is a container, not a root.

| Root | Owns | Lifetime |
| --- | --- | --- |
| [`identity/`](identity/) | IAM Identity Center permission sets and account assignments | Retained. Destroying it removes AWS administrative access. |
| `foundation/` | ECR images and reusable DNS/certificate resources | Retained between lab windows. Not implemented yet. |
| `lab/` | VPC, connector, internal ALB, NAT, ECS services, RDS | Created and destroyed per lab window. Not implemented yet. |

Each root keeps its own state, so destroying the lab cannot delete the login path. This implements the first Phase 1 item in the [roadmap](../docs/roadmap.md) and the separation recorded in [ADR-024](../decisions.md#adr-024-separate-terraform-roots-by-resource-lifecycle).

## Modules

- `modules/identity_center/` — called by the identity root.
- `modules/private_access/` — reference code from the previous combined footprint. **No active root calls it.** The lab root will replace its combined lifecycle rather than reuse it; see the roadmap's network section.

## State

State is local, per root, and gitignored. It is machine-local: switching Git branches does not move or restore it. The identity root's state lives at `identity/terraform.tfstate`.

A local backend suits a single-operator prototype only. Moving to a locking remote backend is a separate change, and its bootstrap must sit outside routine lab teardown.

## Identity root

```bash
aws sso login --profile cross-cloud-admin
terraform -chdir=terraform/identity init -input=false
terraform -chdir=terraform/identity plan -var=aws_profile=cross-cloud-admin
```

The profile is local AWS CLI configuration; its `sso_role_name` must match an assigned permission set. For a new installation, copy `identity/terraform.tfvars.example` to the ignored `identity/terraform.tfvars`. An existing installation must keep its current state rather than applying into a fresh one, which would attempt to create duplicate permission sets.
