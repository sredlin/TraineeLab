// Delegiert die Subdomain des Azubis in der uebergeordneten Zone (Scope: Ressourcengruppe der Parent-Zone).
// Die Parent-Zone wird nur angelegt, wenn sie fehlt. Eine bestehende Zone bleibt unveraendert,
// pro Deployment kommt nur der NS-Record der Subdomain dazu.

@description('Name der uebergeordneten Zone, z. B. lab.example.com.')
param parentZoneName string

@description('Label der Subdomain, z. B. abc.')
param childLabel string

@description('Nameserver der delegierten Zone.')
param nameServers array

// Keine Tags: die Zone wird von allen Azubis geteilt.
@onlyIfNotExists()
resource parentZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: parentZoneName
  location: 'global'
  properties: {
    zoneType: 'Public'
  }
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
