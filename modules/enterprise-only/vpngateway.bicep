// modules/enterprise-only/vpngateway.bicep
// WARNING: Takes 45 minutes to deploy. Costs ~$130/month.

param location string
param prefix string
param tags object
param hubVnetName string
param lawId string

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: hubVnetName
}

// VPN requires its own Public IP
resource vgwPip 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-${prefix}-vgw-001'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

// The Virtual Network Gateway (Route-Based VPN)
resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-05-01' = {
  name: 'vgw-${prefix}-hub-001'
  location: location
  tags: tags
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
    sku: {
      name: 'VpnGw1' // Standard Enterprise Tier 1
      tier: 'VpnGw1'
    }
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: hubVnet.properties.subnets[2].id // Assumes GatewaySubnet is index 2
          }
          publicIPAddress: {
            id: vgwPip.id
          }
        }
      }
    ]
  }
}

// CISA Edit: Log all IKE IPsec tunnel drops/connections
resource vgwDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-vgw'
  scope: vpnGateway
  properties: {
    workspaceId: lawId
    logs: [
      { category: 'GatewayDiagnosticLog', enabled: true }
      { category: 'TunnelDiagnosticLog', enabled: true } // Crucial for troubleshooting IPsec drops
    ]
  }
}
