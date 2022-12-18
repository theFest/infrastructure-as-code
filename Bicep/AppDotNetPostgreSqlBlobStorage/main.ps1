$ApplicationName = "TestApp$(Get-Random)"
$Environment = "dev"
$Location = "westeurope"  

az deployment sub create `
  --location $Location `
  --template-file .\main.bicep `
  --parameters environment=$Environment applicationName=$ApplicationName location=$Location `
  --verbose