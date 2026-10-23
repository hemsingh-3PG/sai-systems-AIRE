# Coding Answer Key: Review Sheet for a Coder

**For:** a certified coder or clinician who will confirm the expected codes for the AI eval
**From:** Hem Singh · **Date:** 2026-10-22 · **Status:** DRAFT, written by the developer, not yet reviewed
**What this is for:** the AI suggests ICD-10-CM and CPT codes from a clinician's note. We test it on five fixed,
synthetic notes. This sheet lists the codes we expect for each note. Once you confirm them, they become the answer
key the AI is scored against.

**How to review:**
- For each note, read the note text (linked below), then mark each code ✔ (correct), ✘ (wrong) or ✎ (change, with
  the right code).
- Add any code we missed.
- **Required** means the AI should suggest it. **Acceptable** means suggesting it isn't counted as wrong, but it isn't
  required either.
- An entry like `I50.*` means "any code starting I50.".
- Please judge from the note alone, not from what any AI produced. No AI output has been seen yet.

**Context for every note:**
- **Coding guideline:** the visits are professional services, so the outpatient guidelines apply. Uncertain
  diagnoses ("probable", "suspected", "rule out") aren't coded; the symptoms are.
- **Instructions in the note:** if a note says not to add ICD or billing codes, the AI must suggest none of that
  kind. A code the note states itself is still expected.
- **Setting:** since 2026-10-22 the eval runs as a **skilled nursing facility** (place of service "SNF", POS 31), with
  date of service **2026-10-08**, matching notes Q2–Q4. Visit codes are still only **acceptable**: please say which
  nursing-facility level each note supports, so they can become **required**.
- **Modifiers and units** are out of scope.

The notes live in `pacEHR_AI/tests/eval/queries/q1.txt` to `q5.txt`.

---

## Q1: Follow-up of CHF and diabetes (plain typed paragraph)

| Type | Code(s) | Meaning | Why | ✔ / ✘ / ✎ |
|---|---|---|---|---|
| ICD, required | `I50.*` (expect `I50.9`) | Heart failure (type not stated) | "follow up of CHF"; plan adjusts furosemide | |
| ICD, required | `E11.9` or `E11.65` | Type 2 diabetes, without complications / with hyperglycemia | "diabetes" on metformin, type not stated, so it defaults to type 2. Sugars 140s–190s: is `E11.65` supportable without the word "hyperglycemia"? | |
| ICD, acceptable | `E87.5` | Hyperkalemia | Potassium 5.3; lisinopril held "given potassium" | |
| ICD, acceptable | `R94.4`, `R79.89` | Abnormal kidney function study / other abnormal blood chemistry | Creatinine 1.4, up from 1.1; no diagnosis stated | |
| ICD, acceptable | `Z79.84` | Long-term use of oral hypoglycemic | Metformin | |
| CPT, acceptable | `99307`–`99310`, `99347`–`99350` | Subsequent nursing facility care / home or residence visit, established patient | Follow-up visit; which family depends on the setting | |

## Q2: Regulatory visit after a fall (note with instructions)

| Type | Code(s) | Meaning | Why | ✔ / ✘ / ✎ |
|---|---|---|---|---|
| ICD | **none** | | The note says "Do not add any ICD-10 codes to this note" | |
| CPT, required | `99309` | Subsequent nursing facility care | The note states "CPT code: 99309" | |

## Q3: 60-day telehealth follow-up (facility template)

| Type | Code(s) | Why | ✔ / ✘ / ✎ |
|---|---|---|---|
| ICD | **none** | The note says "Do not enter billing or diagnosis codes" | |
| CPT | **none** | Same instruction | |

## Q4: New admission history and physical (voice dictation)

| Type | Code(s) | Meaning | Why | ✔ / ✘ / ✎ |
|---|---|---|---|---|
| ICD, required | `I50.33` | Acute on chronic diastolic heart failure | Stated in HPI and A&P | |
| ICD, required | `I48.*` (expect `I48.91`) | Atrial fibrillation | "atrial fibrillation rate controlled" on apixaban | |
| ICD, required | `E11.22` | Type 2 diabetes with diabetic CKD | Type 2 diabetes and CKD stage 3 both documented; the guideline presumes the link ("with") | |
| ICD, required | `N18.30`, `N18.31`, `N18.32` | CKD stage 3 (unspecified, 3a, 3b) | "CKD stage 3", sub-stage not stated, so expect `N18.30` | |
| ICD, required | `R53.81` | Other malaise (debility) | "debility PT OT evaluate and treat" | |
| ICD, acceptable | `E11.9` | Type 2 diabetes without complications | Accepted, but `E11.22` is the expected code: is `E11.9` actually wrong here? | |
| ICD, acceptable | `J18.9`, `Z87.01`, `Z09` | Pneumonia / history of pneumonia / follow-up after completed treatment | Antibiotics completed; still monitoring temperature and O2. Which is right for the facility admission? | |
| ICD, acceptable | `R09.02`, `Z99.81` | Hypoxemia / dependence on supplemental oxygen | Sat 93% on 2 L, weaning | |
| ICD, acceptable | `Z79.4`, `Z79.01` | Long-term insulin / anticoagulant | Lantus; apixaban | |
| ICD, acceptable | `N40.0`, `M17.0` | BPH / bilateral primary osteoarthritis of knee | Past medical history only | |
| ICD, acceptable | `Z96.651`, `Z88.0`, `Z87.891` | Right knee replacement / penicillin allergy / former smoker | History | |
| CPT, acceptable | `99304`–`99306`, `99344`, `99345` | Initial nursing facility care / home or residence visit, new patient | Admission H&P; 55 minutes total. Which family and level? | |
| CPT, acceptable | `99497` | Advance care planning, first 30 minutes | ACP discussed; time for ACP itself not stated | |

## Q5: One-line follow-up command

| Type | Code(s) | Why | ✔ / ✘ / ✎ |
|---|---|---|---|
| ICD | **none** | The only diagnosis is "probable viral gastroenteritis". An uncertain diagnosis isn't coded, and no symptom is documented | |
| CPT | **none** | A command to edit a note, with no visit documented | |

---

## Questions for you

1. **Visit level:** for Q1 (follow-up), Q2 (99309 stated) and Q4 (admission, 55 minutes), which nursing-facility
   code and level is right?
2. **Q1:** does "blood sugars running 140s to 190s" support `E11.65`, or only `E11.9`?
3. **Q4:** with type 2 diabetes and CKD stage 3 both documented, is `E11.9` wrong (so it should be removed from
   "acceptable")?
4. **Q4:** after completed treatment for pneumonia, on admission to the facility: `J18.9`, `Z09`, `Z87.01`, or none?
5. **Anything missing:** any code a coder would always expect from these notes that isn't listed?

**After the review:** your answers go into `tests/eval/cases.json`, and each reviewed case changes to
`"status": "CONFIRMED"`. Coding is scored on every eval run, but it only starts to pass or fail runs once all five
cases are confirmed.
