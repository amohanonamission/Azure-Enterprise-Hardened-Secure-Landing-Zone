// modules/network/spoke-vnet.bicep

param location string
param prefix string
param tags object
param lawId string
param nsgId string // Passed from the NSG module

// Static IP for the Azure Firewall (Avoids circular dependency)
param firewallPrivateIp string = '10.1.2.4' 

// 1. User-Defined Route (UDR) - Forced Tunneling
resource routeTable 'Microsoft.Network/routeTables@2023-05-01' = {
  name: 'rt-${prefix}-spoke-egress-001'
  location: location
  tags: tags
  properties: {
    routes: [
      {
        name: 'ForceInternetToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0' // All traffic
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp // Sent to the Hub Firewall
        }
      }
    ]
  }
}

// 2. Deploy the Spoke Virtual Network
resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-${prefix}-spoke-001'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16' // Spoke Address Space
      ]
    }
    subnets: [
      {
        name: 'snet-web-001'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: { id: nsgId } // Layer 4 Security
          routeTable: { id: routeTable.id }   // Layer 7 Routing
        }
      }
      {
        name: 'snet-data-001'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: { id: nsgId } // Layer 4 Security
          routeTable: { id: routeTable.id }   // Layer 7 Routing
        }
      }
    ]
  }
}

// 3. The CISA Edit: Diagnostic Settings (Audit Trail)
resource spokeVnetDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-spoke-vnet'
  scope: spokeVnet
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

// Outputs required for Peering, Key Vault, and Compute deployments
output spokeVnetName string = spokeVnet.name
output spokeVnetId string = spokeVnet.id
output webSubnetId string = spokeVnet.properties.subnets[0].id
output dataSubnetId string = spokeVnet.properties.subnets[1].id

