<# !!! WORKING | ver 0.1 !!! #>

<# RG App Service plan + Web App + App Insights + SQL Server + SQL Database + KeyVault with connections #>

<# HELPERS
    ## Get all application runtimes
    #az webapp list-runtimes
    ## Get all subscriptions
    #az account list --all --verbose | Write-Host -ForegroundColor Green
    ## Get subscription id or name
    #$SubscriptionID = az account show --query id --output tsv | Write-Host -ForegroundColor Cyan
#>

##################################################-----> BEGIN Your Variables <-----##################################################
$ApplicationName = "$(Get-Random)"
$Environment = "dev"
$InstanceNumber = '001'
$ResourceGroup = "rg-$($ApplicationName)"
$Location = "westeurope"
$Sku = "F1"
$AppServicePlan = "asp-$($ApplicationName)-$Environment-$InstanceNumber"
$AppServiceName = "app-$($ApplicationName)-$Environment-$InstanceNumber"
$AppInsightsName = "ai-$($ApplicationName)-$Environment-$InstanceNumber"
$AppRuntime = "dotnet:6"
$SqlServerName = "sql-$(Get-Random)-$Environment-$InstanceNumber"
$SqlDatabaseName = "sqldb-$(Get-Random)-$Environment-$InstanceNumber"
$AdminSqlLogin = "DeclareYourDBUsername2023"
$AdminSqlPassword = "DeclareYourDBPassword2023"
$StaticWebAppName = "stapp-$(Get-Random)-$Environment-$InstanceNumber"
$KeyVaultName = "kv-$($ApplicationName)-$Environment-$InstanceNumber"
##################################################-----> END Your Variables <-----##################################################

## BEGIN Script
Start-Transcript -Path "$env:TEMP\AzureDeployment\$ApplicationName.txt" -Force -Verbose
Write-Host "Starting with prechecks, then deploying..." -ForegroundColor DarkCyan
## Check Azure CLI
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
    Write-Host "Azure CLI is present, ckecking for latest version and continuing..."
}
az config set auto-upgrade.prompt=yes --verbose
az upgrade --verbose
if (!(az account show)) {
    Write-Host "Not logged in, logging in..."
    az login --verbose
}
else {
    Write-Host "Logged in, continuing..."
}

$StartTime = Get-Date
## Create a resource group
Write-Host "Creating a Resource Group..." -ForegroundColor Yellow
az group create `
    --name $ResourceGroup `
    --location $Location `
    --verbose | Write-Host -ForegroundColor Green

## Create an app service plan
Write-Host "Creating an App Service plan..." -ForegroundColor Yellow
az appservice plan create `
    --name $AppServicePlan `
    --resource-group $ResourceGroup `
    --sku $Sku `
    --verbose ` | Write-Host -ForegroundColor Cyan

## Create a web app
Write-Host "Creating Web App..." -ForegroundColor Yellow
az webapp create `
    --name $AppServicename `
    --resource-group $ResourceGroup `
    --plan $AppServicePlan `
    --runtime $AppRuntime `
    --verbose | Write-Host -ForegroundColor Cyan

## Create web app insights
Write-Host "Creating Web App Insights..." -ForegroundColor Yellow
az monitor app-insights component create `
    --app $AppInsightsName `
    --location $Location `
    --kind web -g $ResourceGroup `
    --application-type web `
    --retention-time 120 `
    --verbose | Write-Host -ForegroundColor Cyan

## Enable web app insights
Write-Host "Enabling and connecting App Insights to Web App..." -ForegroundColor Yellow
az monitor app-insights component connect-webapp `
    --resource-group $ResourceGroup `
    --app $AppInsightsName `
    --web-app $AppServicename `
    --enable-profiler `
    --enable-snapshot-debugger false `
    --verbose | Write-Host -ForegroundColor Cyan

## Create an Azure SQL server
Write-Host "Create an Azure SQL server..." -ForegroundColor Yellow
az sql server create `
    --name $SqlServerName `
    --resource-group $ResourceGroup `
    --location $Location `
    --admin-user $AdminSqlLogin `
    --admin-password $AdminSqlPassword `
    --verbose | Write-Host -ForegroundColor Cyan

## Create an Azure SQL database
Write-Host "Creating an Azure SQL database..." -ForegroundColor Yellow
az sql db create `
    --name $SqlDatabaseName `
    --resource-group $ResourceGroup `
    --server $SqlServerName `
    --service-objective Basic `
    --verbose | Write-Host -ForegroundColor Cyan

## Create a static web app
Write-Host "Creating a static web app..." -ForegroundColor Yellow
az staticwebapp create `
    --name $StaticWebAppName `
    --resource-group $ResourceGroup `
    --location $Location `
    --verbose | Write-Host -ForegroundColor Cyan

## Connect the web app to the SQL database
Write-Host "Connecting the web app to the SQL database..." -ForegroundColor Yellow
az webapp config connection-string set `
    --resource-group $ResourceGroup `
    --name $AppServicename `
    --connection-string-type mysql `
    --settings mysqlsetting="Server=$SqlServerName;Database=$SqlDatabaseName;Uid=$AdminSqlLogin;Pwd=$AdminSqlPassword;" `
    --verbose | Write-Host -ForegroundColor Cyan

## Add connection string to web app
Write-Host "Adding connection string to Web App..." -ForegroundColor Yellow
$ConnString = $(az sql db show-connection-string `
        --name $SqlDatabaseName `
        --server $SqlServerName `
        --client ado.net `
        --output tsv)

## Add credentials to connection string
Write-Host "Adding credentials to connectionstring..." -ForegroundColor Yellow
$ConnString = ${connstring//$AdminSqlLogin/$login}
$ConnString = ${connstring//$AdminSqlPassword/$password}

## Assign the connection string to an app setting in the web app
Write-Host "Adding connectionstring to Web App settings..." -ForegroundColor Yellow
az webapp config appsettings set --name $AppServicename `
    --resource-group $ResourceGroup `
    --settings "SQLSRV_CONNSTR=$ConnString"

## Create KeyVault and connect Database, Web App and KeyVault
Write-Host "Creating KeyVault..." -ForegroundColor Yellow
az keyvault create `
    --name $KeyVaultName `
    --resource-group $ResourceGroup `
    --verbose | Write-Host -ForegroundColor Cyan
Write-Host "Adding secrets to KeyVault..." -ForegroundColor Yellow
az keyvault secret set `
    --description "DatabaseCreds" `
    --name $AdminSqlLogin `
    --value $AdminSqlPassword `
    --vault-name $KeyVaultName `
    --verbose | Write-Host -ForegroundColor Cyan
Write-Host "Connecting KeyVault, Database and Web App..." -ForegroundColor Yellow
az webapp config connection-string set `
    --name $AppServiceName `
    --resource-group $ResourceGroup `
    --settings mysqlsetting `
    --connection-string-type SQLAzure `
    --Verbose | Write-Host -ForegroundColor Cyan

## END Script
Write-Host "Cleaning, then finishing..." -ForegroundColor DarkCyan
Clear-Variable -Name AdminSqlLogin, AdminSqlPassword -Force -Verbose
Clear-History -Verbose
Write-Host "Closing connecting with Azure..." -ForegroundColor DarkYellow
az logout --verbose
Stop-Transcript
Write-Output "Time taken to query requested URL: $Url $((Get-Date).Subtract($StartTime).Duration() -replace ".{8}$")"