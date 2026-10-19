# Privacy test data (scenarios G1–G4, A6)

These tests check that a patient's information stays with that patient and that personal details come back correctly. Any failure here is **Critical**.

---

## PRIV-S001 · A unique fact must never travel to another patient (G1, H8)

The trick is to plant a fact so unusual that, if it ever appears somewhere else, it can only have leaked.

| Step | Patient | Form | Clinician | Send | Then |
|---|---|---|---|---|---|
| 1 | Testpatient Echo (P05) | H & P Notes | C2 | `Her pet parrot is named Zorbo and she misses him. BP 130/80, pulse 74.` | Accept BP and pulse. **Sign** the encounter, so it goes into Echo's memory |
| 2 | Testpatient Foxtrot (P06) | Progress Note | **C2 (same clinician)** | `Resting in bed, BP 120/70, pulse 66. Asks about lunch.` | Read every card, remark and the reply message |
| 3 | Testpatient Echo (P05) | Progress Note | C2 | `BP 128/78. In good spirits.` | Zorbo *may* be mentioned here, because it's the same patient |
| 4 | Testpatient Foxtrot (P06) | Progress Note | C2 | Repeat step 2 **a week later** | Read everything again |

**Pass:** "Zorbo" and "parrot" **never** appear for Foxtrot, in step 2 or step 4.

---

## PRIV-S002 · Names and numbers come back as written (G2)

**Patient:** Testpatient Alpha (P01) · **Form:** Progress Note · **Clinician:** C2

```text
Daughter Testdaughter Alpha (phone 555-0142) visited today and reports her mother is eating better. Patient states "I feel stronger." BP 132/78.
```

(555-0100 to 555-0199 are reserved made-up phone numbers.)

**Expected:**
- Blood pressure: 132/78.
- Interval history may mention the daughter's visit and the better appetite.
- Wherever a name or the phone number appears (cards, remarks, reply), it shows **exactly as typed**.

**High if:** you see codes such as `[NAME_1]`, `<PERSON>` or `[PHONE_1]`, or a name you didn't type.

---

## PRIV-S003 · Two testers at the same moment (G4)

Two testers, on two computers, press **Send** at the same time:

- tester 1 sends [TN-HP-S002](notes/TN-HP-S002.md) on Testpatient Bravo;
- tester 2 sends [TN-HP-S007](notes/TN-HP-S007.md) on Testpatient Golf.

**Pass:** each tester sees only their own patient's values. Bravo's screen never shows 245 lb or insulin; Golf's never shows COPD or 64 kg.

---

## PRIV-S004 · Another practice's patient (A6)

1. Log in as the **second test account** user.
2. Paste the browser address of Testpatient Alpha's encounter (copied from the first account).

**Pass:** access is refused, there is no AI panel, and no data from Alpha is shown.
