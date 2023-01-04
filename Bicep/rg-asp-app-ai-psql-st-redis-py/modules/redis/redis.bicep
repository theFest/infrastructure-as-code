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

var redisName = 'redis-${applicationName}-${environment}-${instanceNumber}'

resource redis 'Microsoft.Cache/Redis@2018-03-01' = {
  name: redisName
  location: location
  tags: resourceTags
  properties: {
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    sku: {
      capacity: 0
      family: 'C'
      name: 'Standard'
    }
  }
}

output redis_host string = redis.properties.hostName
output redis_key string = redis.properties.accessKeys.primaryKey
