@description('The name of your application')
param applicationName string

@description('The environment (dev, test, stage or prod')
@maxLength(5)
param environment string

@description('The Azure region where all resources in this example should be created')
param location string

@description('A list of tags to apply to the resources')
param resourceTags object

@description('The number of this specific instance')
@maxLength(3)
param instanceNumber string

var appInsightsResourceName = 'ai-${applicationName}-${environment}-${instanceNumber}'

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsResourceName
  location: location
  tags: resourceTags
  kind: 'web'
  properties: {
    Application_Type: 'Node.JS'
  }
}

output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
