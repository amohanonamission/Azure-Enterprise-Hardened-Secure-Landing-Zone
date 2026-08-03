<#
.SYNOPSIS
    Automates the creation of a Cloud-Only Emergency Access (Break-Glass) account in Entra ID.

.DESCRIPTION
    This script creates a highly privileged Global Administrator account designed strictly for 
    Business Continuity (BCP) during catastrophic identity outages. 
    
    CRITICAL AUDIT NOTE: 
    1. The UPN must use the default *.onmicrosoft.com domain to bypass custom DNS/federation outages.
    2. This account MUST be explicitly excluded from all Conditional Access MFA policies.
    3. Login events for this account MUST trigger an immediate high-severity SOC alert.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$TenantName, # e.g., "ampt2026.onmicrosoft.com"

    [Parameter(Mandatory=$true)]
    [securestring]$ComplexPassword
)

$ErrorActionPreference = "Stop"

# 1. Connect to Microsoft Graph with required scopes
Write-Host "[*] Connecting to Microsoft Graph API..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.ReadWrite.All", "RoleManagement.ReadWrite.Directory"

try {
    # 2. Define the Emergency Account properties
    $UPN = "emg-admin-vault@$TenantName"
    
    $PasswordProfile = @{
        Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ComplexPassword))
        ForceChangePasswordNextSignIn = $false # Must be false so it doesn't prompt during an emergency
    }

    # 3. Create the Cloud-Only User
    Write-Host "[*] Provisioning Break-Glass User: $UPN" -ForegroundColor Cyan
    $user = New-MgUser -DisplayName "Emergency Access (Break-Glass)" `
                       -UserPrincipalName $UPN `
                       -PasswordProfile $PasswordProfile `
                       -AccountEnabled $true `
                       -UsageLocation "IN"

    Write-Host "[+] User created successfully. Object ID: $($user.Id)" -ForegroundColor Green

    # 4. Assign the Global Administrator Role
    # The Template ID for Global Admin is universally static across all Azure tenants
    $GlobalAdminTemplateId = "62e90394-69f5-4237-9190-012177145e10" 
    
    Write-Host "[*] Assigning Global Administrator role..." -ForegroundColor Cyan
    
    # Check if the Global Admin role is already activated in the directory
    $role = Get-MgDirectoryRole -Filter "RoleTemplateId eq '$GlobalAdminTemplateId'"
    
    if (-not $role) {
        Write-Host "[-] Role not active in directory, activating..." -ForegroundColor Yellow
        $role = New-MgDirectoryRole -RoleTemplateId $GlobalAdminTemplateId
    }

    # Add the user to the Global Admin role
    New-MgDirectoryRoleMember -DirectoryRoleId $role.Id -DirectoryObjectId $user.Id
    
    Write-Host "[+] Global Administrator role assigned successfully." -ForegroundColor Green
    
    # 5. Output Audit Instructions
    Write-Host "`n======================================================================" -ForegroundColor Yellow
    Write-Host "ACTION REQUIRED: POST-DEPLOYMENT COMPLIANCE STEPS" -ForegroundColor Yellow
    Write-Host "======================================================================" -ForegroundColor Yellow
    Write-Host "1. Log into the Azure Portal with your normal admin account."
    Write-Host "2. Navigate to Entra ID -> Security -> Conditional Access."
    Write-Host "3. Open your 'Require MFA for Admins' policy."
    Write-Host "4. Under 'Users -> Exclude', explicitly add: $UPN"
    Write-Host "5. Store the password in a physical fireproof safe or split-knowledge vault."
    Write-Host "======================================================================" -ForegroundColor Yellow

} catch {
    Write-Host "[!] Error provisioning Break-Glass account: $_" -ForegroundColor Red
}
