// Fileserver (Grundsystem): Windows Server 2025 ohne Public IP, Datendisk F: fuer die Freigaben.
// Vorbereitung per Run Command (Disk, Regionaleinstellungen, Ordnergeruest) laeuft parallel zum Aufbau des DC,
// danach erzeugt New-SampleDocuments die Beispieldokumente (Textkorpus aus der userData der VM).
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
param dataDiskSizeGB int = 256

@description('Umfang der Beispieldokumente in Prozent der Datendisk, 0 = keine.')
param sampleDataPercent int = 90

@description('Zeitbudget des Generators im Deployment in Minuten. Danach setzt ein Task im Hintergrund fort.')
param sampleTimeBudgetMinutes int = 60

@description('Dauergroesse nach den Beispieldokumenten, leer = Groesse bleibt. Die VM verkleinert sich selbst (Resize-FileServer.ps1).')
param finalVmSize string = ''

@description('Sprache der Lab-Daten (de, en): Gebietsschema, Lab-Daten und Textkorpus der Beispieldokumente.')
param labLanguage string

// Virtual Machine Contributor: Groessenaenderung inklusive der verknuepften NIC und Disks.
var vmContributorRoleId = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'

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
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    // Textkorpus fuer New-SampleDocuments (gzip-JSON, per IMDS lesbar). Erzeugt von tools/Build-SampleArtifacts.ps1.
    userData: loadFileAsBase64('../../scripts/SampleCorpus.de.gz')
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
        name: 'LabLanguage'
        value: labLanguage
      }
      {
        name: 'LabUsersB64'
        value: labLanguage == 'en' ? loadFileAsBase64('../../scripts/data/en/LabUsers.psd1') : loadFileAsBase64('../../scripts/data/de/LabUsers.psd1')
      }
      {
        name: 'FileServerB64'
        value: labLanguage == 'en' ? loadFileAsBase64('../../scripts/data/en/FileServer.psd1') : loadFileAsBase64('../../scripts/data/de/FileServer.psd1')
      }
    ]
    asyncExecution: false
    timeoutInSeconds: 3600
    treatFailureAsDeploymentFailure: true
  }
}

// Beispieldokumente vor dem Domaenenbeitritt (dessen Neustart wuerde die Erzeugung abbrechen).
// Nach dem Zeitbudget endet der Run Command erfolgreich, der Task TraineeLab-SampleDocuments setzt fort.
resource sampleDocuments 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = if (sampleDataPercent > 0) {
  parent: vm
  name: 'New-SampleDocuments'
  location: location
  tags: tags
  dependsOn: [
    prepareFileServer
  ]
  properties: {
    source: {
      script: loadTextContent('../../scripts/Start-SampleDocuments.ps1')
    }
    parameters: [
      {
        name: 'TargetPercent'
        value: string(sampleDataPercent)
      }
      {
        name: 'TimeBudgetMinutes'
        value: string(sampleTimeBudgetMinutes)
      }
    ]
    asyncExecution: false
    // Zeitbudget plus Reserve fuer laufende Einheiten, Kopien und Ordnerzeitstempel.
    timeoutInSeconds: (sampleTimeBudgetMinutes + 45) * 60
    treatFailureAsDeploymentFailure: true
  }
}

// Die VM verkleinert sich nach der Erzeugung selbst. Rolle auf der Ressourcengruppe, weil die Aenderung
// auch die verknuepfte NIC und die Disks prueft; die Trainees sind ohnehin Owner der Gruppe.
resource resizeRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(finalVmSize)) {
  name: guid(resourceGroup().id, vm.id, vmContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmContributorRoleId)
    principalId: vm.identity.principalId
    principalType: 'ServicePrincipal'
    description: 'Automatische Verkleinerung des Fileservers ${vmName} nach den Beispieldokumenten'
  }
}

output vmName string = vm.name
