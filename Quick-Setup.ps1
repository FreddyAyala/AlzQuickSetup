# Quick-Setup.ps1
# Simplified script to set up ALZ Terraform Accelerator with GitHub

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

# Initialize prerequisites status
$prerequisites = @{
    PowerShell = @{ Required = $true; Installed = $false; Version = "7.0.0"; CurrentVersion = $PSVersionTable.PSVersion }
    Administrator = @{ Required = $false; Installed = $false }
    AzureCLI = @{ Required = $false; Installed = $false; Version = "" }
    Modules = @{
        Az = @{ Required = $true; Installed = $false; Version = "9.3.0"; CurrentVersion = "0.0.0" }
        ALZ = @{ Required = $true; Installed = $false; Version = "0.0.1"; CurrentVersion = "0.0.0" }
    }
}

# Check PowerShell version
$prerequisites.PowerShell.Installed = $PSVersionTable.PSVersion -ge [Version]$prerequisites.PowerShell.Version

# Check Administrator privileges
$prerequisites.Administrator.Installed = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Check Azure CLI
try {
    $azVersion = az --version 2>$null
    if ($azVersion -match "azure-cli\s+(\d+\.\d+\.\d+)") {
        $prerequisites.AzureCLI.Installed = $true
        $prerequisites.AzureCLI.Version = $matches[1]
    } else {
        $azVersion = az version --output tsv --query '"azure-cli"' 2>$null
        if ($azVersion) {
            $prerequisites.AzureCLI.Installed = $true
            $prerequisites.AzureCLI.Version = $azVersion
        }
    }
} catch { 
    Write-Host "Error checking Azure CLI: $_" -ForegroundColor Yellow
}

# Check PowerShell modules
foreach ($module in $prerequisites.Modules.Keys) {
    $installed = Get-Module -ListAvailable -Name $module
    if ($installed) {
        $latestVersion = $installed | Sort-Object Version -Descending | Select-Object -First 1
        $prerequisites.Modules[$module].CurrentVersion = $latestVersion.Version
        $prerequisites.Modules[$module].Installed = $latestVersion.Version -ge [Version]$prerequisites.Modules[$module].Version
    }
}

# Display prerequisites status
Write-Host "`nPrerequisites Status:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

Write-Host "`nRequired Components:" -ForegroundColor Yellow
Write-Host "- PowerShell Core 7+: $(if ($prerequisites.PowerShell.Installed) { "✓" } else { "✗" }) (Current: $($prerequisites.PowerShell.CurrentVersion))"
foreach ($module in $prerequisites.Modules.Keys) {
    Write-Host "- $module Module: $(if ($prerequisites.Modules[$module].Installed) { "✓" } else { "✗" }) (Required: $($prerequisites.Modules[$module].Version), Current: $($prerequisites.Modules[$module].CurrentVersion))"
}

Write-Host "`nOptional Components:" -ForegroundColor Yellow
Write-Host "- Administrator Rights: $(if ($prerequisites.Administrator.Installed) { "✓" } else { "✗" })"
$cliStatus = if ($prerequisites.AzureCLI.Installed) { "✓" } else { "✗" }
$cliVersion = if ($prerequisites.AzureCLI.Version) { " (Version: $($prerequisites.AzureCLI.Version))" } else { "" }
Write-Host "- Azure CLI: $cliStatus$cliVersion"

# Check if any required components are missing
$missingRequired = -not $prerequisites.PowerShell.Installed -or 
                  ($prerequisites.Modules.Values | Where-Object { -not $_.Installed })

if ($missingRequired) {
    Write-Host "`nMissing required prerequisites:" -ForegroundColor Red
    
    if (-not $prerequisites.PowerShell.Installed) {
        Write-Host "- PowerShell Core 7+ must be installed from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Yellow
    }

    $missingModules = $prerequisites.Modules.Keys | Where-Object { -not $prerequisites.Modules[$_].Installed }
    if ($missingModules) {
        Write-Host "`nThe following PowerShell modules need to be installed/updated:" -ForegroundColor Yellow
        foreach ($module in $missingModules) {
            Write-Host "- $module (Required: $($prerequisites.Modules[$module].Version))" -ForegroundColor Yellow
        }
    }

    $installModules = Read-Host "`nWould you like to install/update the required PowerShell modules now? (Y/N)"
    if ($installModules -eq "Y" -or $installModules -eq "y") {
        Write-Host "`nInstalling/updating PowerShell modules..." -ForegroundColor Cyan
        foreach ($module in $missingModules) {
            try {
                Write-Host "Installing $module..." -ForegroundColor Yellow
                Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                Write-Host "$module installed successfully." -ForegroundColor Green
            }
            catch {
                Write-Host "Error installing $module. Error: $_" -ForegroundColor Red
                Write-Host "`nPlease try installing manually after closing all PowerShell windows:" -ForegroundColor Yellow
                Write-Host "Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber" -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "`nWarning: Continuing without required prerequisites may cause errors later." -ForegroundColor Red
        Write-Host "You can install them manually later using:" -ForegroundColor Yellow
        foreach ($module in $missingModules) {
            Write-Host "Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber" -ForegroundColor Yellow
        }
        $continue = Read-Host "`nAre you sure you want to continue anyway? (Y/N)"
        if ($continue -ne "Y" -and $continue -ne "y") {
            exit 1
        }
        Write-Host "Continuing with missing prerequisites..." -ForegroundColor Yellow
    }
}

if (-not $prerequisites.AzureCLI.Installed) {
    Write-Host "`nAzure CLI is not installed (optional but recommended)." -ForegroundColor Yellow
    Write-Host "You can install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
    $continue = Read-Host "Continue without Azure CLI? (Y/N)"
    if ($continue -ne "Y" -and $continue -ne "y") {
        exit 1
    }
}

Write-Host "`nPrerequisites check completed!" -ForegroundColor Green

# Check if ALZ module is installed
if (-not (Get-InstalledModule -Name ALZ -ErrorAction SilentlyContinue)) {
    Write-Host "Installing ALZ module..." -ForegroundColor Yellow
    Install-Module -Name ALZ -Scope CurrentUser -Force
}

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
    Write-Host "Creating template file..." -ForegroundColor Yellow
    Copy-Item ".\config\inputs.yaml" ".\config\inputs.template.yaml" -ErrorAction SilentlyContinue
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

# Ask to run the bootstrap
$runBootstrap = Read-Host -Prompt "Run the bootstrap now? (Y/N)"

if ($runBootstrap -eq "Y" -or $runBootstrap -eq "y") {
    Write-Host "Running ALZ Terraform Accelerator bootstrap..." -ForegroundColor Green
    Write-Host "This will create resources in Azure and GitHub." -ForegroundColor Yellow
    
    try {
        # Run the bootstrap using just the inputs file
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