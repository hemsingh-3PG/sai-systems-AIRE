# Negative test inputs (scenario section L)

Ready-to-use inputs for the negative tests in [05 §L](../05-test-scenarios.md). They use the made-up patients and forms in this folder.

**In every test the system must:**
- not crash;
- save nothing the clinician didn't accept;
- never put data on the wrong patient or field;
- show a clear, polite message.

Items marked **(confirm rule)** don't have a decided expected result yet. Record what happens and ask the architect.

---

## Bad or meaningless notes (L1)

Use **Testpatient Bravo (P02)**, Progress Note, clinician C2. The form starts empty each time.

| ID | Paste exactly | Expected |
|---|---|---|
| NEG-S001 | `... ??? 👍👍` | Polite message; **no cards** |
| NEG-S002 | `asdfgh qwerty zxcv lorem ipsum` | **No cards**; no made-up values |
| NEG-S003 | `What's the weather like today? Any good films on?` | Polite reply; **no cards** |
| NEG-S004 | `82 150 90 99 20 18` | **No values filled.** Numbers with no labels mean nothing; at most Unclear |
| NEG-S005 | `WT 64 KG. BP 128/76. HR 96. DENIES CHEST PAIN.` | Weight 64 kg, BP 128/76, pulse 96, same as lower case |
| NEG-S006 | `<b>BP 128/76</b> <script>alert('test')</script> <img src=x>` | Shown as plain text; **no pop-up**, nothing odd on screen; BP 128/76 |
| NEG-S007 | A two-column table pasted from a spreadsheet: `Weight \t 64 kg` / `Pulse \t 96` | Weight 64 kg, pulse 96; or a clear message |
| NEG-S008 | `Testpatient Golf: BP 148/88, pulse 102` **(sent on Bravo's encounter)** | **Not silently filled into Bravo's form.** Flagged or Unclear **(confirm rule)** |

## Impossible or badly written values (L2)

Use **Testpatient Alpha (P01)**, H & P Notes, clinician C1. Send each line as a separate test on a fresh encounter.

| ID | Paste exactly | Field | Expected |
|---|---|---|---|
| NEG-S010 | `Pulse 400` | Pulse | **Never High confidence**; Unclear or a warning **(confirm rule)** |
| NEG-S011 | `Temp 150 F` | Temperature | As above |
| NEG-S012 | `SpO2 120%` | Oxygen saturation | As above |
| NEG-S013 | `Weight -5 kg` | Weight | As above |
| NEG-S014 | `BP 300/20` | Blood pressure | As above |
| NEG-S015 | `BP 90/150` | Blood pressure | As above (bottom number higher than top) |
| NEG-S016 | `BP 150` | Blood pressure | **Unclear**; never guessed as 150/something |
| NEG-S017 | `Weight 82 kgs lbs` | Weight | **Unclear** (two units) |
| NEG-S018 | `Mobility: crutches` | Mobility | **Unclear**; no invented option ("Crutches") and no different option ("Walker") |
| NEG-S019 | `Fell next Tuesday` (visit date 2026-10-01) | Fall / Date of fall | Not filled as a fall date; Unclear |
| NEG-S020 | `Pain 15/10` | Pain score | Unclear or a warning **(confirm rule)** |
| NEG-S021 | `Smoking: sometimes` | Smoking status | **Unclear**; not forced into "Current" with High confidence |

## Wrong actions on the cards (L3)

Send [TN-HP-S002](notes/TN-HP-S002.md) on **Testpatient Bravo (P02)**, then try each action on the card named.

| ID | Card | Do this | Expected |
|---|---|---|---|
| NEG-S030 | Weight (64 kg) | **Alter** to empty, then save | Clear message, **or** treated as Reject **(confirm rule)**. Never a silently blank field |
| NEG-S031 | Pulse (96) | **Alter** to `abc` | Not saved; clear message |
| NEG-S032 | Smoking status (Former) | **Alter** to `Sometimes` | Not possible, or not saved; only real options allowed |
| NEG-S033 | Plan | **Alter** to 5,000 characters (paste any long made-up text) | Limit message; nothing breaks |
| NEG-S034 | Blood pressure (128/76) | Double-click **Accept** very fast | Saved once; one decision |
| NEG-S035 | Temperature (37.2 °C) | **Accept**, then press **Reject** | The form matches the last decision; no mixed state **(confirm rule)** |
| NEG-S036 | Any | Make 3 decisions, then close the browser without saving; reopen | Nothing shows as saved that wasn't saved |
| NEG-S037 | Height (175 cm) | **Reject** the value, then **Reject** the reference | Field stays empty; no error |

## Wrong timing or state (L4)

| ID | Set-up | Do this | Expected |
|---|---|---|---|
| NEG-S040 | Bravo's encounter (P02) | Send [TN-HP-S002](notes/TN-HP-S002.md), then **immediately open Golf's (P07) encounter** before the reply arrives | Bravo's reply **never** appears on Golf's screen. Check Golf's form is unchanged |
| NEG-S041 | Any encounter | Send a note and **refresh** while the AI is replying | No duplicate reply; you can send again |
| NEG-S042 | Any encounter | Mid-flow, press the browser **Back** button, then return | No values lost or duplicated |
| NEG-S043 | Alpha's encounter open in **two tabs** | Accept Weight in tab 1; reject Weight in tab 2 | No silent overwrite; after a refresh both tabs agree |
| NEG-S044 | Two testers, same encounter | Both make decisions on the same card | No silent overwrite of each other's decisions |
| NEG-S045 | Chat panel open | **Sign** the encounter in another tab, then press Accept in the first tab | Not allowed; clear message |
| NEG-S046 | Chat panel open | Another user **deletes** the encounter; you press Accept | Clear message; nothing saved |
| NEG-S047 | Decisions made, not saved | Wait until the login session expires (ask devs for a short time-out in the test environment) | Asked to log in again; no half-saved values |
| NEG-S048 | AI replied on H & P Notes | Change the encounter's form to Progress Note, then look at the cards | Old suggestions are not applied to the wrong fields |
| NEG-S049 | Any encounter | Send `BP 120/80` 20 times as fast as you can | No crash. All handled, or a polite "slow down" message |

## Wrong user (L5)

| ID | Log in as | Do this | Expected |
|---|---|---|---|
| NEG-S050 | A **read-only** user | Open Alpha's encounter | Can't send; no Accept / Alter / Reject |
| NEG-S051 | **Second test account** user | Paste Alpha's encounter link | Refused |
| NEG-S052 | User in an account with AI **switched off** | Open an encounter that already had AI cards | No AI actions; form values unaffected |

## System problems (L6): the development team must simulate these

| ID | Ask devs to | Then | Expected |
|---|---|---|---|
| NEG-S060 | Stop the AI service | Send any note | "Try again later"; the form still works without AI |
| NEG-S061 | Make the AI return an empty or broken response | Send any note | "Something went wrong, please try again"; no cards; nothing saved |
| NEG-S062 | Make saving fail | Accept a value | Clear error; the card is **not** marked as accepted; the field doesn't show the value as saved |
| NEG-S063 | Slow the AI to over 30 seconds | Send any note | Loading indicator, then a timeout message; no reply appears later out of nowhere |
