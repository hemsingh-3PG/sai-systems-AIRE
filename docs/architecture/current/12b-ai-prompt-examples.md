# AI Prompt Examples — verbatim, per calling context

> ⚠️ **PARTLY STALE - banner re-checked 2026-10-19 (not regenerated).** Compiled 2026-09-08/10 for the legacy OpenAI path only. `AIPromptServices.cs`, `AIController.cs`, `open-ai.service.ts` and `src/app/configs/` have **no commits since 2026-09-10** (git log, HEADs `pacEHR_API` 0f611f65c / `PacEHR` 401caa134), so the legacy content is expected to still hold, but it was not re-verified line by line. It does **not** cover the new Dragon Copilot dictation or the `pacEHR_AI` service. See `12-ai-assistance-deep-dive.md` (refreshed 2026-10-19) and `13-pacehr-ai-service-deep-dive.md`.

**Date**: 2026-09-10
**Compiled By**: ARCHITECT
**Status**: Current state
**Module 12b** — companion to `12a-ai-request-payload-reference.md`

> One worked example per calling context. **System prompts are verbatim from source** — file and
> line cited for each. **User-prompt values are illustrative and synthetic** (no real patient data);
> the *shape* is taken from code. Ellipses `[…]` mark elision and are always flagged.

---

## Index

| § | Context | Route | Prompt origin |
|---|---|---|---|
| 1 | Encounter note formatting | `/streamTemplateCompletion` | **Database** — `AI.prompt` |
| 2 | Encounter field extraction | `/streamCompletionWithData` | Inline literal |
| 3 | Free-text AI command | `/streamCompletion` | Inline template literal |
| 4 | CPT suggestion | `/streamCompletion` | Inline literal |
| 5 | Ambient transcript merge | `/streamCompletion` | **Database** — ambient prompt |
| 6 | AI field summary | `/streamCompletion` | Generated from field metadata |
| 7 | JSON repair | `/getCompletion` | Inline literal |

---

## 1. Encounter note formatting — the flagship path

**Route** `/streamTemplateCompletion` · **Caller** `encounter-ai.facade.ts:232` ·
**Prompt source** `AI.prompt` via `usp_getPrompt`

### 1a. The stored prompt, verbatim

A real seeded row — `PacEHR-Scripts-01022026.sql:5544-5575`,
`promptName = 'AI Prompt - H & P Notes'`, `accountId = 1`, `type = 'System'`.

Reproduced with elisions marked; the full text is ~5,600 characters:

```text
This GPT assists doctors by taking their dictated or documented texts and integrating them
into a predefined encounter-based "<<templateName>>" template. The GPT ensures the text is
formatted correctly and consistently according to the encounter template fields, providing a
polished and professional final output identifying patient specific care outcomes. Communicate
the output in a professional tone, from a medical doctors perspective to another doctor who
will be assuming care of the patient, ensuring clarity, brevity, and precision in the formatted
encounter notes. "<<templateName>>" the text provided by the user is intended to capture the
medical assessment and care specific for documenting a "<<templateName>>" patient encounter.
The information provided by the user is related to a patient <<templateProcess>> a healthcare
facility or healthcare center. The goal of the "<<templateName>>" note is to capture the context
related to why the patient is being <<templateProcess>>. The data received by the user can be
sorted into the <<sectionCount>> separate categories <<sectionName>>. <<promptBody>> Identify as
<<encounterFields>>. Do not override the user selction of template or visit type. The content of
the output must follow the referenced laws, guidelines, and regulatory bodies. Laws and
guidelines: Medicare and Medicaid Services (CMS) Guidelines: [… ~600 chars of CMS / CPT / AHIMA
/ AMA / OIG / NCCI citations …]

For ICD Codes - Extract the appropriate comma separated ICD code(s) only from the following
provider note. Ensure that the code(s) accurately reflect the diagnoses mentioned in the note.
Add additional descriptions in round bracket. And add Treatment and Plan for selected ICD Code
in terms of:- Treatment:"", Plan:"" in double angle bracket after every ICD code Instructions
for ICD-code: 1. Treatment and Plan is mandatory every ICD-codes. 2. If appropriate Treatment
and Plan not found response NA. 3. Do not group ICD codes together into one ICD Code. 4. Do not
select any incomplete ICD codes. 5. Do not select any unbillable/outdated ICD codes. 6. Do not
select any IMO-custom created ICD codes as these are non-billable.

For CPT-code: Identify and suggest only the appropriate CPT codes that strictly match the
services rendered according to the specified Place of Service. [… ~1,900 chars: 9 evaluation
criteria, the justification field list, 9 numbered instructions …] 9. Consider Place of Service
is "<<encounterPOS>>".

For Follow-up section: Identify the next follow-up or visit date if it is explicitly mentioned
in the following patient visit note. If the date is not explicitly mentioned, look for any
references to time frames only like (e.g., "three day", "next week", "in two months", "next
visit in three weeks"). Respond back with a JSON object containing the following fields:
"Date": "MM/DD/YYYY", and "Description". [… ~400 chars …]

Note: 1. Always return "NA" if you are not sure about your response. 2. Focus on the healthcare
domain 3. Do not send data in nested form. 4. Do not change JSON structure or add new key and
sub key. 5. Return JSON in single line. 6. Before returning the JSON, validate that all required
fields are present, values follow the rules, and the JSON is structurally correct. 7. Always
return only the JSON object exactly as required, with no extra text or explanation 8. Consider
the Date of Service is "<<DOSDate>>". 9. Consider Place of Service is "<<encounterPOS>>"
Validate the JSON object before returning it by ensuring: (1) it is valid JSON with proper
opening/closing braces; (2) all required fields exist exactly as defined in the template; (3) no
fields are missing, renamed, or added; (4) values follow all rules (date format, NA usage, empty
strings allowed). Return only the corrected, valid JSON in a single line.
```

Note it asks for JSON validation **four separate times** — in Note 6, Note 7, and twice in the
closing paragraph. That is the prompt compensating for the absent `response_format`.

### 1b. What `<<promptBody>>` expands to

Built by `getPromptBody()`, `encounter-ai.facade.ts:858-874`. Illustrative, for a two-section
template:

```text
Chief Complaint: Capture the presenting problem in the patient's own words where available.
 In the 'Chief Complaint' section there are 2 field in this section. Fields are  Reason for
Visit,  Onset. Reason for Visit: State the primary reason for the encounter. Onset: Record
when symptoms began. Assessment and Plan: Summarise clinical impression and next steps.
 In the 'Assessment and Plan' section there are 3 field in this section. Fields are
 Assessment,  Plan,  Follow-up. Assessment: One line per active problem. Plan: Include
medication changes and monitoring. Follow-up.
```

Three instruction levels, flattened into one prose string, no delimiters, no precedence. A field
with no `prompt` contributes just its name and a full stop (`Follow-up.` above).

### 1c. The resolved wire payload

Illustrative substitutions; synthetic patient text.

```jsonc
{
  "model": "gpt-4o",
  "stream": true,
  "stream_options": { "include_usage": true },
  "temperature": 0,
  "messages": [
    {
      "role": "system",
      "content": "This GPT assists doctors by taking their dictated or documented texts and integrating them into a predefined encounter-based \"H & P Notes\" template. […] The information provided by the user is related to a patient admitted a healthcare facility […] The data received by the user can be sorted into the 2 separate categories Chief Complaint, Assessment and Plan. Chief Complaint: Capture the presenting problem […] Follow-up. Identify as {\"Chief Complaint\":{\"Reason for Visit\":\"\",\"Onset\":\"\"},\"Assessment and Plan\":{\"Assessment\":\"\",\"Plan\":\"\",\"Follow-up\":\"\"}}. […] 9. Consider Place of Service is \"Skilled Nursing Facility\". […] 8. Consider the Date of Service is \"03/14/2026\". […]"
    },
    {
      "role": "user",
      "content": "Patient seen this morning for follow-up of CHF. Reports improved breathing since the diuretic increase last week. No chest pain. Lungs clear bilaterally, trace ankle oedema. Continue current regimen, recheck weight daily, see again in two weeks."
    }
  ]
}
```

| Placeholder | Filled from | Example value |
|---|---|---|
| `<<templateName>>` | `encounterInfo[0].encounterTempleteName` | `H & P Notes` |
| `<<templateProcess>>` | **hardcoded** `'admitted'` (`:814`) | `admitted` |
| `<<sectionCount>>` | `sectionDetails.sectionCount` | `2` |
| `<<sectionName>>` | `sectionDetails.sectionNameList` | `Chief Complaint, Assessment and Plan` |
| `<<promptBody>>` | `getPromptBody()` | §1b |
| `<<encounterFields>>` | `JSON.stringify(nestedEncounterFields)` | the nested field skeleton |
| `<<encounterPOS>>` | `data[0].POSname` | `Skilled Nursing Facility` |
| `<<DOSDate>>` | `moment(DOS).format('MM/DD/YYYY')` | `03/14/2026` |
| `<<todayDate>>` | `moment().format('YYYY-MM-DD')` | `2026-03-14` |

---

## 2. Encounter field extraction

**Route** `/streamCompletionWithData` · **Caller** `add-rounding-notes.component.ts:869-891`

### 2a. System prompt — verbatim, complete

````text
This GPT assists doctors by taking their verbal texts and integrating them into a template From
given text and collect appropriate information to create Encounter. For Follow-up section:
Identify the next follow-up or visit date if it is explicitly mentioned in the following patient
visit note. If the date is not explicitly mentioned, look for any references to time frames only
like (e.g., "three day", "next week", "in two months", "next visit in three weeks"). Instructions
for Follow-up: Consider symptoms, treatment plan, monitoring, patients condition, especially given
the severity of symptoms. Follow date format for follow-up date "YYYY-MM-DD". If Facility is not
mentioned return default Value. If Encounter Templete Name is not mentioned return default Value.
Check all previous chat messages for information to update JSON response. Identify JSON
```{"encounterTempleteID":"","eventTypeId":"","POSID":"","facilityID":"","Date of Service":"","follow-up":""}```
Note: 1. Always return "NA" if you are not sure about your response. 2.Do not change JSON structure
or add new key and sub key. 3. Give eventtypeId only when it is explicity mentioned in the note. If
not mentioned return selected value. 4. Today date is "2026-03-14". 5. Date of Service is today
date if it is not mentioned in the note.
````

### 2b. The three-message payload

````jsonc
{
  "model": "gpt-4o",
  "stream": true,
  "stream_options": { "include_usage": true },
  "temperature": 0,
  "messages": [
    { "role": "system", "content": "This GPT assists doctors by taking their verbal texts […see 2a…]" },
    { "role": "user",   "content": "Note - Seen at bedside for wound check.<br>Dressing changed, no signs of infection.<br>Will review again next week." },
    { "role": "user",   "content": "Encounter Template list JSON ```{\"List\":[{\"encounterTempleteID\":41,\"encounterTempleteName\":\"H & P Notes\",\"default\":1},{\"encounterTempleteID\":52,\"encounterTempleteName\":\"Progress Note\",\"default\":0}]}``` POS list JSON ```{\"List\":[{\"POSID\":31,\"POSname\":\"Skilled Nursing Facility\",\"default\":1},{\"POSID\":32,\"POSname\":\"Nursing Facility\",\"default\":0}]}``` Location/Facility list JSON ```{\"List\":[{\"facilityID\":118,\"facilityName\":\"Riverside Care Center\",\"default\":1}]}``` Event Types list JSON ```{\"List\":[{\"eventTypeId\":4,\"eventType\":\"Follow-up\",\"default\":1}]}``` Default values JSON ```{\"Values\":{…}}```" }
  ]
}
````

The `user` content in `\n`→`<br>` form is exactly as sent — the note is HTML-escaped for display
before being handed to the model.

**The third message is a five-element array client-side** (`generateAdditionalData()`, `:894-903`)
against a `string` DTO (`AIDto.cs:360`). The four labelled ID lists shown are the valid
enumerations — the correct answer set is in the prompt, as prose, where the decoder cannot enforce it.

---

## 3. Free-text AI command

**Route** `/streamCompletion` · **Caller** `encounter-ai.facade.ts:364-385`

### 3a. System prompt — verbatim, complete

```text
You are provided with a JSON object and a set of human-language commands to manipulate this JSON
object. Your task is to update the JSON object based on these commands and response back affected
object only. Focus Areas: 1. Identify and update similar keys in the JSON object as per the user's
commands. 2. Interpret the commands given in natural human language and apply the necessary changes
to the JSON object. 3. Always return 'NA' if you are unsure about your response and delete
operation. 4. Ensure the JSON object is not nested and maintains its original structure.
5. Prioritize the healthcare domain context while making updates. 6. Date Format: Always use the
"MM/DD/YYYY" format for dates. 7. Place of Service (POS): When updating POS, refer to similar data
within the provided JSON list only. 8. Return JSON in a single line. JSON Object to Process
{"Reason for Visit":"Wound check","Onset":"3 days","Assessment":"Stage 2 pressure ulcer","Plan":"Daily dressing","Follow-up":""}
```

The current encounter's field values are appended to the **system** message, not the user turn.

### 3b. Payload

````jsonc
{
  "model": "gpt-4o", "stream": true,
  "stream_options": { "include_usage": true }, "temperature": 0,
  "messages": [
    { "role": "system", "content": "You are provided with a JSON object […] JSON Object to Process {\"Reason for Visit\":\"Wound check\",…}" },
    { "role": "user",   "content": "POS list JSON ```{\"List\":[{\"POSID\":31,\"POSname\":\"Skilled Nursing Facility\"}]}```\nset the follow-up to two weeks from today" }
  ]
}
````

> 🟠 A three-message `promptBody` array is constructed at `:369-373` — `[system, posList, command]` —
> and **never used**. The call at `:374` concatenates `posList + '\n' + openAiCommand` into one user
> message instead. The log at `:385` then records only `openAiCommand`, so `posList` appears in
> neither the log nor its intended message slot.

---

## 4. CPT suggestion

**Route** `/streamCompletion` · **Caller** `encounter-ai.facade.ts:731-733`

A ~4,500-character inline literal. Opening, verbatim:

```text
This GPT assists doctors by taking their dictated or documented texts. The GPT ensures the text is
formatted correctly and consistently according to the encounter template fields, providing a
polished and professional final output identifying patient specific care outcomes. […] Identify as
{"CPT Codes":""}. The content of the output must follow the referenced laws, guidelines, and
regulatory bodies. Laws and guidelines: Medicare and Medicaid Services (CMS) Guidelines: […]
For CPT-code: Identify and suggest only the appropriate CPT codes that strictly match the services
rendered according to the specified Place of Service. […] Consider/Evaluate the following to suggest
CPT codes 1. Type of Service  2. Evaluation and Management complexity (Minimal, Low, Moderate,
High). 3. Duration of therapy (in minutes or hours). 4. Patient comorbidities […] 9. Consider Place
of Service is 'Skilled Nursing Facility' 9. Description sholud be in parentheses.
Note: 1. Always return 'NA' if you are not sure about your response. […]
```

```jsonc
"messages": [
  { "role": "system", "content": "This GPT assists doctors […] Consider Place of Service is 'Skilled Nursing Facility' […]" },
  { "role": "user",   "content": "<this.roundingNote — the provider's full rounding note text>" }
]
```

> 🔴 **This CPT block is a near-verbatim duplicate of the `For CPT-code:` section inside the stored
> template prompt (§1a).** The same clinical coding instructions exist in two places — one in
> `AI.prompt` in the database, one in a TypeScript literal — maintained separately. Note also the
> duplicated list numbering (`9.` twice) and the typo `sholud`, both of which appear in the shipped
> prompt.

---

## 5. Ambient transcript merge

**Route** `/streamCompletion` · **Caller** `add-rounding-notes.component.ts:1529-1539` ·
**Prompt source** selected template's ambient prompt, else account setting (`usp_getAmbientPrompt`)

The system prompt is entirely data-driven — there is **no fallback**. The default sits commented out
at `:1535`, verbatim:

```text
You are a clinical documentation assistant. Given an array of objects where type "RN" contains a
baseline rounding note and type "AL" contains multi-speaker ambient transcription, merge all
clinically relevant information into the RN, normalize conversations into a clear third-person
clinical narrative, ignore non-clinical or filler speech, do not add assumptions, and return only
the finalized Rounding Note as a single plain text string with no JSON, formatting, or metadata.
```

```jsonc
"messages": [
  { "role": "system", "content": "<ambientSettings.ambientPrompt — from DB, no fallback>" },
  { "role": "user",   "content": "[{\"type\":\"RN\",\"note\":\"Routine follow-up, wound stable.\"},{\"type\":\"AL\",\"speaker\":1,\"text\":\"How has the pain been since Tuesday?\"},{\"type\":\"AL\",\"speaker\":2,\"text\":\"Better, maybe a three out of ten now.\"},{\"type\":\"AL\",\"speaker\":1,\"text\":\"Good. Keep the dressing dry and I'll see you next week.\"}]" }
]
```

Note the user turn is the **verbatim multi-speaker conversation**, patient utterances included —
the highest-PHI-density payload of the seven, and `maskPHI` does not run on it.

Of the seven contexts this is the only prompt whose text already states *"do not add assumptions"* —
and it is the one that is commented out.

---

## 6. AI field summary

**Route** `/streamCompletion` · **Caller** `ai-summary-prompt.component.ts:135-146, 168-170`

Assembled at runtime from field metadata (`:146`, verbatim template):

````text
This GPT assists doctors by summarize the data provided in encounter fields. Details of the
fields : Assessment: Summarise the clinical impression in one line per problem. Plan: List
medication changes and monitoring steps. Return the output as a single-line JSON in the following
format JSON ```{"Assessment":"","Plan":""}``` Note: 1. If a field is absent or having blank field
value, return "NA" for that field. 2. Do not modify the JSON structure or add new keys or nested
data. 3. Return JSON in a single line. 4. Consolidate redundant information across entries when
needed.
````

```jsonc
"messages": [
  { "role": "system", "content": "This GPT assists doctors by summarize the data provided in encounter fields. Details of the fields : […]" },
  { "role": "user",   "content": "{\"Assessment\":\"Stage 2 pressure ulcer, sacral. Stable.\",\"Plan\":\"Daily dressing change; reassess in one week.\"}" }
]
```

> 🟠 **A fourth instruction store.** `promptFieldDetails` is built from `item.aiSummaryPrompt`
> (`:141-144`) — a per-field instruction column **distinct from** the `fieldData.prompt` used by
> `getPromptBody()` in §1b. So field-level instructions live in at least two separate places, used
> by different contexts, with no reconciliation between them.

---

## 7. JSON repair

**Route** `/getCompletion` · **Caller** `encounter-ai.facade.ts:270-275`

The workaround the client asked to remove. Verbatim, complete — the shortest prompt in the system:

```jsonc
"messages": [
  { "role": "system", "content": "You are a JSON repair assistant. Your only job is to fix malformed JSON and return valid JSON. Return ONLY the corrected JSON, no explanations." },
  { "role": "user",   "content": "Here is the malformed JSON:\n\n{\"Assessment\":\"Stage 2 ulcer\",\"Plan\":\"Daily dressing\"" }
]
```

Triggered from the `catch` around `JSON.parse(this.aiResult)` on the template path (`:259-262`).
Its input is the output of §1 — so a §1 failure costs a second full round trip, and the malformed
JSON in the user turn still carries whatever PHI the note contained.

---

## Observations from collecting these

| # | Observation |
|---|---|
| 1 | The stored template prompt demands JSON validation **four times**, and §7 exists as a runtime fallback. Both are compensating for the missing `response_format` |
| 2 | The `For CPT-code:` instruction block is duplicated between `AI.prompt` (§1a) and a TypeScript literal (§4), maintained separately |
| 3 | Field-level instructions live in **two** columns — `fieldData.prompt` (§1b) and `item.aiSummaryPrompt` (§6) — consumed by different contexts |
| 4 | The seeded `AI Prompt - H & P Notes` row has `isActive = 0` and `isUniversal = NULL`. `usp_getPrompt` requires `isActive = 1` for all three priorities and `isUniversal = 1` for priorities 2 and 3 — so a `NULL` here means **priorities 2 and 3 both miss and no prompt is returned at all** |
| 5 | Shipped prompt text carries duplicated list numbering (`9.` twice in §1a and §4) and a typo (`sholud`, §4) |
| 6 | Only §5's prompt states "do not add assumptions" — the closest thing to SarahLena's primary rule — and that text is commented out |
| 7 | §3 constructs a correct three-message array and then discards it for string concatenation |
| 8 | Every prompt instructs *"Always return 'NA' if you are not sure"* — an instruction that cannot be verified, and that makes an omission indistinguishable from a genuine absence |

---

**Cross-references**: `12a-ai-request-payload-reference.md` ·
`12-ai-assistance-deep-dive.md` · `design/12-ai-phase1-implementation-architecture.md`
