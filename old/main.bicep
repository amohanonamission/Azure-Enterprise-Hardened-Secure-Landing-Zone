// AMPT-prod Secure Landing Zone - Infrastructure as Code

targetScope = 'subscription' // This allows us to create the Resource Group

param rgName string 
param location string 
param prefix string 
param tags object  // Parameters provided by parameters.json, ensuring consistency and ease of updates

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${rgName}-Enterprise-Security'
  location: location
  tags: tags
}

module security './modules/security-center.bicep' = {
  name: 'securityDeploy'
  scope: rg
  params: { location: location, prefix: prefix, tags: tags }
}

module network './modules/vnet-hub-spoke.bicep' = {
  name: 'networkDeploy'
  scope: rg
  params: { 
    location: location 
    prefix: prefix 
    tags: tags 
  }
}

module compute './modules/hardened-compute.bicep' = {
  name: 'computeDeploy'
  scope: rg
  params: { 
    location: location 
    vmName: 'SRV-PROD-SEC-01'
    subnetId: network.outputs.spokeSubnetId
    lawId: security.outputs.lawId
    tags: tags
  }
}

module vault './modules/key-vault.bicep' = {
  name: 'vaultDeploy'
  scope: rg
  params: {
    location: location
    tags: tags
    prefix: prefix
    vnetId: network.outputs.spokeSubnetId // Used for PE association logic
    subnetId: network.outputs.spokeSubnetId
  }
}
