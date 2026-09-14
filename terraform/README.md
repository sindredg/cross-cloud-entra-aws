# Terraform

Run Terraform from an explicit root. The `terraform/` directory holds roots and modules; it isn't a root itself.

| Root | Owns | Lifetime |
| --- | --- | --- |
| [`identity/`](identity/) | IAM Identity Center permission sets and account assignments | Retained. Destroying it removes AWS administrative access. |

The identity root has its own state, so no other teardown can delete the AWS sign-in path. See [ADR-024](../decisions.md#adr-024-separate-the-identity-terraform-root).

## Modules

| Module | Used by |
| --- | --- |
| `modules/identity_center/` | Identity root |
| `modules/private_access/` | Phase 4 private target: VPC, connector, and Grafana on Fargate |

## State

- State is local, per root, and ignored by Git.
- State is machine-local. Switching branches doesn't move it.
- The identity state is at `identity/terraform.tfstate`.

## Run the identity root

1. Sign in:

   ```bash
   aws sso login --profile cross-cloud-admin
   ```

1. Initialize and plan:

   ```bash
   terraform -chdir=terraform/identity init -input=false
   terraform -chdir=terraform/identity plan -var=aws_profile=cross-cloud-admin
   ```

The profile's `sso_role_name` must match an assigned permission set.

For a new installation, copy `identity/terraform.tfvars.example` to `identity/terraform.tfvars`. For an existing installation, keep the current state. Applying into empty state tries to create duplicate permission sets.
