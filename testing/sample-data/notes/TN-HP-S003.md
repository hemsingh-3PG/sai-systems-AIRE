# Test note `TN-HP-S003`

| | |
|---|---|
| **Set** | Practice (sample; may be shared with developers) |
| **Form** | H & P Notes (sample) |
| **Patient** | Testpatient Charlie (P03), 92, female · MRN TEST-MRN-0003 · Room 9 |
| **Clinician** | Dr Testdoc Three (C3), login `test.clin3` · style: Dictation (speech-to-text): no punctuation, numbers as words |
| **Visit date** | 2026-10-03 · Skilled Nursing Facility · Testview Care Center |
| **Tags** | `dictation` `relative-date` `numbers-as-words` |
| **Form before sending** | Empty |
| **Expected totals** | Found 18 · Unclear 0 · Not mentioned 9 (of 27 fields) |

## Clinician transcript (send as one message)


```text
patient is a ninety two year old female with dementia seen today after a fall yesterday evening in her room no head strike per staff she was found sitting on the floor temperature ninety eight point six fahrenheit pulse seventy two blood pressure one thirty two over seventy eight respirations sixteen oxygen ninety six percent room air she complains of right hip pain six out of ten x ray of the right hip ordered allergic to sulfa she is on donepezil ten milligrams at night and alendronate weekly she is DNR DNI uses a walker she is pleasant but confused assessment fall with right hip pain rule out fracture plan x ray right hip today neuro checks every four hours for twenty four hours fall precautions follow up after x ray result
```


## Answer sheet

Rows in **bold** are Found or Unclear. Every other row is **Not mentioned**: any value the AI gives there is **Made up**.

| Section | Field | Important | Expected | Value | Unit | Also OK | Reference from note | Must NOT contain | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Vitals | **Temperature** | Yes | **Found** | 98.6 | °F |  | "temperature ninety eight point six fahrenheit" |  |  |
| Vitals | **Pulse** | Yes | **Found** | 72 |  |  | "pulse seventy two" |  |  |
| Vitals | **Respiratory rate** | Yes | **Found** | 16 |  |  | "respirations sixteen" |  |  |
| Vitals | **Blood pressure** | Yes | **Found** | 132/78 |  |  | "blood pressure one thirty two over seventy eight" |  |  |
| Vitals | **Oxygen saturation** | Yes | **Found** | 96 |  |  | "oxygen ninety six percent room air" |  |  |
| Vitals | Weight | Yes | Not mentioned |  |  |  |  |  | Not in note |
| Vitals | Height | No | Not mentioned |  |  |  |  |  |  |
| Vitals | **Pain score** | No | **Found** | 6 |  |  | "right hip pain six out of ten" |  |  |
| Chief Complaint | **Reason for visit** | No | **Found** | Key points: fall yesterday evening; right hip pain |  |  | "seen today after a fall yesterday evening" |  |  |
| Chief Complaint | **Onset** | No | **Found** | Yesterday evening |  | 2026-10-02 | "a fall yesterday evening" |  |  |
| History | **Past medical history** | Yes | **Found** | Key points: dementia |  |  | "female with dementia" | osteoporosis | Osteoporosis is in the patient profile but not in this note |
| History | **Allergies** | Yes | **Found** | Sulfa |  |  | "allergic to sulfa" |  |  |
| History | **Current medications** | Yes | **Found** | Key points: donepezil 10 mg at night; alendronate weekly |  |  | "donepezil ten milligrams at night and alendronate weekly" |  |  |
| History | Smoking status | No | Not mentioned |  |  |  |  |  |  |
| History | Family history | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | Chest pain | No | Not mentioned |  |  |  |  |  | Not in note |
| Review of Systems | Shortness of breath | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | Edema | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | Cough | No | Not mentioned |  |  |  |  |  |  |
| Review of Systems | **Fall in last 30 days** | No | **Found** | Yes |  |  | "a fall yesterday evening" |  |  |
| Review of Systems | **Date of fall** | No | **Found** | 2026-10-02 |  |  | "a fall yesterday evening" |  | Visit date 3 Oct → "yesterday" = 2 Oct 2026 |
| Functional Status | **Mobility** | No | **Found** | Walker |  |  | "uses a walker" |  |  |
| Functional Status | Diet | No | Not mentioned |  |  |  |  |  |  |
| Functional Status | **Code status** | Yes | **Found** | DNR/DNI |  |  | "she is DNR DNI" |  |  |
| Assessment and Plan | **Assessment** | Yes | **Found** | Key points: fall with right hip pain; rule out fracture |  |  | "assessment fall with right hip pain rule out fracture" |  |  |
| Assessment and Plan | **Plan** | No | **Found** | Key points: x-ray right hip today; neuro checks every 4 hours for 24 hours; fall precautions |  |  | "plan x ray right hip today neuro checks every four hours" |  |  |
| Assessment and Plan | **Follow-up** | No | **Found** | After x-ray result |  |  | "follow up after x ray result" |  |  |

## Watch out for (examples of bugs this note is designed to catch)

- Date of fall = 2026-10-03 (visit date) → Wrong value
- BP written as 132/7 or 13/278 → Wrong value
- Osteoporosis added to history → Made up
