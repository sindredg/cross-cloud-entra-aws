extension microsoftGraphV1

@minLength(1)
@description('Display name shown in Microsoft Entra ID.')
param displayName string

@minLength(1)
@description('Purpose of the group.')
param groupDescription string

@minLength(1)
@description('Immutable alternate key used for repeatable Microsoft Graph deployments.')
param uniqueName string

@minLength(1)
@description('Mail nickname required by Microsoft Graph, even when mail is disabled.')
param mailNickname string

resource assignedGroup 'Microsoft.Graph/groups@v1.0' = {
  displayName: displayName
  description: groupDescription
  uniqueName: uniqueName
  mailEnabled: false
  mailNickname: mailNickname
  securityEnabled: true
}

output displayName string = assignedGroup.displayName
