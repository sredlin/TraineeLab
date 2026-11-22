// Domain Controller: Windows Server 2025, statische IP, keine Public IP,
// NTDS/SYSVOL auf eigener Datendisk mit Host-Cache None (Microsoft-Empfehlung fuer AD DS in Azure).

@description('Azure-Region.')
param location string

@description('Tags fuer alle Ressourcen.')
param tags object

@description('Name der VM-Ressource.')
param vmName string

@description('Windows-Computername (max. 15 Zeichen).')
@maxLength(15)
param computerName string

@description('VM-Groesse.')
param vmSize string

@description('Subnet-ID.')
param subnetId string

@description('Statische private IP des DC.')
param privateIp string

@description('Lokaler Administrator, wird nach der Heraufstufung zum Domain-Administrator.')
param adminUsername string

@description('Passwort des Administrators, zugleich DSRM-Passwort.')
@secure()
param adminPassword string

@description('FQDN der AD-Domain, z. B. abc.intern.')
param domainName string

@description('NetBIOS-Name der AD-Domain.')
param netbiosName string

@description('Oeffentliche Domain des Azubis fuer Split DNS, z. B. abc.lab.example.com.')
param publicDomainName string

@description('Private IP des Exchange-Servers fuer Split DNS.')
param exchangeIp string

resource nic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: 'nic-${vmName}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: privateIp
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        timeZone: 'W. Europe Standard Time'
        // Updates waehrend des Aufbaus wuerden den DC unkontrolliert neu starten.
        // Der erste Update-Lauf erfolgt per Startup-Task nach der Exchange-Installation.
        enableAutomaticUpdates: false
        patchSettings: {
          patchMode: 'Manual'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2025-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-${vmName}'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          name: 'disk-${vmName}-adds'
          lun: 0
          createOption: 'Empty'
          diskSizeGB: 32
          caching: 'None'
          deleteOption: 'Delete'
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource installDomainController 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = {
  parent: vm
  name: 'Install-DomainController'
  location: location
  tags: tags
  properties: {
    source: {
      script: loadTextContent('../../scripts/Install-DomainController.ps1')
    }
    parameters: [
      {
        name: 'DomainName'
        value: domainName
      }
      {
        name: 'NetbiosName'
        value: netbiosName
      }
      {
        name: 'PublicDomainName'
        value: publicDomainName
      }
      {
        name: 'ExchangeIp'
        value: exchangeIp
      }
    ]
    protectedParameters: [
      {
        name: 'SafeModePasswordB64'
        value: base64(adminPassword)
      }
    ]
    asyncExecution: false
    timeoutInSeconds: 3600
    treatFailureAsDeploymentFailure: true
  }
}

output vmName string = vm.name
