#!/bin/bash
# deploy.sh
# Local execution wrapper for the Azure Enterprise Secure Landing Zone

# Exit immediately if a command exits with a non-zero status
set -e

# Define Variables
LOCATION="southindia"
STACK_NAME="AMPT-2026-Foundation-Stack"
TEMPLATE_FILE="main.bicep"
PARAM_FILE="main.parameters.json"

echo -e "\e[34m[*] Starting Enterprise Landing Zone Deployment...\e[0m"

# 1. Check Azure Login Status
echo -e "\e[36m[*] Checking Azure authentication...\e[0m"
if ! az account show > /dev/null 2>&1; then
    echo -e "\e[33m[!] Not logged in. Prompting for az login...\e[0m"
    az login
fi

# 2. Run Bicep Linter/Build Check
echo -e "\e[36m[*] Running Bicep Linter (Validating bicepconfig.json rules)...\e[0m"
az bicep build --file $TEMPLATE_FILE
echo -e "\e[32m[+] Bicep compilation successful.\e[0m"

# 3. Execute What-If Analysis
echo -e "\e[36m[*] Generating 'What-If' Delta Report...\e[0m"
az deployment sub what-if \
  --location $LOCATION \
  --template-file $TEMPLATE_FILE \
  --parameters $PARAM_FILE

read -p "Proceed with deployment based on What-If results? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo -e "\e[31m[-] Deployment aborted by user.\e[0m"
    exit 1
fi

# 4. Execute Deployment Stack (Immutable Infrastructure)
echo -e "\e[34m[*] Executing Deployment Stack with denyDelete lock...\e[0m"
az stack sub create \
  --name $STACK_NAME \
  --location $LOCATION \
  --template-file $TEMPLATE_FILE \
  --parameters $PARAM_FILE \
  --deny-settings-mode "denyDelete" \
  --yes

echo -e "\e[32m[+] Deployment Completed Successfully! Proceed to Azure Portal for Audit Validation.\e[0m"




# One-click deployment script
#!/bin/sh

az login
az deployment sub create --location centralindia --template-file main.bicep --parameters parameters.json
