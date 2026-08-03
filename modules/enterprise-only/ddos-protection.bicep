// modules/enterprise-only/ddos-protection.bicep
// WARNING: Do not execute in personal labs. Base cost is ~$2,944/month.

param location string
param prefix string
param tags object

resource ddosPlan 'Microsoft.Network/ddosProtectionPlans@2023-05-01' = {
  name: 'ddos-${prefix}-hub-001'
  location: location
  tags: tags
}

output ddosPlanId string = ddosPlan.id
