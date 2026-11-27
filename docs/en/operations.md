# Operating the lab

**English** · [Deutsch](../de/operations.md)

Placeholders: `<k>` = your initials (lower case), `<K>` = your initials (upper case), `<zone>` = parent DNS zone provided by the trainer. The commands run in [Azure Cloud Shell](https://shell.azure.com) (Bash) or locally with Azure CLI.

## Show deployment outputs

```bash
az deployment group list -g rg-exlab-<k> --query "[?properties.outputs.owaUrl].properties.outputs" -o json
```

The important ones are `rdpHost` (Exchange server), `clientRdpHost` (Windows 11 client) and `owaUrl`.

## Start and stop

The Exchange VM, the optional second DC, the client and the file server shut down daily at the shutdown time (`autoShutdownTime`, default 19:00). **The first DC (`vm-<k>-dc01`) always keeps running and is never stopped in the portal.** The reason is explained in [Architecture](architecture.md#costs-and-shutdown).

Start in the morning:

```bash
az vm start -g rg-exlab-<k> -n vm-<k>-dc02   # only with second DC
az vm start -g rg-exlab-<k> -n vm-<k>-ex01
az vm start -g rg-exlab-<k> -n vm-<k>-cl01   # only with client
az vm start -g rg-exlab-<k> -n vm-<k>-fs01   # only with file server
```

Shut down early (saves money, e.g. before a long weekend):

```bash
az vm deallocate -g rg-exlab-<k> -n vm-<k>-cl01
az vm deallocate -g rg-exlab-<k> -n vm-<k>-fs01
az vm deallocate -g rg-exlab-<k> -n vm-<k>-ex01
az vm deallocate -g rg-exlab-<k> -n vm-<k>-dc02
```

The file server has no public IP. RDP to `<K>-FS01` works from the client (Remote Desktop Manager, see below).

After start-up, Exchange needs a few minutes until all services are running. Until then OWA reports error 500 or 503.

## New public IP address (RDP no longer works)

The NSG only allows RDP from the IP that was set in `allowedRdpSourcePrefix` at deployment. After a change (working from home, different network), update the rules:

```bash
MYIP=$(curl -s https://ifconfig.me)
az network nsg rule update -g rg-exlab-<k> --nsg-name nsg-exlab-<k> -n Allow-RDP-Exchange --source-address-prefixes "$MYIP/32"
az network nsg rule update -g rg-exlab-<k> --nsg-name nsg-exlab-<k> -n Allow-RDP-Client --source-address-prefixes "$MYIP/32"
```

The rules `Allow-Exchange-Web` and `Allow-Exchange-SMTP` use the same source by default and may need updating as well. A redeployment resets all rules to the parameter values.

## Reach the servers from the client (Remote Desktop Manager)

Devolutions Remote Desktop Manager Free is installed on `<K>-CL01` (parameter `clientRemoteDesktopManager`, default `true`). Desktop or Start menu → *Remote Desktop Manager*. The **Lab-Server** workspace contains `<K>-DC01`, `<K>-EX01`, `<K>-FS01` and, if deployed, `<K>-DC02`. A double-click connects as `<K>\azadmin` without a password prompt.

How it is set up:

- The connections are stored in a shared file `C:\ProgramData\TraineeLab\RemoteDesktopManager\Lab-Server.xml`. It is recreated in the *Complete* phase of the deployment.
- At each user's first sign-in, Active Setup (`TraineeLab-RemoteDesktopManager`) adds the file as the default workspace. Log: `%LOCALAPPDATA%\TraineeLab\Register-LabWorkspace.log`.
- All users may modify the file because RDM rewrites it when loading. Changes to connections are therefore visible to all users of the client.

> **Security note:** RDM encrypts saved passwords with a key that is the same in every installation. Every user of the client can therefore read the password of `azadmin`. On the client, the separation between `labUserPassword` and `adminPassword` does not apply. This is a deliberate decision for lab convenience. If you do not want this, deploy with `clientRemoteDesktopManager = false`.

**Admin password changed:** In RDM select the connections → *Edit* → *Credentials* and enter the new password. Since the file is shared, this applies to all users.

**Update the RDM version (repository):** `scripts/Initialize-LabClient.ps1` contains the pins `$RdmInstaller` (URL and SHA256 from [productinfo.json](https://devolutions.net/productinfo.json), section `RDMWindows.Current`, x64 MSI), `$RdmModule` (version from the PowerShell Gallery) and `$DotNetDesktopRuntime`. The update check in RDM is disabled by policy because lab users have no admin rights. On a running client, an administrator installs a new MSI by hand.

## Tools on the client (winget)

On `<K>-CL01`, the deployment installs the winget packages from `clientWingetPackages` machine-wide in the latest version; the default is Visual Studio Code.

- The task `TraineeLab-WinGetUpdate` (SYSTEM) updates them when the VM starts and daily at 12:00. It catches up on runs missed because of the auto-shutdown. Log: `C:\ExchangeLab\Logs\Update-WinGetTool.log`.
- VS Code shows no update prompt (policy `UpdateMode = none`), because lab users without admin rights cannot update the system-wide VS Code.
- If a program is open during the update, the update can fail. The next run tries again.
- Update immediately (PowerShell as administrator): `Start-ScheduledTask -TaskName TraineeLab-WinGetUpdate`.
- Change the package list on a running client: `C:\ProgramData\TraineeLab\WinGet\Packages.txt`, one winget ID per line (administrators only). The next run installs new entries.

Remote Desktop Manager deliberately stays on the pinned version (see above): the module `Devolutions.PowerShell`, which creates the connections, has to match the RDM version.

## Check the lab

A tool checks the whole lab from outside (Azure CLI, signed in with Run Command permissions on the resource group):

```powershell
./tools/Test-LabDeployment.ps1 -ResourceGroup rg-exlab-<k>
./tools/Test-LabDeployment.ps1 -ResourceGroup rg-exlab-<k> -Wait   # waits for updates, sample data, resize
```

It reads the language and options from the last lab deployment and checks:

| Area | Checks |
| --- | --- |
| Azure | all deployments and Run Commands succeeded, DNS delegation in the parent zone, file server at its permanent size |
| DCs | DC role and services, `dc-ready.txt`, SYSVOL/NETLOGON, forwarders, SRV records of all DCs, split DNS, PTR, AD sites, replication, lab users with company/fax/city |
| Exchange | installation, services, mailboxes and sample recipients, mailbox language, certificate on 443 (Let's Encrypt, enabled for SMTP), OWA URLs and `healthcheck.htm`, maintenance task |
| File server | phase Complete, shares with access-based enumeration, legacy issues, sample data finished and data drive filled |
| Client | domain and secure channel, display language, Microsoft 365 Apps, Remote Desktop Manager, RDP for domain users |
| all VMs | no `WARNUNG:`/`FEHLER:` (warning/error) in `C:\ExchangeLab\Logs`, locale, update run finished, `Lab-Info.txt` without open placeholders |

Each check is `OK`, `FAIL` or `PENDING` (background work still running). Exit code 0 = all OK, 1 = error, 2 = not finished yet. The check scripts per role are in `tools/LabChecks`. If a VM is stopped (shutdown time), the tool reports `PENDING` until it is running again.

## Check status

Status of a Run Command (e.g. Exchange installation):

```bash
az vm run-command show -g rg-exlab-<k> --vm-name vm-<k>-ex01 --name Install-ExchangeServer --instance-view \
  --query "instanceView.{Status:executionState, ExitCode:exitCode}"
```

Read the end of a log without RDP:

```bash
az vm run-command invoke -g rg-exlab-<k> -n vm-<k>-ex01 --command-id RunPowerShellScript \
  --scripts "Get-Content C:\ExchangeLab\Logs\Update-LabServer.log -Tail 20"
```

All logs are in `C:\ExchangeLab\Logs` on every VM. Which step logs where is described in [Architecture](architecture.md#sequence-and-logs). The file server's Run Commands are called `Initialize-FileServer`, `New-SampleDocuments`, `Wait-DomainController` and `Complete-FileServer`:

```bash
az vm run-command list -g rg-exlab-<k> --vm-name vm-<k>-fs01 --query "[].{name:name, state:provisioningState}" -o table
```

## File server: sample data and VM size

The sample documents fill the data disk `F:` up to `fileServerDataPercent` (default 90 %, around 230 GB), in the language from `labLanguage`. About a third of this is copies, as on real servers (home folders, "Copy of", old versions, quarterly backups in the archive). For more than around 60 GB of original documents, the generator creates correspondingly more projects per client and year. It stops when less than 8 % of the disk is free.

The documents are generated for at most 60 minutes during the deployment; the task `TraineeLab-SampleDocuments` generates the rest in the background (two to three hours in total with `Standard_D4s_v5`; once the Standard SSD's burst credits are used up, its IOPS limit the pace). Afterwards the file server shrinks itself to `fileServerFinalVmSize` (default `Standard_B2s_v2`). If the VM's hardware cluster does not offer this size (resizing without deallocation only works within the cluster), it takes the 2-vCPU size of its family, `Standard_D2s_v5` with the default values. This only happens once sample data, setup and update run are finished, and costs one restart.

At 90 % usage there is little room left on `F:` for shadow copies and your own experiments. If you need more headroom, set `fileServerDataPercent` lower, e.g. 60.

Progress of the sample data and the resize:

```bash
az vm run-command invoke -g rg-exlab-<k> -n vm-<k>-fs01 --command-id RunPowerShellScript \
  --scripts "Get-Content C:\ExchangeLab\sample-documents.json; Get-Content C:\ExchangeLab\Logs\Resize-FileServer.log -Tail 5"
az vm show -g rg-exlab-<k> -n vm-<k>-fs01 --query hardwareProfile.vmSize -o tsv
```

`State` is `laeuft` (running), `wird im Hintergrund fortgesetzt` (continuing in the background) or `fertig` (done). If the shutdown time interrupts generation, the task continues after the next start. Trigger it by hand (on `<K>-FS01`, PowerShell as administrator):

```powershell
Start-ScheduledTask -TaskName TraineeLab-SampleDocuments
Get-Content C:\ExchangeLab\Logs\New-SampleDocuments.log -Tail 10 -Wait
```

**Redeploying:** With the default values the template sets the file server back to `Standard_D4s_v5`; it restarts and shrinks itself again later. You avoid this with the parameter `fileServerVmSize = Standard_B2s_v2`.

## Keep an eye on costs

- The largest item is the Exchange VM (`Standard_E4s_v5`), followed by the Premium disks. Disks incur costs even when the VM is deallocated; this also applies to the file server's 256 GB data disk.
- The file server only runs as `Standard_D4s_v5` until the automatic resize. If it stays larger, the reason is in `Resize-FileServer.log` (see [Troubleshooting](troubleshooting.md#file-server-stays-large)).
- Budget with email alert: in the portal, resource group → *Cost Management* → *Budgets* → *Add*, e.g. alert at 80 % of the monthly amount.
- Delete additional disks from exercises (backup) after use.

## Remove the lab

**Always run both steps.** If the NS record remains in the parent zone, it points to name servers that someone else could take over (subdomain takeover).

```bash
az group delete -n rg-exlab-<k> --yes
az network dns record-set ns delete -g rg-publicdns -z <zone> -n <k> --yes
```
