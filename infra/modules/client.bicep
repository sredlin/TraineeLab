// Windows-11-Client (Grundsystem): Einstieg ins Lab und Arbeitsplatz fuer Outlook-Tests mit eigener Public IP fuer RDP.
// Vorbereitung per Run Command (Sprachpaket, Microsoft 365 Apps, Remote Desktop Manager) laeuft parallel zum Aufbau des DC.
// Windows 11 auf Azure braucht Multitenant Hosting Rights, daher licenseType Windows_Client.

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

@description('Statische private IP des Clients.')
param privateIp string

@description('ID der Public IP.')
param publicIpId string

@description('Lokaler Administrator.')
param adminUsername string

@description('Passwort des lokalen Administrators.')
@secure()
param adminPassword string

@description('SKU des Windows-11-Images (Publisher MicrosoftWindowsDesktop, Offer windows-11).')
param imageSku string

@description('Produkt-ID der Microsoft 365 Apps fuer das Office Deployment Tool.')
param officeProductId string

@description('Devolutions Remote Desktop Manager mit .NET Desktop Runtime, PowerShell 7 und RDM-Modul installieren.')
param installRemoteDesktopManager bool

@description('Sprache der Lab-Daten (de, en): Sprachpaket, Formate, Office-Sprache.')
param labLanguage string

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
          publicIPAddress: {
            id: publicIpId
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
    // Multitenant Hosting Rights (z. B. Windows E3/E5 pro Benutzer) statt Windows-Lizenz ueber Azure.
    licenseType: 'Windows_Client'
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
        // Clients aktualisieren sich selbst (anders als die Server). Neustarts verhindert die
        // Nutzungszeit-Richtlinie aus Initialize-LabClient.ps1 tagsueber und waehrend des Aufbaus.
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: imageSku
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

resource prepareClient 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = {
  parent: vm
  name: 'Initialize-LabClient'
  location: location
  tags: tags
  properties: {
    source: {
      script: loadTextContent('../../scripts/Initialize-LabClient.ps1')
    }
    parameters: [
      {
        name: 'Phase'
        value: 'Prepare'
      }
      {
        name: 'OfficeProductId'
        value: officeProductId
      }
      {
        name: 'RemoteDesktopManager'
        value: installRemoteDesktopManager ? 'Install' : 'Skip'
      }
      {
        name: 'LabLanguage'
        value: labLanguage
      }
    ]
    asyncExecution: false
    timeoutInSeconds: 5400
    treatFailureAsDeploymentFailure: true
  }
}

output vmName string = vm.name
