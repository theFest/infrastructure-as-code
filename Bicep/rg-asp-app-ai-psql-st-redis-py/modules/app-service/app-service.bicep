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

@description('An array of NameValues that needs to be added as environment variables')
param environmentVariables array

@description('A list of tags to apply to the resources')
param resourceTags object

var appServicePlanName = 'plan-${applicationName}-${instanceNumber}'

resource appServicePlan 'Microsoft.Web/serverFarms@2020-12-01' = {
  name: appServicePlanName
  location: location
  tags: resourceTags
  kind: 'linux'
  properties: {
    reserved: true
  }
  sku: {
    tier: 'Free'
    name: 'F1'
  }
}

// Reference: https://docs.microsoft.com/azure/templates/microsoft.web/sites?tabs=bicep
resource appServiceApp 'Microsoft.Web/sites@2020-12-01' = {
  name: 'app-${applicationName}-${environment}-${instanceNumber}'
  location: location
  tags: resourceTags
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {

      ftpsState: 'FtpsOnly'
      http20Enabled: true
      minTlsVersion: '1.2'
      appSettings: union(environmentVariables, [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: false
        }
        ])
      }
    }
}

output application_name string = appServiceApp.name
output application_url string = appServiceApp.properties.hostNames[0]
