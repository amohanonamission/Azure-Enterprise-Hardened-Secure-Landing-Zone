# Azure Enterprise Hardened Landing Zone (Zero-Trust Foundation & SecOps Lab)

### Objective

This repository deploys an **Enterprise-Grade Cloud Foundation** in Azure using Bicep. It follows the **Microsoft Cloud Adoption Framework (CAF)** and **Zero-Trust principles** to build a "Hardened Shell" for production workloads.

This project serves as a comprehensive SecOps lab for demonstrating Identity-based access, Perimeter Security, and Governance-as-Code.

### Architecture Overview:

* **Hub-Spoke Topology:** Centralized management plane via Hub VNet and Azure Bastion.
* **Perimeter Security:** User-Defined Routes (UDR) for forced-tunneling and "Default-Deny" NSGs.
* **Identity & Access (IAM):** System-Assigned Managed Identity for VMs and RBAC-only access for Key Vault.
* **Private Connectivity:** Key Vault isolation via Private Endpoints (Private Link).
* **Observability:** Centralized Log Analytics Workspace (LAW) with diagnostic pipes from all resources.

### Infrastructure as Code (IaC) Components

| Module | Purpose | Security Feature |
| -------- | -------- | -------- |
|security-center.bicep	| Central Logging	| Log Analytics Workspace (LAW) & Immutable Diag Storage. |
|vnet-hub-spoke.bicep	| Network Mesh	| Hub-Spoke Peering, Bastion Host, and UDR Route Tables. |
|vault.bicep	| Secret Management	| Private Endpoint (No Public Access) & RBAC Authorization. |
|compute-hardened.bicep	| Workload Protection	| System Identity, No Public IP, and CanNotDelete Resource Locks. |

### Security Architecture Decisions

* **Decision 1:** Secure Parameterization. "Used @secure() decorators for all administrative credentials to ensure zero exposure in deployment logs and metadata."

* **Decision 2:** Automated Hardening. "Leveraged the CustomScript extension to enforce an immediate password change policy (chage -d 0) upon the first interactive login, mitigating 'Day 1' credential risks."

* **Decision 3:** Observability-by-Design. "Every compute resource is deployed with a pre-configured diagnostic pipe to a centralized Log Analytics Workspace for immediate SIEM ingestion."

* **Decision 4:** Private Link Integration. "Bypassed the public internet entirely for Key Vault access by implementing Azure Private Link. This ensures that even if an attacker had valid credentials, the vault remains physically unreachable from outside the private VNet mesh.

### Repository Structure

```
Repo: Azure-Enterprise-Hardened-Secure-Landing-Zone/
├── .github/
│   └── workflows/
│       └── bicep-deploy.yml          	# UPDATED: Now includes linting and What-If analysis
├── docs/                          	       		# NEW: The "Audit Evidence" & Architecture
│   ├── threat-model.md              		# Threat Model & Firewall vs NSG logic
│   └── architecture-diagram.png  
├── modules/
│   ├── network/
│   │   ├── hub-vnet.bicep
│   │   ├── spoke-vnet.bicep
│   │   ├── peering.bicep         		# NEW: Dedicated peering module
│   │   ├── firewall.bicep         		# Includes Diagnostic Settings
│   │   └── nsg.bicep             		# Includes Diagnostic Settings
│   ├── governance/
│   │   └── policies.bicep
│   ├── security/
│   │   ├── keyvault.bicep        		# Includes Diagnostic Settings
│   │   └── law.bicep             
├── identity/                                                  # NEW: Identity Management
│   └── setup-break-glass.ps1                      # Script & instructions for BCP emergency access
├── monitoring/                                             # NEW: Sentinel & Threat Hunting
│   └── Threat-Detection-Queries.kql           # KQL rules for NSG/Key Vault tampering
├── bicepconfig.json              	            # NEW: Linter rules & registry config
├── main.bicep                    
├── main.parameters.json          
└── README.md                                         # The "Audit Evidence" documentation
```


### How to Deploy:

```bash

az login

az stack sub create \
  --name "AMPT-2026-Foundation-Stack" \
  --location centralindia \
  --template-file main.bicep \
  --parameters parameters.json \
  --deny-settings-mode "denyDelete"     # This prevents manual deletion in portal!
  
* input the username and password when prompted
```

## SecOps: Day 2 Operational & Governance Configurations
Beyond the Bicep deployment, this lab includes documented manual configurations for:

* **Microsoft Defender for Cloud:** Enabling security posture management (CSPM).
* **Just-In-Time (JIT) Access:** Restricting management ports via adaptive network hardening.
* **Azure Policy:** Assigning the "Azure Security Benchmark" for continuous compliance auditing.
* **Disk Encryption:** Implementing Azure Disk Encryption (ADE) via the Hardened Key Vault.

Unlike traditional deployments, this lab focuses on Operational Sustainability using the following "Modern SecOps" pillars:

* **Encryption at Host (The ADE Successor):** Moving beyond legacy ADE, this architecture utilizes Encryption at Host to ensure that temporary disks, OS caches, and data disks are encrypted at the source with zero performance impact.
* **Microsoft Defender for Cloud (CSPM):** Automated onboarding to the Defender for Cloud portal to monitor the "Security Score" and remediate high-risk findings (like open management ports).
* **Adaptive Network Hardening (JIT):** Documentation for implementing Just-In-Time (JIT) access. This ensures that Port 22/3389 are "Closed by Default" and only opened via a time-limited, RBAC-approved request.
* **Policy-as-Code (Azure Security Benchmark):** Integrated guidance on assigning the ASB (v4) initiative to the Resource Group. This ensures any resource that drifts from the security baseline is flagged as "Non-Compliant" automatically.

## Visual Documentation

### Architecture Diagram (VS Code)
 
![Architecture Diagram](images/vscode-networkdiagram.png)
* (IMG001- Diagram shows the Vscode visualizer diagram overview of the Hub-Spoke network.)

![Architecture Diagram](images/Azure-Visualizer.png)
* **(IMG002- Diagram shows the Azure visualizer diagram overview of the Hub-Spoke network.)**

### Network Watcher Topology:

![Architecture Diagram](images/Deployment-Proof-Azure.png)
* **(IMG003- Diagram shows the Azure Network Watcher Topology.)**
![Architecture Diagram](images/network-watcher.png)
* **(IMG004- Diagram shows the Azure Resource Group overview.)**

### Resource Lock Verification (Lock Test): 

![Architecture Diagram](images/vm-resource-lock.png)
* **(IMG005- Diagram shows the Network Security group Inbound and Outbound rules.)**

### Private Link Verification: 

![Architecture Diagram](images/vault-private.png)
* **(IMG006- Diagram shows the Deletion Attempt on the Resource Group with Resource Lock.)**

### Key Vault (Managed Identity)


### NSG Flow 


### Azure Monitor

