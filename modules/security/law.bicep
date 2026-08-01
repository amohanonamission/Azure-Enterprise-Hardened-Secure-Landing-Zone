// modules/security/law.bicep


param location string
param prefix string
param tags object

// Deploy the Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'law-${prefix}-security-001'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30 // Minimum retention for quick threat hunting
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Output the ID to be passed to NSGs, Firewalls, Key Vault, and Compute
output lawId string = logAnalytics.id
output lawName string = logAnalytics.name
