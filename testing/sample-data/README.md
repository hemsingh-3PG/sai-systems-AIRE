# Sample test data

Ready-to-use examples that show the format. Run them as they are, and **copy the pattern** to write your own.

> **Everything here is made up.** The patients, clinicians, facility, phone numbers and notes are all invented. No real patient data is used.

> **The two forms here are samples.** They are realistic, but they are not the real pilot forms. When the team gives you the real field lists ([02](../02-before-you-start.md)), rename the fields in your notes and answer sheets to match exactly.

> **Everything here is the Practice set.** Developers can see this folder. Write your **Locked set** yourself and keep it in the restricted shared folder ([03](../03-creating-test-data.md)).

## What's in this folder

| File | What it is |
|---|---|
| [forms/H-and-P-Notes-sample-fields.csv](forms/H-and-P-Notes-sample-fields.csv) | Sample admission form: 27 fields, with types, dropdown options, units and important fields |
| [forms/Progress-Note-sample-fields.csv](forms/Progress-Note-sample-fields.csv) | Sample progress note form: 16 fields |
| [patients.csv](patients.csv) | 10 made-up nursing-home patients (P01–P10): age, sex, conditions, allergies, medications, code status, mobility, usual weight |
| [clinicians.csv](clinicians.csv) | 3 made-up clinicians with **different writing styles** (terse, full sentences, dictation) and 1 scribe |
| [notes/](notes/) | **12 accuracy test notes.** Each has the patient, clinician, visit date, what's already on the form, the exact transcript to send, a **full answer sheet for every field**, and the bugs it is designed to catch |
| [answer-sheets.csv](answer-sheets.csv) | All 12 answer sheets in one spreadsheet (258 rows), ready to copy into your scorecard |
| [trick-notes.md](trick-notes.md) | 9 trick-message tests (F1–F8) |
| [privacy-tests.md](privacy-tests.md) | 4 privacy tests (G1–G4, A6) |
| [negative-tests.md](negative-tests.md) | About 45 negative tests (section L): bad notes, impossible values, wrong button use, wrong timing, wrong user, system problems |
| [memory-journey.md](memory-journey.md) | One patient over 4 visits, plus clinician-habit tests (H1–H9, F4) |

## The 12 accuracy notes

| Note | Form | Patient | Clinician style | What it tests |
|---|---|---|---|---|
| [TN-HP-S001](notes/TN-HP-S001.md) | H & P | Alpha, 85 F | Terse | Correction, missing temperature unit, lb, negative, field already filled, family vs patient history |
| [TN-HP-S002](notes/TN-HP-S002.md) | H & P | Bravo, 78 M | Full sentences | Metric units, "no known allergies", an unclear dropdown choice, a number that is a target not a reading |
| [TN-HP-S003](notes/TN-HP-S003.md) | H & P | Charlie, 92 F | Dictation | Numbers as words, "yesterday" → a date, fall fields |
| [TN-PN-S004](notes/TN-PN-S004.md) | Progress | Delta, 67 M | Terse | "See yesterday's vitals" (= Not mentioned), room number trap, a field already filled, medication change |
| [TN-HP-S005](notes/TN-HP-S005.md) | H & P | Echo, 74 F | Full sentences | Multi-choice diet, decimals, "denies pain" |
| [TN-PN-S006](notes/TN-PN-S006.md) | Progress | Foxtrot, 88 M | Dictation | Two different weights (→ Unclear), wound description, "tomorrow" |
| [TN-HP-S007](notes/TN-HP-S007.md) | H & P | Golf, 59 F | Full sentences | lb and feet/inches, glucose number trap, planned vs current medicine, younger patient |
| [TN-PN-S008](notes/TN-PN-S008.md) | Progress | Hotel, 81 M | Terse | Heavy short forms, "Parkinson's" must not be treated as a name, which medicine actually changed |
| [TN-HP-S009](notes/TN-HP-S009.md) | H & P | India, 70 F | Full sentences | Spanish phrase, planned medicine not current |
| [TN-PN-S010](notes/TN-PN-S010.md) | Progress | Juliet, 95 M | Dictation | Very short note: 12 of 16 fields must be Not mentioned |
| [TN-PN-S011](notes/TN-PN-S011.md) | Progress | Alpha, 85 F | Terse | Two messages; the second corrects the first |
| [TN-PN-S012](notes/TN-PN-S012.md) | Progress | Delta, 67 M | Full sentences | Field already filled must not be replaced |

## How to run a sample note

1. In the test environment, open (or ask for) an **unsigned encounter** on the right form for the patient named in the note. Log in as the clinician named in the note.
2. If the note says **"Form before sending"** has a value, type that value into the form first and save.
3. Click **AI Encounter** and paste the transcript **exactly**. If there are several messages, send them one at a time, in order.
4. Copy that note's rows from [answer-sheets.csv](answer-sheets.csv) into your scorecard. Fill in what the AI did and score each row ([04](../04-how-to-judge-results.md)).
5. Do **not** accept or sign unless the scenario says to. Then the encounter can be re-used.

## How to write your own (copy this pattern)

1. Pick a patient from [patients.csv](patients.csv), or add one. Always use obviously fake names: "Testpatient …".
2. Pick a clinician style from [clinicians.csv](clinicians.csv), and write in that style.
3. **Fill in the answer sheet first.** For each field, decide Found (with value), Unclear (and what makes it unclear) or Not mentioned. Aim for roughly half Found.
4. Write the transcript so it says exactly that and no more. Include 1–3 tricky things from [03](../03-creating-test-data.md).
5. Copy the exact reference (the words from the note) for each Found or Unclear field into the answer sheet.
6. Add a "Watch out for" list: which mistakes this note is meant to catch.
7. **Use the patient profile only for ideas.** The answer sheet follows the **note**, not the profile. In S001, for example, the profile says the patient has diabetes, but the note doesn't, so Past medical history must **not** contain diabetes.

## Free-text fields (Assessment, Plan, Reason for visit, …)

Their expected value is written as **"Key points: a; b; c"**. Score **Correct** when every key point is there (any wording is fine) and nothing is added that the note doesn't say. Missing a key point is **Missed**; adding something not in the note is **Made up**.
