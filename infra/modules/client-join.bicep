// Windows-11-Client (Domaenenbeitritt): Warten auf den DC, Beitritt, Nacharbeiten (RDP fuer Lab-Benutzer,
// Lab-Info, Verbindungen im Remote Desktop Manager). Eigenes Modul, damit es erst nach DC-Aufbau und
// DNS-Umstellung des VNets startet.
// Die Exchange-Installation verschiebt den Computer anschliessend in die Client-OU der Lab-Struktur.

@description('Azure-Region.')
param location string

@description('Tags fuer alle Ressourcen.')
param tags object

@description('Name der bestehenden Client-VM.')
param vmName string

@description('Domain-Administrator (ohne Domain-Praefix).')
param adminUsername string

@description('Passwort des Domain-Administrators.')
@secure()
param adminPassword string

@description('FQDN der AD-Domain.')
param domainName string

@description('NetBIOS-Name der AD-Domain.')
param netbiosName string

@description('Oeffentliche Domain des Azubis.')
param publicDomainName string

@description('Private IP des ersten Domain Controllers.')
param dcIp string

@description('Private IP des Exchange-Servers.')
param exchangeIp string

@description('Computername des ersten Domain Controllers (Verbindung im Remote Desktop Manager).')
param dcComputerName string

@description('Computername des zweiten Domain Controllers. Leer = kein DC02.')
param secondDcComputerName string = ''

@description('Computername des Exchange-Servers (Verbindung im Remote Desktop Manager).')
param exchangeComputerName string

@description('Computername des optionalen Fileservers fuer Lab-Info.txt und Remote Desktop Manager. Leer = kein Fileserver.')
param fileServerComputerName string = ''

@description('Sprache der Lab-Daten (de, en): Lab-Info.txt.')
param labLanguage string

resource vm 'Microsoft.Compute/virtualMachines@2025-04-01' existing = {
  name: vmName
}

resource waitDomainController 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = {
  parent: vm
  name: 'Wait-DomainController'
  location: location
  tags: tags
  properties: {
    source: {
      script: loadTextContent('../../scripts/Wait-DomainController.ps1')
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
        name: 'AdminUser'
        value: adminUsername
      }
      {
        name: 'DcIp'
        value: dcIp
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
        name: 'AdminPasswordB64'
        value: base64(adminPassword)
      }
    ]
    asyncExecution: false
    timeoutInSeconds: 3600
    treatFailureAsDeploymentFailure: true
  }
}

resource joinDomain 'Microsoft.Compute/virtualMachines/extensions@2025-04-01' = {
  parent: vm
  name: 'JoinDomain'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      Name: domainName
      // UPN-Format: NETBIOS\Benutzer scheitert von Rechnern ausserhalb der Domain.
      User: '${adminUsername}@${domainName}'
      Restart: 'true'
      Options: 3
    }
    protectedSettings: {
      Password: adminPassword
    }
  }
  dependsOn: [
    waitDomainController
  ]
}

// Die Extension startet die VM erst nach ihrer Erfolgsmeldung neu. Dieser Run Command darf vom Neustart
// abgebrochen werden (kein Deployment-Fehler), damit der naechste Run Command sicher erst danach startet.
resource waitJoinReboot 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = {
  parent: vm
  name: 'Wait-DomainJoinReboot'
  location: location
  tags: tags
  properties: {
    source: {
      script: loadTextContent('../../scripts/Wait-DomainJoinReboot.ps1')
    }
    asyncExecution: false
    timeoutInSeconds: 1200
    treatFailureAsDeploymentFailure: false
  }
  dependsOn: [
    joinDomain
  ]
}

resource completeClient 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = {
  parent: vm
  name: 'Complete-LabClient'
  location: location
  tags: tags
  properties: {
    source: {
      script: loadTextContent('../../scripts/Initialize-LabClient.ps1')
    }
    // Leere Werte wuerden als Parameter ohne Argument uebergeben, daher optionale Werte nur bei Bedarf.
    parameters: concat([
      {
        name: 'Phase'
        value: 'Complete'
      }
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
        name: 'AdminUser'
        value: adminUsername
      }
      {
        name: 'DcComputerName'
        value: dcComputerName
      }
      {
        name: 'ExchangeComputerName'
        value: exchangeComputerName
      }
      {
        name: 'LabLanguage'
        value: labLanguage
      }
    ], empty(secondDcComputerName) ? [] : [
      {
        name: 'SecondDcComputerName'
        value: secondDcComputerName
      }
    ], empty(fileServerComputerName) ? [] : [
      {
        name: 'FileServerComputerName'
        value: fileServerComputerName
      }
    ])
    // Fuer die Verbindungen im Remote Desktop Manager (Domain-Admin, fuer alle Benutzer am Client).
    protectedParameters: [
      {
        name: 'AdminPasswordB64'
        value: base64(adminPassword)
      }
    ]
    asyncExecution: false
    timeoutInSeconds: 3600
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    waitJoinReboot
  ]
}
