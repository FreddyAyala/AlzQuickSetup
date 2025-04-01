# Quick-Setup.ps1
# Simplified script to set up ALZ Terraform Accelerator with GitHub

# Helper function to handle default values and saved settings
function Read-HostWithDefault {
    param(
        [string]$prompt,
        $savedValue,
        [string]$defaultValue = ""
    )

    $displayValue = if ($null -ne $savedValue) { $savedValue } else { $defaultValue }
    $promptText = if ($displayValue) { "$prompt (default: $displayValue)" } else { $prompt }
    $value = Read-Host -Prompt $promptText

    if ([string]::IsNullOrWhiteSpace($value)) {
        if ($null -ne $savedValue) {
            return $savedValue
        }
        return $defaultValue
    }
    return $value
}

Write-Host @"
     \     |     __  /       _ \         _)        |          ___|   |                 |   
    _ \    |        /       |   |  |   |  |   __|  |  /     \___ \   __|   _` |   __|  __| 
   ___ \   |       /        |   |  |   |  |  (       <            |  |    (   |  |     |   
 _/    _\ _____| ____|     \__\_\ \__,_| _| \___| _|\_\     _____/  \__| \__,_| _|    \__| 
                                                                                           
                              Quick Setup for Azure Landing Zones
                                 https://aka.ms/alz/accelerator
"@ -ForegroundColor Cyan

Write-Host "Interactive Azure Landing Zone Accelerator Setup for GitHub" -ForegroundColor Yellow
Write-Host "Following: https://azure.github.io/Azure-Landing-Zones/accelerator/userguide/" -ForegroundColor Yellow
Write-Host "---------------------------------------------------------------`n" -ForegroundColor Yellow

Write-Host "Checking prerequisites..." -ForegroundColor Cyan

# Ensure ALZ module is installed and use its built-in prerequisite check
if (-not (Get-Module -ListAvailable -Name ALZ)) {
    Write-Host "ALZ PowerShell module not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name ALZ -Scope CurrentUser -Force
}

if (-not (Test-AcceleratorRequirement)) {
    Write-Error "Prerequisites check failed. Please address the issues above and try again."
    exit 1
}

Write-Host "✓ All prerequisites met" -ForegroundColor Green

# Create required directories
if (-not (Test-Path ".\config")) {
    New-Item -Path ".\config" -ItemType Directory | Out-Null
}
if (-not (Test-Path ".\config\lib")) {
    New-Item -Path ".\config\lib" -ItemType Directory | Out-Null
}
if (-not (Test-Path ".\output")) {
    New-Item -Path ".\output" -ItemType Directory | Out-Null
}

# Define settings file for saved parameters
$settingsFile = ".\config\saved-settings.json"
$savedSettings = @{}

# Load saved settings if they exist
if (Test-Path $settingsFile) {
    try {
        $savedSettings = Get-Content $settingsFile | ConvertFrom-Json -AsHashtable
        Write-Host "Loaded previous settings. Use previous values or enter new ones." -ForegroundColor Green
    }
    catch {
        Write-Host "Error loading saved settings. Will use default values." -ForegroundColor Yellow
        $savedSettings = @{}
    }
}

# Get GitHub Organization with default from saved settings
$defaultOrg = if ($savedSettings.ContainsKey("githubOrg")) { $savedSettings.githubOrg } else { "" }
$prompt = if ($defaultOrg) { "GitHub Organization Name (default: $defaultOrg)" } else { "GitHub Organization Name" }
$githubOrg = Read-Host -Prompt $prompt

# Use default if empty
if ([string]::IsNullOrWhiteSpace($githubOrg) -and $defaultOrg) {
    $githubOrg = $defaultOrg
}

# Get repository name with default
$defaultRepo = if ($savedSettings.ContainsKey("repoName")) { $savedSettings.repoName } else { "alz-terraform-accelerator" }
$prompt = "Repository Name (default: $defaultRepo)"
$repoName = Read-Host -Prompt $prompt

# Use default if empty
if ([string]::IsNullOrWhiteSpace($repoName)) {
    $repoName = $defaultRepo
}

# Get Azure Tenant ID with default
$defaultTenant = if ($savedSettings.ContainsKey("tenantId")) { $savedSettings.tenantId } else { "" }
$prompt = if ($defaultTenant) { "Azure Tenant ID (default: $defaultTenant)" } else { "Azure Tenant ID" }
$tenantId = Read-Host -Prompt $prompt

# Use default if empty
if ([string]::IsNullOrWhiteSpace($tenantId) -and $defaultTenant) {
    $tenantId = $defaultTenant
}

# Get Azure Subscription IDs with defaults
$defaultSubscription = if ($savedSettings.ContainsKey("subscriptionId")) { $savedSettings.subscriptionId } else { "" }
$prompt = if ($defaultSubscription) { "Azure Management Subscription ID (default: $defaultSubscription)" } else { "Azure Management Subscription ID" }
$subscriptionId = Read-Host -Prompt $prompt

# Use default if empty
if ([string]::IsNullOrWhiteSpace($subscriptionId) -and $defaultSubscription) {
    $subscriptionId = $defaultSubscription
}

$defaultConnectivity = if ($savedSettings.ContainsKey("connectivitySubId")) { $savedSettings.connectivitySubId } else { $subscriptionId }
$prompt = "Connectivity Subscription ID (default: $defaultConnectivity)"
$connectivitySubId = Read-Host -Prompt $prompt

# Use default if empty
if ([string]::IsNullOrWhiteSpace($connectivitySubId)) {
    $connectivitySubId = $defaultConnectivity
}

$defaultIdentity = if ($savedSettings.ContainsKey("identitySubId")) { $savedSettings.identitySubId } else { $subscriptionId }
$prompt = "Identity Subscription ID (default: $defaultIdentity)"
$identitySubId = Read-Host -Prompt $prompt

# Use default if empty
if ([string]::IsNullOrWhiteSpace($identitySubId)) {
    $identitySubId = $defaultIdentity
}

$managementSubId = $subscriptionId  # Using the same subscription for management

# Get preferred Azure region with default
$defaultLocation = if ($savedSettings.ContainsKey("location")) { $savedSettings.location } else { "eastus" }
$prompt = "Preferred Azure Region (default: $defaultLocation)"
$location = Read-Host -Prompt $prompt

# Use default if empty
if ([string]::IsNullOrWhiteSpace($location)) {
    $location = $defaultLocation
}

# Get GitHub PAT
Write-Host "`n=== GitHub Personal Access Token Setup ===" -ForegroundColor Cyan
Write-Host "Create a PAT with: repo, workflow, admin:org, read:user, user:email, delete_repo scopes" -ForegroundColor Yellow
$secureGithubPat = Read-Host -Prompt "GitHub PAT Token" -AsSecureString

# Convert secure string to plain text for use in the YAML
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureGithubPat)
$githubPat = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

# Generate a unique storage account name for Terraform state
$randomChars = -join ((97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
$storageAccountName = "stalz$randomChars"

# Save settings for future runs
$settingsToSave = @{
    githubOrg = $githubOrg
    repoName = $repoName
    tenantId = $tenantId
    subscriptionId = $subscriptionId
    connectivitySubId = $connectivitySubId
    identitySubId = $identitySubId
    location = $location
}
$settingsToSave | ConvertTo-Json | Out-File -FilePath $settingsFile -Force
Write-Host "Settings saved for future runs." -ForegroundColor Green

# Check if template exists, if not create it
if (-not (Test-Path ".\config\inputs.template.yaml")) {
    Write-Host "Creating inputs.template.yaml..." -ForegroundColor Yellow
    @"
# Required parameters
bootstrap_module_name: "alz_github"
iac_type: "terraform"
starter_module_name: "platform_landing_zone"
bootstrap_location: "REPLACE_WITH_AZURE_REGION"
starter_locations: ["REPLACE_WITH_AZURE_REGION"]

# Platform Landing Zone tfvars configuration
platform_landing_zone_tfvars:
  root_id: "alz"
  root_name: "Azure Landing Zones"
  subscription_id_connectivity: "REPLACE_WITH_CONNECTIVITY_SUB_ID"
  subscription_id_identity: "REPLACE_WITH_IDENTITY_SUB_ID"
  subscription_id_management: "REPLACE_WITH_MANAGEMENT_SUB_ID"
  default_location: "REPLACE_WITH_AZURE_REGION"
  email_security_contact: "REPLACE_WITH_SECURITY_EMAIL"
  log_retention_in_days: 30
  enable_ddos_protection: false
  enable_private_dns_zones: true

# GitHub configuration
github_organization_name: "REPLACE_WITH_GITHUB_ORG"
github_repository_name: "alz-terraform-accelerator"
github_repository_visibility: "private"
github_personal_access_token: "REPLACE_WITH_GITHUB_PAT"
github_self_hosted_runners: false

# Environment
environment_name: "alz"
service_name: "alz"
root_parent_management_group_id: ""
subscription_id_management: "REPLACE_WITH_MANAGEMENT_SUB_ID"
subscription_id_connectivity: "REPLACE_WITH_CONNECTIVITY_SUB_ID"
subscription_id_identity: "REPLACE_WITH_IDENTITY_SUB_ID"
management_group_name_prefix: ""

# Azure configuration
azure:
  tenant_id: "REPLACE_WITH_TENANT_ID"
  subscription_id: "REPLACE_WITH_SUBSCRIPTION_ID"
  location: "REPLACE_WITH_AZURE_REGION"
  service_principal:
    use_auth_file: false

# Terraform state
terraform:
  version: "1.5.7"
  runner_type: "agent"
  providers:
    azurerm:
      source: "hashicorp/azurerm"
      version: "3.74.0"
  state:
    type: "azurerm"
    resource_group_name: "rg-terraform-state"
    storage_account_name: "REPLACE_WITH_STORAGE_ACCOUNT"
    container_name: "tfstate"
    key: "alz.tfstate"
    use_existing: false
    
# Starter module configuration  
platform_starter:
  type: "avm-ptn-alz"
  version: "1.0.0"

# Management group configuration
management_groups:
  root_id: "alz"
  root_name: "Azure Landing Zones"

# Platform subscription configuration
platform_subscriptions:
  connectivity_subscription:
    subscription_id: "REPLACE_WITH_CONNECTIVITY_SUB_ID"
    location: "REPLACE_WITH_AZURE_REGION"
  identity_subscription:
    subscription_id: "REPLACE_WITH_IDENTITY_SUB_ID"
    location: "REPLACE_WITH_AZURE_REGION"
  management_subscription:
    subscription_id: "REPLACE_WITH_MANAGEMENT_SUB_ID"
    location: "REPLACE_WITH_AZURE_REGION"
"@ | Out-File -FilePath ".\config\inputs.template.yaml" -Encoding utf8
}

# Read the template file and replace placeholders
$templateContent = Get-Content ".\config\inputs.template.yaml" -Raw
$configContent = $templateContent `
    -replace "REPLACE_WITH_AZURE_REGION", $location `
    -replace "REPLACE_WITH_GITHUB_ORG", $githubOrg `
    -replace "REPLACE_WITH_GITHUB_PAT", $githubPat `
    -replace "REPLACE_WITH_MANAGEMENT_SUB_ID", $managementSubId `
    -replace "REPLACE_WITH_CONNECTIVITY_SUB_ID", $connectivitySubId `
    -replace "REPLACE_WITH_IDENTITY_SUB_ID", $identitySubId `
    -replace "REPLACE_WITH_TENANT_ID", $tenantId `
    -replace "REPLACE_WITH_SUBSCRIPTION_ID", $subscriptionId `
    -replace "REPLACE_WITH_STORAGE_ACCOUNT", $storageAccountName

# Save the configuration
$configContent | Out-File -FilePath ".\config\inputs.yaml" -Encoding utf8
Write-Host "Configuration saved to .\config\inputs.yaml" -ForegroundColor Green

# Read the YAML content to determine the starter module
$yamlContent = Get-Content ".\config\inputs.yaml" | ConvertFrom-Yaml

# Get security contact email if using platform_landing_zone
if ($yamlContent.starter_module_name -eq "platform_landing_zone") {
    Write-Host "`n=== Platform Landing Zone Configuration ===" -ForegroundColor Cyan
    
    # Prompt for all tfvars parameters with defaults, using saved settings if available
    $rootId = Read-HostWithDefault "Root ID for the Management Group hierarchy" $savedSettings.root_id "alz"
    $savedSettings.root_id = $rootId
    
    $rootName = Read-HostWithDefault "Root Name for the Management Group hierarchy" $savedSettings.root_name "Azure Landing Zones"
    $savedSettings.root_name = $rootName
    
    $securityEmail = Read-HostWithDefault "Security contact email for alerts" $savedSettings.security_email
    while ([string]::IsNullOrWhiteSpace($securityEmail)) {
        Write-Host "Security contact email is required." -ForegroundColor Yellow
        $securityEmail = Read-Host -Prompt "Security contact email for alerts"
    }
    $savedSettings.security_email = $securityEmail
    
    $logRetention = Read-HostWithDefault "Log retention in days" $savedSettings.log_retention_in_days "30"
    $savedSettings.log_retention_in_days = $logRetention
    
    $enableDdos = Read-HostWithDefault "Enable DDoS Protection? (Y/N)" $savedSettings.enable_ddos_protection "N"
    $enableDdos = ($enableDdos -eq "Y" -or $enableDdos -eq "y")
    $savedSettings.enable_ddos_protection = $enableDdos
    
    $enablePrivateDns = Read-HostWithDefault "Enable Private DNS Zones? (Y/N)" $savedSettings.enable_private_dns_zones "Y"
    $enablePrivateDns = (-not ($enablePrivateDns -eq "N" -or $enablePrivateDns -eq "n"))
    $savedSettings.enable_private_dns_zones = $enablePrivateDns

    # Save settings to file
    $savedSettings | ConvertTo-Json | Out-File -FilePath ".\config\saved-settings.json" -Encoding utf8
    
    # Generate the tfvars file that the accelerator expects
    $tfvarsContent = @{
        root_id = $rootId
        root_name = $rootName
        default_location = $location
        email_security_contact = $securityEmail
        log_retention_in_days = [int]$logRetention
        enable_ddos_protection = $enableDdos
        enable_private_dns_zones = $enablePrivateDns
    }

    # Convert to HCL format
    $tfvarsHCL = ""
    foreach ($key in $tfvarsContent.Keys) {
        $value = $tfvarsContent[$key]
        if ($value -is [string]) {
            $tfvarsHCL += "$key = `"$value`"`n"
        }
        elseif ($value -is [bool]) {
            $tfvarsHCL += "$key = $($value.ToString().ToLower())`n"
        }
        else {
            $tfvarsHCL += "$key = $value`n"
        }
    }

    # Save the tfvars file
    $tfvarsHCL | Out-File -FilePath "config/platform_landing_zone.tfvars" -Encoding UTF8
    Write-Host "Platform Landing Zone configuration saved to config/platform_landing_zone.tfvars" -ForegroundColor Green
}

# Ask to run the bootstrap
$runBootstrap = Read-Host -Prompt "Run the bootstrap now? (Y/N)"

if ($runBootstrap -eq "Y" -or $runBootstrap -eq "y") {
    Write-Host "Running ALZ Terraform Accelerator bootstrap..." -ForegroundColor Green
    Write-Host "This will create resources in Azure and GitHub." -ForegroundColor Yellow
    
    try {
        # Run the bootstrap using just the inputs file - tfvars will be handled by the module
        Deploy-Accelerator -inputs ".\config\inputs.yaml" -output ".\output"
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host "Bootstrap failed. Please check the error message above." -ForegroundColor Yellow
    }
} else {
    Write-Host "To run the bootstrap later, use:" -ForegroundColor Yellow
    Write-Host "Deploy-Accelerator -inputs "".\config\inputs.yaml"" -output "".\output""" -ForegroundColor Cyan
} 