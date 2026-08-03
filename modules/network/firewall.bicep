// modules/network/firewall.bicep

param location string
param prefix string
param tags object
param lawId string
param hubVnetName string

// Reference the Hub VNet to attach the Firewall to its specific subnet
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: hubVnetName
}

// 1. Public IP for the Firewall
resource fwPip 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-${prefix}-fw-001'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// 2. The Azure Firewall (Layer 7)
resource firewall 'Microsoft.Network/azureFirewalls@2023-05-01' = {
  name: 'fw-${prefix}-hub-001'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    ipConfigurations: [
      {
        name: 'fwIpConfig'
        properties: {
          subnet: {
            id: hubVnet.properties.subnets[1].id // Assumes AzureFirewallSubnet is index 1
          }
          publicIPAddress: {
            id: fwPip.id
          }
        }
      }
    ]
    // The Financial Grade Edit: FQDN Filtering
    applicationRuleCollections: [
      {
        name: 'Allow-Approved-Outbound'
        properties: {
          priority: 100
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'Allow-Updates-And-DevOps'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              sourceAddresses: [
                '10.0.0.0/16' // Spoke VNet Address Space
              ]
              targetFqdns: [
                '*.github.com'
                '*.microsoft.com'
                '*.azure.com'
              ]
            }
          ]
        }
      }
    ]
  }
}

// 3. The CISA Edit: Diagnostic Settings (Audit Trail)
resource fwDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-firewall'
  scope: firewall
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
      }
      {
        category: 'AzureFirewallNetworkRule'
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

// Output the private IP (Expected to be 10.1.2.4 by default Azure allocation)
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress

