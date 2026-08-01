param location string
param prefix string
param vnetId string
param subnetId string
param tags object 

resource kv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: take('kv-${prefix}-${uniqueString(resourceGroup().id)}', 24)
  location: location
  tags: tags 
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true // Modern Best Practice
    networkAcls: { defaultAction: 'Deny', bypass: 'AzureServices' }
  }
}

//1.// Private Endpoint for Key Vault
resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-${kv.name}'
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: 'kvConnection'
        properties: { privateLinkServiceId: kv.id, groupIds: ['vault'] }
      }
    ]
  }
}

// 2. Private DNS Zone for Key Vault
resource kvDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
}

// 3. Link DNS Zone to the VNet
resource dnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: kvDnsZone
  name: 'link-to-spoke'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: vnetId }
  }
}

// 4. DNS A Record for the Private Endpoint
resource kvDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: kvPrivateEndpoint
  name: 'vault-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: { privateDnsZoneId: kvDnsZone.id }
      }
    ]
  }
}
