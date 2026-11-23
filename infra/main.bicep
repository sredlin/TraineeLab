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

@description('Azure-Region. Standard: Region der Ressourcengruppe.')
param location string = resourceGroup().location

@description('Administrator beider VMs, nach der Heraufstufung zugleich Domain-Administrator.')
param adminUsername string = 'azadmin'

@description('Passwort des Administrators (auch DSRM-Passwort).')
@secure()
param adminPassword string

@description('Passwort der 12 Lab-Benutzer. Leer = Administrator-Passwort.')
@secure()
param labUserPassword string = ''

@description('Quelle fuer RDP auf den Exchange-Server, z. B. eigene oeffentliche IP als 203.0.113.10/32. Kein "*".')
param allowedRdpSourcePrefix string

@description('Quelle fuer SMTP/HTTP/HTTPS auf den Exchange-Server. Leer = wie RDP. Erst nach dem Update-Lauf auf "Internet" stellen.')
param exchangePublishedSourcePrefix string = ''

@description('Uebergeordnete oeffentliche DNS-Zone fuer die Subdomain-Delegation (Name vom Ausbilder). Wird angelegt, falls sie fehlt; eine bestehende Zone bleibt unveraendert.')
param parentDnsZoneName string

@description('Ressourcengruppe der uebergeordneten DNS-Zone (gleiche Subscription).')
param parentDnsZoneResourceGroup string = 'rg-publicdns'

@description('Download-URL des Exchange-Server-SE-ISO (Microsoft Download Center, ID 108244).')
param exchangeIsoUri string = 'https://download.microsoft.com/download/ad9b1e53-f28e-4a82-987d-6c88803795b2/ExchangeServerSE-x64.iso'

@description('Let\'s-Encrypt-Wildcard-Zertifikat ueber die Managed Identity anfordern (Deployer braucht Owner/User Access Administrator auf der Ressourcengruppe).')
param enableLetsEncrypt bool = true

@description('Let\'s-Encrypt-Staging (Test-CA) verwenden, z. B. fuer Testdeployments.')
param letsEncryptStaging bool = false

@description('Optionale Tools per winget auf dem Exchange-Server.')
param wingetPackages array = [
  'Microsoft.VisualStudioCode'
]

@description('VM-Groesse des Domain Controllers.')
@allowed([
  'Standard_B2ms'
  'Standard_D2s_v5'
])
param dcVmSize string = 'Standard_B2ms'

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

var names = {
  vnet: 'vnet-exlab-${traineeLower}'
  subnet: 'snet-servers'
  nsg: 'nsg-exlab-${traineeLower}'
  dcVm: 'vm-${traineeLower}-dc01'
  dcComputer: '${traineeUpper}-DC01'
  exchangeVm: 'vm-${traineeLower}-ex01'
  exchangeComputer: '${traineeUpper}-EX01'
  exchangePublicIp: 'pip-${traineeLower}-ex01'
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
    exchangePublishedSourcePrefix: empty(exchangePublishedSourcePrefix) ? allowedRdpSourcePrefix : exchangePublishedSourcePrefix
    publicIpName: names.exchangePublicIp
    publicIpDnsLabel: 'mail-${traineeLower}-${take(uniqueString(resourceGroup().id), 6)}'
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
    enableLetsEncrypt: enableLetsEncrypt
    letsEncryptStaging: letsEncryptStaging
    wingetPackages: wingetPackages
  }
  // Zertifikat braucht Zone (Rollenzuweisung) und funktionierende Delegation.
  dependsOn: [
    dnsZone
    dnsDelegation
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
    dnsServers: [
      dcPrivateIp
    ]
  }
  dependsOn: [
    domainController
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
    labUserPassword: empty(labUserPassword) ? adminPassword : labUserPassword
    domainName: adDomainName
    netbiosName: traineeUpper
    publicDomainName: publicDomainName
    companyOu: companyOu
    dcComputerName: names.dcComputer
    dcIp: dcPrivateIp
    exchangeIp: exchangePrivateIp
  }
  dependsOn: [
    vnetDns
  ]
}

// ---------------------------------------------------------------------------------------------
// Ausgaben
// ---------------------------------------------------------------------------------------------

output owaUrl string = 'https://mail.${publicDomainName}/owa'
output rdpHost string = network.outputs.publicIpFqdn
output adDomain string = adDomainName
output publicDomain string = publicDomainName
