# 7 · Test timeline

The AI assistant is being built in stages, so you can start preparing **now**, well before there is anything to click. The dates follow the development plan and can move. Check with the development lead each week.

| Period | What's ready to test | What you do | Done when |
|---|---|---|---|
| **Week 0** · 14–20 Oct | Nothing yet | Read this guide. Get access ([02](02-before-you-start.md)). Get the pilot form field lists. Set up the shared folders and the Test Plans suites | Checklist in [02](02-before-you-start.md) mostly ticked |
| **Weeks 1–2** · 21 Oct–3 Nov | Nothing yet | Write **30 test notes with answer sheets** for pilot form 1 ([03](03-creating-test-data.md)). Write test cases for scenarios A, B and E ([05](05-test-scenarios.md)). Write your first 15 trick notes (F) | 30 notes checked; test cases in Test Plans |
| **Weeks 3–4** · 4–17 Nov | **Screens with sample answers**: the chat panel and cards, showing fixed example replies rather than the real AI | Test the screens: card layout, Accept / Alter / Reject for values, Accept / Reject for references, saving, ease of use (B, K), and wrong button use (negative tests L3). Grow the notes to 60 across pilot forms 1–2 | Screen bugs raised; 60 notes ready |
| **Weeks 5–6** · 18 Nov–1 Dec | **First real AI** in the test environment, arriving towards the end of this period (about 1 Dec) | Until it arrives: finish trick notes and the privacy test set-up (G). As soon as it arrives: first full run of the **locked set**. That **first scorecard is the starting point (baseline)**. Run A, B, D, E, F, G, I and the negative tests L1, L2, L4–L6. Raise bugs | Baseline scorecard and first weekly report with numbers |
| **Weeks 7–8** · 2–15 Dec | AI with **memory** (patient and clinician summaries); speed testing possible | Memory scenarios H1–H10 (ask devs to preload visits). Speed tests J. Re-score each new build. Grow to 100 notes. Send the **clinical questions list** to the clinical reviewer, and have them review 50 of your results | Memory and speed results; reviewer feedback received; targets confirmed by the architect |
| **Weeks 9–10** · 16–29 Dec | **Release candidate** | Full run of every P1 scenario plus the locked set. Re-test all fixed bugs. Fill in the **[release test summary](templates/release-test-summary-template.md)** | Summary signed; go / no-go decision |
| **From Jan 2027** | Pilot with a few real clinicians | Re-score every new build on the locked set. Weekly report with the trend table. Turn every problem reported by pilot users into a new test note. Full regression before each release | Ongoing |

## Every week

- Score any new build on the locked set.
- Re-test fixed bugs.
- Send the **[weekly test report](templates/weekly-test-report-template.md)** (Friday).
- Add at least 5 new notes covering whatever went wrong that week.

## Before every release

- Every **P1** scenario passed, including the P1 negative tests (section L)
- Locked-set targets met ([04](04-how-to-judge-results.md) §5)
- **Zero** open Critical bugs; any open High bugs agreed with the product owner
- Release test summary completed and signed
