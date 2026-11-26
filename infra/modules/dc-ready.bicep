// Schranke fuer den zweiten DC: Ein Run Command auf dem ersten DC wartet, bis DC02 vollstaendig bereit ist
// (DC, SYSVOL, DNS, Replikation in beide Richtungen). Erst danach traegt das Deployment DC02 als DNS-Server
// ins VNet ein und startet die Exchange-Installation. Faellt nach 75 Minuten mit dem Log von DC02 aus.

@description('Azure-Region.')
param location string

@description('Tags fuer alle Ressourcen.')
param tags object

@description('Name der VM des ersten DC (fuehrt die Pruefung aus).')
param vmName string

@description('FQDN der AD-Domain.')
param domainName string

@description('NetBIOS-Name der AD-Domain.')
param netbiosName string

@description('Domain-Administrator.')
param adminUsername string

@description('Passwort des Domain-Administrators.')
@secure()
param adminPassword string

@description('Computername des zweiten DC.')
param secondDcComputerName string

@description('Private IP des zweiten DC.')
param secondDcIp string

@description('Oeffentliche Domain des Azubis (Split DNS).')
param publicDomainName string

@description('Private IP des Exchange-Servers (Split DNS).')
param exchangeIp string

resource vm 'Microsoft.Compute/virtualMachines@2025-04-01' existing = {
  name: vmName
}

resource waitSecondDc 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = {
  parent: vm
  name: 'Wait-SecondDomainController'
  location: location
  tags: tags
  properties: {
    source: {
      script: loadTextContent('../../scripts/Wait-SecondDomainController.ps1')
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
        name: 'SecondDcComputerName'
        value: secondDcComputerName
      }
      {
        name: 'SecondDcIp'
        value: secondDcIp
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
    // Interne Wartezeit 75 Minuten plus Reserve.
    timeoutInSeconds: 5400
    treatFailureAsDeploymentFailure: true
  }
}
