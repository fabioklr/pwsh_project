param location string = resourceGroup().location
param networkSecurityGroupName string = 'myVM-nsg'
param subnetName string = 'FrontEndSubnet'
param virtualMachineName string = 'myVM'
param osDiskType string = 'Standard_LRS'
param osDiskDeleteOption string = 'Delete'
param virtualMachineSize string = 'Standard_DS1_v2'
param nicDeleteOption string = 'Delete'
param adminUsername string = 'fabioklr'

@secure()
param adminPassword string

var nsgId = resourceId(resourceGroup().name, 'Microsoft.Network/networkSecurityGroups', networkSecurityGroupName)
var vnetId = '/subscriptions/51ca10b0-8c55-4489-b098-38271441570c/resourceGroups/myRG/providers/Microsoft.Network/virtualNetworks/myVNet'
var subnetRef = '${vnetId}/subnets/${subnetName}'

resource networkInterface 'Microsoft.Network/networkInterfaces@2021-03-01' = {
  name: 'myNI'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgId
    }
  }
  dependsOn: [
    networkSecurityGroup
  ]
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: networkSecurityGroupName
  location: location
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'fromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        deleteOption: osDiskDeleteOption
      }
      imageReference: {
        publisher: 'ntegralinc1586961136942'
        offer: 'ntg_ubuntu_22_04_daas'
        sku: 'ntg_ubuntu_22_04_daas'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: nicDeleteOption
          }
        }
      ]
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
  }
  plan: {
    name: 'ntg_ubuntu_22_04_daas'
    publisher: 'ntegralinc1586961136942'
    product: 'ntg_ubuntu_22_04_daas'
  }
}

// Deploys but does not execute code after deployment.
// resource deploymentscript 'Microsoft.Compute/virtualMachines/runCommands@2022-08-01' = {
//   parent: virtualMachine
//   name: 'postDeploymentPSInstall'
//   location: location
//   properties: {
//     source: {
//       script: '''sudo apt-get update &&\
//       sudo apt-get install -y wget apt-transport-https software-properties-common &&\
//       wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" &&\
//       sudo dpkg -i packages-microsoft-prod.deb &&\
//       sudo apt-get update &&\
//       sudo apt-get install -y powershell &&\
//       pwsh'''
//     }
//   }
// }

output adminUsername string = adminUsername
