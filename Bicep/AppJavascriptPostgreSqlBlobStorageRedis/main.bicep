targetScope = 'subscription'

// If an environment is set up (dev, test, prod...), it is used in the application name
param environment string = 'dev'
param applicationName string = 'demo-1561-5711'
param location string = 'westeurope'
var instanceNumber = '001'

var defaultTags = {
  'environment': environment
  'application': applicationName
  'nubesgen-version': 'undefined'
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

module redis 'modules/redis/redis.bicep' = {
  name: 'redis'
  scope: resourceGroup(rg.name)
  params: {
    location: location
    applicationName: applicationName
    environment: environment
    resourceTags: defaultTags
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
      {
        name: 'REDIS_HOST'
        value: redis.outputs.redis_host
      }
      {
        name: 'REDIS_PASSWORD'
        value: redis.outputs.redis_key
      }
      {
        name: 'REDIS_PORT'
         value: '6380'
      }
]

module webApp 'modules/app-service/app-service.bicep' = {
  name: 'webApp'
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

output application_name string = webApp.outputs.application_name
output application_url string = webApp.outputs.application_url
output resource_group string = rg.name
