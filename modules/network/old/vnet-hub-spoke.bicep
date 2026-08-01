// AMPT-prod Secure Landing Zone - Infrastructure as Code
// Architecture: Hub & Spoke with Azure Bastion

param location string = resourceGroup().location
param prefix string = 'AMPT2026-Bicep'
param tags object 

// ==========================================
// 1. HUB NETWORK (Management & Security)
// ==========================================

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-${prefix}-hub-001'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16' // Distinct address space to prevent overlap
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet' // Mandatory exact name
        properties: {
          addressPrefix: '10.1.1.0/26' // Must be at least /26 for Bastion
        }
      }
    ]
  }
}

// Bastion Public IP (Required for Bastion Host)
resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-${prefix}-bastion-001'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Azure Bastion Host (For secure SSH/RDP without Public IPs)
resource bastionHost 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: 'bas-${prefix}-hub-001'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: hubVnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

// ==========================================
// 2. SPOKE NETWORK + NSG + UDR
// ==========================================

// Route Table (The UDR)
resource routeTable 'Microsoft.Network/routeTables@2023-05-01' = {
  name: 'rt-${prefix}-spoke-egress-001'
  location: location
  tags: tags
  properties: {
    routes: [
      {
        name: 'ForceTrafficToHub'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance' 
          nextHopIpAddress: '10.1.0.4' // Placeholder for Firewall/NVA IP
        }
      }
    ]
  }
}

// Network Security Group (NSG) for Web Subnet
resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'nsg-${prefix}-web-001'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPSInbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Spoke Virtual Network 

resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-${prefix}-prod-001'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16' // Your production address space
      ]
    }
    subnets: [
      {
        name: 'snet-web-001'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsgWeb.id // Public HTTPS access
          }
        }
      }
      {
        name: 'snet-vm-001'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: { id: nsgWeb.id }
          routeTable: { id: routeTable.id } // UDR Attached here
        }
      }
    ]
  }
}

// ==========================================
// 3. PEERINGS
// ==========================================

resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  name: 'hub-to-spoke'
  parent: hubVnet
  properties: {
    remoteVirtualNetwork: {
      id: spokeVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

// Peer Spoke to Hub
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  name: 'spoke-to-hub'
  parent: spokeVnet
  properties: {
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

// ==========================================
// 4. OUTPUTS (For main.bicep and further deployment)
// ==========================================

output spokeSubnetId string = spokeVnet.properties.subnets[0].id
output spokeVnetId string = spokeVnet.id
output vmSubnetId string = spokeVnet.properties.subnets[1].id
