// Fileserver (Domaenenbeitritt): Warten auf den DC, Beitritt, Rollen, Gruppen, Berechtigungen, Freigaben,
// Basisordner. Eigenes Modul, damit es erst nach DC-Aufbau und DNS-Umstellung des VNets startet.

@description('Azure-Region.')
param location string

@description('Tags fuer alle Ressourcen.')
param tags object

@description('Name der bestehenden Fileserver-VM.')
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

@description('Name der Firmen-OU, z. B. LEARN-abc.')
param companyOu string

@description('Computername des ersten Domain Controllers (Ziel aller AD-Aufrufe).')
param dcComputerName string

@description('Private IP des ersten Domain Controllers.')
param dcIp string

@description('Private IP des Exchange-Servers.')
param exchangeIp string

@description('Dauergroesse der VM nach den Beispieldokumenten, leer = Groesse bleibt.')
param finalVmSize string = ''

@description('Verkleinern erst nach fertigen Beispieldokumenten.')
param waitForSampleDocuments bool = true

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

resource completeFileServer 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = {
  parent: vm
  name: 'Complete-FileServer'
  location: location
  tags: tags
  properties: {
    source: {
      script: loadTextContent('../../scripts/Initialize-FileServer.ps1')
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
        name: 'AdminUser'
        value: adminUsername
      }
      {
        name: 'DcComputerName'
        value: dcComputerName
      }
      {
        name: 'CompanyOu'
        value: companyOu
      }
      {
        name: 'UpdateScriptB64'
        value: loadFileAsBase64('../../scripts/Update-LabServer.ps1')
      }
      {
        name: 'FinalVmSize'
        value: finalVmSize
      }
      {
        name: 'ResizeScriptB64'
        value: empty(finalVmSize) ? '' : loadFileAsBase64('../../scripts/Resize-FileServer.ps1')
      }
      {
        name: 'WaitForSampleDocuments'
        value: waitForSampleDocuments ? 'true' : 'false'
      }
    ]
    protectedParameters: [
      {
        name: 'AdminPasswordB64'
        value: base64(adminPassword)
      }
    ]
    asyncExecution: false
    // Wartet bis zu 90 Minuten auf die Lab-Benutzer aus der Exchange-Installation.
    timeoutInSeconds: 7200
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    joinDomain
  ]
}
