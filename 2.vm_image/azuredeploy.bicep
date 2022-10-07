param location string = resourceGroup().location

param osDiskResourceId string
param dataDiskResourceId string

resource osDisk_snapshot 'Microsoft.Compute/snapshots@2019-03-01' = {
  name: 'osDisk-snapshot'
  location: location
  properties: {
    creationData: {
      createOption: 'Copy'
      sourceResourceId: osDiskResourceId
    }
    incremental: false
  }
}

resource dataDisk_snapshot 'Microsoft.Compute/snapshots@2019-03-01' = {
  name: 'dataDisk-snapshot'
  location: location
  properties: {
    creationData: {
      createOption: 'Copy'
      sourceResourceId: dataDiskResourceId
    }
    incremental: false
  }
}

resource tempOsDisk 'Microsoft.Compute/disks@2018-06-01' = {
  name: 'tempOsDisk'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    creationData: {
      createOption: 'Copy'
      sourceResourceId: osDisk_snapshot.id
    }
  }
}

resource tempDataDisk 'Microsoft.Compute/disks@2018-06-01' = {
  name: 'tempDataDisk'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    creationData: {
      createOption: 'Copy'
      sourceResourceId: dataDisk_snapshot.id
    }
  }
}

resource tempvnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: 'tempVnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'tempSubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

resource diagStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: 'hyuktmpdiagstorage'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  properties: {
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: 'tmpPubIP'
  location: location
  tags: {
    displayName: 'PublicIPAddress'
  }

  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource tmpnic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: 'tmpNic'
  location: location
  dependsOn: [
    tempvnet
  ]
  tags: {
    displayName: 'NetworkInterface'
 }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddress.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', tempvnet.name, 'tempSubnet')
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'tmpVM'
  location: location
  tags: {
    displayName: 'VirtualMachine'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D4s_v3'
    }
    storageProfile: {
      osDisk: {
        osType: 'Linux'
        caching: 'ReadWrite'
        createOption: 'Attach'
        managedDisk: {
          id: tempOsDisk.id
        }
      }
      dataDisks: [
        {
          lun: 0
          managedDisk: {
            id: tempDataDisk.id
          }
          caching: 'ReadOnly'
          createOption: 'Attach'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: tmpnic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: reference(diagStorageAccount.name, '2021-02-01').primaryEndpoints.blob
      }
    }
  }
}

