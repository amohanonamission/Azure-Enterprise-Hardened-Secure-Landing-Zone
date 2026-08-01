param location string
param prefix string
param tags object

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'law-${prefix}-security-001'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource diagStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'stdiag${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  tags: tags
}

output lawId string = logAnalytics.id
output diagStorageUri string = diagStorage.properties.primaryEndpoints.blob




param lawId string // Add this to the top parameters

// The CISA Edit: Audit Logging for Key Vault
resource kvDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'kv-to-law'
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
