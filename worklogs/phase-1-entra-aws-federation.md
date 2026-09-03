# Phase 1: Entra federation and AWS access

**Date:** 2026-09-01

## Goal

Make Microsoft Entra ID the workforce identity source for AWS IAM Identity Center.

## Implementation

Switched the IAM Identity Center identity source to an external provider.

![IAM Identity Center identity source set to an external identity provider](../docs/images/phase-1-01-identity-source-external-idp.png)

Added the AWS IAM Identity Center gallery application and set the Name ID to the email-address format, sourced from `user.userprincipalname`. IAM Identity Center matches the SCIM `userName` against this value, so a mismatch here breaks sign-in after provisioning succeeds.

![SAML Name ID claim mapped to the Entra user principal name](../docs/images/phase-1-02-saml-nameid-claim.png)

Exchanged metadata in both directions: the AWS service provider metadata into Entra, the Entra federation metadata into AWS.

![AWS confirms that the external identity provider is active](../docs/images/phase-1-03-saml-trust-established.png)

Enabled automatic provisioning in AWS. The endpoint and token are shown once and were not retained in the repository.

![AWS issues the SCIM endpoint and a one-time access token](../docs/images/phase-1-04-scim-endpoint-and-token.png)

![Entra confirms a successful SCIM connection to AWS IAM Identity Center](../docs/images/phase-1-05-scim-connection.png)

Deployed the `AWS-Administrators` security group through Microsoft Graph Bicep. Membership requires an enabled member account with department `Cloud Platform` and job title `Cloud Administrator`.

![az deployment group create applies the Graph Bicep group template](../docs/images/phase-1-06-bicep-group-deploy.png)

![Dynamic membership conditions for the AWS administrators group](../docs/images/phase-1-07-dynamic-admin-rule.png)

Assigned the group to the enterprise application and scoped provisioning to assigned identities only.

![AWS administrators group assigned to the enterprise application](../docs/images/phase-1-08-enterprise-app-assignment.png)

## Validation

The provisioning service created the group and its member in AWS, and IAM Identity Center reports both as SCIM-owned.

![Provisioning log showing the group and user created in AWSSingleSignon](../docs/images/phase-1-09-scim-provisioning-log.png)

![IAM Identity Center lists the user with source SCIM](../docs/images/phase-1-10-identity-center-users-scim.png)

Created the `CrossCloud-Administrators` permission set with `AdministratorAccess` and a one-hour session, then assigned it to the group on the project account. Phase 3 replaced this permission set with a Terraform-managed one.

![AWS administrator permission set configuration](../docs/images/phase-1-11-permission-set.png)

The access portal shows the assigned account after Entra authentication, and `aws sso login` completes browser authorization for the `cross-cloud-admin` profile.

![AWS access portal listing the assigned account after Entra authentication](../docs/images/phase-1-12-access-portal-account.png)

![AWS confirms successful CLI SSO authorization](../docs/images/phase-1-13-cli-sso-success.png)

## Troubleshooting

The first SSO test failed with `AADSTS50105`. The user authenticated to Entra but was not assigned to the enterprise application, and the application blocks unassigned users by default.

![Entra blocks the sign-in because the user is not assigned to the application](../docs/images/phase-1-14-app-assignment-blocked.png)

Assigning the dynamic group fixed it. Turning off assignment enforcement would also have cleared the error, but that would let every tenant identity reach the AWS application, so the group assignment was the correct fix.

## Next steps

Implement the synthetic Joiner identity, automatic baseline entitlement, and Joiner Lifecycle Workflow.
