// Abschluss des Deployments: Erst wenn Exchange, Client und Fileserver fertig sind, starten die DCs ihren
// einmaligen Update-Lauf. Dessen Neustarts treffen so keine VM mehr, die gerade beitritt oder sich einrichtet.

@description('Azure-Region.')
param location string

@description('Tags fuer alle Ressourcen.')
param tags object

@description('Namen der DC-VMs.')
param vmNames array

resource vms 'Microsoft.Compute/virtualMachines@2025-04-01' existing = [for name in vmNames: {
  name: name
}]

resource startUpdate 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = [for (name, i) in vmNames: {
  parent: vms[i]
  name: 'Start-LabUpdate'
  location: location
  tags: tags
  properties: {
    source: {
      script: loadTextContent('../../scripts/Start-LabUpdate.ps1')
    }
    parameters: [
      {
        name: 'UpdateScriptB64'
        value: loadFileAsBase64('../../scripts/Update-LabServer.ps1')
      }
    ]
    asyncExecution: false
    timeoutInSeconds: 600
    treatFailureAsDeploymentFailure: true
  }
}]
