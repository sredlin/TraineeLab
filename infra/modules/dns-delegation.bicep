// Delegiert die Subdomain des Azubis in der uebergeordneten Zone (Scope: Ressourcengruppe der Parent-Zone).
// Ersetzt das fruehere portal-interne Template (dns.hosting.portal.azure.net).

@description('Name der uebergeordneten Zone, z. B. lab.example.com.')
param parentZoneName string

@description('Label der Subdomain, z. B. abc.')
param childLabel string

@description('Nameserver der delegierten Zone.')
param nameServers array

resource parentZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: parentZoneName
}

resource delegation 'Microsoft.Network/dnsZones/NS@2018-05-01' = {
  parent: parentZone
  name: childLabel
  properties: {
    TTL: 300
    NSRecords: [
      for server in nameServers: {
        nsdname: server
      }
    ]
  }
}
