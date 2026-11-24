// Fileserver (Grundsystem): Windows Server 2025 ohne Public IP, Datendisk F: fuer die Freigaben.
// Vorbereitung per Run Command (Disk, Regionaleinstellungen, Ordnergeruest) laeuft parallel zum Aufbau des DC.
// Rollen installiert erst file-server-join.bicep nach dem Neustart des Domaenenbeitritts.

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

@description('Statische private IP des Fileservers.')
param privateIp string

@description('Lokaler Administrator.')
param adminUsername string

@description('Passwort des lokalen Administrators.')
@secure()
param adminPassword string

@description('Groesse der Datendisk in GB.')
param dataDiskSizeGB int = 128

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
        // Wie bei DC und Exchange: kein unkontrollierter Neustart waehrend des Aufbaus, der erste
        // Update-Lauf startet am Ende der Einrichtung (Initialize-FileServer.ps1, Phase Complete).
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
          name: 'disk-${vmName}-data'
          lun: 0
          createOption: 'Empty'
          diskSizeGB: dataDiskSizeGB
          // Lesecache fuer Dateizugriffe, Schreibvorgaenge gehen direkt auf die Disk.
          caching: 'ReadOnly'
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

resource prepareFileServer 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = {
  parent: vm
  name: 'Initialize-FileServer'
  location: location
  tags: tags
  properties: {
    source: {
      script: loadTextContent('../../scripts/Initialize-FileServer.ps1')
    }
    parameters: [
      {
        name: 'Phase'
        value: 'Prepare'
      }
      {
        name: 'LabUsersB64'
        value: loadFileAsBase64('../../scripts/LabUsers.psd1')
      }
      {
        name: 'FileServerB64'
        value: loadFileAsBase64('../../scripts/FileServer.psd1')
      }
    ]
    asyncExecution: false
    timeoutInSeconds: 3600
    treatFailureAsDeploymentFailure: true
  }
}

output vmName string = vm.name
