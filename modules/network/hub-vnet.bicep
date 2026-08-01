// modules/network/hub-vnet.bicep

param location string
param prefix string
param tags object
param lawId string

// 1. Deploy the Hub Virtual Network
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-${prefix}-hub-001'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16' // Hub Address Space
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet' // Mandatory exact name
        properties: {
          addressPrefix: '10.1.1.0/26' // /26 is required for Bastion
        }
      }
      {
        name: 'AzureFirewallSubnet' // Mandatory exact name
        properties: {
          addressPrefix: '10.1.2.0/26' // /26 is required for Firewall
        }
      }
    ]
  }
}

// 2. The CISA Edit: Diagnostic Settings (Audit Trail)
resource hubVnetDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-hub-vnet'
  scope: hubVnet
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'VMProtectionAlerts'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Outputs required for Peering and Firewall deployment
output hubVnetName string = hubVnet.name
output hubVnetId string = hubVnet.id
