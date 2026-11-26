// Exchange-Server (Installation): Warten auf den DC, Domaenenbeitritt, Exchange-Setup und Konfiguration.
// Eigenes Modul, damit es erst nach DC-Aufbau und DNS-Umstellung des VNets startet.

@description('Azure-Region.')
param location string

@description('Tags fuer alle Ressourcen.')
param tags object

@description('Name der bestehenden Exchange-VM.')
param vmName string

@description('Domain-Administrator (ohne Domain-Praefix).')
param adminUsername string

@description('Passwort des Domain-Administrators.')
@secure()
param adminPassword string

@description('Passwort der Lab-Benutzer.')
@secure()
param labUserPassword string

@description('FQDN der AD-Domain.')
param domainName string

@description('NetBIOS-Name der AD-Domain.')
param netbiosName string

@description('Oeffentliche Domain des Azubis.')
param publicDomainName string

@description('Name der Firmen-OU, z. B. LEARN-abc.')
param companyOu string

@description('Computername des Domain Controllers.')
param dcComputerName string

@description('Computername des optionalen zweiten DC. Leer = kein zweiter DC.')
param secondDcComputerName string = ''

@description('Computername des optionalen Windows-11-Clients, wird in die Client-OU verschoben. Leer = kein Client.')
param clientComputerName string = ''

@description('Computername des optionalen Fileservers, nur fuer Lab-Info.txt. Leer = kein Fileserver.')
param fileServerComputerName string = ''

@description('Sprache der Lab-Daten (de, en): Benutzer und Empfaenger, Postfachsprache, Lab-Info.txt.')
param labLanguage string

@description('Private IP des Domain Controllers.')
param dcIp string

@description('Private IP des Exchange-Servers.')
param exchangeIp string

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
      // UPN-Format: NETBIOS\Benutzer scheitert von Rechnern ausserhalb der Domain (Testdeployment).
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

resource installExchangeServer 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = {
  parent: vm
  name: 'Install-ExchangeServer'
  location: location
  tags: tags
  properties: {
    source: {
      script: loadTextContent('../../scripts/Install-ExchangeServer.ps1')
    }
    // Leere Werte wuerden als Parameter ohne Argument uebergeben, daher optionale Werte nur bei Bedarf.
    parameters: concat([
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
        name: 'PublicDomainName'
        value: publicDomainName
      }
      {
        name: 'CompanyOu'
        value: companyOu
      }
      {
        name: 'DcComputerName'
        value: dcComputerName
      }
      {
        name: 'OrganizationName'
        value: 'ExchOrg'
      }
      {
        name: 'UpdateScriptB64'
        value: base64(loadTextContent('../../scripts/Update-LabServer.ps1'))
      }
      {
        name: 'MaintenanceScriptB64'
        value: base64(loadTextContent('../../scripts/Invoke-LabMaintenance.ps1'))
      }
    ], empty(secondDcComputerName) ? [] : [
      {
        name: 'SecondDcComputerName'
        value: secondDcComputerName
      }
    ], empty(clientComputerName) ? [] : [
      {
        name: 'ClientComputerName'
        value: clientComputerName
      }
    ], empty(fileServerComputerName) ? [] : [
      {
        name: 'FileServerComputerName'
        value: fileServerComputerName
      }
    ], [
      {
        name: 'LabLanguage'
        value: labLanguage
      }
    ])
    protectedParameters: [
      {
        name: 'AdminPasswordB64'
        value: base64(adminPassword)
      }
      {
        name: 'LabUserPasswordB64'
        value: base64(labUserPassword)
      }
    ]
    asyncExecution: false
    timeoutInSeconds: 9000
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    waitJoinReboot
  ]
}
