type dynamicGroupConfiguration = {
  displayName: string
  description: string
  uniqueName: string
  mailNickname: string
  membershipRule: string
}

@description('Dynamic security groups managed by this deployment.')
param groups dynamicGroupConfiguration[]

module dynamicGroups './modules/dynamic-group.bicep' = [for group in groups: {
  name: 'dynamic-group-${uniqueString(group.uniqueName)}'
  params: {
    displayName: group.displayName
    groupDescription: group.description
    uniqueName: group.uniqueName
    mailNickname: group.mailNickname
    membershipRule: group.membershipRule
  }
}]

output groupDisplayNames array = [for (group, index) in groups: dynamicGroups[index].outputs.displayName]
