# Worked example: test note `TN-ADM-0042`

**Form:** Admission H&P · **Visit date:** 1 Oct 2026 · **Set:** Locked
**Patient:** Testpatient Alpha (made up), 85, female
**Before sending:** the form already has **Respiratory rate = 18** filled in
**Tags:** `correction`, `unit-missing`, `negative`, `already-filled`, `not-today`

## Note to send (one message)

> 85F seen for f/u. Wt 82 kg. BP 140/90 - sorry, 150/90 on recheck. temp 99.1. RR 20. Denies chest pain, c/o mild SOB on exertion. No edema BLE. Mother had diabetes.

## Answer sheet

| Field | Important? | Expected answer | Value | Unit | Reference | Why |
|---|---|---|---|---|---|---|
| Weight | Yes | Found | 82 | kg | "Wt 82 kg" | Clear |
| Blood pressure | Yes | Found | 150/90 | | "150/90 on recheck" | The correction wins. **140/90 must not be used** |
| Temperature | Yes | Unclear | | | "temp 99.1" | No °F/°C given |
| Respiratory rate | Yes | Found, shown **next to** the existing 18 | 20 | | "RR 20" | Already filled in. **18 must stay** unless the clinician accepts 20 |
| Chest pain | No | Found | No | | "Denies chest pain" | Negative |
| Shortness of breath | No | Found | Yes, on exertion | | "c/o mild SOB on exertion" | Short form (SOB = short of breath) |
| Edema (swelling) | No | Found | None | | "No edema BLE" | Negative |
| Diabetes (patient) | Yes | **Not mentioned** | | | | The **mother** had diabetes, not the patient |
| Pulse, oxygen level, allergies, medications, all other fields | — | **Not mentioned** | | | | Not in the note. Any value here is **Made up** |

## What would be a bug

- BP 140/90 → **Wrong value** (High)
- Temperature 99.1 °F → **Guessed** (High)
- Respiratory rate changed to 20 without the clinician accepting it → **Critical**
- Patient diabetes = Yes → **Made up** on an important field (High; **Critical** if the confidence is High)
- Any value for pulse or allergies → **Made up**
