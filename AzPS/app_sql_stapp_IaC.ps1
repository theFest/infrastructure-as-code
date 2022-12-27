#--------------------------------------------------[IaC with CI/CD]--------------------------------------------------#
#requires -version 5.1
<#
.SYNOPSIS
  Function that instantiates, creates and modifies Azure Resources, GitHub Pipelines and more.

.DESCRIPTION
  Elements involved that currently work:
  Azure
  Web App 
  Web App SP
  Web App AI
  SQL Server
  SQL Database
  Static Web App
  Deployemnt from GitHub
  Pipeline creation on GitHub
  Ci/Cd ends with success
  ...

.NOTES
  Version           : 0.2.4
  Author            : Fest White
  Written by        : Fest White
  Company           : FW
  Creation Date     : 10/12/2023
  Script Complexity : Basic
  Purpose/Change    : IaC from GitHub to Azure via Azure PowerShell
#>

#------------------------------------------------------[FUNCTIONS]-------------------------------------------------------#

Function app_sql_stapp_IaC {
  <# Notes, helpers, intructions...
  Get-Help -Name Microsoft.Web
  Deployment details: https://azure.github.io/AppService/2021/07/29/Deploying-Your-Infrastructure-to-App-Service.html
  Monitor Azure SQL Database: https://learn.microsoft.com/en-us/azure/azure-sql/database/scripts/monitor-and-scale-database-powershell?view=azuresql
  API for Azure Resources: API version are different for each Azure Resource type(versions constantly change as Azure evolves)
  ValidaPattern(regex) = [a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}
  MSI Azure PS releases here: https://github.com/Azure/azure-powershell/releases
  Modules check command: $env:PSModulePath (Set-PSRepository -Name)
  Second option where we silently install with MSI package is currently unused
  Use 'isGitHubAction = $true;' only when you combine it with GitHub Actions secrets, can be done either via GitHub CLI or Deployment profile
  When using 'isManualIntegration = $false', it means geeting code from a private repo

  [Future::Improvements](some will be optional(switch))
  -Apply PS parametars sets
  -Verification on all level and types
  -Implement GitHub CLI to interact with GitHub
  -Keyvault implementation with Service Connector
  -Virtual Network integration, secure private endpoint
  -Storage addon, either File or Blob if application demands
  -Send result in a form of a report to e-mail, remote filesystem, Azure or GitHub
  ....
  #>
  [CmdletBinding()]
  param(
    [Parameter(Position = 0, Mandatory = $false, HelpMessage = "Verify Tenant")]
    #[ValidateSet("guid1", "guid2")]
    [guid]$Tenant = "guid1",

    [Parameter(Position = 1, Mandatory = $false, HelpMessage = "Verify Subscription in following order: guid1, guid2")]
    [ValidateSet("Visual Studio Enterprise Subscription", "Visual Studio Professional Subscription")] 
    [string]$Subscription = "Visual Studio Enterprise Subscription",

    [Parameter(Position = 2, ValueFromPipeline = $true, Mandatory = $true, HelpMessage = "Enter your Resource Group name")]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Enter Location, our standard is to use 'West Europe'(we'll do a combine in a script)")]
    [string]$Location = "West Europe",

    [Parameter(Mandatory = $true, HelpMessage = "Enter name of Azure Resource for API App / Web App")]
    [string]$AppServicename, #-->if not mandatory="App$(Get-Random)"

    [Parameter(Mandatory = $false, HelpMessage = "Supported API version for 'sites'(App Service / WebApps(REST APIs))")]
    [ValidateSet("2015-08-01", "2020-03-13", "2020-08-01")]
    [string]$AppServiceApiVersion = "2015-08-01", #-->[datetime] param.?

    [Parameter(Mandatory = $false, HelpMessage = "AppServicePlan's name will be same as AppService one, Tier is predefined to 'Free'")]
    [ValidateSet("Free", "Shared", "Basic", "Standard", "Premium")]
    [string]$AppServicePlanTier = "Free",    
  
    [Parameter(Mandatory = $true, HelpMessage = "Declare SQL Server name")]
    [string]$SqlServerName,

    [Parameter(Mandatory = $false, HelpMessage = "Declare SQL Database name")]
    [string]$SqlDatabaseName,

    [Parameter(Mandatory = $true, HelpMessage = "Create an SQL username")]
    [string]$AdminSqlLogin,

    [Parameter(Mandatory = $true, HelpMessage = "Define a SQL password")]
    [string]$AdminSqlPassword,

    [Parameter(Mandatory = $false, HelpMessage = "Start IP address range that you want to allow to access your server")]
    [ipaddress]$SqlAllowedStartIP = "0.0.0.0", #= "0.0.0.0",

    [Parameter(Mandatory = $false, HelpMessage = "End IP address range that you want to allow to access your server")]
    [ipaddress]$SqlAllowedEndIP = "0.0.0.0", #= "0.0.0.0",

    [Parameter(Mandatory = $true, HelpMessage = "Enter name or Azure Resource for Client app")]
    [string]$StaticWebAppName,

    [Parameter(Mandatory = $false, HelpMessage = "Supported API version for 'staticSites'")]
    [ValidateSet("2019-08-01", "2020-06-01", "2020-09-01", "2020-10-01", "2020-12-01", "2021-01-01", "2021-01-15", "2021-02-01", "2021-03-01", "2022-03-01")]
    [string]$StaticSiteApiVersion = "2022-03-01", #-->[datetime] param.?

    [Parameter(Mandatory = $true, HelpMessage = "Relative path where Client app resides in your project")]
    [string]$StaticWebAppPath,

    [Parameter(Mandatory = $false, HelpMessage = "API path of your project, leave blank")]
    [string]$StaticWebAppAPIPath = "",

    [Parameter(Mandatory = $true, HelpMessage = "Relative path of Client's app output path")]
    [string]$StaticWebAppOutputPath,

    [Parameter(Mandatory = $false, HelpMessage = "Hosting Plan(Sku) for 'Static Web App'")]
    [ValidateSet("Free", "Standard")]
    [string]$StaticWebAppHostingPlan = "Free",

    [Parameter(Mandatory = $true, HelpMessage = "Enter GitHub Repository name")]
    [uri]$GitHubRepo,

    [Parameter(Mandatory = $false, HelpMessage = "Enter GitHub Repository Branch name")]
    [ValidateSet("main", "master")]
    [string]$GitHubRepoBranch = "main",

    [Parameter(Mandatory = $true, HelpMessage = "Enter GitHub's Personal Access Token")]
    [string]$GitHubPAT
  ) 
  BEGIN {
    $StartTime = Get-Date
    New-Item -Path $env:TEMP -Name AzureDeployment -ItemType Directory -Force -Verbose | Out-Null
    Start-Transcript -Path "$env:TEMP\AzureDeployment\AdfPSAzure.txt" -Append
    ## Verify and sign Execution policy
    if ((Get-ExecutionPolicy) -eq "Restricted") {
      Write-Verbose -Message "Execution policy is set to 'Restriced, changing to 'RemoteSigned'..."      
      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -Verbose  
      #exit
    }
    ## Check or update and/or install Module and MSI package.
    if (Get-InstalledModule -Name Az) {
      Write-Output "Azure Powershell is installed, checking for updates and continuing..."
      #Update-Module -Name Az -Force -Verbose
    }
    else {
      Write-Output "Azure Powershell module is missing. Installing via NuGet, please wait..."
      Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force -Verbose
      <# 
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls, ssl3"
    $AzPSurl = https://github.com/Azure/azure-powershell/releases/download/v9.0.1-October2022/Az-Cmdlets-9.0.1.36486-x64.1.msi 
    Invoke-WebRequest -Uri $AzPSurl -OutFile "$env:TEMP\Az-Cmdlets-9.0.1.36486-x64.1.msi" -Verbose
    $AzInstallerArgs = @{
        FilePath     = 'msiexec.exe'
        ArgumentList = @(
            "/i $env:TEMP\Az-Cmdlets-9.0.1.36486-x64.1.msi",
            "/qr",
            "/l* $env:TEMP\Az-Cmdlets.log"
        )
        Wait         = $true
    }
    Start-Process @AzInstallerArgs -NoNewWindow
    #>
    }
    ## Connect interactively to Azure and check other options and information prior to execution....
    Write-Host "Checking authentification context against Azure..." -ForegroundColor Cyan
    $CheckLogin = Get-AzContext #-->(Get-AzContext).Account
    if (!($CheckLogin.Subscription.Name -eq $Subscription)) {
      Write-Host "You're not connected to Azure, please login interactively..." -ForegroundColor Yellow
      Connect-AzAccount -Verbose
    }
    Stop-Transcript
  }
  PROCESS {
    ## Checks prior to creation and deplomenty...
    Start-Transcript -Path "$env:TEMP\AzureDeployment\AdfPSAzure.txt" -Append
    if (Get-AzResourceGroup -Name $ResourceGroup -Location $Location -ErrorAction SilentlyContinue) {
      Write-Host "INFO: Resource Group: $ResourceGroup does exist, what do you wanna do ?" -ForegroundColor Yellow
      Write-Host "<-×××××××××××××××××××××××××××××××××××××××× [ Choose an operation to continue ] ××××××××××××××××××××××××××××××××××××××××->" -ForegroundColor Cyan
      $Choice = $(Write-Host "Remove and Redeploy(r) | Pause or Continue (p) | Stop and Exit(x)" -NoNewLine -ForegroundColor Cyan ; Read-Host)
      switch ($Choice) {
        { $Choice -eq 'r' } {
          Write-Host "WARNING: Removing resources and starting fresh deploy, please wait..."
          Remove-AzResourceGroup $ResourceGroup -ErrorAction SilentlyContinue -Force -Verbose
        }
        { $Choice -eq 'p' } {
          Write-Host "Press CTRL-C to cancel." ; pause      
        }
        { $Choice -eq 'x' } {
          Write-Host "Exiting..."  ; Stop-AzDeployment -Name * -ErrorAction SilentlyContinue -Verbose ; exit
        }
        default {
          Write-Warning "WARNING: Unknown warning, incorrect key pressed..."
        }
      } 
    }   
    Write-Warning "Starting in $Tleft seconds..."
    for ($Tleft = 3; $Tleft -gt 0; $Tleft--) {
      Write-Host "$Tleft seconds left"
      Start-Sleep -Seconds 1
    }
    try {
      Write-Verbose -Message "Creating new Resource group: $ResourceGroup"
      New-AzResourceGroup -Name $ResourceGroup -Location $Location -Force -Verbose
      Start-Sleep -Seconds 5
    }
    catch {
      Write-Error $_.Exception.Message
    }
    finally {
      Write-Verbose -Message "Verifiying newly created Resource group: $ResourceGroup"
      Get-AzResourceGroup -Name AADTesting | Out-Null
      Write-Verbose -Message "Verification finished"
    }
    Stop-Transcript ; Start-Transcript -Path "$env:TEMP\AzureDeployment\AdfPSAzure.txt" -Append   
    Write-Output "INFO: No AppService plan detected with that name, creating..."
    New-AzAppServicePlan -ResourceGroupName $ResourceGroup -Name $AppServiceName -Location $Location -Tier $AppServicePlanTier -ErrorAction SilentlyContinue -Verbose
    Write-Output "INFO: Name available for WebApp: $AppServiceName, cleaning and creating...."
    New-AzWebApp -Name $AppServiceName -Location $Location -AppServicePlan $AppServiceName -ResourceGroupName $ResourceGroup -Verbose
    ## Starting API Resource(Azure App Service/Web App) creation | deployment...
    Write-Host "INFO: Instantiating API app(backend) Azure resources | deployment..." -ForegroundColor Green
    #$SecuredPAT = ConvertTo-SecureString $GitHubPAT -AsPlainText -Force
    $PropertiesObject = @{
      token = $GitHubPAT;
      #tokenSecret  = "";
      #refreshToken = "";
      #environment  = "";
    }
    Set-AzResource -PropertyObject $PropertiesObject `
      -ResourceId /providers/Microsoft.Web/sourcecontrols/GitHub -ApiVersion $AppServiceApiVersion -Force -Verbose
    $PropertiesObject = @{
      repoUrl             = $GitHubRepo;
      branch              = $GitHubRepoBranch;
      isManualIntegration = $false; # $False when using a private repo
      isGitHubAction      = $false;
      #deploymentRollbackEnabled = $false;
      #isMercurial = $false;
      #provisioningState = ""; 
      #gitHubActionConfiguration = "";
    }
    Set-AzResource -PropertyObject $PropertiesObject -ResourceGroupName $ResourceGroup `
      -ResourceType Microsoft.Web/sites/sourcecontrols -ResourceName $AppServiceName/web `
      -ApiVersion $AppServiceApiVersion -Force -Verbose #-->kind, should we define?
    Write-Verbose -Message "Creating, enabling and modifiying new Application insights..."
    New-AzApplicationInsights -Kind 'web' -ResourceGroupName $ResourceGroup -Name $AppServiceName -location westeurope -ApplicationType 'web'
    $AiResource = Get-AzResource -Name $AppServiceName -ResourceGroupName $ResourceGroup -ResourceType "Microsoft.Insights/components"
    $AiDetails = Get-AzResource -ResourceId $AiResource.ResourceId
    $AiKey = $AiDetails.Properties.InstrumentationKey
    $AiSetting = @{"ApplicationInsightsAgent_EXTENSION_VERSION" = "~3" ; "APPINSIGHTS_INSTRUMENTATIONKEY" = $AiKey }
    Set-AzWebApp -AppSettings $AiSetting -Name $AppServiceName -ResourceGroupName $ResourceGroup -AppServicePlan $AppServiceName
    ## Starting Database Resource(Azure SQL Server and Database) creation | deployment...
    New-AzSqlServer -ResourceGroupName $ResourceGroup `
      -ServerName $SqlServerName `
      -Location $Location `
      -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AdminSqlLogin, $(ConvertTo-SecureString -String $AdminSqlPassword -AsPlainText -Force))
    New-AzSqlServerFirewallRule -ResourceGroupName $ResourceGroup `
      -ServerName $SqlServerName `
      -FirewallRuleName "AllowedIPs" -StartIpAddress $SqlAllowedStartIP -EndIpAddress $SqlAllowedEndIP
    if ($SqlDatabaseName) {
      New-AzSqlDatabase  -ResourceGroupName $ResourceGroup `
        -ServerName $SqlServerName `
        -DatabaseName $SqlDatabaseName `
        -RequestedServiceObjectiveName "S0" `
        -SampleName "AdventureWorksLT" #-->predifined sample!
    }
    ## Starting Client Resource(Azure Static Web App) creation | deployment...
    Write-Host "INFO: Instantiating Client app(frontnend) Azure resources | deployment..." -ForegroundColor Green
    $Location = ("West Europe" -replace '\s', '').ToLower()
    New-AzStaticWebApp -ResourceGroupName $ResourceGroup -Name $StaticWebAppName -Location $Location `
      -RepositoryUrl $GitHubRepo -RepositoryToken $GitHubPAT -Branch $GitHubRepoBranch `
      -AppLocation $StaticWebAppPath -ApiLocation $StaticWebAppAPIPath -OutputLocation $StaticWebAppOutputPath -SkuName $StaticWebAppHostingPlan
    Set-AzResource -PropertyObject $PropertiesObject -ResourceGroupName $ResourceGroup -ResourceType Microsoft.Web/staticSites -ResourceName $StaticWebAppName -ApiVersion $StaticSiteApiVersion -Force -Verbose
    Stop-Transcript ; Start-Transcript -Path "$env:TEMP\AzureDeployment\AdfPSAzure.txt" -Append
  }
  END {
    Write-Host "INFO: Cleaning up and finishing..." -ForegroundColor DarkCyan
    Clear-Variable -Name GitHubPAT -Force -Verbose
    $PropertiesObject.Clear()
    Clear-History -Verbose
    Write-Host "INFO: Closing connecting with Azure..." -ForegroundColor DarkYellow
    Disconnect-AzAccount -Verbose
    return "INFO: Time taken to complete IaC, deployment and CI/CD with PowerShell; $((Get-Date).Subtract($StartTime).Duration() -replace ".{8}$")"
    Stop-Transcript
  }
}

<# uncomment this, enter mandatory information with your PAT to run this function
app_sql_stapp_IaC `
  -ResourceGroup "rg-testing-app" `
  -AppServicename "APIApp$(Get-Random)" `
  -SqlServerName "sqlserver-2023$(Get-Random)" `
  -AdminSqlLogin "ChangeYourTestingPhaseUsername2023" `
  -AdminSqlPassword "ChangeYourTestingPhasePassword2023" `
  -SqlDatabaseName "testing-database" `
  -StaticWebAppName "ClientApp$(Get-Random)" `
  -StaticWebAppPath "ClientApp" `
  -StaticWebAppOutPutPath "dist/client" `
  -GitHubRepo "https://github.com/your_user/your_repo" `
  -GitHubRepoBranch "main" `
  -GitHubPAT "your_pat_goes_here" `
  -Verbose
#>