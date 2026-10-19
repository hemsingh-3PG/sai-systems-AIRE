# Test note `TN-HP-S009`

| | |
|---|---|
| **Set** | Practice (sample; may be shared with developers) |
| **Form** | H & P Notes (sample) |
| **Patient** | Testpatient India (P09), 70, female · MRN TEST-MRN-0009 · Room 5 |
| **Clinician** | NP Testnurse Two (C2), login `test.clin2` · style: Full sentences, tidy, metric units |
| **Visit date** | 2026-10-10 · Skilled Nursing Facility · Testview Care Center |
| **Tags** | `other-language` `relative-date` `negative` `planned-not-current` |
| **Form before sending** | Empty |
| **Expected totals** | Found 18 · Unclear 0 · Not mentioned 9 (of 27 fields) |

## Clinician transcript (send as one message)


```text
70-year-old Spanish-speaking woman, history obtained with an interpreter. She reports 'ardor al orinar' (burning on urination) for 2 days and increased frequency. Recurrent UTIs. Hypothyroidism on levothyroxine 75 mcg daily. Allergy: nitrofurantoin (rash). T 38.1 C, P 90, BP 124/70, RR 18, SpO2 97% RA. Walks independently. Full code. Pain 4/10 suprapubic. No chest pain, no cough. Assessment: suspected UTI. Plan: urinalysis and urine culture, start cephalexin after culture sent, encourage fluids. Follow up in 48 hours with culture results.
```


## Answer sheet

Rows in **bold** are Found or Unclear. Every other row is **Not mentioned**: any value the AI gives there is **Made up**.

| Section | Field | Important | Expected | Value | Unit | Also OK | Reference from note | Must NOT contain | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Vitals | **Temperature** | Yes | **Found** | 38.1 | °C |  | "T 38.1 C" |  |  |
| Vitals | **Pulse** | Yes | **Found** | 90 |  |  | "P 90" |  |  |
| Vitals | **Respiratory rate** | Yes | **Found** | 18 |  |  | "RR 18" |  |  |
| Vitals | **Blood pressure** | Yes | **Found** | 124/70 |  |  | "BP 124/70" |  |  |
| Vitals | **Oxygen saturation** | Yes | **Found** | 97 |  |  | "SpO2 97% RA" |  |  |
| Vitals | Weight | Yes | Not mentioned |  |  |  |  |  | Not in note |
| Vitals | Height | No | Not mentioned |  |  |  |  |  | Not in note |
| Vitals | **Pain score** | No | **Found** | 4 |  |  | "Pain 4/10 suprapubic" |  |  |
| Chief Complaint | **Reason for visit** | No | **Found** | Key points: burning on urination for 2 days; increased frequency |  |  | "She reports 'ardor al orinar' (burning on urination) for 2 days" |  |  |
| Chief Complaint | **Onset** | No | **Found** | 2 days |  | 2026-10-08 | "for 2 days" |  |  |
| History | **Past medical history** | Yes | **Found** | Key points: recurrent UTIs; hypothyroidism |  |  | "Recurrent UTIs. Hypothyroidism" |  |  |
| History | **Allergies** | Yes | **Found** | Nitrofurantoin (rash) |  | Nitrofurantoin | "Allergy: nitrofurantoin (rash)" |  |  |
| History | **Current medications** | Yes | **Found** | Key points: levothyroxine 75 mcg daily |  |  | "levothyroxine 75 mcg daily" | cephalexin | Cephalexin is planned, not current |
| History | Smoking status | No | Not mentioned |  |  |  |  |  | Not in note |
| History | Family history | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | **Chest pain** | No | **Found** | No |  |  | "No chest pain" |  |  |
| Review of Systems | Shortness of breath | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | Edema | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | **Cough** | No | **Found** | No |  |  | "no cough" |  |  |
| Review of Systems | Fall in last 30 days | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | Date of fall | No | Not mentioned |  |  |  |  |  |  |
| Functional Status | **Mobility** | No | **Found** | Independent |  |  | "Walks independently" |  |  |
| Functional Status | Diet | No | Not mentioned |  |  |  |  |  |  |
| Functional Status | **Code status** | Yes | **Found** | Full code |  |  | "Full code" |  |  |
| Assessment and Plan | **Assessment** | Yes | **Found** | Key points: suspected UTI |  |  | "Assessment: suspected UTI" |  |  |
| Assessment and Plan | **Plan** | No | **Found** | Key points: urinalysis and urine culture; start cephalexin after culture sent; encourage fluids |  |  | "Plan: urinalysis and urine culture" |  |  |
| Assessment and Plan | **Follow-up** | No | **Found** | 48 hours with culture results |  | 48 hours; 2026-10-12 | "Follow up in 48 hours with culture results" |  |  |

## Watch out for (examples of bugs this note is designed to catch)

- Cephalexin in Current medications → Wrong value (High)
- Reply message in Spanish or the Spanish phrase breaking the reply → Medium
