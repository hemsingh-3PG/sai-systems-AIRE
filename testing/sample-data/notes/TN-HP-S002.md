# Test note `TN-HP-S002`

| | |
|---|---|
| **Set** | Practice (sample; may be shared with developers) |
| **Form** | H & P Notes (sample) |
| **Patient** | Testpatient Bravo (P02), 78, male · MRN TEST-MRN-0002 · Room 15B |
| **Clinician** | NP Testnurse Two (C2), login `test.clin2` · style: Full sentences, tidy, metric units |
| **Visit date** | 2026-10-02 · Skilled Nursing Facility · Testview Care Center |
| **Tags** | `full-sentences` `negative` `unclear-option` `metric` |
| **Form before sending** | Empty |
| **Expected totals** | Found 20 · Unclear 1 · Not mentioned 6 (of 27 fields) |

## Clinician transcript (send as one message)


```text
Mr. Testpatient Bravo is a 78-year-old man admitted for rehabilitation after a COPD exacerbation. He reports a mild cough, mostly in the mornings, and shortness of breath when walking to the bathroom. He has no chest pain. Temperature 37.2 °C, pulse 96, respiratory rate 22, blood pressure 128/76, oxygen saturation 90% on 2 L nasal cannula. Weight 64 kg, height 175 cm. He quit smoking 10 years ago after 40 pack-years. No known drug allergies. Current medications are a tiotropium inhaler once daily and an albuterol inhaler as needed. He uses a wheelchair for longer distances but can walk short distances. He wishes to be full code. Pain 2 out of 10 in his lower back. Assessment: COPD exacerbation, improving. Plan: continue inhalers, wean oxygen to keep saturation above 88%, physical therapy daily. Follow up in 2 weeks.
```


## Answer sheet

Rows in **bold** are Found or Unclear. Every other row is **Not mentioned**: any value the AI gives there is **Made up**.

| Section | Field | Important | Expected | Value | Unit | Also OK | Reference from note | Must NOT contain | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Vitals | **Temperature** | Yes | **Found** | 37.2 | °C |  | "Temperature 37.2 °C" |  |  |
| Vitals | **Pulse** | Yes | **Found** | 96 |  |  | "pulse 96" |  |  |
| Vitals | **Respiratory rate** | Yes | **Found** | 22 |  |  | "respiratory rate 22" |  |  |
| Vitals | **Blood pressure** | Yes | **Found** | 128/76 |  |  | "blood pressure 128/76" |  |  |
| Vitals | **Oxygen saturation** | Yes | **Found** | 90 |  |  | "oxygen saturation 90% on 2 L nasal cannula" | 88 | 88% is a target in the plan, not a reading |
| Vitals | **Weight** | Yes | **Found** | 64 | kg |  | "Weight 64 kg" |  |  |
| Vitals | **Height** | No | **Found** | 175 | cm |  | "height 175 cm" |  |  |
| Vitals | **Pain score** | No | **Found** | 2 |  |  | "Pain 2 out of 10" |  |  |
| Chief Complaint | **Reason for visit** | No | **Found** | Key points: rehabilitation after COPD exacerbation |  |  | "admitted for rehabilitation after a COPD exacerbation" |  |  |
| Chief Complaint | Onset | No | Not mentioned |  |  |  |  |  |  |
| History | **Past medical history** | Yes | **Found** | Key points: COPD |  |  | "COPD exacerbation" |  |  |
| History | **Allergies** | Yes | **Found** | No known drug allergies |  | None; NKDA | "No known drug allergies" |  |  |
| History | **Current medications** | Yes | **Found** | Key points: tiotropium inhaler once daily; albuterol inhaler as needed |  |  | "tiotropium inhaler once daily and an albuterol inhaler as needed" |  |  |
| History | **Smoking status** | No | **Found** | Former |  |  | "He quit smoking 10 years ago" |  |  |
| History | Family history | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | **Chest pain** | No | **Found** | No |  |  | "He has no chest pain" |  |  |
| Review of Systems | **Shortness of breath** | No | **Found** | On exertion |  |  | "shortness of breath when walking to the bathroom" |  |  |
| Review of Systems | Edema | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | **Cough** | No | **Found** | Yes |  |  | "He reports a mild cough" |  |  |
| Review of Systems | Fall in last 30 days | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | Date of fall | No | Not mentioned |  |  |  |  |  |  |
| Functional Status | **Mobility** | No | **Unclear** |  |  |  | "uses a wheelchair for longer distances but can walk short distances" |  | Two options fit (Wheelchair / Independent). Flagging as Unclear is correct; picking one with High confidence is Guessed |
| Functional Status | Diet | No | Not mentioned |  |  |  |  |  |  |
| Functional Status | **Code status** | Yes | **Found** | Full code |  |  | "He wishes to be full code" |  |  |
| Assessment and Plan | **Assessment** | Yes | **Found** | Key points: COPD exacerbation, improving |  |  | "Assessment: COPD exacerbation, improving" |  |  |
| Assessment and Plan | **Plan** | No | **Found** | Key points: continue inhalers; wean oxygen to keep saturation above 88%; physical therapy daily |  |  | "Plan: continue inhalers, wean oxygen" |  |  |
| Assessment and Plan | **Follow-up** | No | **Found** | 2 weeks |  | 2026-10-16 | "Follow up in 2 weeks" |  |  |

## Watch out for (examples of bugs this note is designed to catch)

- Oxygen saturation 88 → Wrong value
- Mobility = Wheelchair with High confidence → Guessed
- Allergies left as Not mentioned → Missed (the note does say "No known drug allergies")
