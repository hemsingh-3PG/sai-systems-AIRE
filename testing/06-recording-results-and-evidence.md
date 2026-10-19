# 6 · Recording results and evidence

## 1. For every test session, write down

- Date, and your name or initials
- **Build number**
- Which form(s) you tested
- Which set you used: practice or locked
- Anything unusual, e.g. the system was slow that day, or a known issue

## 2. Scorecard (accuracy tests)

Use the [scorecard template](templates/results-scorecard-template.csv). Use **one row per field per note**, including fields that should be Not mentioned.

| Column | What to put |
|---|---|
| Build | Build number |
| Test note ID | e.g. `TN-ADM-0042` |
| Set | Practice / Locked |
| Form | Form name |
| Field | Field name |
| Important field? | Yes / No |
| Expected answer | Found / Not mentioned / Unclear |
| Expected value, Expected unit | From your answer sheet |
| AI answer | Found / Not mentioned / Unclear |
| AI value, AI unit | As shown on the card |
| AI confidence | High / Medium / Low |
| Reference correct? | Yes / No / n/a (does the reference pass the check in [04](04-how-to-judge-results.md) §3?) |
| Result | Correct / Wrong value / Wrong unit / Missed / Made up / Guessed / Too cautious / Missed the doubt / Needs review |
| Reply time (s) | For the note's message |
| Bug ID | If you raised one |
| Notes | Anything else |

Then work out the measures in [04](04-how-to-judge-results.md) §5 using spreadsheet counts. In Excel, use COUNTIFS on the Result column. Ask the architect if you want a ready-made summary tab.

## 3. Test cases and step results

- Write scenario-based tests (sections A, B, D–K in [05](05-test-scenarios.md)) as **test cases in Azure DevOps Test Plans**, using the [test case template](templates/test-case-template.md).
- Group them into suites: Access · Basic flow · Conversation · Already-filled · Trick messages · Privacy · Memory · Errors · Speed · Ease of use · Negative · Accuracy.
- For each run, mark every step Pass, Fail or Blocked, and attach the evidence.

## 4. Evidence: what to keep

| Kind | When | How |
|---|---|---|
| **Screenshot** | Every failed step; one per passed P1 test case | Name it `<TestID>_<step>_<build>_<date>.png`, e.g. `B3_step2_b1842_2026-12-03.png` |
| **Screen recording** | Any bug that is hard to describe | Short clip (under 1 minute) |
| **Scorecard** | Every accuracy run | Save as `Scorecard_<build>_<date>.xlsx` |
| **Reply times** | Speed tests | In the scorecard or test case |
| **Clinical questions list** | Ongoing | One shared sheet |

**Only made-up test data may appear in evidence.** If you ever see what looks like real patient information, **stop**, don't screenshot it, and tell the development lead straight away.

## 5. Where to keep things

| What | Where |
|---|---|
| Test notes and answer sheets | Team shared folder → `AI Testing / Test notes / <Practice or Locked> / <Form>`. Restrict the **Locked** folder to testers only |
| Scorecards | Shared folder → `AI Testing / Scorecards` |
| Test cases and run results | Azure DevOps Test Plans |
| Screenshots and recordings | Attached to the test run or bug in Azure DevOps |
| Bugs | Azure DevOps bug board, using the [bug template](templates/bug-report-template.md) |
| Weekly reports | Shared folder → `AI Testing / Weekly reports` |
| Release summaries | Shared folder → `AI Testing / Releases`, plus a copy on the team wiki |

## 6. Raising a bug

Use the [bug template](templates/bug-report-template.md). Always include:

1. Build number
2. Test note ID or test case ID
3. Exact note text you sent (made-up data only)
4. What you expected (from your answer sheet)
5. What happened
6. Severity ([04](04-how-to-judge-results.md) §4)
7. Screenshot

After a bug is fixed, re-test it on the new build. The note that found it stays in your set permanently, so it can't quietly come back.

## 7. Showing that the system is improving

This is how you show progress to the team and management:

1. **Use the same locked set for every build.** Don't change it during a release cycle.
2. **Score every new build** on the locked set and save its scorecard.
3. **Keep a trend table** in the weekly report:

   | Build | Date | Suggestions correct | Values found | Made-up values | Unclear caught | Avg reply time |
   |---|---|---|---|---|---|---|
   | b1790 | 01 Dec | 91% | 80% | 4 | 55% | 7.1 s |
   | b1842 | 08 Dec | 95% | 86% | 1 | 68% | 5.4 s |

   (The numbers above are only examples.)

4. Add a simple **line chart** of each measure across builds.
5. **Compare like with like.** Only compare builds scored on the same locked set. When you add new notes, start a new trend line and say so in the report.
6. Note **which bugs were fixed** between builds. That explains why the numbers changed.
