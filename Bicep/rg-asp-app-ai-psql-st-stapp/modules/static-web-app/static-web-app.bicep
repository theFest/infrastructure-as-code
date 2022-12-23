@description('The name of your application')
param applicationName string

@description('The environment (dev, test, stage or prod')
@maxLength(5)
param environment string

@description('The number of this specific instance')
@maxLength(3)
param instanceNumber string

@allowed([ 'centralus', 'eastus2', 'eastasia', 'westeurope', 'westus2' ])
param location string

param stapp string = 'stapp-${applicationName}-${environment}-${instanceNumber}'

// Reference: https://learn.microsoft.com/en-us/azure/templates/microsoft.web/staticsites?pivots=deployment-language-bicep
resource staticwebApplication 'Microsoft.Web/staticSites@2021-03-01' = {
    name: stapp
    location: location
    properties: {
        stagingEnvironmentPolicy: 'Enabled'
        allowConfigFileUpdates: true
    }
    sku: {
        tier: 'Free'
        name: 'Free'
    }
    tags: resourceGroup().tags
}

output staticwebapp string = staticwebApplication.name
