# Phase 0 project readiness

**Date:** 2026-09-01

## Goal

Start project implementation by removing superseded infrastructure, confirming the local toolchain, and identifying the remaining prerequisites before any workload infrastructure is provisioned.

## Changes

- Confirmed the repository name is `entra+aws`.
- Removed the superseded Google Cloud Terraform directory from the repository.
- Replaced the obsolete Terraform validation workflow with a provider-neutral secret-scanning workflow.
- Standardized repository documentation on the term "project."
- Added a proportional security-review rule and ADR-014.
- Updated the prerequisite checker to detect Bicep through Azure CLI.

The removed Google Cloud files and workflow were moved to a dated recovery directory outside the repository. No AWS or Microsoft Entra resources were changed.

## Validation

The first local prerequisite check reported:

| Component | Result |
| --- | --- |
| Git | 2.43.0 |
| Terraform | 1.15.8 |
| AWS CLI | 2.36.34 |
| Docker | 29.1.3; daemon reachable |
| Azure CLI | 2.88.0 |
| Bicep | Not installed |
| PowerShell 7 | Not installed in the working WSL environment |
| `jq` | Not installed; optional |
| Workstation architecture | Linux ARM64 (`aarch64`) |

The check correctly remains unsuccessful because two required tools are missing. No credentials, tenant IDs, account IDs, or secret values were read or recorded.

## Decisions and tradeoffs

- Phase 3 will pin the Terraform version after the AWS configuration is introduced. Phase 0 records the installed version without coupling it to a deleted workflow.
- Secret scanning remains active even though Terraform validation is temporarily absent.
- ARM64 is the natural Fargate default because it matches the workstation, but the project records that choice separately before building an image.

## Next steps

1. Install Bicep through Azure CLI.
2. Install PowerShell 7 in the working WSL environment.
3. Decide whether to install optional `jq`.
4. Rerun `./scripts/check-prereqs.sh` and record the result.
5. Continue the remaining Phase 0 account, licence, naming, certificate, and device checks.
