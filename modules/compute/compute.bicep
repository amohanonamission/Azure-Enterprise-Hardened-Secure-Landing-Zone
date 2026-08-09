// modules/compute/compute.bicep

param location string
param prefix string
param tags object
param webSubnetId string
param dataSubnetId string
param lawId string

@secure()
param adminUsername string

@secure()
param adminPassword string

// ==========================================
// 1. NETWORK INTERFACES (No Public IPs)
// ==========================================

resource webNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nic-${prefix}-web-001'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: webSubnetId }
          // Notice: No publicIPAddress property here. Complies with our Azure Policy.
        }
      }
    ]
  }
}

resource dataNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nic-${prefix}-data-001'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: dataSubnetId }
        }
      }
    ]
  }
}

// ==========================================
// 2. VIRTUAL MACHINES (Zero-Trust IAM)
// ==========================================

resource webVm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'vm-${prefix}-web-001'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned' // Grants the VM an identity in Entra ID
  }
  properties: {
    hardwareProfile: { vmSize: 'Standard_D2s_v5' }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-focal', sku: '20_04-lts-gen2', version: 'latest' }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Standard_LRS' } }
    }
    osProfile: {
      computerName: 'vm-web-001'
      adminUsername: adminUsername
      adminPassword: adminPassword 
    }
    networkProfile: { networkInterfaces: [{ id: webNic.id }] }
  }
}

resource dataVm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'vm-${prefix}-data-001'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned' 
  }
  properties: {
    hardwareProfile: { vmSize: 'Standard_D2s_v5' }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-focal', sku: '20_04-lts-gen2', version: 'latest' }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Standard_LRS' } }
    }
    osProfile: {
      computerName: 'vm-data-001'
      adminUsername: adminUsername
      adminPassword: adminPassword 
    }
    networkProfile: { networkInterfaces: [{ id: dataNic.id }] }
  }
}

// ==========================================
// 3. SECURITY EXTENSIONS & LOCKS
// ==========================================

// Force Password Change on First Login (Web)
resource webVmExpirer 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: webVm
  name: 'ForcePasswordChange'
  location: location
  tags: tags // Added tags to pass Azure Policy validation
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'chage -d 0 ${adminUsername}' 
    }
  }
}

// Force Password Change on First Login (Data)
resource dataVmExpirer 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: dataVm
  name: 'ForcePasswordChange'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'chage -d 0 ${adminUsername}' 
    }
  }
}

// Immutable Resource Lock (Data VM - Protects critical assets from accidental deletion)
resource dataLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: 'CanNotDelete-DataVM'
  scope: dataVm
  properties: {
    level: 'CanNotDelete'
    notes: 'Critical Workload - Deletion requires explicit override.'
  }
}

// ==========================================
// 4. DIAGNOSTIC SETTINGS (Audit Trail)
// ==========================================

resource webDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-web-vm'
  scope: webVm
  properties: {
    workspaceId: lawId
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

resource dataDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-data-vm'
  scope: dataVm
  properties: {
    workspaceId: lawId
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

// Output the Principal IDs so we can grant them access to Key Vault later
output webVmPrincipalId string = webVm.identity.principalId
output dataVmPrincipalId string = dataVm.identity.principalId
