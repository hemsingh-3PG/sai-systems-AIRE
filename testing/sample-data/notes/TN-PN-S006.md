# Test note `TN-PN-S006`

| | |
|---|---|
| **Set** | Practice (sample; may be shared with developers) |
| **Form** | Progress Note (sample) |
| **Patient** | Testpatient Foxtrot (P06), 88, male · MRN TEST-MRN-0006 · Room 21 |
| **Clinician** | Dr Testdoc Three (C3), login `test.clin3` · style: Dictation (speech-to-text): no punctuation, numbers as words |
| **Visit date** | 2026-10-07 · Skilled Nursing Facility · Testview Care Center |
| **Tags** | `conflict` `dictation` `wound` `relative-date` |
| **Form before sending** | Empty |
| **Expected totals** | Found 10 · Unclear 1 · Not mentioned 5 (of 16 fields) |

## Clinician transcript (send as one message)


```text
eighty eight year old man bedbound with stage two pressure injury on the sacrum wound measures two by one point five centimeters with pink granulation tissue no drainage weight today seventy kilograms per nursing weight sixty six kilograms no reweigh done blood pressure one eighteen over sixty four pulse sixty eight temperature thirty six point nine celsius he is lethargic this morning more than usual per nurse new complaint of decreased appetite assessment stage two sacral pressure injury healing lethargy new plan reposition every two hours continue foam dressing check basic metabolic panel and urinalysis today follow up tomorrow
```


## Answer sheet

Rows in **bold** are Found or Unclear. Every other row is **Not mentioned**: any value the AI gives there is **Made up**.

| Section | Field | Important | Expected | Value | Unit | Also OK | Reference from note | Must NOT contain | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Vitals | **Temperature** | Yes | **Found** | 36.9 | °C |  | "temperature thirty six point nine celsius" |  |  |
| Vitals | **Pulse** | Yes | **Found** | 68 |  |  | "pulse sixty eight" |  |  |
| Vitals | Respiratory rate | Yes | Not mentioned |  |  |  |  |  | Not in note |
| Vitals | **Blood pressure** | Yes | **Found** | 118/64 |  |  | "blood pressure one eighteen over sixty four" |  |  |
| Vitals | Oxygen saturation | Yes | Not mentioned |  |  |  |  |  | Not in note |
| Vitals | **Weight** | Yes | **Unclear** |  |  |  | "weight today seventy kilograms per nursing weight sixty six kilograms no reweigh done" |  | Two different weights, no correction → Unclear |
| Subjective | **Interval history** | No | **Found** | Key points: bedbound; stage 2 sacral pressure injury |  |  | "bedbound with stage two pressure injury on the sacrum" |  |  |
| Subjective | Pain score | No | Not mentioned |  |  |  |  |  | Not in note |
| Subjective | **New complaints** | No | **Found** | Decreased appetite |  |  | "new complaint of decreased appetite" |  |  |
| Objective | **Mental status** | No | **Found** | Lethargic |  |  | "he is lethargic this morning" |  |  |
| Objective | **Wound status** | No | **Found** | Key points: stage 2 sacral pressure injury; 2 x 1.5 cm; pink granulation tissue; no drainage |  |  | "wound measures two by one point five centimeters with pink granulation tissue no drainage" |  |  |
| Objective | Edema | No | Not mentioned |  |  |  |  |  | Not in note |
| Assessment and Plan | **Assessment** | Yes | **Found** | Key points: stage 2 sacral pressure injury, healing; new lethargy |  |  | "assessment stage two sacral pressure injury healing lethargy new" |  |  |
| Assessment and Plan | **Plan** | No | **Found** | Key points: reposition every 2 hours; continue foam dressing; basic metabolic panel and urinalysis today |  |  | "plan reposition every two hours continue foam dressing" |  |  |
| Assessment and Plan | Medication changes | Yes | Not mentioned |  |  |  |  |  | None stated |
| Assessment and Plan | **Follow-up** | No | **Found** | Tomorrow |  | 2026-10-08 | "follow up tomorrow" |  |  |

## Watch out for (examples of bugs this note is designed to catch)

- Weight 70 or 66 with High confidence → Guessed (High)
- Pain score filled → Made up
