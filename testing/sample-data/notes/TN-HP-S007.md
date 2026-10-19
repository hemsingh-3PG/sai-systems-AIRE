# Test note `TN-HP-S007`

| | |
|---|---|
| **Set** | Practice (sample; may be shared with developers) |
| **Form** | H & P Notes (sample) |
| **Patient** | Testpatient Golf (P07), 59, female · MRN TEST-MRN-0007 · Room 7 |
| **Clinician** | NP Testnurse Two (C2), login `test.clin2` · style: Full sentences, tidy, metric units |
| **Visit date** | 2026-10-08 · Skilled Nursing Facility · Testview Care Center |
| **Tags** | `other-unit` `distractor` `age-group-younger` |
| **Form before sending** | Empty |
| **Expected totals** | Found 19 · Unclear 0 · Not mentioned 8 (of 27 fields) |

## Clinician transcript (send as one message)


```text
59-year-old woman admitted for wound care of a diabetic foot ulcer on the left heel and IV antibiotics. Type 2 diabetes on insulin glargine 30 units at bedtime and lispro sliding scale. Fingerstick glucose this morning 212. Weight 245 lb, height 5 ft 4 in. Temp 100.4 F, HR 102, BP 148/88, RR 18, SpO2 98% RA. No known allergies. Never smoked. Pain in left heel 5/10. Uses a wheelchair while non-weight-bearing on the left foot. Diabetic diet. Full code. Assessment: infected diabetic foot ulcer, left heel, with fever; uncontrolled type 2 diabetes. Plan: IV cefazolin per infectious disease, daily wound care, podiatry consult, adjust insulin. Follow-up in 3 days.
```


## Answer sheet

Rows in **bold** are Found or Unclear. Every other row is **Not mentioned**: any value the AI gives there is **Made up**.

| Section | Field | Important | Expected | Value | Unit | Also OK | Reference from note | Must NOT contain | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Vitals | **Temperature** | Yes | **Found** | 100.4 | °F |  | "Temp 100.4 F" |  |  |
| Vitals | **Pulse** | Yes | **Found** | 102 |  |  | "HR 102" |  |  |
| Vitals | **Respiratory rate** | Yes | **Found** | 18 |  |  | "RR 18" |  |  |
| Vitals | **Blood pressure** | Yes | **Found** | 148/88 |  |  | "BP 148/88" |  |  |
| Vitals | **Oxygen saturation** | Yes | **Found** | 98 |  |  | "SpO2 98% RA" |  |  |
| Vitals | **Weight** | Yes | **Found** | 245 | lb |  | "Weight 245 lb" |  |  |
| Vitals | **Height** | No | **Found** | 64 | in | 5 ft 4 in | "height 5 ft 4 in" |  |  |
| Vitals | **Pain score** | No | **Found** | 5 |  |  | "Pain in left heel 5/10" |  |  |
| Chief Complaint | **Reason for visit** | No | **Found** | Key points: wound care of left heel diabetic foot ulcer; IV antibiotics |  |  | "admitted for wound care of a diabetic foot ulcer on the left heel and IV antibiotics" |  |  |
| Chief Complaint | Onset | No | Not mentioned |  |  |  |  |  |  |
| History | **Past medical history** | Yes | **Found** | Key points: type 2 diabetes |  |  | "Type 2 diabetes on insulin" |  |  |
| History | **Allergies** | Yes | **Found** | No known allergies |  | None; NKA | "No known allergies" |  |  |
| History | **Current medications** | Yes | **Found** | Key points: insulin glargine 30 units at bedtime; insulin lispro sliding scale |  |  | "insulin glargine 30 units at bedtime and lispro sliding scale" | cefazolin | Cefazolin is planned, not a current medication |
| History | **Smoking status** | No | **Found** | Never |  |  | "Never smoked" |  |  |
| History | Family history | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | Chest pain | No | Not mentioned |  |  |  |  |  | Not in note |
| Review of Systems | Shortness of breath | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | Edema | No | Not mentioned |  |  |  |  |  | Not in note |
| Review of Systems | Cough | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | Fall in last 30 days | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | Date of fall | No | Not mentioned |  |  |  |  |  |  |
| Functional Status | **Mobility** | No | **Found** | Wheelchair |  |  | "Uses a wheelchair while non-weight-bearing" |  |  |
| Functional Status | **Diet** | No | **Found** | Diabetic |  |  | "Diabetic diet" |  |  |
| Functional Status | **Code status** | Yes | **Found** | Full code |  |  | "Full code" |  |  |
| Assessment and Plan | **Assessment** | Yes | **Found** | Key points: infected diabetic foot ulcer, left heel, with fever; uncontrolled type 2 diabetes |  |  | "Assessment: infected diabetic foot ulcer" |  |  |
| Assessment and Plan | **Plan** | No | **Found** | Key points: IV cefazolin; daily wound care; podiatry consult; adjust insulin |  |  | "Plan: IV cefazolin per infectious disease" |  |  |
| Assessment and Plan | **Follow-up** | No | **Found** | 3 days |  | 2026-10-11 | "Follow-up in 3 days" |  |  |

## Watch out for (examples of bugs this note is designed to catch)

- "212" (glucose) in any field → Made up (there is no glucose field on this form)
- Weight converted to kg → Wrong unit
