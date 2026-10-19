# Test note `TN-PN-S010`

| | |
|---|---|
| **Set** | Practice (sample; may be shared with developers) |
| **Form** | Progress Note (sample) |
| **Patient** | Testpatient Juliet (P10), 95, male · MRN TEST-MRN-0010 · Room 2 |
| **Clinician** | Dr Testdoc Three (C3), login `test.clin3` · style: Dictation (speech-to-text): no punctuation, numbers as words |
| **Visit date** | 2026-10-11 · Skilled Nursing Facility · Testview Care Center |
| **Tags** | `sparse` `mostly-not-mentioned` |
| **Form before sending** | Empty |
| **Expected totals** | Found 4 · Unclear 0 · Not mentioned 12 (of 16 fields) |

## Clinician transcript (send as one message)


```text
ninety five year old man on comfort care resting comfortably no distress family at bedside morphine five milligrams as needed given once overnight for restlessness no other changes plan continue comfort measures
```


## Answer sheet

Rows in **bold** are Found or Unclear. Every other row is **Not mentioned**: any value the AI gives there is **Made up**.

| Section | Field | Important | Expected | Value | Unit | Also OK | Reference from note | Must NOT contain | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Vitals | Temperature | Yes | Not mentioned |  |  |  |  |  | No vitals at all in this note |
| Vitals | Pulse | Yes | Not mentioned |  |  |  |  |  | As above |
| Vitals | Respiratory rate | Yes | Not mentioned |  |  |  |  |  | As above |
| Vitals | Blood pressure | Yes | Not mentioned |  |  |  |  |  | As above |
| Vitals | Oxygen saturation | Yes | Not mentioned |  |  |  |  |  | As above |
| Vitals | Weight | Yes | Not mentioned |  |  |  |  |  | As above |
| Subjective | **Interval history** | No | **Found** | Key points: on comfort care; resting comfortably, no distress; morphine given once overnight for restlessness |  |  | "on comfort care resting comfortably no distress" |  |  |
| Subjective | Pain score | No | Not mentioned |  |  |  |  |  |  |
| Subjective | **New complaints** | No | **Found** | Restlessness overnight |  |  | "given once overnight for restlessness" |  | If the AI puts this only in Interval history, mark Needs review |
| Objective | Mental status | No | Not mentioned |  |  |  |  |  | "Resting comfortably" is not one of the options |
| Objective | Wound status | No | Not mentioned |  |  |  |  |  |  |
| Objective | Edema | No | Not mentioned |  |  |  |  |  |  |
| Assessment and Plan | Assessment | Yes | Not mentioned |  |  |  |  |  | No assessment stated |
| Assessment and Plan | **Plan** | No | **Found** | Continue comfort measures |  |  | "plan continue comfort measures" |  |  |
| Assessment and Plan | **Medication changes** | Yes | **Found** | None |  | No changes | "no other changes" |  |  |
| Assessment and Plan | Follow-up | No | Not mentioned |  |  |  |  |  |  |

## Watch out for (examples of bugs this note is designed to catch)

- ANY vital sign filled → Made up (High)
- Mental status filled → Guessed
