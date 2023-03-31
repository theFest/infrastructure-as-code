function DeployViaTerraform {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        [Parameter(Mandatory = $false)]
        [string]$ClientId,
        [Parameter(Mandatory = $false)]
        [string]$ClientSecret
    )
    Clear-Host
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
    if (!(az account show)) {
        Write-Host "Not logged in, logging in..."
        az login --verbose
        az account set --name "Visual Studio Enterprise Subscription" --verbose
    }
    else {
        Write-Host "Logged in, continuing..."
    }
    <#
    # Validate the configuration path
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuration path not found: $ConfigPath"
        return
    }
    #>
    if ($ClientId -or $ClientSecret) {
        # Authenticate with Azure using a service principal
        if (-not ($ClientId -and $ClientSecret)) {
            $Credential = Get-Credential -Message "Enter the credentials for a service principal with access to the Azure subscription"
            $ClientId = $Credential.UserName
            $ClientSecret = $Credential.Password | ConvertFrom-SecureString
        }
        Add-AzAccount -ServicePrincipal -Tenant $TenantId -Credential (New-Object System.Management.Automation.PSCredential ($ClientId, ($ClientSecret | ConvertTo-SecureString -AsPlainText -Force)))
    }

    ## Change to the directory containing the Terraform configuration files
    Set-Location -Path $ConfigPath

    ## Initialize the Terraform working directory
    Write-Host "Initializing Terraform..." -ForegroundColor Yellow
    terraform init

    ## Apply the Terraform configuration and wait for the deployment to complete
    Write-Host "Applying Terraform configuration..." -ForegroundColor Yellow
    terraform apply -auto-approve

    ## Get the outputs from the Terraform state file
    $Outputs = terraform output -json

    ## Display the outputs
    Write-Host "Deployment complete. Outputs:" -ForegroundColor Green
    $Outputs | ConvertFrom-Json
}

DeployViaTerraform -ConfigPath .\
