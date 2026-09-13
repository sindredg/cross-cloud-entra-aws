# Phase 0: Project readiness

**Date:** 2026-09-01

**Goal:** Remove superseded infrastructure and confirm the local toolchain before provisioning anything.

## Changes

- Removed the Google Cloud Terraform draft ([ADR-013](../decisions.md#adr-013-remove-the-google-cloud-draft)). No AWS or Entra resources changed.
- Replaced the Terraform validation workflow with a secret-scanning workflow.
- Added a proportionate security review rule ([ADR-014](../decisions.md#adr-014-evaluate-security-controls-proportionately)).

## Toolchain

| Component | Version |
| --- | --- |
| Git | 2.43.0 |
| Terraform | 1.15.8 |
| AWS CLI | 2.36.34 |
| Docker | 29.1.3; daemon reachable |
| Azure CLI | 2.88.0 |
| Bicep | Installed through Azure CLI |
| PowerShell 7 | Installed on Windows; Graph modules added in Phase 2 |
| Workstation | Linux ARM64 (`aarch64`) |
