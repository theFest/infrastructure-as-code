targetScope = 'subscription'

param environment string = 'YourEnvironment'
param applicationName string = 'YourApplicationName'
param location string = 'YourLocation'
var instanceNumber = '000'

var defaultTags = {
  environment: environment
  application: applicationName
}

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${applicationName}-${instanceNumber}'
  location: location
  tags: defaultTags
}

module instrumentation 'modules/application-insights/app-insights.bicep' = {
  name: 'instrumentation'
  scope: resourceGroup(rg.name)
  params: {
    location: location
    applicationName: applicationName
    environment: environment
    instanceNumber: instanceNumber
    resourceTags: defaultTags
  }
}

module blobStorage 'modules/storage-blob/storage.bicep' = {
  name: 'storage'
  scope: resourceGroup(rg.name)
  params: {
    location: location
    applicationName: applicationName
    environment: environment
    resourceTags: defaultTags
    instanceNumber: instanceNumber
  }
}

module database 'modules/postgresql/postgresql.bicep' = {
  name: 'sqlDb'
  scope: resourceGroup(rg.name)
  params: {
    location: location
    applicationName: applicationName
    environment: environment
    tags: defaultTags
    instanceNumber: instanceNumber
  }
}

var applicationEnvironmentVariables = [
  // You can add your custom environment variables here
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: instrumentation.outputs.appInsightsInstrumentationKey
  }
  {
    name: 'azure_storage_account_name'
    value: blobStorage.outputs.storageAccountName
  }
  {
    name: 'azure_storage_account_key'
    value: blobStorage.outputs.storageKey
  }
  {
    name: 'azure_storage_connectionstring'
    value: 'DefaultEndpointsProtocol=https;AccountName=${blobStorage.outputs.storageAccountName};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${blobStorage.outputs.storageKey}'
  }
  {
    name: 'DATABASE_URL'
    value: database.outputs.db_url
  }
  {
    name: 'DATABASE_USERNAME'
    value: database.outputs.db_username
  }
  {
    name: 'DATABASE_PASSWORD'
    value: database.outputs.db_password
  }
]

module function 'modules/function/function.bicep' = {
  name: 'function'
  scope: resourceGroup(rg.name)
  params: {
    location: location
    applicationName: applicationName
    environment: environment
    resourceTags: defaultTags
    instanceNumber: instanceNumber
    environmentVariables: applicationEnvironmentVariables
  }
}
