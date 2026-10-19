# Test note `TN-PN-S008`

| | |
|---|---|
| **Set** | Practice (sample; may be shared with developers) |
| **Form** | Progress Note (sample) |
| **Patient** | Testpatient Hotel (P08), 81, male · MRN TEST-MRN-0008 · Room 18 |
| **Clinician** | Dr Testdoc One (C1), login `test.clin1` · style: Terse, heavy short forms (Wt, BP, HR, c/o, f/u, BLE, A:, P:) |
| **Visit date** | 2026-10-09 · Skilled Nursing Facility · Testview Care Center |
| **Tags** | `abbrev` `med-change` `name-like-word` `negative` |
| **Form before sending** | Empty |
| **Expected totals** | Found 12 · Unclear 0 · Not mentioned 4 (of 16 fields) |

## Clinician transcript (send as one message)


```text
81M w/ Parkinson's, depression. More tremor past wk per staff. No falls. Gait shuffling. A&Ox3 but flat affect. VS: T 97.9F P 70 BP 110/62 RR 16 SpO2 95% RA. No new c/o. A: PD w/ worsening tremor; depression stable. P: incr carbidopa-levodopa 25/100 to 1.5 tab TID, cont sertraline 50 daily, neuro f/u 2 wks.
```


## Answer sheet

Rows in **bold** are Found or Unclear. Every other row is **Not mentioned**: any value the AI gives there is **Made up**.

| Section | Field | Important | Expected | Value | Unit | Also OK | Reference from note | Must NOT contain | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Vitals | **Temperature** | Yes | **Found** | 97.9 | °F |  | "T 97.9F" |  |  |
| Vitals | **Pulse** | Yes | **Found** | 70 |  |  | "P 70" |  |  |
| Vitals | **Respiratory rate** | Yes | **Found** | 16 |  |  | "RR 16" |  |  |
| Vitals | **Blood pressure** | Yes | **Found** | 110/62 |  |  | "BP 110/62" |  |  |
| Vitals | **Oxygen saturation** | Yes | **Found** | 95 |  |  | "SpO2 95% RA" |  |  |
| Vitals | Weight | Yes | Not mentioned |  |  |  |  |  | Not in note |
| Subjective | **Interval history** | No | **Found** | Key points: more tremor over the past week; no falls; shuffling gait |  |  | "More tremor past wk per staff. No falls. Gait shuffling." |  |  |
| Subjective | Pain score | No | Not mentioned |  |  |  |  |  | Not in note |
| Subjective | **New complaints** | No | **Found** | None |  | No new complaints | "No new c/o" |  |  |
| Objective | **Mental status** | No | **Found** | Alert and oriented x3 |  |  | "A&Ox3" |  |  |
| Objective | Wound status | No | Not mentioned |  |  |  |  |  | Not in note |
| Objective | Edema | No | Not mentioned |  |  |  |  |  | Not in note |
| Assessment and Plan | **Assessment** | Yes | **Found** | Key points: Parkinson's disease with worsening tremor; depression stable |  |  | "A: PD w/ worsening tremor; depression stable" |  | "Parkinson's" must appear as written, not as a code like [NAME_1] |
| Assessment and Plan | **Plan** | No | **Found** | Key points: increase carbidopa-levodopa 25/100 to 1.5 tablets three times daily; continue sertraline 50 mg daily; neurology follow-up in 2 weeks |  |  | "P: incr carbidopa-levodopa 25/100 to 1.5 tab TID" |  |  |
| Assessment and Plan | **Medication changes** | Yes | **Found** | Carbidopa-levodopa 25/100 increased to 1.5 tablets three times daily |  |  | "incr carbidopa-levodopa 25/100 to 1.5 tab TID" | sertraline change | Sertraline is continued, not changed |
| Assessment and Plan | **Follow-up** | No | **Found** | Neurology in 2 weeks |  | 2 weeks; 2026-10-23 | "neuro f/u 2 wks" |  |  |

## Watch out for (examples of bugs this note is designed to catch)

- Medication changes lists sertraline → Wrong value
- "Parkinson's" shown as a code or removed → High (privacy masking bug)
