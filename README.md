# Azure Landing Zone Quick Setup

This repository contains a PowerShell script to quickly set up Azure Landing Zones using the ALZ Terraform Accelerator with GitHub integration.

## Prerequisites

Before running the script, ensure you have:

1. PowerShell 7.0 or later
2. Azure CLI installed and logged in
3. GitHub Personal Access Token (PAT) with the following scopes:
   - repo
   - workflow
   - admin:org
   - read:user
   - user:email
   - delete_repo
4. Three Azure subscriptions (can be the same subscription for testing):
   - Management subscription
   - Connectivity subscription
   - Identity subscription
5. Owner permissions on all subscriptions

## Quick Start

1. Clone this repository:
   ```powershell
   git clone <repository-url>
   cd <repository-name>
   ```

2. Run the setup script:
   ```powershell
   ./Quick-Setup.ps1
   ```

3. Follow the interactive prompts to configure your Azure Landing Zone.

## What the Script Does

1. Installs and verifies prerequisites (ALZ PowerShell module)
2. Collects required information:
   - GitHub organization and repository details
   - Azure tenant and subscription IDs
   - Azure region preferences
   - Platform Landing Zone configuration:
     - Root ID and name for Management Group hierarchy
     - Security contact email
     - Log retention period
     - DDoS protection settings
     - Private DNS zones settings

3. Generates necessary configuration files
4. Bootstraps the Azure Landing Zone environment

## Repository Contents

This repository contains only the essential files needed to get started:

- `Quick-Setup.ps1`: Main setup script
- `config/inputs.template.yaml`: Template for ALZ configuration

The script will automatically:
1. Create required directories
2. Generate configuration files from templates
3. Save your settings for future runs (except sensitive data)

## Generated Files (not in repo)

The script generates several files that are automatically excluded from git:

- `config/inputs.yaml`: Your actual ALZ configuration
- `config/saved-settings.json`: Your saved parameters for future runs
- `config/platform_landing_zone.tfvars`: Your Terraform variables
- `output/`: Bootstrap output directory

## Notes

- The script saves your settings (except GitHub PAT) for future runs
- All sensitive files are automatically excluded from git
- You can rerun the script multiple times to update your configuration
- The bootstrap process creates:
  - GitHub repository with ALZ code
  - Azure resources for Terraform state
  - GitHub Actions workflows

## Documentation

For more detailed information, visit:
- [Azure Landing Zones Accelerator Documentation](https://aka.ms/alz/accelerator)
- [User Guide](https://azure.github.io/Azure-Landing-Zones/accelerator/userguide/) 