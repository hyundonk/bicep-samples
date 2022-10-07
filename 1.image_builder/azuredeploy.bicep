@description('Location of the Shared Image Gallery.')
param location string = resourceGroup().location

@description('Name of the Shared Image Gallery.')
param galleryName string

@description('Name of the Image Definition.')
param galleryImageDefinitionName string

@description('Name of the staging resource group.')
param stagingResourceGroupId string

@description('Name of the Image Definition.')
param azureImageBuilderName string

resource galleryName_resource 'Microsoft.Compute/galleries@2019-12-01' = {
  name: galleryName
  location: location
  properties: {
    description: 'My Private Gallery'
  }
}

resource galleryName_galleryImageDefinition 'Microsoft.Compute/galleries/images@2019-12-01' = {
  name: '${galleryName_resource.name}/${galleryImageDefinitionName}'
  location: location
  properties: {
    description: 'Sample Gallery Image Description'
    osType: 'Linux'
    osState: 'Generalized'
    endOfLifeDate: '2030-01-01'
    identifier: {
      publisher: 'myPublisher'
      offer: 'myOffer'
      sku: 'mySku'
    }
    recommended: {
      vCPUs: {
        min: 1
        max: 64
      }
      memory: {
        min: 2048
        max: 307720
      }
    }
  }
}

resource azureImageBuilder 'Microsoft.VirtualMachineImages/imageTemplates@2022-02-14' = {
  name: azureImageBuilderName
  location: location
  tags: {
    imagebuilderTemplate: 'MyAzureImageBuilderSIG'
    userIdentity: 'enabled'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/ibLinuxGalleryRG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aibBuiUserId1665034053': {}
    }
  }

  properties:{
    buildTimeoutInMinutes: 80
    vmProfile:{
      vmSize: 'Standard_D2s_v3'
      osDiskSizeGB: 30
    }
    source: {
      type: 'PlatformImage'
      publisher: 'OpenLogic'
      offer: 'CentOS'
      sku: '7_9'
      version: 'latest'
    }

    customize: [
      {
        type: 'Shell'
        name: 'RunScriptFromSource'
        scriptUri: 'https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/quickquickstarts/customizeScript.sh'
      }
      {
          type: 'Shell'
          name: 'CheckSumCompareShellScript'
          scriptUri: 'https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/quickquickstarts/customizeScript2.sh'
          sha256Checksum: 'ade4c5214c3c675e92c66e2d067a870c5b81b9844b3de3cc72c49ff36425fc93'
      }
      {
          type: 'File'
          name: 'downloadBuildArtifacts'
          sourceUri: 'https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/quickquickstarts/exampleArtifacts/buildArtifacts/index.html'
          destination: '/tmp/index.html'
      }
      {
          type: 'Shell'
          name: 'setupBuildPath'
          inline: [
              'sudo mkdir /buildArtifacts'
              'sudo cp /tmp/index.html /buildArtifacts/index.html'
          ]
      }
    ]
    distribute: [
      {
        type: 'SharedImage'
        galleryImageId: galleryName_galleryImageDefinition.id
        runOutputName: 'aibLinuxSIG'
        artifactTags: {
            source: 'azureVmImageBuilder'
            baseosimg: 'centos7.9'
        }
        replicationRegions: [
          'koreacentral','southeastasia'
        ]
      }
    ]
  }
}
