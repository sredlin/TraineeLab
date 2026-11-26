// Exchange-Server (Grundsystem): Windows Server 2025, Premium Storage fuer OS (Binaries, Transport-DB)
// und Daten (Datenbanken, Logs) wie fuer Exchange in Azure vorgeschrieben, System-Managed-Identity
// fuer Let's Encrypt, Vorbereitung per Run Command (laeuft parallel zum Aufbau des DC).

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

@description('Statische private IP des Exchange-Servers.')
param privateIp string

@description('ID der Public IP.')
param publicIpId string

@description('Lokaler Administrator.')
param adminUsername string

@description('Passwort des lokalen Administrators.')
@secure()
param adminPassword string

@description('Oeffentliche Domain des Azubis, z. B. abc.lab.example.com (zugleich Name der DNS-Zone).')
param publicDomainName string

@description('Download-URL des Exchange-Server-SE-ISO.')
param exchangeIsoUri string

@description('Let\'s-Encrypt-Zertifikat ueber die Managed Identity anfordern.')
param enableLetsEncrypt bool

@description('Let\'s-Encrypt-Staging (Test-CA) statt Produktion verwenden.')
param letsEncryptStaging bool

@description('Optionale winget-Pakete.')
param wingetPackages array

@description('Sprache der Lab-Daten (de, en): Gebietsschema der VM.')
param labLanguage string

// Integrierte Rolle "DNS Zone Contributor"
var dnsZoneContributorRoleId = 'befefa01-2a29-4197-83a8-272ff33ce314'

resource zone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: publicDomainName
}

resource nic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: 'nic-${vmName}'
  location: location
  tags: tags
  properties: {
    enableAcceleratedNetworking: true
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
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    // LabUsers.psd1 der Lab-Sprache fuer Install-ExchangeServer (per IMDS lesbar). Als Run-Command-Parameter
    // wuerde die Kommandozeile zu lang (Windows-Grenze 32.767 Zeichen).
    userData: base64(labLanguage == 'en' ? loadTextContent('../../scripts/data/en/LabUsers.psd1') : loadTextContent('../../scripts/data/de/LabUsers.psd1'))
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
        // Updates waehrend des Aufbaus wuerden die Exchange-Installation stoeren.
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
        diskSizeGB: 128
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [
        {
          name: 'disk-${vmName}-data'
          lun: 0
          createOption: 'Empty'
          diskSizeGB: 128
          caching: 'None'
          deleteOption: 'Delete'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
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

resource dnsZoneContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableLetsEncrypt) {
  name: guid(zone.id, vm.id, dnsZoneContributorRoleId)
  scope: zone
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', dnsZoneContributorRoleId)
    principalId: vm.identity.principalId
    principalType: 'ServicePrincipal'
    description: 'Let\'s-Encrypt-DNS-Challenge der Exchange-VM ${vmName}'
  }
}

resource initializeExchangeServer 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = {
  parent: vm
  name: 'Initialize-ExchangeServer'
  location: location
  tags: tags
  properties: {
    source: {
      script: loadTextContent('../../scripts/Initialize-ExchangeServer.ps1')
    }
    // Leere Werte wuerden als Parameter ohne Argument uebergeben, daher WingetPackages nur bei Bedarf.
    parameters: concat([
      {
        name: 'PublicDomainName'
        value: publicDomainName
      }
      {
        name: 'IsoUri'
        value: exchangeIsoUri
      }
      {
        name: 'SubscriptionId'
        value: subscription().subscriptionId
      }
      {
        name: 'EnableLetsEncrypt'
        value: toLower(string(enableLetsEncrypt))
      }
      {
        name: 'LetsEncryptStaging'
        value: toLower(string(letsEncryptStaging))
      }
      {
        name: 'LabLanguage'
        value: labLanguage
      }
    ], empty(wingetPackages) ? [] : [
      {
        name: 'WingetPackages'
        value: join(wingetPackages, ',')
      }
    ])
    asyncExecution: false
    timeoutInSeconds: 5400
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    dnsZoneContributor
  ]
}

output vmName string = vm.name
