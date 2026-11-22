// Stellt den DNS-Server des VNets auf den Domain Controller um, sobald dieser heraufgestuft ist.
// Ersetzt das fruehere VirtualNetwork.json. Die Subnets kommen aus derselben Variable wie bei der
// Erstanlage, damit NSG-Zuordnung und Outbound-Einstellung nicht verloren gehen.

@description('Azure-Region.')
param location string

@description('Tags fuer alle Ressourcen.')
param tags object

@description('Name des virtuellen Netzwerks.')
param vnetName string

@description('Adressraum des VNets.')
param addressPrefix string

@description('Subnet-Definitionen (identisch zu modules/network.bicep).')
param subnets array

@description('DNS-Server fuer das VNet.')
param dnsServers array

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
    dhcpOptions: {
      dnsServers: dnsServers
    }
    subnets: subnets
  }
}
