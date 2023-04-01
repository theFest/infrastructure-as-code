//targetScope = 'resourceGroup'

@description('The name of your application')
param applicationName string

@description('The environment (dev, test, prod, ...')
@maxLength(4)
param environment string //= 'dev'

@description('The number of this specific instance')
@maxLength(3)
param instanceNumber string //= '001'

@description('The Azure region where all resources in this example should be created')
param location string

@description('A list of tags to apply to the resources')
param tags object

@description('The name of the PostgreSQL Flexible server.')
param serverName string = 'psql-${applicationName}-${environment}-${instanceNumber}'

@description('The name of a database inside the PostgreSQL Flexible server.')
param databaseName string = applicationName

@description('The administrator username of the PostgreSQL Flexible server.')
param administratorLogin string = 'sql${replace(applicationName, '-', '')}root'

@description('The administrator password of the PostgreSQL Flexible server.')
@secure()
param administratorPassword string = newGuid()

@description('The high availability setting for the PostgreSQL Flexible server.')
@allowed([
  'Disabled'
  'SameZone'
  'ZoneRedundant'
])
param highAvailability string = 'Disabled'

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '14'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    storage: {
      storageSizeGB: 128
    }
    highAvailability: {
      mode: highAvailability
    }
  }

  resource database 'databases' = {
    name: databaseName
  }

  resource firewallAzure 'firewallRules' = {
    name: 'AllowAzureServices'
    properties: {
      endIpAddress: '0.0.0.0'
      startIpAddress: '0.0.0.0'
    }
  }
}

output db_url string = postgresServer.properties.fullyQualifiedDomainName
output db_username string = administratorLogin
#disable-next-line outputs-should-not-contain-secrets //disable warning
output db_password string = administratorPassword
