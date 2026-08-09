// modules/network/bastion.bicep

param location string
param prefix string
param tags object
param hubVnetName string
param lawId string

// Reference the existing Hub VNet
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: hubVnetName
}

// Reference the AzureBastionSubnet explicitly by NAME
resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: 'AzureBastionSubnet'
  parent: hubVnet
}

// 1. Bastion Public IP (Required for the Bastion service itself, not your VMs)
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

// 2. Azure Bastion Host
resource bastionHost 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: 'bas-${prefix}-hub-001'
  location: location
  tags: tags
  sku: {
    name: 'Basic' // 'Basic' is sufficient for the lab. Enterprise uses 'Standard' for native client support.
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: bastionSubnet.id // Explicitly using the named subnet ID
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

// 3. The CISA Edit: Diagnostic Settings (Audit Trail for SSH/RDP sessions)
resource bastionDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-bastion'
  scope: bastionHost
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'BastionAuditLogs' // Critical for SOC teams tracking admin access
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
