Function rg-asp-app-ai-psql-st {
  <#
  .SYNOPSIS
  DOTNETCORE|6.0 / Linux
  Instantiating Azure Resources.
  
  .DESCRIPTION
  Resource Abbreviations
  https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations?WT.mc_id=java-26679-cxa
  
  .PARAMETER ApplicationName
  Parameter description
  
  .PARAMETER Location
  Parameter description
  
  .PARAMETER Environment
  Parameter description
  
  .PARAMETER InstanceNumber
  Parameter description
  
  .PARAMETER AppInsightsInstrumenKey
  Parameter description
  
  .PARAMETER StorageAccountName
  Parameter description
  
  .PARAMETER StorageAccountKey
  Parameter description
  
  .PARAMETER StorageConnectionString
  Parameter description
  
  .PARAMETER DatabaseURL
  Parameter description
  
  .PARAMETER DatabaseUser
  Parameter description
  
  .PARAMETER DatabasePass
  Parameter description
  
  .EXAMPLE
  rg-asp-app-ai-psql-st
  rg-asp-app-ai-psql-st -any_of_params_that_you_wanna_customize
  
  .NOTES
  0.1.6
  Working version
  #>
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline = $true, Mandatory = $false, HelpMessage = "Enter your Resource Group / Aplication name")]
    [ValidateRange(3, 24)]
    [string]$ApplicationName = "app$(Get-Random)",

    [Parameter(Mandatory = $false, HelpMessage = "Location")]
    [ValidateSet("centralus", "eastus2", "eastasia", "westeurope", "westus2")]
    [string]$Location = "westeurope",

    [Parameter(Mandatory = $false, HelpMessage = "Choose Dev, Test, Stage or Prod")]
    [ValidateSet("dev", "test", "stage", "prod")]
    [string]$Environment = "dev",

    [Parameter(Mandatory = $false, HelpMessage = "Suffix for instantiated Azure resources")]
    [ValidateRange("001", "999")]
    [string]$InstanceNumber = '001',

    [Parameter(Mandatory = $false, HelpMessage = "AppServicePlan's name will be same as AppService one, Tier is predefined to 'Free'")]
    [string]$AppInsightsInstrumenKey = "APPINSIGHTS_INSTRUMENTATIONKEY",

    [Parameter(Mandatory = $false, HelpMessage = "Declare Storage account name")]
    [string]$StorageAccountName = "storageaccusername2023-$ApplicationName-$Environment",

    [Parameter(Mandatory = $false, HelpMessage = "Enter Storage account key")]
    [string]$StorageAccountKey = "storageaccpassword2023-$ApplicationName-$Environment",

    [Parameter(Mandatory = $false, HelpMessage = "Define Storage connection string")]
    [string]$StorageConnectionString = "azure_storage_connectionstring",

    [Parameter(Mandatory = $false, HelpMessage = "Define a SQL URL")]
    [string]$DatabaseURL = "DATABASE_URL",

    [Parameter(Mandatory = $false, HelpMessage = "Define a SQL username")]
    [string]$DatabaseUser = "ChangeYourTestingPhaseUsername2023",

    [Parameter(Mandatory = $false, HelpMessage = "Define a SQL password")]
    [string]$DatabasePass = "ChangeYourTestingPhasePassword2023"
  )
  BEGIN {
    ## Check and set script path
    Write-Host "CurrentDirectory: "$PWD.ProviderPath -ForegroundColor Cyan
    Push-Location $MyInvocation.MyCommand.Path
    Write-Host "Checking authentification context against Azure..." -ForegroundColor Cyan
    $TimeBegin = Get-Date
    Start-Transcript -Path "$env:TEMP\AzureDeployment\$ApplicationName.txt" -Force -Verbose
    Write-Host "Starting with prechecks, then deploying..." -ForegroundColor Cyan
    ## Check Azure CLI is installed
    Write-Host "Checking if Azure CLI is installed..." -ForegroundColor Cyan
    if (!(cmd /c az --version)) {
      Write-Host "Azure CLI is missing, installing latest version..."
      $AzPSurl = "https://aka.ms/installazurecliwindows"
      Invoke-WebRequest -Uri $AzPSurl -OutFile "$env:TEMP\AzureCLI.msi" -Verbose
      $AzInstallerArgs = @{
        FilePath     = 'msiexec.exe'
        ArgumentList = @(
          "/i $env:TEMP\AzureCLI.msi",
          "/qr",
          "/l* $env:TEMP\AzureCLI.log"
        )
        Wait         = $true
      }
      Start-Process @AzInstallerArgs -NoNewWindow
      Remove-Item -Path "$env:TEMP\AzureCLI.msi" -Verbose
    }
    else {
      Write-Host "Azure CLI is present, do you want to check for update or continue?"
    }
    ## Option to update Azure CLI
    $Choice = $(Write-Host "Continue[ c ] | Upgrade[ u ] | Exit [ x ]" -NoNewLine -ForegroundColor Cyan ; Read-Host)
    switch ($Choice) {
      { $Choice -eq 'c' } {
        Write-Host "Continuing without Bicep upgrade check..." -ForegroundColor Cyan
        continue      
      }
      { $Choice -eq 'u' } {
        Write-Host "Performing upgrade, please wait..." -ForegroundColor Cyan
        az config set auto-upgrade.prompt=yes --verbose
        az upgrade --verbose
      }
      { $Choice -eq 'x' } {
        Write-Host "Exiting script!" -ForegroundColor DarkRed ; Stop-Transcript ; exit
      }
      default {
        Write-Warning "Incorrect key pressed..."
        Write-Host "Press CTRL-C to cancel or ENTER to continue!" -ForegroundColor DarkYellow ; pause
      }
    }
    ## Login to Azure via Azure CLI
    if (!(az account show)) {
      Write-Host "Not logged in, logging in..." -ForegroundColor DarkGreen
      az login --verbose
    }
    else {
      Write-Host "Logged in, continuing..." -ForegroundColor Green
    }
    Write-Output "Time taken finish prerequisites: $((Get-Date).Subtract($TimeBegin).Duration() -replace ".{8}$")"  
  }
  PROCESS {
    ## Replace and reuse Bicep file
    $BicepFile = "$PSScriptRoot\main.bicep"
    $BicepFileOrigin = "$PSScriptRoot\main_origin.bicep"  
    $GetOrgBicep = Get-Content -Path $BicepFileOrigin
    $GetBicep = Get-Content -Path $BicepFile
    Set-Content -Path $BicepFile -Value $GetOrgBicep -Verbose
    $GetBicep | Foreach-Object {
      $_ -replace "YourApplicationName", $ApplicationName `
        -replace "YourLocation", $Location `
        -replace "YourEnvironment", $Environment `
        -replace "000", $InstanceNumber `
        -replace "APPINSIGHTS_INSTRUMENTATIONKEY", $AppInsightsInstrumenKey `
        -replace "azure_storage_connectionstring", $StorageConnectionString `
        -replace "azure_storage_account_name", $StorageAccountName `
        -replace "azure_storage_account_key", $StorageAccountKey `
        -replace "DATABASE_URL", $DatabaseURL `
        -replace "DATABASE_USERNAME", $DatabaseUser `
        -replace "DATABASE_PASSWORD", $DatabasePass
    }
    Set-Content -Path $BicepFile -Value $GetBicep -Verbose
    $TimeDeploy = Get-Date
    Write-Host "Starting deployment, please wait as it can take a while..." -ForegroundColor Cyan
    ## Execute Azure Resource deployment with Azure CLI
    az deployment sub create -f .\main.bicep `
      --location $Location `
      --template-file .\main.bicep `
      --verbose `
      --parameters `
      environment=$Environment `
      applicationName=$ApplicationName `
      location=$Location `
      instanceNumber=$InstanceNumber
  }
  END {
    ## Clean up and close connection...
    Write-Output "Time taken to instantiate Azure Resources: $((Get-Date).Subtract($TimeDeploy).Duration() -replace ".{8}$")"
    Clear-Variable -Name DatabaseURL, DatabaseUser, DatabasePass -Force -Verbose
    Write-Host "Closing connecting with Azure..." -ForegroundColor DarkYellow
    az logout --verbose
    Clear-History -Verbose
    Stop-Transcript
  }
}

rg-asp-app-ai-psql-st