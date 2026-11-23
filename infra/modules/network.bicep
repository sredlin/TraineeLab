// Netzwerk des Labs: NSG, VNet mit einem Subnet und Public IP fuer den Exchange-Server.

@description('Azure-Region.')
param location string

@description('Tags fuer alle Ressourcen.')
param tags object

@description('Name des virtuellen Netzwerks.')
param vnetName string

@description('Adressraum des VNets.')
param addressPrefix string

@description('Subnet-Definitionen. Identisch zur spaeteren DNS-Umstellung (modules/vnet-dns.bicep), damit NSG und Outbound-Einstellung erhalten bleiben.')
param subnets array

@description('Name der Network Security Group.')
param nsgName string

@description('Private IP des Exchange-Servers (Ziel der eingehenden Regeln).')
param exchangePrivateIp string

@description('Quelle fuer RDP (z. B. eigene oeffentliche IP/32).')
param allowedRdpSourcePrefix string

@description('Quelle fuer HTTP und HTTPS zum Exchange-Server.')
param exchangePublishedSourcePrefix string

@description('Quelle fuer SMTP zum Exchange-Server. Getrennt von HTTP/HTTPS, damit eingehende Mails aus dem Internet nicht auch ECP oeffentlich machen.')
param smtpSourcePrefix string

@description('Name der Public IP des Exchange-Servers.')
param publicIpName string

@description('DNS-Label der Public IP (<label>.<region>.cloudapp.azure.com).')
param publicIpDnsLabel string

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-Exchange'
        properties: {
          description: 'RDP auf den Exchange-Server (Jump-Host fuer den DC), nur von der freigegebenen Quelle.'
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedRdpSourcePrefix
          sourcePortRange: '*'
          destinationAddressPrefix: exchangePrivateIp
          destinationPortRange: '3389'
        }
      }
      {
        name: 'Allow-Exchange-Web'
        properties: {
          description: 'HTTP (Weiterleitung) und HTTPS auf den Exchange-Server (OWA, ECP, Outlook, Autodiscover).'
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: exchangePublishedSourcePrefix
          sourcePortRange: '*'
          destinationAddressPrefix: exchangePrivateIp
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
      }
      {
        name: 'Allow-Exchange-SMTP'
        properties: {
          description: 'SMTP auf den Exchange-Server (eingehende Mails).'
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: smtpSourcePrefix
          sourcePortRange: '*'
          destinationAddressPrefix: exchangePrivateIp
          destinationPortRange: '25'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: subnets
  }
  dependsOn: [
    nsg
  ]
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: publicIpDnsLabel
    }
  }
}

output subnetId string = vnet.properties.subnets[0].id
output publicIpId string = publicIp.id
output publicIpAddress string = publicIp.properties.ipAddress
output publicIpFqdn string = publicIp.properties.dnsSettings.fqdn
