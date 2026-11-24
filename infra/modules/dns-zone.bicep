// Oeffentliche DNS-Zone des Azubis (<trainee>.<parent>) mit den Exchange-Records.

@description('Tags fuer alle Ressourcen.')
param tags object

@description('Name der Zone, z. B. abc.lab.example.com.')
param zoneName string

@description('Oeffentliche IP des Exchange-Servers.')
param exchangePublicIp string

resource zone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: zoneName
  location: 'global'
  tags: tags
  properties: {
    zoneType: 'Public'
  }
}

resource mailRecord 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  parent: zone
  name: 'mail'
  properties: {
    TTL: 300
    ARecords: [
      {
        ipv4Address: exchangePublicIp
      }
    ]
  }
}

resource autodiscoverRecord 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  parent: zone
  name: 'autodiscover'
  properties: {
    TTL: 300
    CNAMERecord: {
      cname: 'mail.${zoneName}'
    }
  }
}

resource mxRecord 'Microsoft.Network/dnsZones/MX@2018-05-01' = {
  parent: zone
  name: '@'
  properties: {
    TTL: 300
    MXRecords: [
      {
        preference: 10
        exchange: 'mail.${zoneName}'
      }
    ]
  }
}

// SPF: nur der MX-Host darf fuer die Domain senden. Ausgehend geht aus Azure ohnehin nur ueber einen Smart Host.
resource spfRecord 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  parent: zone
  name: '@'
  properties: {
    TTL: 300
    TXTRecords: [
      {
        value: [
          'v=spf1 mx -all'
        ]
      }
    ]
  }
}

// DMARC nur im Beobachtungsmodus, damit Uebungen zu Mail-Hygiene darauf aufbauen koennen.
resource dmarcRecord 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  parent: zone
  name: '_dmarc'
  properties: {
    TTL: 300
    TXTRecords: [
      {
        value: [
          'v=DMARC1; p=none'
        ]
      }
    ]
  }
}

output zoneId string = zone.id
output nameServers array = zone.properties.nameServers
