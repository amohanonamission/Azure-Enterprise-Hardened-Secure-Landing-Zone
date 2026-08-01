param hubVnetName string
param spokeVnetName string

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = { name: hubVnetName }
resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = { name: spokeVnetName }

resource hubToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  name: 'hub-to-spoke'
  parent: hubVnet
  properties: {
    remoteVirtualNetwork: { id: spokeVnet.id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

resource spokeToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  name: 'spoke-to-hub'
  parent: spokeVnet
  properties: {
    remoteVirtualNetwork: { id: hubVnet.id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}
