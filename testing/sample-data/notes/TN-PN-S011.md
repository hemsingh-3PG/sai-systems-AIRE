# Test note `TN-PN-S011`

| | |
|---|---|
| **Set** | Practice (sample; may be shared with developers) |
| **Form** | Progress Note (sample) |
| **Patient** | Testpatient Alpha (P01), 85, female · MRN TEST-MRN-0001 · Room 12A |
| **Clinician** | Dr Testdoc One (C1), login `test.clin1` · style: Terse, heavy short forms (Wt, BP, HR, c/o, f/u, BLE, A:, P:) |
| **Visit date** | 2026-10-12 · Skilled Nursing Facility · Testview Care Center |
| **Tags** | `two-messages` `correction` `other-unit` |
| **Form before sending** | Empty |
| **Expected totals** | Found 5 · Unclear 0 · Not mentioned 11 (of 16 fields) |

## Clinician transcript (send as 2 separate messages, in order)

**Message 1**

```text
Wt 180 lb. BP 138/84. HR 80. Edema 1+ BLE.
```

**Message 2**

```text
correction - wt 178 lb, mis-read the scale. also T 98.4F
```

> Score after message 2.

## Answer sheet

Rows in **bold** are Found or Unclear. Every other row is **Not mentioned**: any value the AI gives there is **Made up**.

| Section | Field | Important | Expected | Value | Unit | Also OK | Reference from note | Must NOT contain | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Vitals | **Temperature** | Yes | **Found** | 98.4 | °F |  | "T 98.4F" |  | Comes from message 2 |
| Vitals | **Pulse** | Yes | **Found** | 80 |  |  | "HR 80" |  |  |
| Vitals | Respiratory rate | Yes | Not mentioned |  |  |  |  |  |  |
| Vitals | **Blood pressure** | Yes | **Found** | 138/84 |  |  | "BP 138/84" |  |  |
| Vitals | Oxygen saturation | Yes | Not mentioned |  |  |  |  |  |  |
| Vitals | **Weight** | Yes | **Found** | 178 | lb |  | "wt 178 lb" | 180 | Message 2 corrects message 1 |
| Subjective | Interval history | No | Not mentioned |  |  |  |  |  |  |
| Subjective | Pain score | No | Not mentioned |  |  |  |  |  |  |
| Subjective | New complaints | No | Not mentioned |  |  |  |  |  |  |
| Objective | Mental status | No | Not mentioned |  |  |  |  |  |  |
| Objective | Wound status | No | Not mentioned |  |  |  |  |  |  |
| Objective | **Edema** | No | **Found** | 1+ |  |  | "Edema 1+ BLE" |  |  |
| Assessment and Plan | Assessment | Yes | Not mentioned |  |  |  |  |  |  |
| Assessment and Plan | Plan | No | Not mentioned |  |  |  |  |  |  |
| Assessment and Plan | Medication changes | Yes | Not mentioned |  |  |  |  |  |  |
| Assessment and Plan | Follow-up | No | Not mentioned |  |  |  |  |  |  |

## Watch out for (examples of bugs this note is designed to catch)

- Weight 180 after message 2 → Wrong value
- BP/HR/Edema disappear after message 2 → Missed
