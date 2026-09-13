# Phase 1: Entra federation and AWS access

**Date:** 2026-09-01

**Goal:** Make Microsoft Entra ID the workforce identity source for AWS IAM Identity Center.

```mermaid
flowchart LR
    Group["AWS-Administrators<br/>dynamic group"] --> App["Enterprise app<br/>assigned users only"]
    App -->|"SAML sign-in"| IC["IAM Identity Center"]
    App -->|"SCIM users + groups"| IC
    IC --> PS["Permission set"] --> Account["AWS account"]
```

## Steps

1. Set the IAM Identity Center identity source to an external provider.

   ![IAM Identity Center identity source set to an external identity provider](../docs/images/phase-1-01-identity-source-external-idp.png)

1. Add the AWS IAM Identity Center gallery app. Set Name ID to email format from `user.userprincipalname`.

   > **Important:** Identity Center matches the SCIM `userName` against Name ID. A mismatch breaks sign-in even when provisioning succeeds.

   ![SAML Name ID claim mapped to the Entra user principal name](../docs/images/phase-1-02-saml-nameid-claim.png)

1. Exchange SAML metadata in both directions.

   ![AWS confirms that the external identity provider is active](../docs/images/phase-1-03-saml-trust-established.png)

1. Enable automatic provisioning in AWS. The SCIM endpoint and token are shown once and aren't stored in the repository.

   ![AWS issues the SCIM endpoint and a one-time access token](../docs/images/phase-1-04-scim-endpoint-and-token.png)

   ![Entra confirms a successful SCIM connection to AWS IAM Identity Center](../docs/images/phase-1-05-scim-connection.png)

1. Deploy `AWS-Administrators` with Graph Bicep. Membership rule: enabled member, department `Cloud Platform`, job title `Cloud Administrator`.

   ![az deployment group create applies the Graph Bicep group template](../docs/images/phase-1-06-bicep-group-deploy.png)

   ![Dynamic membership conditions for the AWS administrators group](../docs/images/phase-1-07-dynamic-admin-rule.png)

1. Assign the group to the enterprise app. Scope provisioning to assigned identities.

   ![AWS administrators group assigned to the enterprise application](../docs/images/phase-1-08-enterprise-app-assignment.png)

## Validation

SCIM created the group and user in AWS. Identity Center shows both as SCIM-owned.

![Provisioning log showing the group and user created in AWSSingleSignon](../docs/images/phase-1-09-scim-provisioning-log.png)

![IAM Identity Center lists the user with source SCIM](../docs/images/phase-1-10-identity-center-users-scim.png)

The `CrossCloud-Administrators` permission set (`AdministratorAccess`, one-hour session) was assigned to the group. Phase 3 replaced it with a Terraform-managed permission set.

![AWS administrator permission set configuration](../docs/images/phase-1-11-permission-set.png)

The access portal and `aws sso login` both work through Entra.

![AWS access portal listing the assigned account after Entra authentication](../docs/images/phase-1-12-access-portal-account.png)

![AWS confirms successful CLI SSO authorization](../docs/images/phase-1-13-cli-sso-success.png)

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `AADSTS50105` on first sign-in | User not assigned to the enterprise app | Assign the dynamic group |

![Entra blocks the sign-in because the user is not assigned to the application](../docs/images/phase-1-14-app-assignment-blocked.png)

Turning off assignment enforcement also clears the error, but it lets every tenant identity reach AWS.
