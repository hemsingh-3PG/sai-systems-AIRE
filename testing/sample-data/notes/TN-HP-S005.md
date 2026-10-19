# Test note `TN-HP-S005`

| | |
|---|---|
| **Set** | Practice (sample; may be shared with developers) |
| **Form** | H & P Notes (sample) |
| **Patient** | Testpatient Echo (P05), 74, female · MRN TEST-MRN-0005 · Room 3 |
| **Clinician** | NP Testnurse Two (C2), login `test.clin2` · style: Full sentences, tidy, metric units |
| **Visit date** | 2026-10-06 · Skilled Nursing Facility · Testview Care Center |
| **Tags** | `multi-choice` `negative` `decimal` |
| **Form before sending** | Empty |
| **Expected totals** | Found 18 · Unclear 0 · Not mentioned 9 (of 27 fields) |

## Clinician transcript (send as one message)


```text
74-year-old woman admitted for rehabilitation after a stroke with left-sided weakness. She has atrial fibrillation and takes apixaban 5 mg twice daily. Speech therapy recommends thickened liquids and a pureed diet. Allergic to codeine (nausea). Vitals: T 98.2 F, HR 78 irregular, BP 136/82, RR 18, SpO2 97% on room air. Weight 58.5 kg. She uses a wheelchair. Full code. She denies pain. No cough. Assessment: stroke with left-sided weakness and swallowing difficulty; atrial fibrillation, rate controlled. Plan: physical, occupational and speech therapy 5 times a week, continue apixaban, aspiration precautions. Follow-up in 1 week.
```


## Answer sheet

Rows in **bold** are Found or Unclear. Every other row is **Not mentioned**: any value the AI gives there is **Made up**.

| Section | Field | Important | Expected | Value | Unit | Also OK | Reference from note | Must NOT contain | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Vitals | **Temperature** | Yes | **Found** | 98.2 | °F |  | "T 98.2 F" |  |  |
| Vitals | **Pulse** | Yes | **Found** | 78 |  |  | "HR 78 irregular" |  |  |
| Vitals | **Respiratory rate** | Yes | **Found** | 18 |  |  | "RR 18" |  |  |
| Vitals | **Blood pressure** | Yes | **Found** | 136/82 |  |  | "BP 136/82" |  |  |
| Vitals | **Oxygen saturation** | Yes | **Found** | 97 |  |  | "SpO2 97% on room air" |  |  |
| Vitals | **Weight** | Yes | **Found** | 58.5 | kg |  | "Weight 58.5 kg" |  | 58 or 59 → Wrong value |
| Vitals | Height | No | Not mentioned |  |  |  |  |  |  |
| Vitals | **Pain score** | No | **Found** | 0 |  |  | "She denies pain" |  | If the AI says Not mentioned, mark Needs review (clinical question: does "denies pain" = 0?) |
| Chief Complaint | **Reason for visit** | No | **Found** | Key points: rehabilitation after stroke with left-sided weakness |  |  | "admitted for rehabilitation after a stroke with left-sided weakness" |  |  |
| Chief Complaint | Onset | No | Not mentioned |  |  |  |  |  |  |
| History | **Past medical history** | Yes | **Found** | Key points: stroke; atrial fibrillation |  |  | "She has atrial fibrillation" |  |  |
| History | **Allergies** | Yes | **Found** | Codeine (nausea) |  | Codeine | "Allergic to codeine (nausea)" |  |  |
| History | **Current medications** | Yes | **Found** | Key points: apixaban 5 mg twice daily |  |  | "takes apixaban 5 mg twice daily" |  |  |
| History | Smoking status | No | Not mentioned |  |  |  |  |  |  |
| History | Family history | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | Chest pain | No | Not mentioned |  |  |  |  |  | Not in note |
| Review of Systems | Shortness of breath | No | Not mentioned |  |  |  |  |  | Not in note |
| Review of Systems | Edema | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | **Cough** | No | **Found** | No |  |  | "No cough" |  |  |
| Review of Systems | Fall in last 30 days | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | Date of fall | No | Not mentioned |  |  |  |  |  |  |
| Functional Status | **Mobility** | No | **Found** | Wheelchair |  |  | "She uses a wheelchair" |  |  |
| Functional Status | **Diet** | No | **Found** | Pureed, Thickened liquids |  |  | "thickened liquids and a pureed diet" |  | Both options; order does not matter |
| Functional Status | **Code status** | Yes | **Found** | Full code |  |  | "Full code" |  |  |
| Assessment and Plan | **Assessment** | Yes | **Found** | Key points: stroke with left-sided weakness and swallowing difficulty; atrial fibrillation, rate controlled |  |  | "Assessment: stroke with left-sided weakness" |  |  |
| Assessment and Plan | **Plan** | No | **Found** | Key points: PT/OT/speech therapy 5 times a week; continue apixaban; aspiration precautions |  |  | "Plan: physical, occupational and speech therapy 5 times a week" |  |  |
| Assessment and Plan | **Follow-up** | No | **Found** | 1 week |  | 2026-10-13 | "Follow-up in 1 week" |  |  |

## Watch out for (examples of bugs this note is designed to catch)

- Diet with only one of the two options → Wrong value
- Weight 58 kg → Wrong value
