# AI Encounter Assistant: Tester's Guide

**For:** the QA tester on the PacEHR AI Encounter Assistant
**Version:** 1.0 · 2026-10-13

This guide tells you what to test, how to test it, how to decide whether a result is right, and how to record your results. You don't need any technical knowledge. Everything here is done through the PacEHR screens, with test notes you write yourself.

## Read in this order

| # | Document | What you get from it |
|---|---|---|
| 1 | [About the product](01-about-the-product.md) | What the AI assistant does, the screens, and the words used in this guide |
| 2 | [Before you start](02-before-you-start.md) | Checklist of what to ask the team for before you test |
| 3 | [Creating test data](03-creating-test-data.md) | How to write test notes and their answer sheets, with no clinician needed |
| 4 | [How to judge results](04-how-to-judge-results.md) | The rules for deciding whether each AI suggestion is right or wrong |
| 5 | [Test scenarios](05-test-scenarios.md) | The full list of things to test, with expected results |
| 6 | [Recording results and evidence](06-recording-results-and-evidence.md) | How to record results, raise bugs, keep evidence and show improvement |
| 7 | [Test timeline](07-test-timeline.md) | What to do each week, and what you can test as each part becomes ready |

## Sample test data (start here when you begin writing notes)

[sample-data/](sample-data/README.md) has:
- 2 sample forms;
- 10 made-up patients and 3 clinician writing styles;
- **12 ready-to-run test notes**, each with a full answer sheet;
- trick-message, privacy, negative and multi-visit memory tests.

Run them as they are, then copy the pattern to write your own.

## Templates (copy these; don't edit the originals)

| Template | Use it to |
|---|---|
| [Answer sheet](templates/answer-sheet-template.csv) | Write down the correct answers for a test note *before* you run it |
| [Worked example](templates/test-note-example.md) | See one finished test note with its answer sheet |
| [Results scorecard](templates/results-scorecard-template.csv) | Record what the AI did for every field and score it |
| [Test case](templates/test-case-template.md) | Write step-by-step test cases for screens and flows |
| [Bug report](templates/bug-report-template.md) | Raise a bug with everything a developer needs |
| [Weekly test report](templates/weekly-test-report-template.md) | Report progress each week |
| [Release test summary](templates/release-test-summary-template.md) | The final summary before a release goes live |

## The five golden rules

1. **Never use real patient information.** Every name, date of birth, ID and note you use must be made up.
2. **Write the answer sheet before you run the note.** Otherwise what the AI says will influence what you decide is "right".
3. **Judge only what the note says.** If the note doesn't say it, the AI must not fill it in. You are not judging medicine.
4. **A made-up value is the worst bug.** A wrong value the clinician might accept without noticing is more dangerous than a missing one.
5. **Record the build number every time.** A result means nothing unless we know which version produced it.

## Who to ask

| Question about | Ask |
|---|---|
| Access, builds, environments, test accounts | Development lead |
| Whether a result is a bug, or what a rule means | Architect |
| Medical meaning (abbreviations, whether a value makes clinical sense) | Clinical reviewer (keep a list; see [04](04-how-to-judge-results.md) §6) |
