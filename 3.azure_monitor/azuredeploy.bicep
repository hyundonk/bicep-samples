@description('Unique DNS Name for the Storage Account where the Virtual Machine\'s disks will be placed.')
param dnsLabelPrefix string

@description('User name for the Virtual Machine.')
param adminUsername string

@description('VM size')
param vmSize string = 'Standard_D2_v3'

@description('Data Collection Rule Name')
param dcrName string

@description('Log Analytics Workspace Name')
param logAnalyticsWorkspaceName string

@description('DCR Association Name')
param dcrAssociationName string

@description('Data Collection Endpoint Name')
param dataCollectionEndpointName string

@description('Data Collection Rule Name for custom log collection')
param dcrName_customlog string

@description('Log Analytics Custom Table Name')
param customtable_name string

@description('EventHub Namespace Name')
param eventHubNamespaceName string

@description('EventHub Name')
param eventHubName string

@description('The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version. Allowed values: 14.04-LTS,16.04-LTS,18.04-LTS,20.04-LTS.')
@allowed([
  '14.04-LTS'
  '16.04-LTS'
  '18.04-LTS'
  '20.04-LTS'
])

param ubuntuOSVersion string = '18.04-LTS'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'password'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

var storageAccountName_var = '${uniqueString(resourceGroup().id)}sacustmdata'
var imagePublisher = 'Canonical'
var imageOffer = 'UbuntuServer'
var nicName_var = 'networkInterface1'
var vmName_var = 'vm1'
var virtualNetworkName_var = 'virtualNetwork1'
var publicIPAddressName_var = 'publicIp1'
var addressPrefix = '10.0.0.0/16'
var subnet1Name = 'Subnet-1'
var subnet1Prefix = '10.0.0.0/24'
var publicIPAddressType = 'Dynamic'
var storageAccountType = 'Standard_LRS'
var apiVersion = '2015-06-15'
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}
var networkSecurityGroupName_var = 'default-NSG'

resource storageAccountName 'Microsoft.Storage/storageAccounts@2021-01-01' = {
  name: storageAccountName_var
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
}

resource publicIPAddressName 'Microsoft.Network/publicIPAddresses@2015-06-15' = {
  name: publicIPAddressName_var
  location: location
  properties: {
    publicIPAllocationMethod: publicIPAddressType
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

resource networkSecurityGroupName 'Microsoft.Network/networkSecurityGroups@2019-08-01' = {
  name: networkSecurityGroupName_var
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-22'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '22'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource virtualNetworkName 'Microsoft.Network/virtualNetworks@2015-06-15' = {
  name: virtualNetworkName_var
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnet1Name
        properties: {
          addressPrefix: subnet1Prefix
          networkSecurityGroup: {
            id: networkSecurityGroupName.id
          }
        }
      }
    ]
  }
}


resource nicName 'Microsoft.Network/networkInterfaces@2015-06-15' = {
  name: nicName_var
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddressName.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName_var, subnet1Name)
          }
        }
      }
    ]
  }
  dependsOn: [

    virtualNetworkName
  ]
}

resource vmName 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: vmName_var
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName_var
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? json('null') : linuxConfiguration)
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: ubuntuOSVersion
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicName.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: reference(storageAccountName_var, apiVersion).primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    storageAccountName

  ]
}

resource vmName_AzureMonitorLinuxAgent 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  parent: vmName
  name: 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource custom_table 'Microsoft.OperationalInsights/workspaces/tables@2021-12-01-preview' = {
  parent: logAnalyticsWorkspace
  name: customtable_name
  properties: {
    totalRetentionInDays: 30
    plan: 'Analytics'
    schema: {
      name: customtable_name
      columns: [
        {
          name: 'TimeGenerated'
          type: 'DateTime'
        }
        {
          name: 'RawData'
          type: 'String'
        }
      ]
    }
    retentionInDays: 30
  }
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: 7
    partitionCount: 1
  }
}


resource demoexportrule 'Microsoft.OperationalInsights/workspaces/dataexports@2020-08-01' = {
  parent: logAnalyticsWorkspace
  name: 'mydemoexportrule'
  location: location
  properties: {
    destination: {
      resourceId: eventHubNamespace.id
      metaData: {
        eventHubName: eventHubName
      }
    }
    tableNames: [
      'MyTable_CL'
    ]
    enable: true
  }
}

resource dcr 'Microsoft.Insights/dataCollectionRules@2019-11-01-preview' = {
  name: dcrName
  location: location
  kind: 'Linux'
  properties: {
    dataSources: {
      performanceCounters: [
        {
          streams: [
            'Microsoft-InsightsMetrics'
          ]
          samplingFrequencyInSeconds: 10
          counterSpecifiers: [
            'Processor(*)\\% Processor Time'
            'Processor(*)\\% Idle Time'
            'Processor(*)\\% User Time'
            'Processor(*)\\% Nice Time'
            'Processor(*)\\% Privileged Time'
            'Processor(*)\\% IO Wait Time'
            'Processor(*)\\% Interrupt Time'
            'Processor(*)\\% DPC Time'
            'Memory(*)\\Available MBytes Memory'
            'Memory(*)\\% Available Memory'
            'Memory(*)\\Used Memory MBytes'
            'Memory(*)\\% Used Memory'
            'Memory(*)\\Pages/sec'
            'Memory(*)\\Page Reads/sec'
            'Memory(*)\\Page Writes/sec'
            'Memory(*)\\Available MBytes Swap'
            'Memory(*)\\% Available Swap Space'
            'Memory(*)\\Used MBytes Swap Space'
            'Memory(*)\\% Used Swap Space'
            'Logical Disk(*)\\% Free Inodes'
            'Logical Disk(*)\\% Used Inodes'
            'Logical Disk(*)\\Free Megabytes'
            'Logical Disk(*)\\% Free Space'
            'Logical Disk(*)\\% Used Space'
            'Logical Disk(*)\\Logical Disk Bytes/sec'
            'Logical Disk(*)\\Disk Read Bytes/sec'
            'Logical Disk(*)\\Disk Write Bytes/sec'
            'Logical Disk(*)\\Disk Transfers/sec'
            'Logical Disk(*)\\Disk Reads/sec'
            'Logical Disk(*)\\Disk Writes/sec'
            'Network(*)\\Total Bytes Transmitted'
            'Network(*)\\Total Bytes Received'
            'Network(*)\\Total Bytes'
            'Network(*)\\Total Packets Transmitted'
            'Network(*)\\Total Packets Received'
            'Network(*)\\Total Rx Errors'
            'Network(*)\\Total Tx Errors'
            'Network(*)\\Total Collisions'
          ]
          name: 'perfCounterDataSource10'
        }
      ]
      syslog: [
        {
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'auth'
            'authpriv'
            'cron'
            'daemon'
            'mark'
            'kern'
            'local0'
            'local1'
            'local2'
            'local3'
            'local4'
            'local5'
            'local6'
            'local7'
            'lpr'
            'mail'
            'news'
            'syslog'
            'user'
            'UUCP'
          ]
          logLevels: [
            'Debug'
            'Info'
            'Notice'
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'
          ]
          name: 'sysLogsDataSource'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspace.id
          name: 'la-data-destination'
        }
      ]
      azureMonitorMetrics: {
        name: 'azureMonitorMetrics-default'
      }
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-InsightsMetrics'
        ]
        destinations: [
          'azureMonitorMetrics-default'
        ]
      }
      {
        streams: [
          'Microsoft-Syslog'
        ]
        destinations: [
          'la-data-destination'
        ]
      }
    ]
  }
}

resource dataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2021-04-01' = {
  name: dataCollectionEndpointName
  location: location
  properties: {
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

resource dcr_customlog 'Microsoft.Insights/dataCollectionRules@2021-09-01-preview' = {
  name: dcrName_customlog
  location: location
  properties: {
    dataCollectionEndpointId: dataCollectionEndpoint.id
    streamDeclarations: {
      'Custom-MyLogFileFormat': {
        columns: [
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'RawData'
            type: 'string'
          }
        ]
      }
    }
    dataSources: {
      logFiles: [
        {
          streams: [
            'Custom-MyLogFileFormat'
          ]
          filePatterns: [
            '//var//log//auth.log'
          ]
          format: 'text'
          settings: {
            text: {
              recordStartTimestampFormat: 'ISO 8601'
            }
          }
          name: 'myLogFileFormat-Linux'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspace.id
          name: 'la-customlog-destination'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Custom-MyLogFileFormat'
        ]
        destinations: [
          'la-customlog-destination'
        ]
        transformKql: 'source'
        outputStream: 'Custom-MyTable_CL'
      }
    ]
  }
}


resource association 'Microsoft.Insights/dataCollectionRuleAssociations@2021-09-01-preview' = {
  name: dcrAssociationName
  scope: vmName
  properties: {
    description: 'Association of data collection rule. Deleting this association will break the data collection for this virtual machine.'
    dataCollectionRuleId: dcr.id
  }
}

resource association_customlog 'Microsoft.Insights/dataCollectionRuleAssociations@2021-09-01-preview' = {
  name: 'my-vm-customlog-dcr'
  scope: vmName
  properties: {
    description: 'Association of data collection rule. Deleting this association will break the data collection for this virtual machine.'
    dataCollectionRuleId: dcr_customlog.id
  }
}

