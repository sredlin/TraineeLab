metadata name = 'Exchange Server SE Lab'
metadata description = 'Azubi-Lab: separater Domain Controller und Exchange Server SE auf Windows Server 2025, fertig konfiguriert (Split DNS, Zertifikat, URLs, Postfaecher).'

targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------------------------
// Parameter
// ---------------------------------------------------------------------------------------------

@description('Kuerzel des Azubis (3 Buchstaben). Wird fuer Ressourcennamen, AD-Domain <kuerzel>.intern und Subdomain <kuerzel>.<parentDnsZoneName> verwendet.')
@minLength(3)
@maxLength(3)
param trainee string

@description('Sprache der Lab-Daten: de = Mustermann Medien GmbH (Berlin, Hamburg), en = Contoso Ltd (London, Manchester). Bestimmt Benutzer, Gruppen, Freigaben, Beispieldokumente, Gebietsschema der VMs und Postfachsprache.')
@allowed([
  'de'
  'en'
])
param labLanguage string = 'de'

@description('Azure-Region. Standard: Region der Ressourcengruppe.')
param location string = resourceGroup().location

@description('Administrator beider VMs, nach der Heraufstufung zugleich Domain-Administrator.')
param adminUsername string = 'azadmin'

@description('Passwort des Administrators (auch DSRM-Passwort).')
@secure()
param adminPassword string

@description('Passwort der Lab-Benutzer. Bewusst getrennt vom Administrator-Passwort, damit Testkonten nicht das Domain-Admin-Passwort verraten. Ausnahme: Mit clientRemoteDesktopManager kann jeder Benutzer am Client das Admin-Passwort auslesen.')
@secure()
param labUserPassword string

@description('Quelle fuer RDP auf den Exchange-Server, z. B. eigene oeffentliche IP als 203.0.113.10/32. Kein "*".')
param allowedRdpSourcePrefix string

@description('Quelle fuer HTTP/HTTPS (OWA, ECP, Outlook, Autodiscover) auf den Exchange-Server. Leer = wie RDP. "Internet" macht auch ECP mit Admin-Anmeldung oeffentlich.')
param exchangePublishedSourcePrefix string = ''

@description('Quelle fuer SMTP (Port 25) auf den Exchange-Server. Leer = wie HTTP/HTTPS. Fuer eingehende Mails aus dem Internet erst nach dem Update-Lauf auf "Internet" stellen.')
param smtpSourcePrefix string = ''

@description('Taegliches automatisches Herunterfahren der Exchange-VM im Format HHmm (W. Europe Standard Time). Leer = aus. Der DC wird bewusst nie automatisch deallokiert.')
param autoShutdownTime string = '1900'

@description('Uebergeordnete oeffentliche DNS-Zone fuer die Subdomain-Delegation (Name vom Ausbilder). Wird angelegt, falls sie fehlt; eine bestehende Zone bleibt unveraendert.')
param parentDnsZoneName string

@description('Ressourcengruppe der uebergeordneten DNS-Zone (gleiche Subscription).')
param parentDnsZoneResourceGroup string = 'rg-publicdns'

@description('Download-URL des Exchange-Server-SE-ISO (Microsoft Download Center, ID 108244).')
param exchangeIsoUri string = 'https://download.microsoft.com/download/ad9b1e53-f28e-4a82-987d-6c88803795b2/ExchangeServerSE-x64.iso'

@description('SHA256 des Exchange-ISO: Pruefung vor dem Entpacken, bei Abweichung neuer Download. Bei eigenem exchangeIsoUri anpassen oder leeren (keine Pruefung).')
param exchangeIsoSha256 string = 'CD2B13F2C297187776AF4CFF3541B4BE3C677CF907CCA69D85AB0E2B70377BD1'

@description('Let\'s-Encrypt-Wildcard-Zertifikat ueber die Managed Identity anfordern (Deployer braucht Owner/User Access Administrator auf der Ressourcengruppe).')
param enableLetsEncrypt bool = true

@description('Let\'s-Encrypt-Staging (Test-CA) verwenden, z. B. fuer Testdeployments.')
param letsEncryptStaging bool = false

@description('VM-Groesse der Domain Controller.')
@allowed([
  'Standard_B2ms'
  'Standard_D2s_v5'
])
param dcVmSize string = 'Standard_B2ms'

@description('Zweiten Domain Controller <K>-DC02 bereitstellen (Replikation, FSMO, DC-Ausfall ueben). Der erste DC laeuft durch, DC02 schaltet mit der Exchange-VM ab.')
param deploySecondDc bool = false

@description('Windows-11-Client <K>-CL01 mit Microsoft 365 Apps bereitstellen, Domaenenmitglied mit eigener Public IP fuer RDP. Braucht Windows-Lizenzen mit Multitenant Hosting Rights.')
param deployClient bool = true

@description('VM-Groesse des Windows-11-Clients.')
@allowed([
  'Standard_B2ms'
  'Standard_D2s_v5'
])
param clientVmSize string = 'Standard_B2ms'

@description('SKU des Windows-11-Images (Publisher MicrosoftWindowsDesktop, Offer windows-11).')
param clientImageSku string = 'win11-25h2-ent'

@description('Microsoft 365 Apps auf dem Client: O365ProPlusRetail = Apps for enterprise (M365 E3/E5), O365BusinessRetail = Apps for business (Business Standard/Premium). Aktiviert wird mit einem Konto aus dem Microsoft-365-Demo-Tenant.')
@allowed([
  'O365ProPlusRetail'
  'O365BusinessRetail'
])
param officeProductId string = 'O365ProPlusRetail'

@description('Devolutions Remote Desktop Manager Free auf dem Client mit fertigen RDP-Verbindungen zu allen Lab-Servern (Domain-Admin, fuer jeden Benutzer am Client). Das Admin-Passwort ist dort fuer alle Benutzer auslesbar; RDM Free ist laut Devolutions fuer eine Einzelperson lizenziert.')
param clientRemoteDesktopManager bool = true

@description('Tools per winget auf dem Client, maschinenweit in der jeweils neuesten Version. Ein taeglicher Task (TraineeLab-WinGetUpdate) haelt sie aktuell. Leer = keine.')
param clientWingetPackages array = [
  'Microsoft.VisualStudioCode'
]

@description('Fileserver <K>-FS01 bereitstellen: Freigaben mit AGDLP-Berechtigungen, Basisordner, FSRM und absichtliche Altlasten fuer Uebungen. Keine Public IP.')
param deployFileServer bool = true

@description('VM-Groesse des Fileservers. Mehr vCPUs erzeugen die Beispieldokumente schneller (siehe docs/de/deployment.md). Startet er mit einer B-Groesse, bleibt sie.')
@allowed([
  'Standard_B2s_v2'
  'Standard_B2ms'
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D8s_v5'
])
param fileServerVmSize string = 'Standard_D4s_v5'

// B2s_v2 statt B2ms: Die VM verkleinert sich im laufenden Betrieb, also nur auf Groessen ihres Hardware-Clusters.
// Die Dsv5-Cluster fuehren Bsv2, aber nicht die alte B-Serie (Testdeployment: B2ms nicht verfuegbar).
@description('Dauergroesse des Fileservers: Nach Beispieldokumenten und Updates verkleinert sich die VM selbst darauf. Leer = fileServerVmSize bleibt.')
@allowed([
  ''
  'Standard_B2s_v2'
  'Standard_D2s_v5'
  'Standard_D4s_v5'
])
param fileServerFinalVmSize string = 'Standard_B2s_v2'

@description('Umfang der Beispieldokumente (Word, Excel, PowerPoint, PDF) in Prozent der Datendisk des Fileservers (256 GB), 0 = keine. Was im Deployment nicht fertig wird, entsteht danach im Hintergrund.')
@minValue(0)
@maxValue(90)
param fileServerDataPercent int = 90

@description('VM-Groesse des Exchange-Servers (Microsoft empfiehlt fuer Produktion 128 GB RAM; 32 GB reichen fuer das Lab).')
@allowed([
  'Standard_E4s_v5'
  'Standard_E8s_v5'
])
param exchangeVmSize string = 'Standard_E4s_v5'

@description('Zusaetzliche Tags.')
param tags object = {}

// ---------------------------------------------------------------------------------------------
// Variablen
// ---------------------------------------------------------------------------------------------

var traineeLower = toLower(trainee)
var traineeUpper = toUpper(trainee)
var adDomainName = '${traineeLower}.intern'
var publicDomainName = '${traineeLower}.${parentDnsZoneName}'
var companyOu = 'LEARN-${traineeLower}'

var addressPrefix = '10.0.0.0/16'
var dcPrivateIp = '10.0.1.4'
var exchangePrivateIp = '10.0.1.5'
var dc2PrivateIp = '10.0.1.6'
var fileServerPrivateIp = '10.0.1.7'
var fileServerResizeTo = fileServerFinalVmSize == fileServerVmSize || startsWith(fileServerVmSize, 'Standard_B') ? '' : fileServerFinalVmSize
var clientPrivateIp = '10.0.1.10'

var names = {
  vnet: 'vnet-exlab-${traineeLower}'
  subnet: 'snet-servers'
  nsg: 'nsg-exlab-${traineeLower}'
  dcVm: 'vm-${traineeLower}-dc01'
  dcComputer: '${traineeUpper}-DC01'
  dc2Vm: 'vm-${traineeLower}-dc02'
  dc2Computer: '${traineeUpper}-DC02'
  exchangeVm: 'vm-${traineeLower}-ex01'
  exchangeComputer: '${traineeUpper}-EX01'
  exchangePublicIp: 'pip-${traineeLower}-ex01'
  clientVm: 'vm-${traineeLower}-cl01'
  clientComputer: '${traineeUpper}-CL01'
  clientPublicIp: 'pip-${traineeLower}-cl01'
  fsVm: 'vm-${traineeLower}-fs01'
  fsComputer: '${traineeUpper}-FS01'
}

// Einzige Quelle der Subnet-Definition: wird bei Erstanlage und DNS-Umstellung identisch verwendet.
// defaultOutboundAccess explizit true: der DC hat keine Public IP, braucht aber Aktivierung und Updates.
var subnets = [
  {
    name: names.subnet
    properties: {
      addressPrefix: '10.0.1.0/24'
      defaultOutboundAccess: true
      networkSecurityGroup: {
        id: resourceId('Microsoft.Network/networkSecurityGroups', names.nsg)
      }
    }
  }
]

var webSourcePrefix = empty(exchangePublishedSourcePrefix) ? allowedRdpSourcePrefix : exchangePublishedSourcePrefix

var allTags = union(tags, {
  workload: 'exchange-lab'
  trainee: traineeLower
  managedBy: 'bicep'
})

// ---------------------------------------------------------------------------------------------
// Module
// ---------------------------------------------------------------------------------------------

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    tags: allTags
    vnetName: names.vnet
    addressPrefix: addressPrefix
    subnets: subnets
    nsgName: names.nsg
    exchangePrivateIp: exchangePrivateIp
    allowedRdpSourcePrefix: allowedRdpSourcePrefix
    exchangePublishedSourcePrefix: webSourcePrefix
    smtpSourcePrefix: empty(smtpSourcePrefix) ? webSourcePrefix : smtpSourcePrefix
    publicIpName: names.exchangePublicIp
    publicIpDnsLabel: 'mail-${traineeLower}-${take(uniqueString(resourceGroup().id), 6)}'
    deployClient: deployClient
    clientPrivateIp: clientPrivateIp
    clientPublicIpName: names.clientPublicIp
    clientPublicIpDnsLabel: 'cl-${traineeLower}-${take(uniqueString(resourceGroup().id), 6)}'
  }
}

module dnsZone 'modules/dns-zone.bicep' = {
  name: 'dns-zone'
  params: {
    tags: allTags
    zoneName: publicDomainName
    exchangePublicIp: network.outputs.publicIpAddress
  }
}

module dnsDelegation 'modules/dns-delegation.bicep' = {
  name: 'ns-delegation-${traineeLower}'
  scope: resourceGroup(parentDnsZoneResourceGroup)
  params: {
    parentZoneName: parentDnsZoneName
    childLabel: traineeLower
    nameServers: dnsZone.outputs.nameServers
  }
}

module domainController 'modules/domain-controller.bicep' = {
  name: 'domain-controller'
  params: {
    location: location
    tags: allTags
    vmName: names.dcVm
    computerName: names.dcComputer
    vmSize: dcVmSize
    subnetId: network.outputs.subnetId
    privateIp: dcPrivateIp
    adminUsername: adminUsername
    adminPassword: adminPassword
    domainName: adDomainName
    netbiosName: traineeUpper
    publicDomainName: publicDomainName
    exchangeIp: exchangePrivateIp
    labLanguage: labLanguage
  }
}

module exchangeServer 'modules/exchange-server.bicep' = {
  name: 'exchange-server'
  params: {
    location: location
    tags: allTags
    vmName: names.exchangeVm
    computerName: names.exchangeComputer
    vmSize: exchangeVmSize
    subnetId: network.outputs.subnetId
    privateIp: exchangePrivateIp
    publicIpId: network.outputs.publicIpId
    adminUsername: adminUsername
    adminPassword: adminPassword
    publicDomainName: publicDomainName
    exchangeIsoUri: exchangeIsoUri
    exchangeIsoSha256: exchangeIsoSha256
    enableLetsEncrypt: enableLetsEncrypt
    letsEncryptStaging: letsEncryptStaging
    labLanguage: labLanguage
  }
  // Zertifikat braucht Zone (Rollenzuweisung) und funktionierende Delegation.
  dependsOn: [
    dnsZone
    dnsDelegation
  ]
}

// Laeuft parallel zum ersten DC und wartet selbst (Run Command Wait-DomainController), bis dieser fertig ist.
module secondDomainController 'modules/domain-controller.bicep' = if (deploySecondDc) {
  name: 'domain-controller-2'
  params: {
    location: location
    tags: allTags
    vmName: names.dc2Vm
    computerName: names.dc2Computer
    vmSize: dcVmSize
    subnetId: network.outputs.subnetId
    privateIp: dc2PrivateIp
    adminUsername: adminUsername
    adminPassword: adminPassword
    domainName: adDomainName
    netbiosName: traineeUpper
    publicDomainName: publicDomainName
    exchangeIp: exchangePrivateIp
    mode: 'Replica'
    firstDcIp: dcPrivateIp
    labLanguage: labLanguage
  }
}

// Schranke: DC02 ist vollstaendig bereit (SYSVOL, DNS, Replikation), bevor er DNS-Server des VNets wird
// und die Exchange-Installation beginnt.
module dcReady 'modules/dc-ready.bicep' = if (deploySecondDc) {
  name: 'dc-ready'
  params: {
    location: location
    tags: allTags
    vmName: names.dcVm
    domainName: adDomainName
    netbiosName: traineeUpper
    adminUsername: adminUsername
    adminPassword: adminPassword
    secondDcComputerName: names.dc2Computer
    secondDcIp: dc2PrivateIp
    publicDomainName: publicDomainName
    exchangeIp: exchangePrivateIp
  }
  dependsOn: [
    domainController
    secondDomainController
  ]
}

module vnetDns 'modules/vnet-dns.bicep' = {
  name: 'vnet-dns'
  params: {
    location: location
    tags: allTags
    vnetName: names.vnet
    addressPrefix: addressPrefix
    subnets: subnets
    dnsServers: deploySecondDc ? [
      dcPrivateIp
      dc2PrivateIp
    ] : [
      dcPrivateIp
    ]
  }
  dependsOn: [
    domainController
    secondDomainController
    dcReady
  ]
}

module exchangeInstall 'modules/exchange-install.bicep' = {
  name: 'exchange-install'
  params: {
    location: location
    tags: allTags
    vmName: exchangeServer.outputs.vmName
    adminUsername: adminUsername
    adminPassword: adminPassword
    labUserPassword: labUserPassword
    domainName: adDomainName
    netbiosName: traineeUpper
    publicDomainName: publicDomainName
    companyOu: companyOu
    dcComputerName: names.dcComputer
    secondDcComputerName: deploySecondDc ? names.dc2Computer : ''
    clientComputerName: deployClient ? names.clientComputer : ''
    fileServerComputerName: deployFileServer ? names.fsComputer : ''
    dcIp: dcPrivateIp
    exchangeIp: exchangePrivateIp
    labLanguage: labLanguage
  }
  // Exchange-Setup erst, wenn alle DCs stehen, damit es keinen halb replizierten DC erwischt.
  dependsOn: [
    vnetDns
  ]
}

// Vorbereitung (Sprachpaket, Office) parallel zum DC-Aufbau, Beitritt erst nach der DNS-Umstellung.
module client 'modules/client.bicep' = if (deployClient) {
  name: 'client'
  params: {
    location: location
    tags: allTags
    vmName: names.clientVm
    computerName: names.clientComputer
    vmSize: clientVmSize
    subnetId: network.outputs.subnetId
    privateIp: clientPrivateIp
    publicIpId: network.outputs.clientPublicIpId
    adminUsername: adminUsername
    adminPassword: adminPassword
    imageSku: clientImageSku
    officeProductId: officeProductId
    installRemoteDesktopManager: clientRemoteDesktopManager
    wingetPackages: clientWingetPackages
    labLanguage: labLanguage
  }
}

module clientJoin 'modules/client-join.bicep' = if (deployClient) {
  name: 'client-join'
  params: {
    location: location
    tags: allTags
    vmName: names.clientVm
    adminUsername: adminUsername
    adminPassword: adminPassword
    domainName: adDomainName
    netbiosName: traineeUpper
    publicDomainName: publicDomainName
    dcIp: dcPrivateIp
    exchangeIp: exchangePrivateIp
    dcComputerName: names.dcComputer
    secondDcComputerName: deploySecondDc ? names.dc2Computer : ''
    exchangeComputerName: names.exchangeComputer
    fileServerComputerName: deployFileServer ? names.fsComputer : ''
    labLanguage: labLanguage
  }
  dependsOn: [
    client
    vnetDns
  ]
}

// Vorbereitung (Disk, Ordnergeruest) und Beispieldokumente parallel zum DC-Aufbau und zur Exchange-Installation,
// Beitritt erst danach und nach der DNS-Umstellung.
module fileServer 'modules/file-server.bicep' = if (deployFileServer) {
  name: 'file-server'
  params: {
    location: location
    tags: allTags
    vmName: names.fsVm
    computerName: names.fsComputer
    vmSize: fileServerVmSize
    subnetId: network.outputs.subnetId
    privateIp: fileServerPrivateIp
    adminUsername: adminUsername
    adminPassword: adminPassword
    sampleDataPercent: fileServerDataPercent
    finalVmSize: fileServerResizeTo
    labLanguage: labLanguage
  }
}

// Gruppen und Basisordner brauchen die Lab-Benutzer, die Phase Complete wartet selbst auf die Exchange-Installation.
module fileServerJoin 'modules/file-server-join.bicep' = if (deployFileServer) {
  name: 'file-server-join'
  params: {
    location: location
    tags: allTags
    vmName: names.fsVm
    adminUsername: adminUsername
    adminPassword: adminPassword
    domainName: adDomainName
    netbiosName: traineeUpper
    publicDomainName: publicDomainName
    companyOu: companyOu
    dcComputerName: names.dcComputer
    dcIp: dcPrivateIp
    exchangeIp: exchangePrivateIp
    finalVmSize: fileServerResizeTo
    waitForSampleDocuments: fileServerDataPercent > 0
    labLanguage: labLanguage
  }
  dependsOn: [
    fileServer
    vnetDns
  ]
}

// Update-Lauf der DCs erst ganz am Ende: Ihre Neustarts treffen keine VM mehr, die beitritt oder sich einrichtet.
module labFinalize 'modules/lab-finalize.bicep' = {
  name: 'lab-finalize'
  params: {
    location: location
    tags: allTags
    vmNames: deploySecondDc ? [
      names.dcVm
      names.dc2Vm
    ] : [
      names.dcVm
    ]
  }
  dependsOn: [
    exchangeInstall
    clientJoin
    fileServerJoin
    dcReady
  ]
}

// Erst nach der Installation, damit der Schedule das Exchange-Setup nicht unterbricht.
module exchangeShutdown 'modules/auto-shutdown.bicep' = if (!empty(autoShutdownTime)) {
  name: 'auto-shutdown-${names.exchangeVm}'
  params: {
    location: location
    tags: allTags
    vmName: names.exchangeVm
    shutdownTime: autoShutdownTime
  }
  dependsOn: [
    exchangeInstall
  ]
}

// DC02 darf deallokiert werden: Beim Start holt er sich SYSVOL vom durchlaufenden ersten DC.
module secondDcShutdown 'modules/auto-shutdown.bicep' = if (deploySecondDc && !empty(autoShutdownTime)) {
  name: 'auto-shutdown-${names.dc2Vm}'
  params: {
    location: location
    tags: allTags
    vmName: names.dc2Vm
    shutdownTime: autoShutdownTime
  }
  dependsOn: [
    exchangeInstall
    secondDomainController
  ]
}

module clientShutdown 'modules/auto-shutdown.bicep' = if (deployClient && !empty(autoShutdownTime)) {
  name: 'auto-shutdown-${names.clientVm}'
  params: {
    location: location
    tags: allTags
    vmName: names.clientVm
    shutdownTime: autoShutdownTime
  }
  dependsOn: [
    exchangeInstall
    clientJoin
  ]
}

module fileServerShutdown 'modules/auto-shutdown.bicep' = if (deployFileServer && !empty(autoShutdownTime)) {
  name: 'auto-shutdown-${names.fsVm}'
  params: {
    location: location
    tags: allTags
    vmName: names.fsVm
    shutdownTime: autoShutdownTime
  }
  dependsOn: [
    exchangeInstall
    fileServerJoin
  ]
}

// ---------------------------------------------------------------------------------------------
// Ausgaben
// ---------------------------------------------------------------------------------------------

output owaUrl string = 'https://mail.${publicDomainName}/owa'
output rdpHost string = network.outputs.publicIpFqdn
output adDomain string = adDomainName
output publicDomain string = publicDomainName
output clientRdpHost string = deployClient ? network.outputs.clientPublicIpFqdn : ''
output fileServerUnc string = deployFileServer ? '\\\\${names.fsComputer}' : ''
