@description('The name of your application')
param applicationName string

@description('The environment (dev, test, stage or prod')
@maxLength(5)
param environment string

@description('The number of this specific instance')
@maxLength(3)
param instanceNumber string

@description('The Azure region where all resources in this example should be created')
param location string

@description('A list of tags to apply to the resources')
param resourceTags object

@description('The name of the container to create. Defaults to applicationName value.')
param containerName string = applicationName

var storageName = 'st${take(replace(applicationName, '-', ''),14)}${environment}${instanceNumber}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageName
  location: location
  tags: resourceTags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource storageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: '${storageAccount.name}/default/${containerName}'
}

output storageAccountName string = storageAccount.name
output id string = storageAccount.id
output apiVersion string = storageAccount.apiVersion
#disable-next-line outputs-should-not-contain-secrets
output storageKey string = listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
