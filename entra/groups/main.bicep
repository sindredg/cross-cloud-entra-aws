extension microsoftGraphV1

@description('Display name of the AWS administrator group.')
param groupDisplayName string = 'AWS-Administrators'

@description('Immutable identifier used by Microsoft Graph Bicep.')
param groupUniqueName string = 'crossCloudAwsAdministrators'

@description('Department required for membership.')
param requiredDepartment string = 'Cloud Platform'

@description('Job title required for membership.')
param requiredJobTitle string = 'Cloud Administrator'

resource awsAdministrators 'Microsoft.Graph/groups@v1.0' = {
  displayName: groupDisplayName
  description: 'Identities eligible for AWS administrator access.'
  uniqueName: groupUniqueName
  mailEnabled: false
  mailNickname: 'aws-administrators'
  securityEnabled: true
  groupTypes: [
    'DynamicMembership'
  ]
  membershipRule: '(user.accountEnabled -eq true) and (user.userType -eq "Member") and (user.department -eq "${requiredDepartment}") and (user.jobTitle -eq "${requiredJobTitle}")'
  membershipRuleProcessingState: 'On'
}

output groupDisplayName string = awsAdministrators.displayName
output groupId string = awsAdministrators.id
