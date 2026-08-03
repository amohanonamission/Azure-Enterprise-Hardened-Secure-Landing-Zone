// modules/governance/policies.bicep

targetScope = 'resourceGroup' // Scoped safely to the project environment

param prefix string
param allowedLocation string = 'centralindia'

// ==========================================
// BUILT-IN POLICY DEFINITION IDs
// ==========================================

// Built-in Policy: Network interfaces should not have public IPs
var noPublicIpPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/83a86a26-fd1f-447c-b59d-e51f44264114'

// Built-in Policy: Allowed locations
var allowedLocationsPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'

// Built-in Policy: Require a tag on resources
var requireTagPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99'


// ==========================================
// POLICY ASSIGNMENTS   -   THOU SHALL NOT BY-PASS
// ==========================================

// 1. The Auditor's Twist: Block Public IPs
resource denyPublicIps 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: '${prefix}-deny-pip'
  properties: {
    displayName: 'Enforce Zero-Trust: Deny Public IPs on NICs'
    description: 'Ensures that no network interfaces in the Spoke workloads can be exposed directly to the internet. All egress must route through the Hub.'
    policyDefinitionId: noPublicIpPolicyId
    enforcementMode: 'Default' // 'Default' acts as a Deny effect for this policy
  }
}

// 2. Data Residency: Restrict Regions
resource restrictLocations 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: '${prefix}-allow-loc'
  properties: {
    displayName: 'Data Residency: Restrict Allowed Locations'
    description: 'Ensures data does not leave the approved geographic boundary.'
    policyDefinitionId: allowedLocationsPolicyId
    parameters: {
      listOfAllowedLocations: {
        value: [
          allowedLocation
        ]
      }
    }
  }
}

// 3. Traceability: Enforce Resource Tagging
resource enforceTagging 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: '${prefix}-req-tag'
  properties: {
    displayName: 'FinOps: Require CostCenter Tag'
    description: 'Requires the CostCenter tag on all resources for audit and billing traceability.'
    policyDefinitionId: requireTagPolicyId
    parameters: {
      tagName: {
        value: 'CostCenter'
      }
    }
  }
}
