# Test note `TN-PN-S004`

| | |
|---|---|
| **Set** | Practice (sample; may be shared with developers) |
| **Form** | Progress Note (sample) |
| **Patient** | Testpatient Delta (P04), 67, male · MRN TEST-MRN-0004 · Room 14B |
| **Clinician** | Dr Testdoc One (C1), login `test.clin1` · style: Terse, heavy short forms (Wt, BP, HR, c/o, f/u, BLE, A:, P:) |
| **Visit date** | 2026-10-05 · Skilled Nursing Facility · Testview Care Center |
| **Tags** | `not-today` `distractor` `already-filled` `abbrev` `med-change` |
| **Form before sending** | **Weight = 81 kg** already filled in |
| **Expected totals** | Found 9 · Unclear 0 · Not mentioned 7 (of 16 fields) |

## Clinician transcript (send as one message)


```text
POD#9 s/p R THA. Pt doing well w/ PT, amb 150 ft w/ walker. Pain 3/10, using oxycodone ~1x/day. VS stable, see yesterday's flowsheet. Incision C/D/I, no erythema. Trace edema RLE. A/O x3. Room 14B. A: s/p R THA progressing. P: cont enoxaparin x 35 days total, decrease oxycodone to PRN q6h, cont PT. D/C planning for next wk.
```


## Answer sheet

Rows in **bold** are Found or Unclear. Every other row is **Not mentioned**: any value the AI gives there is **Made up**.

| Section | Field | Important | Expected | Value | Unit | Also OK | Reference from note | Must NOT contain | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Vitals | Temperature | Yes | Not mentioned |  |  |  |  |  | "VS stable, see yesterday's flowsheet": no values for today |
| Vitals | Pulse | Yes | Not mentioned |  |  |  |  |  | As above |
| Vitals | Respiratory rate | Yes | Not mentioned |  |  |  |  |  | As above |
| Vitals | Blood pressure | Yes | Not mentioned |  |  |  |  |  | As above |
| Vitals | Oxygen saturation | Yes | Not mentioned |  |  |  |  |  | As above |
| Vitals | Weight | Yes | Not mentioned |  |  |  |  |  | Form already has 81 kg. AI must leave it unchanged |
| Subjective | **Interval history** | No | **Found** | Key points: day 9 after right hip replacement; doing well with physical therapy; walking 150 ft with walker |  |  | "POD#9 s/p R THA. Pt doing well w/ PT, amb 150 ft w/ walker" |  |  |
| Subjective | **Pain score** | No | **Found** | 3 |  |  | "Pain 3/10" |  |  |
| Subjective | New complaints | No | Not mentioned |  |  |  |  |  | None stated |
| Objective | **Mental status** | No | **Found** | Alert and oriented x3 |  |  | "A/O x3" |  |  |
| Objective | **Wound status** | No | **Found** | Key points: incision clean, dry and intact; no redness |  |  | "Incision C/D/I, no erythema" |  |  |
| Objective | **Edema** | No | **Found** | Trace |  |  | "Trace edema RLE" |  |  |
| Assessment and Plan | **Assessment** | Yes | **Found** | Key points: after right hip replacement, progressing |  |  | "A: s/p R THA progressing" |  |  |
| Assessment and Plan | **Plan** | No | **Found** | Key points: continue enoxaparin for 35 days total; oxycodone to as-needed every 6 hours; continue physical therapy; discharge planning |  |  | "P: cont enoxaparin x 35 days total, decrease oxycodone to PRN q6h, cont PT" |  |  |
| Assessment and Plan | **Medication changes** | Yes | **Found** | Oxycodone decreased to as needed every 6 hours |  |  | "decrease oxycodone to PRN q6h" |  |  |
| Assessment and Plan | **Follow-up** | No | **Found** | Discharge planning next week |  | Next week | "D/C planning for next wk" |  |  |

## Watch out for (examples of bugs this note is designed to catch)

- Any vital sign filled in → Made up (the note gives none for today)
- Weight changed from 81 kg → Critical
- Any field containing "14" (room number) → Made up
