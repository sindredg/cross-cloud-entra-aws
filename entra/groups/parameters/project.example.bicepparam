using '../main.bicep'

param groups = [
  {
    displayName: 'AWS-Administrators'
    description: 'Identities eligible for AWS administrator access.'
    uniqueName: 'crossCloudAwsAdministrators'
    mailNickname: 'aws-administrators'
    membershipRule: '(user.accountEnabled -eq true) and (user.userType -eq "Member") and (user.department -eq "Cloud Platform") and (user.jobTitle -eq "Cloud Administrator")'
  }
  {
    displayName: 'CrossCloud-Workforce'
    description: 'Enabled synthetic workforce identities in the cross-cloud project.'
    uniqueName: 'crossCloudProjectWorkforce'
    mailNickname: 'crosscloud-workforce'
    membershipRule: '(user.accountEnabled -eq true) and (user.userType -eq "Member") and (user.companyName -eq "CrossCloud Identity Project")'
  }
  {
    displayName: 'AWS-Developers'
    description: 'Cross-cloud engineers eligible for AWS developer access.'
    uniqueName: 'crossCloudAwsDevelopers'
    mailNickname: 'aws-developers'
    membershipRule: '(user.accountEnabled -eq true) and (user.userType -eq "Member") and (user.companyName -eq "CrossCloud Identity Project") and (user.department -eq "Cloud Platform") and (user.jobTitle -eq "Cloud Engineer")'
  }
  {
    displayName: 'AWS-Auditors'
    description: 'Cross-cloud security analysts eligible for read-only AWS access.'
    uniqueName: 'crossCloudAwsAuditors'
    mailNickname: 'aws-auditors'
    membershipRule: '(user.accountEnabled -eq true) and (user.userType -eq "Member") and (user.companyName -eq "CrossCloud Identity Project") and (user.department -eq "Security") and (user.jobTitle -eq "Security Analyst")'
  }
]
