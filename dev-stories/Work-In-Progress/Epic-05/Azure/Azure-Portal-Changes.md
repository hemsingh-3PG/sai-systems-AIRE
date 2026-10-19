# Epic 05 — Changes Needed in Microsoft Foundry (Azure OpenAI)

**For:** whoever has access to change the pacEHR Azure OpenAI resources (Foundry portal or Azure CLI)
**From:** Hem Singh, pacEHR_AI team · **Date:** 2026-10-14
**Time needed:** about 15 minutes per environment
**Checked against:** Microsoft Learn, *Configure content filters (classic)*, updated 2026-09-23, and the raiPolicies REST
API reference, version 2024-10-01

---

## 1. What we're asking for, and why

The pacEHR AI service sends clinical notes to Azure OpenAI to extract structured fields. Azure's **default** content
filter blocks text it rates as Medium for self-harm, violence, sexual content or hate. Ordinary clinical notes hit
that threshold: *"Hx of suicidal ideation, denies current SI/HI"*, *"laceration from assault"*, *"sexual history:
…"*. The default filter would refuse those notes.

We're asking for **one custom content filter**, with the same name and settings, on each environment's Azure OpenAI
resource. It does three things:
- it lets clinical text through on the way in;
- it still blocks anything Azure rates **High** in the model's answer;
- it keeps Microsoft's jailbreak detection (Prompt Shields) **blocking**.

Our code names the filter on each request using the `x-policy-id` header, so **the filter doesn't need to be attached
to any deployment**.

There's also one **read-only check** (§3) and a short list of things **not** to change (§4).

## 2. Change 1: create the content filter `pacehr-clinical-extraction`

Do this on each environment's Azure OpenAI resource, **dev first**. Do the next environment only after we confirm dev
works (§6).

| Environment | Azure OpenAI resource | Resource group |
|---|---|---|
| Dev | `oai-3pillar-dev-eus2` | *please fill in* |
| QA | `thesnfist-q-eastus2-oai` *(please confirm this is QA)* | *please fill in* |
| UAT | *please fill in* | *please fill in* |
| Preprod | *please fill in* | *please fill in* |
| Prod | *please fill in* | *please fill in* |

**Permission needed:** *Cognitive Services Contributor* (or Contributor or Owner) on the Azure OpenAI resource.

**The name must be exactly `pacehr-clinical-extraction`**: lowercase, with hyphens. Our service sends this exact
string. If the name differs, Azure rejects every request with `InvalidContentFilterPolicy`.

Use either option A (portal) or option B (CLI). Both create the same filter.

### Option A: Foundry portal

1. Sign in to <https://ai.azure.com>. Make sure the **New Foundry** toggle at the top is **off**. These steps are for
   **Foundry (classic)**.
2. Open the environment's Azure OpenAI resource, for example `oai-3pillar-dev-eus2`.
3. In the left menu, select **Guardrails + controls**, then the **Content filters** tab. If you don't see it, select
   **… More** at the bottom of the menu.
4. Select **+ Create content filter**.
5. **Basic information:**
   - **Name:** `pacehr-clinical-extraction`.
   - **Connection:** if the portal asks for one, pick this environment's Azure OpenAI resource.
   - Then select **Next**.
6. **Input filter** (applies to the clinical note we send):

   | Setting | Set it to | Why |
   |---|---|---|
   | Violence | **Annotate only** | Notes describe injuries and assaults |
   | Hate | **Annotate only** | Notes quote what patients said |
   | Sexual | **Annotate only** | Notes include sexual history and screening |
   | Self-harm | **Annotate only** | Notes include suicide-risk assessments |
   | Prompt shields for jailbreak attacks | **Annotate and block** | Keeps Microsoft's jailbreak detection on |
   | Prompt shields for indirect attacks | **Off** | Needs a document format we don't use |
   | Blocklist (including the built-in **Profanity** list) | **Off** | Quoted patient language is part of the record |

   **If the portal won't offer *Annotate only* for the four harm categories,** set their threshold slider to **High**
   instead, and tell us. Microsoft's documentation allows annotate-only on input for all customers, but one page also
   describes it as needing approval. Then select **Next**.
7. **Output filter** (applies to the model's answer):

   | Setting | Set it to |
   |---|---|
   | Violence, Hate, Sexual, Self-harm | Threshold **High**, **block** |
   | Protected material for text | **Annotate only** |
   | Protected material for code | **Annotate only** |
   | Groundedness (preview) | **Off** |
   | Personally identifiable information (PII) (preview) | **Off**: the answer is supposed to contain patient details |
   | Streaming mode | **Leave it at the default.** We don't stream |
   | Blocklist | **Off** |

   Then select **Next**.
8. **Connection** (apply to deployments): **don't select any deployment.** Leave it empty and continue. Attaching the
   filter would change behaviour for any other application using the same deployment. Our service selects the filter
   on each request.
9. **Review:** check the settings against the tables above, then select **Create filter**.

### Option B: Azure CLI

This option suits anyone with CLI access, or anyone who wants a repeatable record. Save this JSON as
`pacehr-clinical-extraction.json`:

```json
{
  "properties": {
    "basePolicyName": "Microsoft.Default",
    "contentFilters": [
      { "name": "Hate",     "enabled": true, "blocking": false, "severityThreshold": "High", "source": "Prompt" },
      { "name": "Sexual",   "enabled": true, "blocking": false, "severityThreshold": "High", "source": "Prompt" },
      { "name": "Selfharm", "enabled": true, "blocking": false, "severityThreshold": "High", "source": "Prompt" },
      { "name": "Violence", "enabled": true, "blocking": false, "severityThreshold": "High", "source": "Prompt" },
      { "name": "Hate",     "enabled": true, "blocking": true,  "severityThreshold": "High", "source": "Completion" },
      { "name": "Sexual",   "enabled": true, "blocking": true,  "severityThreshold": "High", "source": "Completion" },
      { "name": "Selfharm", "enabled": true, "blocking": true,  "severityThreshold": "High", "source": "Completion" },
      { "name": "Violence", "enabled": true, "blocking": true,  "severityThreshold": "High", "source": "Completion" },
      { "name": "Jailbreak", "enabled": true, "blocking": true, "source": "Prompt" },
      { "name": "Profanity", "enabled": false, "blocking": false, "source": "Prompt" },
      { "name": "Protected Material Text", "enabled": true, "blocking": false, "source": "Completion" },
      { "name": "Protected Material Code", "enabled": true, "blocking": false, "source": "Completion" }
    ]
  }
}
```

Then run the following, filling in the subscription, resource group and resource name:

```bash
az login
az account set --subscription "<subscription-id>"

URL="https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<openai-resource-name>/raiPolicies/pacehr-clinical-extraction?api-version=2024-10-01"

az rest --method put --url "$URL" --body @pacehr-clinical-extraction.json   # create, or update if it exists
az rest --method get --url "$URL"                                           # confirm what was saved
```

Notes on the JSON:
- `"enabled": true, "blocking": false` means **annotate only**.
- If Azure rejects the four `"source": "Prompt"` harm entries, change each of them to `"blocking": true` with
  `"severityThreshold": "High"` and tell us, as in the portal fallback.
- The filter names and the `Microsoft.Default` base policy come from Microsoft's REST API reference sample.
- Running the command again with the same file changes nothing.

## 3. Check 1, read-only: the deployment type

Under the BAA we want the requests processed **in the US**. A **Global** deployment may process them in any Azure
region.

- **Portal:** open the resource, go to **Models + endpoints** (or **Deployments**), select the GPT-4.1 deployment, and
  note its **Deployment type**.
- **CLI:**
  ```bash
  az cognitiveservices account deployment show -g "<resource-group>" -n "<openai-resource-name>" \
    --deployment-name "<gpt-4.1-deployment-name>" --query sku.name -o tsv
  ```

| Result | Meaning |
|---|---|
| `Standard` (regional) or `DataZoneStandard` (US data zone) | ✅ Fine, nothing to do |
| Anything with **Global** in it | ⚠️ **Tell us; don't change it yourself.** Moving to another type means a new deployment and a configuration change on our side |

## 4. Please don't change these

| Item | Leave it as | Why |
|---|---|---|
| The filter currently attached to the GPT-4.1 deployment | Unchanged | Our service selects its own filter per request; the deployment's filter only affects other callers |
| **Defender for Cloud → AI threat protection** | **Not enabled** | Decided for Phase 1. Our service logs attack attempts itself, with the clinician's id. If it's ever turned on, **prompt evidence must be off**: that option copies note text into the alerts |
| Custom **blocklists** | None | Our service already blocks those phrasings before Azure sees them |
| Data controls (Purview prompt capture) | Off | It would create another copy of patient data |
| **Try it out** pages (content safety, prompt shields) | Fine to use, with **made-up text only** | Never paste a real patient's note into a portal test page |

## 5. Later, before go-live: not needed now

These belong to the deployment epic (Epic 11). They're listed here so they aren't forgotten.

| Item | What it is |
|---|---|
| **Abuse-monitoring opt-out** | By default Azure keeps prompts for up to 30 days, and Microsoft staff may review flagged ones. Opting out is done through Microsoft's *modified abuse monitoring* application form, submitted by whoever holds the Azure agreement (EA or MCA). There's no API for it |
| Disable key authentication | `disableLocalAuth` on the QA, UAT, preprod and prod resources, once the service uses managed identity there. Dev keeps keys while developers need them |
| Network access | Already private, per the team. Keep public network access disabled |
| Diagnostic settings | Send metrics and non-content logs only. Leave off any log category that records request content |

## 6. What to send back to us, and the order

For each environment, after creating the filter, send:

| Environment | Resource | Resource group | Filter created? | Input harm categories set to | GPT-4.1 deployment name | Deployment type |
|---|---|---|---|---|---|---|
| Dev | `oai-3pillar-dev-eus2` | | ☐ | Annotate only / High | | |
| QA | | | ☐ | | | |
| UAT | | | ☐ | | | |
| Preprod | | | ☐ | | | |
| Prod | | | ☐ | | | |

**Order:**
1. Create the filter on **dev** and send the dev row.
2. We switch our dev service to use the filter and run our test set of made-up clinical notes against it. We'll tell
   you whether it passed.
3. Then do **QA**, and we repeat the test.
4. Then do **UAT**, **preprod** and **prod**. Each environment's service only starts using the filter after you've
   confirmed it exists there.

**Changing or removing the filter later:** please **tell us first**. Our service names the filter on every request, so
deleting or renaming it makes every request fail. We switch our setting off first, then you remove it.
