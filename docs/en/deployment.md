# Deployment

**English** · [Deutsch](../de/deployment.md)

Prerequisites, parameters and first steps after the deployment. Placeholders: `<k>` = the trainee's initials (3 letters, lower case), `<K>` = initials in upper case, `<zone>` = parent DNS zone provided by the trainer. How the lab is built is described in [Architecture](architecture.md).

## Prerequisites

- **Permissions:** Owner on your own target resource group (for the role assignments of the managed identities of the Exchange server and file server) and *DNS Zone Contributor* on `rg-publicdns`. **No** Entra role is required in the production tenant, not even Global Administrator; trainees hold Entra admin roles only in the Microsoft 365 demo tenant. Without Owner: set the parameters `enableLetsEncrypt = false` and leave `fileServerFinalVmSize` empty (the file server then does not shrink itself).
- **Initials** must not yet exist as a subdomain in `<zone>`.
- **Parent zone:** If `<zone>` exists in the resource group `parentDnsZoneResourceGroup`, it is left unchanged; the deployment only adds the NS record `<k>`. If it is missing, it is created. The resource group itself must exist. A newly created zone has to be delegated once at the registrar, otherwise Let's Encrypt fails.
- **Quota:** 8 vCPUs in the region (4 × BS family for DC and client, 4 × ESv5 family), with a second DC 10 vCPUs (6 × BS family). Without the client 2 vCPUs fewer. While generating the sample data, the file server additionally needs 4 × DSv5 family, afterwards 2 × BSv2 family: 12 vCPUs in total, 14 with a second DC. If the quota is not sufficient, set `fileServerVmSize = Standard_B2s_v2`; the sample data is then generated in the background over many hours.
- **Windows 11 licence (client):** Azure bills the VMs pay-as-you-go. For Windows Server the licence is included, for Windows 11 it is not: Windows 11 on Azure requires Multitenant Hosting Rights, according to Microsoft e.g. Windows Enterprise E3/E5 or VDA per user (also covered by M365 E3/E5/F3 and Business Premium, among others), or alternatively a Dev/Test offer on the subscription. In the lab, this is covered by the trainee's Microsoft 365 E5 licence in the demo tenant (a CDX tenant or, alternatively, a Microsoft 365 E5 trial). Without a suitable licence set `deployClient = false`.
- **Office licence (client):** Microsoft 365 Apps are licensed through the demo tenant with Microsoft 365 E5 (a CDX tenant or, alternatively, a Microsoft 365 E5 trial): the trainee activates them with their account from the demo tenant (one of five installations), not with their company account. E5 matches the default `O365ProPlusRetail`. In general, `officeProductId` must match the licence: `O365ProPlusRetail` for Apps for enterprise (M365 E3/E5), `O365BusinessRetail` for Apps for business (Business Standard/Premium).
- **Remote Desktop Manager (client):** According to Devolutions, RDM Free is licensed for a single individual, including for work. The lab client has several users and a shared connection list. If you do not want that, set `clientRemoteDesktopManager = false`.

## Deploy

1. Click **Deploy to Azure** and choose a resource group (e.g. `rg-exlab-<k>`).
2. Fill in the parameters:

   | Parameter | Required | Meaning |
   | --- | --- | --- |
   | `trainee` | yes | Initials, 3 letters |
   | `labLanguage` | no | Language of the lab data: `de` (default, Mustermann Medien GmbH, Berlin and Hamburg) or `en` (Contoso Ltd, London and Manchester). Determines users, groups, shares, sample documents, VM locale and mailbox language |
   | `adminPassword` | yes | Password for `azadmin` (local, domain admin, DSRM) |
   | `labUserPassword` | yes | Password of the 28 lab users, deliberately different from `adminPassword` |
   | `allowedRdpSourcePrefix` | yes | Your own public IP, e.g. `203.0.113.10/32` |
   | `parentDnsZoneName` | yes | Parent DNS zone `<zone>`, name provided by the trainer |
   | `parentDnsZoneResourceGroup` | no | Resource group of the parent zone, default `rg-publicdns` |
   | `exchangePublishedSourcePrefix` | no | Source for 443/80, empty = same as RDP |
   | `smtpSourcePrefix` | no | Source for 25, empty = same as 443/80. For inbound mail, set to `Internet` only after the update run |
   | `autoShutdownTime` | no | Daily shutdown of Exchange VM, client, file server and second DC (`HHmm`), default `1900`, empty = off |
   | `deploySecondDc` | no | Deploy a second domain controller `<K>-DC02`, default `false` |
   | `deployClient` | no | Deploy the Windows 11 client `<K>-CL01`, default `true` |
   | `officeProductId` | no | `O365ProPlusRetail` (default, Apps for enterprise) or `O365BusinessRetail` (Apps for business) |
   | `clientImageSku` / `clientVmSize` | no | Windows 11 image (default `win11-25h2-ent`) and VM size of the client |
   | `clientRemoteDesktopManager` | no | Remote Desktop Manager with connections to all lab servers on the client, default `true`. Caution: every user on the client can then read the password of `azadmin` |
   | `clientWingetPackages` | no | Tools via winget on the client, machine-wide in the latest version and updated daily. Default `Microsoft.VisualStudioCode`, `[]` = none |
   | `deployFileServer` | no | Deploy the file server `<K>-FS01`, default `true` |
   | `fileServerDataPercent` | no | Amount of sample documents as a percentage of the data disk (256 GB), default `90` (around 230 GB), `0` = none |
   | `fileServerVmSize` / `fileServerFinalVmSize` | no | Size during generation (default `Standard_D4s_v5`) and permanent size afterwards (default `Standard_B2s_v2`, empty = keep). On a redeployment pass `fileServerVmSize = Standard_B2s_v2`, otherwise the file server is briefly scaled up again |
   | `enableLetsEncrypt` / `letsEncryptStaging` | no | Certificate on/off, test CA for test deployments |

3. The deployment takes **about 1–1.5 hours**, slightly longer with a second DC: Exchange only starts once DC02 is fully ready (SYSVOL, DNS, replication in both directions). In testing it took around 65 minutes, 31 of them for Exchange setup alone. The Exchange server then restarts and installs all updates in the background, including the Exchange security update via Microsoft Update. The DCs start their update run only at the very end of the deployment, once Exchange, client and file server are finished; this way no DC restart hits a VM that is just joining. Allow another 30–60 minutes. The file server's sample data is generated for at most 60 minutes during the deployment, the rest in the background: with `Standard_D4s_v5`, 60 GB were done after just over 30 minutes in testing; for around 230 GB expect about two hours. Afterwards the file server shrinks itself to `Standard_B2s_v2` and restarts once to do so.

   **Start time:** With the default shutdown time of 19:00, start the deployment by about **17:30**. The shutdown does not interrupt any deployment module, but it does interrupt running background work (updates, sample data). This continues after the next start, so the lab is only finished the next day.

4. **Check:** `./tools/Test-LabDeployment.ps1 -ResourceGroup rg-exlab-<k> -Wait` checks the deployment, DNS delegation, all VMs and the background work, and waits until it is finished. Exit code 0 means: lab complete and error-free. Details in [Operations](operations.md#check-the-lab).

Which step runs when on which VM and where it logs is described in [Architecture](architecture.md#sequence-and-logs).

## After the deployment

- **Entry via the client:** RDP to `clientRdpHost`, e.g. as `<K>\fbloggs` (German lab `<K>\mmustermann`). From there, **Remote Desktop Manager** (desktop or Start menu, workspace "Lab-Server") connects as `<K>\azadmin` without a password prompt to `<K>-DC01`, `<K>-EX01`, `<K>-FS01` and, if deployed, `<K>-DC02`. OWA and ECP are there as web entries (default browser, sign in by hand). Active Setup adds the workspace at each user's first sign-in. **Security note:** RDM encrypts saved passwords with a built-in key, so every user of the client can read the password of `azadmin`. On the client, the separation between `labUserPassword` and `adminPassword` is therefore lifted. This is a deliberate decision for lab convenience; switch it off with `clientRemoteDesktopManager = false`.
- **Direct RDP:** The Exchange server can also be reached directly via its public IP (output `rdpHost`, as `<K>\azadmin`). DNS console, GPMC and AD administration tools are installed there.
- **Client:** When starting Word or Outlook for the first time, sign in with your account from the Microsoft 365 demo tenant so that Office activates. Registering the lab client in Entra ID is blocked by policy (`BlockAADWorkplaceJoin`). Outlook (classic) creates the profile itself via Autodiscover. If Office reports a missing licence, `officeProductId` does not match the licence.
- **Lab info:** On the desktop of the Exchange server there is `Lab-Info.txt` (domain, URLs, all users and sample recipients, certificate, logs) and shortcuts to OWA, ECP and the logs.
- **File server:** RDP from the client to `<K>-FS01` (no public IP). There, `Lab-Info.txt` shows shares, groups and the progress of the sample data. On the client the shares are available at `\\<K>-FS01\Departments`, `\Projects`, `\Archive` and `\Scans` (German `\Abteilungen`, `\Projekte`, `\Archiv`, `\Scans`), the home folder as `H:`. Whether the sample data is finished is shown in `C:\ExchangeLab\sample-documents.json` (`State` = `fertig`, i.e. done), see also [Operations](operations.md#file-server-sample-data-and-vm-size).
- **OWA/ECP:** `https://mail.<k>.<zone>/owa` or `/ecp`, e.g. as `fbloggs@<k>.<zone>` or `mmustermann@<k>.<zone>`.
- **Diagnostics:** `C:\ExchangeLab\Tools` contains `HealthChecker.ps1`, `SetupAssist.ps1` and `SetupLogReviewer.ps1` from [CSS-Exchange](https://github.com/microsoft/CSS-Exchange) (pinned release, SHA256-verified). Run them in the Exchange Management Shell as administrator.
- **Inbound mail from the internet:** only once `Update-LabServer.log` is finished, set the NSG rule `Allow-Exchange-SMTP` to source `Internet`.
- **OWA/Outlook from anywhere:** set `Allow-Exchange-Web` to `Internet` only briefly. This also exposes ECP with the domain admin sign-in to the public.
- **Passwords** of `azadmin` and the lab users do not expire (lab compromise, otherwise after 42 days).
- **Deleted AD objects** can be restored from the AD Recycle Bin (Active Directory Administrative Center).
- **Outbound mail** to external domains is only supported from Azure via a smart host (send connector with relay). This is deliberately not preconfigured.

## Remove the lab

When deleting a lab, always remove the delegation in `<zone>` as well, otherwise an orphaned NS record remains (risk of subdomain takeover). Commands in [Operations](operations.md#remove-the-lab).
