// PostgreSQL - Bicep module
// Generated by NubesGen (www.nubesgen.com)

@description('The name of your application')
param applicationName string

@description('The environment (dev, test, prod, ...')
@maxLength(4)
param environment string = 'dev'

@description('The number of this specific instance')
@maxLength(3)
param instanceNumber string = '001'

@description('The Azure region where all resources in this example should be created')
param location string

@description('A list of tags to apply to the resources')
param tags object

@description('The name of the SQL logical server.')
param serverName string = 'psql-${applicationName}-${environment}-${instanceNumber}'

@description('The name of the SQL Database.')
param sqlDBName string = applicationName

@description('The administrator username of the SQL logical server.')
param administratorLogin string = 'sql${replace(applicationName, '-', '')}root'

@description('The administrator password of the SQL logical server.')
@secure()
param administratorPassword string = newGuid()

resource sqlServer 'Microsoft.DBforPostgreSQL/servers@2017-12-01' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: 'B_Gen5_1' 
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    createMode: 'Default'
    sslEnforcement: 'Enabled'
    storageProfile: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
      storageAutogrow: 'Enabled'
      storageMB: 5120
    }
    version: '11'
  }
}

resource sqlDatabase 'Microsoft.DBforPostgreSQL/servers/databases@2017-12-01' = {
  name: sqlDBName
  parent: sqlServer
  properties: {
    charset: 'UTF8'
    collation: 'English_United States.1252'
  }
}

resource symbolicname 'Microsoft.DBforPostgreSQL/servers/firewallRules@2017-12-01' = {
  name: 'AllowAzureServices'
  parent: sqlServer
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

output db_url string = sqlServer.properties.fullyQualifiedDomainName
output db_username string = administratorLogin
output db_password string = administratorPassword
