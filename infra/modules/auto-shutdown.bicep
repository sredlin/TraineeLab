// Taegliches automatisches Herunterfahren (Deallokieren) einer VM ueber einen DevTest-Labs-Schedule.
// Der Name shutdown-computevm-<vm> ist vorgegeben, sonst erscheint der Schedule nicht im Portal-Blade der VM.
// Nicht fuer den ersten DC verwenden: Deallokieren setzt die VM-Generation-ID zurueck, SYSVOL wird
// dadurch nicht-autoritativ und braucht ohne erreichbaren Partner-DC einen manuellen Eingriff.

@description('Azure-Region.')
param location string

@description('Tags fuer alle Ressourcen.')
param tags object

@description('Name der bestehenden VM.')
param vmName string

@description('Uhrzeit des Herunterfahrens im Format HHmm (W. Europe Standard Time).')
@minLength(4)
@maxLength(4)
param shutdownTime string

resource vm 'Microsoft.Compute/virtualMachines@2025-04-01' existing = {
  name: vmName
}

resource schedule 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  tags: tags
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: shutdownTime
    }
    timeZoneId: 'W. Europe Standard Time'
    targetResourceId: vm.id
    notificationSettings: {
      status: 'Disabled'
      timeInMinutes: 30
    }
  }
}
