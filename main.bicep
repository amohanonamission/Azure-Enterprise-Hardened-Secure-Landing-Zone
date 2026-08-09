// main.bicep
targetScope = 'subscription' // Allows us to create the Resource Group natively

// ==========================================
// PARAMETERS
// ==========================================
param rgName string = 'AMPT-Enterprise-Security'
param location string = 'southindia'
param prefix string = 'AMPT'
param tags object = {
  Environment: 'Production'
  CostCenter: 'SecOps-2026'
  Owner: 'Arnav Mohan'
  Compliance: 'CISA-Level-2'
}

@secure()
@description('Administrator username for the Spoke VMs')
param adminUsername string

@secure()
@description('Administrator password for the Spoke VMs. Must meet Azure complexity requirements.')
param adminPassword string

// ==========================================
// 1. RESOURCE GROUP
// ==========================================
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
  tags: tags
}

// ==========================================
// 2. GOVERNANCE & OBSERVABILITY (The Cameras & Guardrails)
// ==========================================

// Deploys the Log Analytics Workspace first
module law './modules/security/law.bicep' = {
  name: 'lawDeploy'
  scope: rg
  params: {
    location: location
    prefix: prefix
    tags: tags
  }
}

// Deploys Azure Policies to block Public IPs and enforce location/tags
module policies './modules/governance/policies.bicep' = {
  name: 'policyDeploy'
  scope: rg
  params: {
    prefix: prefix
    allowedLocation: location
  }
}

// ==========================================
// 3. NETWORK SECURITY & PERIMETER (Layer 4)
// ==========================================

// Deploys the Network Security Group
module nsg './modules/network/nsg.bicep' = {
  name: 'nsgDeploy'
  scope: rg
  params: {
    location: location
    prefix: prefix
    tags: tags
    lawId: law.outputs.lawId // Implicit dependency: Waits for LAW to deploy
  }
}

// ==========================================
// 4. THE CORE MESH (Hub & Spoke VNets)
// ==========================================

module hub './modules/network/hub-vnet.bicep' = {
  name: 'hubDeploy'
  scope: rg
  dependsOn: [
    law // Forces Hub to wait until LAW exists
  ]
  params: {
    location: location
    prefix: prefix
    tags: tags
    lawId: law.outputs.lawId
  }
}

module spoke './modules/network/spoke-vnet.bicep' = {
  name: 'spokeDeploy'
  scope: rg
  dependsOn: [
    law // Forces Hub to wait until LAW exists
  ]
  params: {
    location: location
    prefix: prefix
    tags: tags
    lawId: law.outputs.lawId
    nsgId: nsg.outputs.nsgId // Implicit dependency: Waits for NSG to deploy
  }
}

// Bridges the Hub and Spoke
module peering './modules/network/vnet-peering.bicep' = {
  name: 'peeringDeploy'
  scope: rg
  params: {
    hubVnetName: hub.outputs.hubVnetName
    spokeVnetName: spoke.outputs.spokeVnetName
  }
}

// Deploys Azure Bastion for secure remote access
module bastion './modules/network/bastion.bicep' = {
  name: 'bastionDeploy'
  scope: rg
  params: {
    location: location
    prefix: prefix
    tags: tags
    lawId: law.outputs.lawId
    hubVnetName: hub.outputs.hubVnetName
  }
}

// ==========================================
// 5. LAYER 7 SECURITY (Azure Firewall)
// ==========================================

// Deploys the Firewall into the Hub
module firewall './modules/network/firewall.bicep' = {
  name: 'firewallDeploy'
  scope: rg
  params: {
    location: location
    prefix: prefix
    tags: tags
    lawId: law.outputs.lawId
    hubVnetName: hub.outputs.hubVnetName // Implicit dependency: Waits for Hub VNet
  }
  dependsOn: [
    spoke
    law
    peering // Best practice: Ensure peering is established before Firewall spins up
  ]
}

// ==========================================
// 6. WORKLOADS (Compute)
// ==========================================

module compute './modules/compute/compute.bicep' = {
  name: 'computeDeploy'
  scope: rg
  dependsOn: [
    spoke
    law
  ]
  params: {
    location: location
    prefix: prefix
    tags: tags
    lawId: law.outputs.lawId
    webSubnetId: spoke.outputs.webSubnetId
    dataSubnetId: spoke.outputs.dataSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// ==========================================
// 7. SECRETS MANAGEMENT (Key Vault)
// ==========================================

module vault './modules/security/key-vault.bicep' = {
  name: 'vaultDeploy'
  scope: rg
  dependsOn: [
    spoke
    law
  ]
  params: {
    location: location
    prefix: prefix
    tags: tags
    lawId: law.outputs.lawId
    spokeVnetId: spoke.outputs.spokeVnetId
    dataSubnetId: spoke.outputs.dataSubnetId
    webVmPrincipalId: compute.outputs.webVmPrincipalId   // Implicit dependency: Waits for Compute
    dataVmPrincipalId: compute.outputs.dataVmPrincipalId // Implicit dependency: Waits for Compute
  }
}
