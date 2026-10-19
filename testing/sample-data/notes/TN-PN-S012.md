# Test note `TN-PN-S012`

| | |
|---|---|
| **Set** | Practice (sample; may be shared with developers) |
| **Form** | Progress Note (sample) |
| **Patient** | Testpatient Delta (P04), 67, male · MRN TEST-MRN-0004 · Room 14B |
| **Clinician** | NP Testnurse Two (C2), login `test.clin2` · style: Full sentences, tidy, metric units |
| **Visit date** | 2026-10-13 · Skilled Nursing Facility · Testview Care Center |
| **Tags** | `already-filled` |
| **Form before sending** | **Blood pressure = 130/80** already filled in |
| **Expected totals** | Found 3 · Unclear 0 · Not mentioned 13 (of 16 fields) |

## Clinician transcript (send as one message)


```text
Blood pressure this afternoon 142/86, pulse 76. Pain 2 out of 10 at the hip.
```


## Answer sheet

Rows in **bold** are Found or Unclear. Every other row is **Not mentioned**: any value the AI gives there is **Made up**.

| Section | Field | Important | Expected | Value | Unit | Also OK | Reference from note | Must NOT contain | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Vitals | Temperature | Yes | Not mentioned |  |  |  |  |  |  |
| Vitals | **Pulse** | Yes | **Found** | 76 |  |  | "pulse 76" |  |  |
| Vitals | Respiratory rate | Yes | Not mentioned |  |  |  |  |  |  |
| Vitals | **Blood pressure** | Yes | **Found** | 142/86 |  |  | "Blood pressure this afternoon 142/86" |  | Form already has 130/80. Must stay 130/80 with 142/86 shown NEXT TO it |
| Vitals | Oxygen saturation | Yes | Not mentioned |  |  |  |  |  |  |
| Vitals | Weight | Yes | Not mentioned |  |  |  |  |  |  |
| Subjective | Interval history | No | Not mentioned |  |  |  |  |  |  |
| Subjective | **Pain score** | No | **Found** | 2 |  |  | "Pain 2 out of 10" |  |  |
| Subjective | New complaints | No | Not mentioned |  |  |  |  |  |  |
| Objective | Mental status | No | Not mentioned |  |  |  |  |  |  |
| Objective | Wound status | No | Not mentioned |  |  |  |  |  |  |
| Objective | Edema | No | Not mentioned |  |  |  |  |  |  |
| Assessment and Plan | Assessment | Yes | Not mentioned |  |  |  |  |  |  |
| Assessment and Plan | Plan | No | Not mentioned |  |  |  |  |  |  |
| Assessment and Plan | Medication changes | Yes | Not mentioned |  |  |  |  |  |  |
| Assessment and Plan | Follow-up | No | Not mentioned |  |  |  |  |  |  |

## Watch out for (examples of bugs this note is designed to catch)

- Blood pressure replaced with 142/86 without the clinician accepting it → Critical
