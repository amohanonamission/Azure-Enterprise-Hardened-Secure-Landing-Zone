param location string
param subnetId string
param vmName string
param lawId string
param tags object
param uname string = 'amptadmin' // A limitation to this solution. Since the whole infrastructure/Platform is deployed at once.
param pword string = 'Password1234!' // This password will be expired on login. 

resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [{ name: 'ipconfig1', properties: { subnet: { id: subnetId } } }]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    hardwareProfile: { vmSize: 'Standard_D2s_v3' }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-focal', sku: '20_04-lts-gen2', version: 'latest' }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Standard_LRS' } }
    }
    osProfile: {
      computerName: vmName
      adminUsername: uname 
      adminPassword: pword // This password will be expired on login. 
    }
    networkProfile: { networkInterfaces: [{ id: nic.id }] }
  }
}

// Immutable Resource Lock
resource lock 'Microsoft.Authorization/locks@2017-04-01' = {
  name: 'CanNotDeleteVM'
  scope: vm
  properties: { level: 'CanNotDelete', notes: 'Critical Workload' }
}

// Diagnostic Settings (The Pipe)
resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'vm-to-law'
  scope: vm
  properties: {
    workspaceId: lawId
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

// Password expiry on login.

resource vmExpirer 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: vm
  name: 'ForcePasswordChange'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'chage -d 0 amptadmin'
    }
  }
}
