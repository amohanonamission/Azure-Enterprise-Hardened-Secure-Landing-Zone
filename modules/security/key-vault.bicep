// modules/security/keyvault.bicep

param location string
param prefix string
param tags object
param lawId string
param spokeVnetId string
param dataSubnetId string

// Passed in from the compute module
param webVmPrincipalId string
param dataVmPrincipalId string

// Azure Built-in Role ID for "Key Vault Secrets User"
var keyVaultSecretsUserRole = '4633458b-17de-408a-b874-0445c86b69e6'

// ==========================================
// 1. THE VAULT (Zero-Trust Configuration)
// ==========================================

resource kv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: take('kv-${prefix}-${uniqueString(resourceGroup().id)}', 24) // KV names must be globally unique and <= 24 chars
  location: location
  tags: tags 
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true // Modern Best Practice: Replaces legacy Access Policies
    enableSoftDelete: true
    enablePurgeProtection: true // The CISA Edit: Prevents rogue admins from permanently deleting secrets
    networkAcls: { 
      defaultAction: 'Deny' // Drops all public internet traffic
      bypass: 'AzureServices' 
    }
  }
}

// ==========================================
// 2. PRIVATE LINK (Data Plane Isolation)
// ==========================================

// Drop a Private NIC into the Data Subnet
resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-${kv.name}'
  location: location
  tags: tags
  properties: {
    subnet: { id: dataSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'kvConnection'
        properties: { 
          privateLinkServiceId: kv.id 
          groupIds: ['vault'] 
        }
      }
    ]
  }
}

// Private DNS Zone (Allows VMs to resolve the vault's private IP)
resource kvDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

// Link the DNS Zone to the Spoke VNet
resource dnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: kvDnsZone
  name: 'link-to-spoke'
  tags: tags
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// Map the Private Endpoint to the DNS Zone
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

// ==========================================
// 3. IDENTITY & ACCESS (RBAC)
// ==========================================

// Grant the Web VM Identity "Secrets User" Access
resource webVmKvAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, webVmPrincipalId, keyVaultSecretsUserRole)
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRole)
    principalId: webVmPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the Data VM Identity "Secrets User" Access
resource dataVmKvAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, dataVmPrincipalId, keyVaultSecretsUserRole)
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRole)
    principalId: dataVmPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ==========================================
// 4. DIAGNOSTIC SETTINGS (Audit Trail)
// ==========================================

resource kvDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-kv'
  scope: kv
  properties: {
    workspaceId: lawId
    logs: [
      { category: 'AuditEvent', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}
