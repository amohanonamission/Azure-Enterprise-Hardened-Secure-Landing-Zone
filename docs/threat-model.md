# Threat Model: Enterprise Secure Landing Zone
**Methodology:** STRIDE (Microsoft)
**Scope:** Hub-and-Spoke Network, Identity (Entra ID), and Key Vault.

## 1. Information Disclosure (Data Exfiltration)
* **Threat:** A compromised Web VM attempts to upload sensitive data to an external, attacker-controlled server (e.g., Dropbox, Pastebin).
* **Mitigation (Implemented):** 
  * Layer 4: NSGs block outbound traffic not destined for the Hub.
  * Layer 7: Azure Firewall (UDR Forced Tunneling) intercepts all egress traffic. The `applicationRuleCollections` strictly limits outbound connections to approved FQDNs (e.g., `*.github.com`). The data exfiltration attempt is dropped and logged.

## 2. Elevation of Privilege (Lateral Movement)
* **Threat:** An attacker gains access to the Web VM and attempts to extract database connection strings from the Key Vault to access the Data subnet.
* **Mitigation (Implemented):** 
  * Key Vault access relies on **System-Assigned Managed Identities** and Azure RBAC. The Web VM's identity is granted *only* the specific secrets it needs. 
  * The Key Vault's public endpoint is disabled. It is only accessible via the **Private Endpoint** (`10.0.2.5`), preventing the attacker from accessing it over the public internet even if they stole the token.

## 3. Tampering (Configuration Drift)
* **Threat:** A rogue or compromised administrator attempts to attach a Public IP to a workload VM to bypass the Firewall and establish a backdoor.
* **Mitigation (Implemented):** 
  * **Azure Policy** is enforced at the Resource Group level. The ARM API will physically reject the creation of any Public IP on a Spoke Network Interface, acting as an immutable Preventative Control.

## 4. Repudiation (Covering Tracks)
* **Threat:** An attacker deletes NSG rules to open port 3389 (RDP) and then deletes the logs to hide their activity.
* **Mitigation (Implemented):** 
  * `diagnosticSettings` are baked into the IaC for every resource. Logs are immediately streamed to a central Log Analytics Workspace (LAW). 
  * Sentinel KQL alerts trigger immediately upon NSG rule modification (`Microsoft.Network/networkSecurityGroups/securityRules/write`).
