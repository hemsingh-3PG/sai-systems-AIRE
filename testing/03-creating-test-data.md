# 3 · Creating test data (no clinician needed)

We have no ready-made set of "correct answers", so you will create one. The trick is to **decide the answers first, then write the note**. Because you wrote the note to say exactly those things, you already know what the AI should find. No medical knowledge is needed.

**See it done first:** [sample-data/](sample-data/README.md) has 12 finished notes with answer sheets, plus made-up patients and clinician styles to reuse.

## Step by step

1. **Pick a form** (one of the pilot forms) and open its field list.
2. **Fill in the answer sheet** ([template](templates/answer-sheet-template.csv)). For each field, decide one of three things:
   - **Found:** write the value and unit, e.g. Weight = 82 kg.
   - **Unclear:** decide what will make it unclear, e.g. temperature with no unit.
   - **Not mentioned:** leave it out of the note.

   **Mix them on purpose.** Roughly half Found, a third Not mentioned, and the rest Unclear. The "Not mentioned" fields are how we catch made-up values, so don't skip them.
3. **Write the note** so it states exactly the Found values and the Unclear items, and nothing else about the form's fields. Write it the way a busy clinician would; see "Make it realistic" below.
4. **Copy the exact words** that support each Found value into the answer sheet's "Reference" column. This is the reference you expect the AI to show.
5. **Check it:** re-read the note against the answer sheet. Every Found value must be in the note. Nothing else must be in the note that matches a field.
6. **Give it an ID and tag it** with the tricky things it contains (see the list below).
7. **Save the note and its answer sheet together** ([06](06-recording-results-and-evidence.md) §5).

Faster option: the development team can turn your answer sheets into notes for you. You then do step 5, the check.

## Make it realistic

Real notes are messy. Use these styles across your notes:

- **Short forms:** "Wt", "BP", "HR", "RR", "SOB" (short of breath), "c/o" (complains of), "f/u" (follow-up), "pt" (patient)
- **No full sentences:** "85F seen for f/u. Wt 82 kg. BP 150/90."
- **Typos and dictation slips:** "blood pressure one fifty over ninety", missing punctuation
- **Information in a jumbled order**
- **Short notes** (2 lines) and **long notes** (a full page)

Ask the clinical reviewer to read a few of your notes and tell you whether they look like real notes.

## Tricky things to include (and how to tag them)

Every note should contain 1–3 of these. They are where the AI is most likely to go wrong.

| Tag | What to write | What the answer sheet says |
|---|---|---|
| `unit-missing` | "temp 99.1" | Temperature: **Unclear** |
| `other-unit` | "wt 180 lb" (form normally uses kg) | Weight: **180 lb**. Never converted to kg |
| `negative` | "Denies chest pain", "no swelling" | Chest pain: **No** (or the form's "No" option) |
| `correction` | "BP 140/90 – sorry, 150/90" | BP: **150/90**. 140/90 must not be used |
| `conflict` | "weight 82 kg … weight 79 kg" with no explanation | Weight: **Unclear** |
| `relative-date` | "fell yesterday" (visit date 1 Oct 2026) | Fall date: **30 Sep 2026** |
| `not-today` | "vitals as per yesterday", "mother has diabetes" | Today's vitals / patient's diabetes: **Not mentioned** |
| `distractor` | A number that belongs to no field, e.g. "room 12" | No field gets "12" |
| `dropdown` | A value that matches a dropdown option in different words, e.g. "mild" for option "Mild" | Exactly the option |
| `multi-choice` | Several options in any order | All the options, in the form's order |
| `already-filled` | A value for a field that already has a value on the form | AI shows its suggestion **next to** the existing value; the existing value is **not** changed |
| `two-messages` | Send a value in message 1 and a correction in message 2 | The corrected value |
| `long` | A very long note | Still correct; or a clear "too long" message |

## How many notes

| By when | Notes | Purpose |
|---|---|---|
| End of week 2 | 30 on the first pilot form | First full run |
| End of week 4 | 100 across the pilot forms | Main test set |
| Before each release | Add notes for every bug found | So fixed bugs stay fixed |

**Split your notes into two sets:**
- **Practice set (about 40%).** You may share these with developers to help them fix problems.
- **Locked set (about 60%).** **Never share these with the developers and never change them.** You use them only to score each build. That way, improvements in the score are real, not just the AI being tuned to your exact notes.

## IDs

- Form-based notes: `TN-<form short name>-<number>`, e.g. `TN-ADM-0042`
- Trick-message notes: `TN-TRICK-<number>`
- Memory (multi-visit) notes: `TN-MEM-<patient>-<visit number>`

## Never

- Never copy a real note, even with names removed.
- Never use a real person's name, birth date, phone number, address or ID number.
- When you need a name, make it obviously fake: "Testpatient Alpha", "Dr Testdoc".
