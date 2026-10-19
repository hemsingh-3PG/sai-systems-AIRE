# PacEHR — Azure Resource Map & AI Engine Resource Plan

**Scope:** PacEHR only (`PacEHR` Angular front end · `pacEHR_API` .NET back end) and the new
`pacEHR_AI` Node service. ECM, BillEHR, NavigatEHR, Client Portal and the other products in the
subscription appear only where PacEHR depends on them.
**Date:** 2026-10-06

---

## 0. How this was built, and what it cannot tell you

**Three sources, cross-checked against each other:**

| Source | What it gives | Captured |
|---|---|---|
| `Extra_Resources/full-architecture-map.html` | Production Azure inventory (951 resources), and who-calls-what from Application Insights telemetry | 2026-09-24, 30-day window, **production only** |
| `pacEHR_API` source | *Why* the API calls each resource — the code path and the user action behind it | current HEAD |
| `PacEHR` source | Which screen and button starts each flow | current HEAD |

A resource listed in §2 carries one of three evidence marks:

- **📡 observed** — seen in production telemetry in the 30-day window
- **💻 code** — found in the source, with the file named
- **📦 inventory** — exists in the subscription; no telemetry or code proves it is used

**Five limits, stated up front so nothing below is over-read:**

1. **The source for 26 function apps and ~40 WebJobs is not in these two repositories.** The
   `pacEHR_API` solution holds only `PacEHR.Functions.Process` (six timers). Their purpose here is
   inferred from name, trigger and telemetry edges — not from code.
2. **Network topology was redacted** from the export — 154 networking resources are counted but
   none is listed. Private endpoints and VNet integration cannot be mapped from this source.
3. **Call volumes are redacted** — every edge shows `n=0`. An edge proves a call *happened* in the
   window, not how often.
4. **App Service configuration is not visible.** Where behaviour depends on an app setting, this
   document says so rather than guessing.
5. **`settings.appsettings` (a SQL table) changes runtime routing** — see §3.1. Its contents are
   not in either source.

---

## 1. The estate at a glance

```
                        Azure Front Door Premium (thesnfist-<e>-eastus2-afd)
           secure.thesnfist.com  ·  pacehrapi.thesnfist.com  ·  hie.thesnfist.com
                                 │ private link
          ┌──────────────────────┼─────────────────────────────┐
          ▼                      ▼                             ▼
   pacehr-<e>-ui-app      pacehr-<e>-api-app          pacehr-<e>-webhook-kno2
   (Angular, Windows)     (.NET 8, P3v3, 1 worker)    (HIE / Kno2 inbound)
                                 │
     ┌──────────┬───────────┬────┴──────┬──────────────┬──────────────┬──────────────┐
     ▼          ▼           ▼           ▼              ▼              ▼              ▼
  Azure SQL   Blob       Cosmos DB   Azure OpenAI   Service Bus    Managed Redis   9 external
  pacehr_live "pacehr"   PCC call    AI Command     14 namespaces  PCC tokens      vendors
                         logging     (see §3.1)     ~30 queues
                                                          │
                                                          ▼
                                       22 function apps  (EP3, Windows, 1 worker)
                                       + 2 WebJob hosts  (B3, Windows)
                                                          │
                              ┌───────────────┬───────────┴──────┬────────────────┐
                              ▼               ▼                  ▼                ▼
                        pacehr_live    pacehr_prod_       public OpenAI    PCC · DrFirst ·
                                       auditlog_sqldb     (chart audit)    Updox · MatrixCare …
```

**Two estates run side by side.** A modern, consistently named one
(`pacehr-<e>-eastus2-*`, resource group `THESNFIST-<E>-EASTUS2-PACEHR`, 81 resources) and a legacy
one (`pacehrapi`, `pacehrapi2`, `pacehrintegration`, `pacehrwebappservices` …, mostly resource group
`thesnfist`). The legacy estate is **not dead** — `pacehrapi` still shows live SQL, Blob, Paubox and
ShareFile traffic. Anyone changing a shared resource has to account for both.

| Resource type | Modern estate | Legacy estate |
|---|---|---|
| Web apps | 5 (`api`, `ui`, `referralq-api`, `ssrs`, `webhook-kno2`) | 5 |
| Function apps | 22 | 4 |
| WebJob hosts | 2 | 2 web apps also host WebJobs |
| Service Bus namespaces | 14 | 2 shared (`ecmservicebus`, `pacehrmessagebus`) |
| App Service plans | 3 (`P3v3`, `EP3`, `B3`) | 5 |

---

## 2. Resource by resource

### 2.1 Azure Front Door Premium — the only public entry 📡

`thesnfist-<e>-eastus2-afd`, shared across products, resource group `RG01`.

| Hostname | Origin | Private link |
|---|---|---|
| `secure.thesnfist.com` | `pacehr-<e>-ui-app` | ✅ |
| `pacehrapi.thesnfist.com` | `pacehr-<e>-api-app` | ✅ |
| `hie.thesnfist.com` | `pacehr-<e>-webhook-kno2` | ✅ |

**Scenario:** every clinician request. The browser loads the Angular app from `secure.`, then calls
the API at `pacehrapi.` directly. Health-probe metric alerts exist for both PacEHR origins.

### 2.2 App Service — web apps and plans 📡 📦

| App | Plan · SKU | Role |
|---|---|---|
| `pacehr-<e>-ui-app` | `windows-asp` · P3v3 | Angular SPA. Slots: `maintenance`, `stable` |
| `pacehr-<e>-api-app` | `windows-asp` · P3v3 | **The API.** Every flow in this document starts here |
| `pacehr-<e>-referralq-api-app` | `windows-asp` · P3v3 | Referral queue API |
| `pacehr-<e>-ssrs-app` | `windows-asp` · P3v3 | Proxy to `reports.thesnfist.com` (SSRS) |
| `pacehr-<e>-webhook-kno2` | `windows-asp` · P3v3 | Inbound HIE webhooks |
| `pacehr-<e>-webjobs-app` / `-webjobs-imo-app` | `windows-webjobs-asp` · **B3** | WebJob hosts, §2.6 |
| `pacehrapi` (legacy) | `thesnfist` · P2v3 | Still live: SQL, Blob, Paubox, ShareFile |
| `pacehrapi2` (legacy) | **`dev-apps` · Basic B1** | ⚠️ Production app on a plan named `dev-apps` |
| `pacehrwebhooksapp` (legacy) | **`ASP-CareManagementUAT-a22e`** | ⚠️ Production app on a UAT-named plan |
| `pacehrwebappservices` (legacy) | `thesnfist` · P2v3 | PCC calls; hosts WebJobs |

**Every plan runs one worker.** The API has no redundancy at the instance level — a single P3v3. And
everything is **Windows**, which matters for the AI service (§5.2).

### 2.3 Azure SQL 📡 💻

| Database | Server | Used by | What it holds |
|---|---|---|---|
| **`pacehr_live`** | `thesnfist` | API, 8 function apps, 4 legacy apps | Everything clinical — the database the `AI.*` schema lives in |
| `pacehr_prod_auditlog_sqldb` | `thesnfist` | `auditlog-func`, `auditlog-sb-func`, `errorlog-func` | Audit and error logs, moved out of `pacehr_live` |
| `ecm_live` | `thesnfistecm` | `pacehrintegration` (legacy) | ⚠️ PacEHR writes into ECM's database — cross-product coupling |

The API connects with the `PACEHR-DB` connection string and an EF Core retry policy
(`EnableRetryOnFailure`, 3 retries, deadlock `1205` included) — `PacEHR.API/Program.cs`.

### 2.4 Azure Service Bus — every queue, who sends, and why 📡 💻

The pattern: **the API does the user-facing write synchronously, then puts anything slow or
external on a queue** for a function to finish. One namespace per domain — 14 in the PacEHR
resource group.

| Queue | Sent when (user action → code) | Consumed by | Status |
|---|---|---|---|
| `encounter-event-queue` | **Clinician signs an encounter** → `EncounterController.updateVerifiedFlag` → `sendEncounterDetailsToServiceBus` | `encounter-data-func` · `EncounterEventFunction` | ✅ |
| `chart-audit-sbq` | Sent *by* `EncounterEventFunction` after a signed encounter is processed | `chartaudit-func` → **public OpenAI**, §3.2 | ✅ |
| `patient-event-queue` | Patient added or edited → `PatientController.addEditPatient` | `patient-data-func` → SQL, DrFirst, then Updox & Quantician queues | ✅ |
| `encounter-quality-measures` | Quality measures saved → `PqrsController.PQRSSave` | `encounterqm-func` | ✅ |
| `acoecqms-sbq` | eCQM sent → `ECQMController.SendEcqmServiceBus` | `acoecqms-func` | ✅ |
| `ccm-encounter-sbq` | `CCMController.SendCCMEncounterServiceBus` | `ccm-func` | ✅ |
| `documents-upload` | Assessment/attachment to PointClickCare → `FacilityController.SentAssessmentAndAttachmentToPCC` | `pcc-func` · `pccDocumentUploadFunction` | ✅ |
| `add-progress-note` | Progress note to PCC | `pcc-func` · `pccAddProgressNote` | ✅ |
| `external-patients-link` | `PatientController.linkExternalPatients` | `pcc-func` | ✅ |
| `kno2-patient-sbq` | HIE request → `HIEController.triggerHIEPatientData` | `kno2-func` | ✅ |
| `drfirst-diagnostic-queue` | Diagnosis to DrFirst | `drfirst-func` · `SaveDiagnosisProcessor` | ✅ |
| `matrixcare-progress-note` | Progress note to MatrixCare | `matrixcare-func` | ✅ |
| `updox-outboundfax-sbq` | Outbound fax | `outboundfax-func` | ✅ |
| `audit-log-sbq` | Sent by `auditlog-func` (timer) | `auditlog-sb-func` | ✅ |
| 🔴 **`add-facility-configuration`** | API sends (observed) | **no consumer function exists** | orphan |
| 🔴 **`updox-encounter-note-sbq`** | API sends (observed) | `updox-func` · **disabled** | orphan |
| 🔴 **`updox-patientportal-sbq`** | `patient-data-func` sends (observed) | `updox-func` · **disabled** | orphan |
| `hl7-outbound-sbq` | — | `hl7outbound-func` | ⚠️ lives in **`billehrservicebus`** — another product's namespace |

**The three orphans need a look this week.** Telemetry shows messages being *sent* in the last 30
days to queues nothing reads. Check each queue's active and dead-letter counts: either a feature is
silently not working, or the sender should be switched off.

**The send path uses a retired SDK.** `pacEHR.DomainServices/ServiceBusQueueHelper.cs` imports both
`Azure.Messaging.ServiceBus` and the legacy `Microsoft.Azure.ServiceBus`, and constructs legacy
`QueueClient` instances. Microsoft announced end of support for the legacy libraries for
30 September 2026 — that date has passed.

### 2.5 Azure Functions — 51 functions in 26 apps 📡 📦

All on `pacehr-<e>-eastus2-windows-ep-asp` (**Elastic Premium EP3, Windows**) except the legacy four.
Service Bus triggers are covered in §2.4; the timers are below.

| App | Timer function | Schedule | Purpose (inferred) |
|---|---|---|---|
| `auditlog-func` | `processAuditLogFunction` | every 30 min | move audit rows out of `pacehr_live` |
| | `processAuditLogArchivalFunction` | daily 00:30 | archive to `auditlogsa` blob |
| `errorlog-func` | `processErrorLogFunction` | **every minute** | move error rows |
| | `SendErrorLogEmail` | hourly | e-mail error digest |
| `jobs-func` | `pacEHR_ECQM_Job` · `pacEHR_UpdateUserDefaultRole_Job` | daily | nightly jobs |
| `pcc-func` | token renewal, scope update, two upload retries, retry notification | daily | keep the PCC integration healthy |
| `pccadtsync-func` | `PCCPatientADTSyncJob` | daily 07:12 | ADT sync |
| `auditlog-bkp-sb-func` | `pacEHRAuditLogFunction_Migration` | every 2 min | audit migration |
| 🔴 `pacehrIntegration` (legacy) | `PacehrFunc-Prod` | **`* */5 * * * *`** | see below |

🔴 **`PacehrFunc-Prod` almost certainly runs 60 times more often than intended.** NCRONTAB's first
field is *seconds*: `* */5 * * * *` fires **every second** of every fifth minute — 60 runs, then
four quiet minutes. `0 */5 * * * *` is "every five minutes". Worth confirming against its
invocation count.

**Disabled in production:** `hl7inbound-func` (app stopped), `restoreAuditLogArchiveFunction`,
`processAuditDBBackupFunction`, `UpdoxEncounterNotesUpload`, `UpdoxPatientPortal`, and the duplicate
`pccpatientQueue` in `PacehrWebhookQueue` (the live one is in `pacEHRWebhookReceiver`).

### 2.6 WebJobs 📦

`pacehr-<e>-webjobs-app` (B3) runs the continuous integrations — DrFirst event polling, HL7
outbound (plus ADT), Updox patient sync and e-fax, PCC patient-admit webhook — and these triggered
jobs:

| WebJob | Last result | Note |
|---|---|---|
| **`pacEHRAIBotEncounters_1` … `_10`** | Success | 🔵 **An AI batch process nobody has documented.** Ten instances; source not in these repos. §3.3 |
| `pacEHRAssessmentAlertJob` | Success | daily 08:00 |
| `pacEHRQRSWebJob` | Success | daily 12:15 |
| 🔴 `pacEHRResentDX-DrFirst` | **Failed** | nightly 22:30 |
| 🔴 `MatrixCareNightlyJob` | **Failed** | on legacy `pacehrwebappservices` |
| 🔴 `pacEHRQualityDataService` | **Failed** | on legacy host |
| 🔴 `PacherSOf` | **Failed** | on legacy host |
| `pacEHRImoMonthlyJobService` | Never run | |

The legacy `pacehrapi` host carries nine continuous WebJobs, all **Stopped** — `CCDAService-Batch1..4`,
`ProgressNotes-Batch1..4`, `pacEHRService`. Candidates for deletion once confirmed superseded.

### 2.7 Azure Managed Redis 💻 📦

`pacehr-<e>-eastus2-redis` — `Microsoft.Cache/redisEnterprise`, **Balanced B1**. This is Azure
*Managed* Redis, the successor service, not Azure Cache for Redis.

**Scenario: one, and only one — caching PointClickCare OAuth tokens.** So every PCC call does not
re-authenticate.

**It is written twice.** `pacEHR.PCC.Services/Services/PccRedisTokenCache.cs` and
`pacEHR.DomainServices/RedisServices/PccRedisTokenCacheService.cs` both cache PCC tokens, over two
separate `ConnectionMultiplexer`s — one lazy static in `RedisConnection.cs`, one registered in
`PccServicesCollectionExtensions.cs`. Two connections and two code paths for one cache.

No telemetry edge appears for Redis, which is normal: Application Insights does not auto-collect
Redis dependencies from StackExchange.Redis.

### 2.8 Cosmos DB 📡 💻

`thesnfist-<e>-eastus2-cosno` — shared resource group `RG01`, East US 2 + Central US.

**Scenario: logging PointClickCare API calls.** `PccCosmosLoggingConvention` marks the PCC API
endpoints listed in `PccCosmosSettings.PccApiNames`; `PccCosmosWorker` (a hosted service) writes the
call records. Configured in `PacEHR.API/Program.cs` with bulk execution, direct mode, a 10s timeout
and a retention setting.

⚠️ **Key-based auth** (`new CosmosClient(account, key, …)`) and **public network access is
enabled** on the account.

### 2.9 Blob Storage 📡 💻

| Account | Used by | Holds |
|---|---|---|
| `pacehr` | API, `updox-func`, legacy `pacehrapi`/`pacehrapi2`, **ECM API** | documents, attachments, QRDA output, Updox files |
| `pacehr<e>eastus2auditlogsa` | audit and error-log functions, `jobs-func` | audit archives |
| `pacehr<e>eastus2funcsa` | function runtime | Functions host storage |
| `pacehrpeastusdbbackupsa` | — | DB backups |

⚠️ **A container named `pacehrdev` is hard-coded in production code** —
`PacEHR.API/Controllers/QRDAController.cs:231`, and five more sites in the legacy `pacEHR/` tree.

### 2.10 Azure OpenAI 📡 💻

`thesnfist-<e>-eastus2-oai` — `Microsoft.CognitiveServices/accounts`, shared resource group `RG01`.
**Only caller: `pacehr-<e>-api-app`.** The full flow is §3.1.

### 2.11 Key Vault 📦 — provisioned, never used

`pacehr-<e>-eastus2-kv` exists in the PacEHR resource group (and `thesnfist-<e>-eastus2-kv` in
`RG01`). **No PacEHR app calls either.** `Program.cs` loads Key Vault only if `KeyVault:Uri` is
set; no appsettings file sets it, and telemetry shows no call.

Where PacEHR's secrets actually live:

1. `PacEHR.API/appsettings.json` — **committed to git**, including OpenAI, SendGrid and Google Maps keys
2. `settings.appsettings` — a **SQL table**, holding `OPENAI_API_KEY` and `OPENAI_API_URL`
3. App Service application settings — not visible in either source

### 2.12 SignalR 💻 — in-process, no Azure service

`PacEHR.API/Hubs/` — `EmailNotificationHub` and `ChatNotificationHub`, registered with plain
`AddSignalR()`. **No Azure SignalR Service and no backplane.** That works only because the API runs
one instance: scale the API to two and half the clients stop receiving their notifications.

### 2.13 Monitoring and alerting 📦

| Resource | Where |
|---|---|
| Application Insights `thesnfist-<e>-eastus2-appi` (+ `westus`) | `RG01` — the shared instance |
| Log Analytics `thesnfist-<e>-eastus2-log`, `pacehr-<e>-eastus2-audit-log` | `RG01`, PacEHR RG |
| Action groups | `CriticalAlertGroup`, `pacehr-product-team-ag`, `pacehr-<e>-eastus2-healthprobe-ag` |
| Alerts | PCC/non-PCC 400 errors, slow API (5 min), HTTP 4xx/5xx, SQL dependency errors, App Service CPU, Front Door health probes, Service Bus failures |
| Workbooks | 7 in the PacEHR resource group |

### 2.14 Identity 📡 📦

- **Microsoft Entra ID** — sign-in, and the audit/error-log functions query Log Analytics with it.
- **Managed identity** — the API calls IMDS (observed), so it *has* a managed identity. But
  Cosmos, Redis, Service Bus and OpenAI are all reached with keys or connection strings.
- **User-assigned identity** `thesnfist-<e>-eastus2-user-identity` exists in `RG01`.

### 2.15 External partners 📡

| Partner | Purpose | Called by |
|---|---|---|
| PointClickCare | EHR integration | API, `pacehrwebappservices` |
| DrFirst | e-prescribing (Rcopia) | API, `patient-data-func` |
| MatrixCare | EHR integration | API, `matrixcare-func` |
| Updox | patient portal, e-fax | API, `updox-func` |
| IMO Health | clinical terminology | API |
| Twilio | SMS | API |
| Paubox | HIPAA e-mail | API, legacy `pacehrapi` |
| ShareFile | HIPAA file sharing | legacy `pacehrapi` |
| **OpenAI (public API)** | `api.openai.com` | **`chartaudit-func`** |

### 2.16 Shared platform in `RG01` — available, mostly not used by PacEHR yet 📦

This is the most useful list for §5. Every item below already exists in production:

| Resource | Name | PacEHR uses it today? |
|---|---|---|
| Azure OpenAI | `thesnfist-<e>-eastus2-oai` | ✅ API only |
| **Azure AI Search** | `thesnfist-<e>-eastus2-srch` | ❌ |
| **PostgreSQL Flexible Server** | `thesnfist-<e>-eastus2-pgsql` | ❌ |
| **Azure Container Registry** | `thesnfist<e>eastus2acr` | ❌ |
| **User-assigned managed identity** | `thesnfist-<e>-eastus2-user-identity` | ❌ |
| Key Vault | `thesnfist-<e>-eastus2-kv` | ❌ |
| Azure Managed Redis | `thesnfist-<e>-eastus2-redis` (B0) | ❌ |
| Cosmos DB | `thesnfist-<e>-eastus2-cosno` | ✅ PCC logging |
| Application Insights + Log Analytics | `thesnfist-<e>-eastus2-appi` / `-log` | ✅ |
| Automation | `thesnfist-<e>-eastus2-aa` — runbooks to scale Azure SQL | — |
| Data Factory | `thesnfist-<e>-eastus2-adf` — copies to reporting | — |

---

## 3. AI in production today

**Three separate AI paths, on two different OpenAI endpoints, with no shared controls.**

### 3.1 "AI Command" — interactive extraction on the encounter form 📡 💻

```
Clinician presses AI Command          encounter-form.component.html:991
  │  medicalNote → getResponse()       encounter-ai.facade.ts:221
  ├─ checkAndAddRoundingNote()         → Patient.roundingNotes
  ├─ detectInjection(note)             browser only
  ├─ maskPHI(note)                     🔴 returns its input unchanged (phi-masker.ts)
  ├─ encrypt(body, 'SecretKey123')     key in the shipped bundle
  └─ POST pacehrapi.thesnfist.com/streamTemplateCompletion   (SSE)
        │
        ▼  AIController → AIPromptServices.StreamOpenAITemplateCompletionAsync
        ├─ fills <<templateName>> <<promptBody>> <<encounterFields>> <<encounterPOS>> …
        ├─ reads OPENAI_API_KEY, OPENAI_API_URL from settings.appsettings
        └─ POST <OPENAI_API_URL>   model "gpt-4o", temperature 0, stream
              │
              ▼  thesnfist-<e>-eastus2-oai  (Azure OpenAI)
        ◀── stream back to the browser
  on completion → storeOpenAILogs() → Log.AILogs      (token counts from localStorage)
  clinician clicks Continue → fields land on the form → 10s autosave → Encounter.encounterData
```

> ⚠️ **Correction to an earlier analysis.** I previously described this path as calling public
> OpenAI directly. Telemetry shows it reaching **Azure OpenAI**, and the code explains how: the
> named `OpenAI` HttpClient's base address is `https://api.openai.com/`
> (`PacEHR.API/Program.cs:267`), but `OPENAI_API_URL` from `settings.appsettings`, when present,
> replaces it with an absolute URL. In production that row points at Azure OpenAI.

🔴 **That makes one SQL row the only thing keeping this PHI on Azure.** Delete or blank
`settings.appsettings.OPENAI_API_URL` and the same code silently falls back to public OpenAI — no
deployment, no error, no alert. The key is read from the same table and falls back to the committed
key in `appsettings.json`.

### 3.2 Chart audit — automatic, on every signed encounter 📡

```
Clinician signs the encounter        EncounterController.updateVerifiedFlag
  → encounter-event-queue            EncounterEventFunction (encounter-data-func)
  → chart-audit-sbq                  processChartAuditFunction (chartaudit-func)
  → api.openai.com                   🔴 PUBLIC OpenAI
  → pacehr_live
```

**This one is not user-initiated and not visible on screen.** Every signed encounter goes to the
public OpenAI endpoint. Its source is not in these repositories, so what it sends is unknown from
here. **Confirm that a BAA and zero-data-retention terms cover this traffic** — the AI architecture
document recommends Azure OpenAI for PHI precisely because those terms are available there.

### 3.3 `pacEHRAIBotEncounters_1…10` — unknown 📦

Ten triggered WebJobs on `pacehr-<e>-webjobs-app`, all last-run *Success*. The name suggests batch
AI processing of encounters. **Source not available; no telemetry edge to any OpenAI endpoint was
recorded for the WebJob host.** Worth finding its owner — it is the one AI component in production
nobody in the Epic 02 documents knows about.

### 3.4 Also present in code, not traced here

HIE document AI summary (`summarize-hie-using-ai` component, `usp_getHIEAISummaryPrompt`), the
per-field AI Summary prompt (`Template.fields.aiSummaryPrompt`) and the chart-audit-rule AI prompts.
All go through `AIPromptServices`, so they share §3.1's routing.

---

## 4. Findings, ranked

| # | Finding | Severity | Evidence | Fix |
|---|---|---|---|---|
| F1 | Chart audit sends every signed encounter to **public OpenAI** | 🔴 | 📡 `chartaudit-func → api.openai.com` | Confirm BAA + ZDR, or move to Azure OpenAI |
| F2 | **PHI masking is a no-op**; raw notes reach the model and `Log.AILogs` | 🔴 | 💻 `phi-masker.ts` returns early | Server-side masking — `pacEHR_AI` Epic 5 |
| F3 | **One SQL row** keeps AI Command on Azure; removing it reroutes to public OpenAI silently | 🔴 | 💻 `Program.cs:267` + `settings.appsettings` | Hard-code the Azure endpoint per environment; fail closed |
| F4 | Live keys **committed** in `appsettings.json`; Key Vault provisioned but **unused** | 🔴 | 💻 📦 | Rotate; load Key Vault; managed identity |
| F5 | **Three orphan queues** receiving messages | 🔴 | 📡 §2.4 | Check DLQ depth; fix or stop the sender |
| F6 | `PacehrFunc-Prod` fires **every second** of every 5th minute | 🟠 | 📦 `* */5 * * * *` | `0 */5 * * * *` |
| F7 | Service Bus send path on the **retired legacy SDK** | 🟠 | 💻 `ServiceBusQueueHelper.cs` | Move to `Azure.Messaging.ServiceBus` |
| F8 | **Single worker** on every plan; in-process SignalR breaks on scale-out | 🟠 | 📦 💻 | ≥2 instances; Azure SignalR or Redis backplane |
| F9 | Four **failing** WebJobs; nine stopped on legacy hosts | 🟠 | 📦 | Fix or delete |
| F10 | Production apps on `dev-apps` (Basic B1) and a UAT-named plan | 🟠 | 📦 | Re-home |
| F11 | Cosmos, Redis, Service Bus, OpenAI all **key-based**; Cosmos public access enabled | 🟠 | 💻 📦 | Managed identity, private access |
| F12 | `pacehrdev` container hard-coded in production code | 🟡 | 💻 `QRDAController.cs:231` | Config |
| F13 | PCC token cache **implemented twice** over two Redis connections | 🟡 | 💻 | Delete one |
| F14 | Cross-product coupling: PacEHR writes `ecm_live`; HL7 outbound reads `billehrservicebus` | 🟡 | 📡 | Record the ownership |

---

## 5. `pacEHR_AI` — which Azure resources to use, and why

### 5.1 Principles

Derived from the target design in `TicketsByAkash` and the code already in `pacEHR_AI`:

1. **Reuse before provision.** §2.16 already has most of what the service needs.
2. **Managed identity everywhere, keys nowhere.** The Node foundation already supports it —
   `src/core/database.ts` uses `azure-active-directory-default`, `src/core/llm.ts` uses Entra auth,
   `AZURE_CLIENT_ID` selects a user-assigned identity.
3. **Private by default.** The service is called server-to-server by the .NET API. Nothing about it
   should be reachable from a browser.
4. **Its own boundary.** `pacEHR_AI` owns all new AI code and the `AI.*` schema. Its Azure resources
   should be separately identifiable, deployable and revocable.
5. **Do not inherit §4.** Every finding there is a pattern not to copy.

### 5.2 Target topology

```
  PacEHR Angular ──▶ pacehr-<e>-api-app (.NET)          unchanged; no browser path to AI
                          │  Entra token for the AI app registration, via the API's managed identity
                          │  private network only — not on Front Door
                          ▼
              pacehr-<e>-ai-app   (Node 22, Linux container, image from thesnfist ACR)
              user-assigned MI:   pacehr-<e>-ai-id
                ├──▶ Azure OpenAI       thesnfist-<e>-eastus2-oai   private endpoint · MI · own deployment
                ├──▶ Azure SQL          pacehr_live / AI.* schema   Entra-only · MI
                ├──▶ Key Vault          pacehr-<e>-eastus2-kv       Key Vault references, if any secret remains
                ├──▶ App Insights       thesnfist-<e>-eastus2-appi  OpenTelemetry
                └──▶ (Phase 2) Service Bus · Blob · AI Search
              pacehr-<e>-ai-jobs      Functions, Node v4 — retention purge, eval replay
```

### 5.3 Resource by resource

| Need | Recommend | Reuse? | Why | Epic |
|---|---|---|---|---|
| **Request host** | **App Service, Linux, Web App for Containers**, P1v3 or above, **≥2 instances**, Always On, a staging slot | New plan — the existing ones are Windows | Extraction is a synchronous, streaming HTTP call; App Service handles SSE natively, and PacEHR alone already runs ten web apps the team knows how to operate. Slots give shadow-mode cutover for free. The repo's `feature/docker-webapp-pipeline` branch already points this way | 11 |
| **Background jobs** | **Azure Functions, Node v4, Flex Consumption** (or Elastic Premium Linux if VNet constraints require) | New | ⚠️ **This reverses a constraint in the backlog.** PEA-1101 chose Premium because Python needed a custom container, which Flex Consumption cannot run. A Node code deployment *can* run on Flex Consumption. Timers and queue handlers don't need a container | 2 (PEA-204), 10, 12 |
| **Container image** | `thesnfist<e>eastus2acr` | ✅ Reuse | Already in production | 11 |
| **Model** | `thesnfist-<e>-eastus2-oai`, a **dedicated deployment** for `pacEHR_AI` (the foundation names `AZURE_OPENAI_GPT_4_1_DEPLOYMENT`) | ✅ Reuse the account | A separate deployment gives the service its own quota, so a bulk eval run cannot throttle a clinician's AI Command. **Confirm Modified Abuse Monitoring / ZDR** on the account | 4, 11 |
| **Model access** | Managed identity + *Cognitive Services OpenAI User*; **private endpoint**; disable key auth | Change on the reused account | Closes F3 for the new service by construction — no URL in a table, no key | 11 (PEA-1103, 1104) |
| **Database** | `pacehr_live`, `AI.*` schema, **Entra-only** login for the service identity | ✅ Reuse | Decided in Epic 02. ⚠️ "No roles" still needs **one contained database user** for the managed identity (`CREATE USER … FROM EXTERNAL PROVIDER`). That is D31's question | 2 |
| **Identity** | **A dedicated user-assigned identity**, `pacehr-<e>-ai-id` | New — do *not* reuse the shared one | The shared `thesnfist-<e>-eastus2-user-identity` serves other products; one identity across products means one compromise reaches all of them | 1, 11 |
| **Secrets** | `pacehr-<e>-eastus2-kv` via Key Vault references | ✅ Reuse — finally used | With MI everywhere there should be close to nothing to store. Its job is to hold whatever cannot be MI | 11 |
| **Observability** | `thesnfist-<e>-eastus2-appi` via `@azure/monitor-opentelemetry`; GenAI semantic conventions | ✅ Reuse | PEA-1105 says reuse the existing instance. **Keep the foundation's `REFUSED` list** — it blocks LangSmith tracing, which would send prompt text off-platform | 10 |
| **Alerting** | Add AI alerts (latency, model 429s, extraction failure rate, `agentRun` vs `Log.AILogs` ratio) to `pacehr-product-team-ag` | ✅ Reuse the action group | The routing already reaches the right people | 10 |
| **Ingress** | **Not on Front Door.** Access restriction or private endpoint so only the .NET API reaches it | — | The browser never calls the AI service — that is what makes `AI.agentRun`'s token counts trustworthy, unlike `Log.AILogs` | 9 |
| **CI/CD** | Azure DevOps (`Saisystems-PaaS/PacEHR`) — build image → ACR → deploy to slot → swap | ✅ Same org | Matches every other PacEHR pipeline | 11 |
| **Messaging** | None in Phase 1. Later: **one** namespace, `pacehr-<e>-eastus2-ai-sbns`, `azure-messaging-servicebus` (current SDK) | Pattern reuse | Phase 1 extraction is synchronous. Async review, memory condensation and eval replay can use queues later. **One namespace, not one per feature** — 14 is already a lot to operate | 9, 12 |
| **Cache** | **None.** | — | REQ-03-06 forbids caching prompt inputs; a cached description breaks the per-call prompt hash. Prompt caching is explicitly Phase 2. The existing Redis is a PCC token store and should stay that way | 3, 8 |
| **Blob** | Phase 2 only — eval datasets and replay artefacts in a dedicated container on `pacehr` | Reuse later | Not needed for extraction | 10 |
| **Vector / RAG** | **None in Phase 1.** `thesnfist-<e>-eastus2-srch` (AI Search) or Postgres + `pgvector` if retrieval is ever added | Available | Epic 12's memory is SQL tables (`AI.memoryEvent`, `AI.memory`), not embeddings. Don't provision for a feature not in the backlog | 12 |
| **Async primitives** | Avoid Cosmos and Durable Functions for Phase 1 | — | Nothing in the backlog needs them, and Cosmos's only current job is PCC logging | — |

### 5.4 What not to copy from the current estate

| Today | For `pacEHR_AI` |
|---|---|
| Keys in `appsettings.json` and a SQL table | Managed identity; Key Vault for leftovers |
| Model endpoint chosen by a database row | Endpoint fixed per environment in configuration; fail closed |
| PHI guards in the browser, one disabled | Server-side guards before any model call — Epic 5 |
| Token counts asserted by the browser | Read from the model response, written server-side — `AI.agentRun` |
| One worker, no slot | ≥2 instances, staging slot, shadow mode |
| Public OpenAI for chart audit | Azure OpenAI only, private endpoint |
| A namespace per feature, legacy SDK | One namespace, current SDK |
| Windows plans | Linux container |

### 5.5 Phased rollout

| Phase | Provision | Reuse |
|---|---|---|
| **R0 — before code ships** | Linux App Service plan + `pacehr-<e>-ai-app` with slot · dedicated identity · OpenAI private endpoint + dedicated deployment · SQL contained user for the identity | ACR · Key Vault · App Insights · action group · Azure DevOps |
| **R1 — Epic 02 lands** | Nothing new — the migration runner applies `AI.*` to `pacehr_live` | `pacehr_live` |
| **R2 — shadow mode** | Alerts for the AI service | App Insights · action group |
| **R3 — background work** | Functions on Flex Consumption (retention purge) | — |
| **Phase 2** | Service Bus namespace · eval Blob container · prompt cache if measured | AI Search / Postgres only if retrieval is added |

**Net new resources for Phase 1: about six.** Everything else already exists and is paid for.

---

## 6. Questions this document cannot answer

1. **Who owns `chartaudit-func`, and is there a BAA and ZDR agreement covering its public OpenAI
   traffic?** (F1)
2. **What do `pacEHRAIBotEncounters_1…10` do, and where is their source?** (§3.3)
3. **Is the Azure OpenAI account approved for Modified Abuse Monitoring / ZDR?** Determines whether
   `pacEHR_AI` can rely on it for PHI as-is.
4. **App Service versus Functions for the request host.** This document recommends App Service; the
   backlog (PEA-1101) specified Functions Premium for a Python container that no longer exists. Worth
   one conversation.
5. **Network.** Do VNets with private endpoints already exist for SQL and Azure OpenAI? The export
   redacted them, and §5's private-endpoint recommendation depends on the answer.

---

## Referenced paths

- `Other-Docs/Extra_Resources/full-architecture-map.html` — source inventory and telemetry
- `pacEHR_API/PacEHR.API/Program.cs` — Key Vault (lines 52–58), OpenAI client (265–269), Cosmos (415–445), SignalR (114)
- `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` — AI routing, `settings.appsettings`
- `pacEHR_API/pacEHR.DomainServices/ServiceBusQueueHelper.cs` — every queue send; both SDKs
- `pacEHR_API/pacEHR.PCC.Services/Services/PccRedisTokenCache.cs`, `pacEHR.DomainServices/RedisServices/` — Redis
- `pacEHR_API/PacEHR.API/Hubs/` — SignalR
- `pacEHR_API/PacEHR.API/Controllers/EncounterController.cs` — `updateVerifiedFlag`, the start of chart audit
- `PacEHR/src/app/configs/phi-masker.ts` — the no-op mask
- `PacEHR/src/app/features/encounter-list/encounter-form/facades/encounter-ai.facade.ts` — AI Command
- `pacEHR_AI/src/core/{settings,database,llm}.ts` — the Node foundation §5 builds on
- `Other-Docs/TicketsByAkash/epic-11-azure-deployment.md`, `epic-10-observability.md`, `epic-12-memory.md` — target resources
