type dynamicGroupConfiguration = {
  displayName: string
  description: string
  uniqueName: string
  mailNickname: string
  membershipRule: string
}

type assignedGroupConfiguration = {
  displayName: string
  description: string
  uniqueName: string
  mailNickname: string
}

@description('Dynamic security groups managed by this deployment.')
param groups dynamicGroupConfiguration[]

@description('Assigned security groups whose membership an access package owns.')
param assignedGroups assignedGroupConfiguration[] = []

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

module assignedGroupResources './modules/assigned-group.bicep' = [for group in assignedGroups: {
  name: 'assigned-group-${uniqueString(group.uniqueName)}'
  params: {
    displayName: group.displayName
    groupDescription: group.description
    uniqueName: group.uniqueName
    mailNickname: group.mailNickname
  }
}]

output groupDisplayNames array = [for (group, index) in groups: dynamicGroups[index].outputs.displayName]

output assignedGroupDisplayNames array = [for (group, index) in assignedGroups: assignedGroupResources[index].outputs.displayName]
