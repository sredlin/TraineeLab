# Troubleshooting

**English** · [Deutsch](../de/troubleshooting.md)

Placeholders as in [Operations](operations.md). "EMS" = Exchange Management Shell on `<K>-EX01`, started as administrator.

## Deployment failed

1. In the portal, find the failed step under resource group → *Deployments*. It is usually a Run Command (`Install-DomainController`, `Initialize-ExchangeServer`, `Wait-DomainController`, `Install-ExchangeServer`, `Initialize-LabClient`, `Complete-LabClient`, on the file server `Initialize-FileServer`, `New-SampleDocuments`, `Complete-FileServer`).
2. The error message contains the end of the corresponding log. The full log is on the VM in `C:\ExchangeLab\Logs`.
3. Fix the cause (e.g. quota, permissions, zone), then **delete the failed Run Command** and **redeploy with the same parameters**. Without deleting it, Azure does not run a failed Run Command with unchanged properties again; the deployment only reports the old error. The scripts are idempotent; steps already completed are skipped.

   ```bash
   az vm run-command list -g rg-exlab-<k> --vm-name vm-<k>-dc02 --query "[].{name:name, state:provisioningState}" -o table
   az vm run-command delete -g rg-exlab-<k> --vm-name vm-<k>-dc02 --name Install-DomainController --yes
   ```

Typical causes:

| Message / symptom | Cause | Solution |
| --- | --- | --- |
| `QuotaExceeded` | not enough vCPUs in the region | Have the quota increased or switch off `deployClient`/`deploySecondDc`. If the DSv5 family is affected: `fileServerVmSize = Standard_B2s_v2` |
| `AuthorizationFailed` on the role assignment | no Owner on the resource group | Get permissions from the trainer, or set `enableLetsEncrypt = false` and leave `fileServerFinalVmSize` empty |
| `New-SampleDocuments` reports an error | data disk missing or text corpus from userData not readable | Read `New-SampleDocuments.log` on the file server. A pure timing issue is not an error: after 60 minutes the Run Command ends successfully and the task continues |
| `Wait-DomainController` times out | DC did not finish | Read `Install-DomainController-*.log` on the DC, and `Install-DomainController-Promote.log` if a restart was scheduled |
| "Role change is in progress or this computer needs to be restarted" | Windows maintenance after the first start has scheduled a restart | The script then promotes automatically after a restart. If the error still appears in the log: restart the DC from within the guest, delete the Run Command, redeploy |
| `letsencrypt-failed.txt` in `C:\ExchangeLab` | certificate not issued, Exchange uses a self-signed certificate | Check the subdomain delegation, see below |

## OWA reports a certificate error

- **Test deployment with `letsEncryptStaging = true`:** The staging CA is deliberately not trusted. This is not an error.
- **`C:\ExchangeLab\letsencrypt-failed.txt` exists:** The DNS challenge did not work. Check whether the subdomain resolves from outside:

  ```powershell
  Resolve-DnsName -Name <k>.<zone> -Type NS -Server 1.1.1.1
  ```

- **Certificate expired:** Read `C:\ExchangeLab\Logs\Invoke-LabMaintenance.log`. Trigger maintenance by hand: `Start-ScheduledTask -TaskName ExchangeLab-Maintenance`. If that does not help, use the manual renewal from [Architecture](architecture.md#certificate).

## Exchange services not running after start-up

Shortly after start-up some services are not ready yet. After 10 minutes, in the EMS:

```powershell
Test-ServiceHealth
Get-Service MSExchange* | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' } | Start-Service
```

If services stay down, the DC is often unreachable: `nltest /dsgetdc:<k>.intern` on the Exchange server.

## SYSVOL and NETLOGON missing on the DC

Symptom: `net share` on the DC shows neither `SYSVOL` nor `NETLOGON`, Group Policy is not applied. The cause is almost always that the DC was stopped (deallocated) in the portal. Afterwards SYSVOL is non-authoritative and finds no partner to synchronise from.

**Only one DC:** Set SYSVOL on this DC to authoritative (corresponds to "D4" in the Microsoft guide). On `<K>-DC01`, PowerShell as administrator:

```powershell
Install-WindowsFeature RSAT-DFS-Mgmt-Con          # provides dfsrdiag
Set-Service DFSR -StartupType Manual; Stop-Service DFSR

$dn = "CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,$((Get-ADDomainController).ComputerObjectDN)"
Set-ADObject -Identity $dn -Replace @{ 'msDFSR-Enabled' = $false; 'msDFSR-options' = 1 }

Start-Service DFSR                                 # event 4114 in the "DFS Replication" log
Set-ADObject -Identity $dn -Replace @{ 'msDFSR-Enabled' = $true }
dfsrdiag pollad                                    # event 4602: SYSVOL initialised
Set-Service DFSR -StartupType Automatic
net share                                          # SYSVOL and NETLOGON are back
```

**Two DCs, both were deallocated:** Set `<K>-DC01` (PDC emulator) authoritative and `<K>-DC02` non-authoritative. The full sequence is documented by Microsoft: [Force authoritative and non-authoritative synchronization for DFSR-replicated SYSVOL](https://learn.microsoft.com/troubleshoot/windows-server/group-policy/force-authoritative-non-authoritative-synchronization).

## Mail stuck in the queue

```powershell
Get-Queue
Get-Message -Queue "<K>-EX01\<Queue-Identität>" | Format-List FromAddress, Recipients, LastError
```

- **External recipients** (queue with `DeliveryType` `Unreachable`): There is no send connector, and Azure blocks outbound port 25. This is intended.
- **Internal recipients:** Check `Test-ServiceHealth` and `Get-ServerComponentState <K>-EX01`. If `HubTransport` is `Inactive`, activate it with `Set-ServerComponentState <K>-EX01 -Component HubTransport -State Active -Requester Maintenance`.

## Outlook on the client does not connect

1. Is the user signed in with a domain account (`<K>\fbloggs`, German lab `<K>\mmustermann`), not as local admin?
2. Does the client resolve correctly? `Resolve-DnsName mail.<k>.<zone>` must return `10.0.1.5` (split DNS).
3. Test Autodiscover: Ctrl + right-click the Outlook icon in the notification area → *Test E-mail AutoConfiguration*.
4. Was the **new** Outlook started by mistake? It does not support Exchange on-premises. Open the classic Outlook via *Start → Outlook (classic)*.

## Office reports "Unlicensed Product"

- Signed in with the **company account**, not the lab account? The lab account has no Microsoft 365 licence.
- Show the licence status (PowerShell as administrator):

  ```powershell
  cd "C:\Program Files\Microsoft Office\Office16"
  .\vnextdiag.ps1 -action list
  ```

- If the product ID does not match the licence (Apps for business vs. Apps for enterprise): uninstall Microsoft 365 Apps under *Settings → Apps*, change the `Product ID` in `C:\ExchangeLab\Install\OfficeDeploymentTool\LabConfiguration.xml` and reinstall as administrator:

  ```powershell
  cd C:\ExchangeLab\Install\OfficeDeploymentTool
  .\setup.exe /configure LabConfiguration.xml
  ```

## Client user interface is in English

With `labLanguage = en` this is intended: English user interface from the image, en-GB formats, German keyboard.

With `labLanguage = de` the language pack is installed during setup and takes effect after the restart. If `Initialize-LabClient-Prepare.log` contains a warning about the language pack, catch up as administrator:

```powershell
Install-Language de-DE -CopyToSettings
Set-SystemPreferredUILanguage de-DE
Restart-Computer
```

## Remote Desktop Manager shows no lab connections

1. Is RDM installed? `C:\ExchangeLab\Logs\Initialize-LabClient-Prepare.log` lists the steps .NET Desktop Runtime, Remote Desktop Manager, PowerShell 7 and module. On failure there is also `C:\ExchangeLab\rdm-failed.txt` with the cause.
2. Was the data source created? `Initialize-LabClient-Complete.log` reports `RDM-Datenquelle ... angelegt` (RDM data source created) with all servers.
3. If the "Lab-Server" workspace is missing for one user only: check `%LOCALAPPDATA%\TraineeLab\Register-LabWorkspace.log` and repeat the registration by hand as that user (close RDM first):

   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\TraineeLab\RemoteDesktopManager\Register-LabWorkspace.ps1
   ```

4. If RDM asks for a password when connecting, the saved one is no longer correct, for example because `azadmin` has a new password. See [Operations](operations.md#reach-the-servers-from-the-client-remote-desktop-manager).

## Sample data missing or no longer growing

Status on `<K>-FS01` (PowerShell as administrator):

```powershell
Get-Content C:\ExchangeLab\sample-documents.json
Get-Content C:\ExchangeLab\Logs\New-SampleDocuments.log -Tail 20
Get-ScheduledTask -TaskName TraineeLab-SampleDocuments | Get-ScheduledTaskInfo
```

- **`State` = `wird im Hintergrund fortgesetzt` (continuing in the background), log not moving:** The VM was shut down at the shutdown time. The task starts by itself at the next start; to run it immediately use `Start-ScheduledTask -TaskName TraineeLab-SampleDocuments`. The generator skips existing files and cleans up half-finished ones.
- **`WARNUNG` (warning) lines in the log:** Individual files or units failed. This does not affect the remaining data. If there are many identical warnings, pass the log to the trainer.
- **No status file:** The Run Command `New-SampleDocuments` did not run (`fileServerDataPercent = 0` or an error in the deployment).
- **`Volume fast voll` (volume almost full) in the log:** The generator stops when less than 8 % of the data disk is free. The target (90 %) is then practically reached; cluster slack and the file system take up the rest.

## File server stays large

The file server only shrinks once sample data, setup and update run are finished and it has been running for at least 30 minutes. The log states the reason for waiting:

```powershell
Get-Content C:\ExchangeLab\Logs\Resize-FileServer.log -Tail 10
```

If the cluster does not offer `fileServerFinalVmSize`, the script picks the 2-vCPU size of the family itself (e.g. `Standard_D2s_v5`, noted in the log). If the log says that this size is not available either, shrink it by hand (Cloud Shell):

```bash
az vm deallocate -g rg-exlab-<k> -n vm-<k>-fs01
az vm resize -g rg-exlab-<k> -n vm-<k>-fs01 --size Standard_B2s_v2
az vm start -g rg-exlab-<k> -n vm-<k>-fs01
```

## Access denied on `Home\WHughes\Private` (German `Home\JFrick\Privat`)

This is intended: the folder is one of the file server's deliberate legacy issues. Only William Hughes (German lab: Johann Frick) and SYSTEM have permissions, Domain Admins do not.

## Lab user password forgotten

On the Exchange server, as `<K>\azadmin`, reset the password in *Active Directory Users and Computers*, or:

```powershell
Set-ADAccountPassword -Identity mmustermann -Reset -NewPassword (Read-Host -AsSecureString 'Neues Kennwort')   # English lab e.g. fbloggs
```
