// Windows-11-Client (Domaenenbeitritt): Warten auf den DC, Beitritt, Nacharbeiten (RDP fuer Lab-Benutzer,
// Lab-Info). Eigenes Modul, damit es erst nach DC-Aufbau und DNS-Umstellung des VNets startet.
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

resource completeClient 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = {
  parent: vm
  name: 'Complete-LabClient'
  location: location
  tags: tags
  properties: {
    source: {
      script: loadTextContent('../../scripts/Initialize-LabClient.ps1')
    }
    parameters: [
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
    ]
    asyncExecution: false
    timeoutInSeconds: 3600
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    joinDomain
  ]
}
