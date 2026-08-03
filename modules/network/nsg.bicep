// modules/network/nsg.bicep

param location string
param prefix string
param tags object
param lawId string

// 1. Deploy the Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'nsg-${prefix}-spoke-001'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork' // Only allow internal routing
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Deny-All-Inbound'
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
      // Note: Outbound internet is handled by the Route Table (UDR) sending traffic to the Firewall
    ]
  }
}

// 2. The CISA Edit: Diagnostic Settings (Audit Trail)
resource nsgDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-nsg'
  scope: nsg
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'NetworkSecurityGroupEvent' // Logs when a rule is added/modified
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter' // Logs how many times a rule is hit
        enabled: true
      }
    ]
  }
}

// Output the ID to attach to the Spoke subnets
output nsgId string = nsg.id

