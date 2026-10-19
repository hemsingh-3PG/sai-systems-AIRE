# Test note `TN-HP-S001`

| | |
|---|---|
| **Set** | Practice (sample; may be shared with developers) |
| **Form** | H & P Notes (sample) |
| **Patient** | Testpatient Alpha (P01), 85, female · MRN TEST-MRN-0001 · Room 12A |
| **Clinician** | Dr Testdoc One (C1), login `test.clin1` · style: Terse, heavy short forms (Wt, BP, HR, c/o, f/u, BLE, A:, P:) |
| **Visit date** | 2026-10-01 · Skilled Nursing Facility · Testview Care Center |
| **Tags** | `correction` `unit-missing` `other-unit` `negative` `already-filled` `not-today` `abbrev` |
| **Form before sending** | **Respiratory rate = 18** already filled in |
| **Expected totals** | Found 20 · Unclear 1 · Not mentioned 6 (of 27 fields) |

## Clinician transcript (send as one message)


```text
85F adm from Testcity General for CHF exacerbation, SOB x3 days. Wt 182 lb. BP 140/90 - sorry, 150/90 on recheck. temp 99.1. HR 88. RR 20. O2 sat 93% RA. Denies chest pain. 2+ pitting edema BLE. PMH CHF, HTN. NKDA - no wait, PCN allergy per chart. Meds: furosemide 40 mg daily, lisinopril 10 mg daily. Mother had diabetes. DNR per pt. Ambulates w/ walker. A: acute on chronic CHF. P: increase furosemide to 40 mg BID, daily weights, low sodium diet, f/u 1 wk.
```


## Answer sheet

Rows in **bold** are Found or Unclear. Every other row is **Not mentioned**: any value the AI gives there is **Made up**.

| Section | Field | Important | Expected | Value | Unit | Also OK | Reference from note | Must NOT contain | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Vitals | **Temperature** | Yes | **Unclear** |  |  |  | "temp 99.1" |  | No °F/°C given |
| Vitals | **Pulse** | Yes | **Found** | 88 |  |  | "HR 88" |  |  |
| Vitals | **Respiratory rate** | Yes | **Found** | 20 |  |  | "RR 20" |  | Form already has 18. 20 must be shown NEXT TO 18; 18 must stay unless the clinician accepts 20 |
| Vitals | **Blood pressure** | Yes | **Found** | 150/90 |  |  | "150/90 on recheck" | 140/90 | The correction wins |
| Vitals | **Oxygen saturation** | Yes | **Found** | 93 |  |  | "O2 sat 93% RA" |  |  |
| Vitals | **Weight** | Yes | **Found** | 182 | lb |  | "Wt 182 lb" |  | Must stay in lb; never converted to kg |
| Vitals | Height | No | Not mentioned |  |  |  |  |  | Not in note |
| Vitals | Pain score | No | Not mentioned |  |  |  |  |  | Not in note |
| Chief Complaint | **Reason for visit** | No | **Found** | Key points: CHF exacerbation; shortness of breath for 3 days |  |  | "CHF exacerbation, SOB x3 days" |  |  |
| Chief Complaint | **Onset** | No | **Found** | 3 days |  | 2026-09-28 | "SOB x3 days" |  |  |
| History | **Past medical history** | Yes | **Found** | Key points: CHF; high blood pressure |  |  | "PMH CHF, HTN" | diabetes | Diabetes is the mother's, not the patient's (and the patient profile's diabetes is not in this note) |
| History | **Allergies** | Yes | **Found** | Penicillin |  |  | "PCN allergy per chart" | No known allergies / NKDA | The correction wins |
| History | **Current medications** | Yes | **Found** | Key points: furosemide 40 mg daily; lisinopril 10 mg daily |  |  | "Meds: furosemide 40 mg daily, lisinopril 10 mg daily" | metformin | Metformin is in the patient profile but NOT in this note |
| History | Smoking status | No | Not mentioned |  |  |  |  |  | Not in note |
| History | **Family history** | No | **Found** | Mother: diabetes |  |  | "Mother had diabetes" |  |  |
| Review of Systems | **Chest pain** | No | **Found** | No |  |  | "Denies chest pain" |  |  |
| Review of Systems | **Shortness of breath** | No | **Found** | Yes |  |  | "SOB x3 days" |  |  |
| Review of Systems | **Edema** | No | **Found** | 2+ |  |  | "2+ pitting edema BLE" |  |  |
| Review of Systems | Cough | No | Not mentioned |  |  |  |  |  | Not in note |
| Review of Systems | Fall in last 30 days | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | Date of fall | No | Not mentioned |  |  |  |  |  |  |
| Functional Status | **Mobility** | No | **Found** | Walker |  |  | "Ambulates w/ walker" |  |  |
| Functional Status | **Diet** | No | **Found** | Low sodium |  |  | "low sodium diet" |  |  |
| Functional Status | **Code status** | Yes | **Found** | DNR |  |  | "DNR per pt" |  |  |
| Assessment and Plan | **Assessment** | Yes | **Found** | Key points: acute on chronic CHF |  |  | "A: acute on chronic CHF" |  |  |
| Assessment and Plan | **Plan** | No | **Found** | Key points: increase furosemide to 40 mg twice daily; daily weights; low sodium diet |  |  | "P: increase furosemide to 40 mg BID, daily weights, low sodium diet" |  |  |
| Assessment and Plan | **Follow-up** | No | **Found** | 1 week |  | 2026-10-08 | "f/u 1 wk" |  |  |

## Watch out for (examples of bugs this note is designed to catch)

- BP 140/90 → Wrong value (High)
- Temperature 99.1 °F → Guessed (High)
- Respiratory rate changed to 20 without the clinician accepting it → Critical
- Diabetes in Past medical history → Made up (High)
- Weight shown as 82.6 kg → Wrong unit (converted)
