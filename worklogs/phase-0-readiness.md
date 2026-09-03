# Phase 0: Project readiness

**Date:** 2026-09-01

## Goal

Remove superseded infrastructure, confirm the local toolchain, and identify the remaining prerequisites before any workload infrastructure is provisioned.

## Changes

- Removed the superseded Google Cloud Terraform directory, per ADR-013. The files moved to a dated recovery directory outside the repository. No AWS or Entra resources were touched.
- Replaced the obsolete Terraform validation workflow with a provider-neutral secret-scanning workflow.
- Added a proportional security-review rule and ADR-014.

## Validation

Toolchain as installed on the working WSL environment:

| Component | Result |
| --- | --- |
| Git | 2.43.0 |
| Terraform | 1.15.8 |
| AWS CLI | 2.36.34 |
| Docker | 29.1.3; daemon reachable |
| Azure CLI | 2.88.0 |
| Bicep | Installed through Azure CLI |
| PowerShell 7 | Installed on Windows; Graph modules added in Phase 2 |
| Workstation architecture | Linux ARM64 (`aarch64`) |

No credentials, tenant IDs, account IDs, or secret values were read or recorded.

## Decisions and tradeoffs

- Phase 3 pins the Terraform version once the AWS configuration exists. Phase 0 records the installed version without coupling it to a deleted workflow.
- Secret scanning stays active even while Terraform validation is absent.
- ARM64 is the natural Fargate default because it matches the workstation, but Phase 6 records that choice separately before the first image build.

## Next steps

Remaining prerequisites moved to the phases that need them: the Entra trial expiry date and least-privileged role assignments stay open, DNS and certificates moved to Phase 7, and the Windows 11 test device moved to Phase 9.
