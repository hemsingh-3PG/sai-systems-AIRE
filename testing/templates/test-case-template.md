# Test case template

> Copy this into Azure DevOps Test Plans. Use made-up data only.

| | |
|---|---|
| **Test ID** | e.g. `D3` (from [05](../05-test-scenarios.md)); add `-01`, `-02` for variations |
| **Title** | e.g. Accepted value is kept when a different value is sent later |
| **Suite** | Access / Basic flow / Accuracy / Conversation / Already-filled / Trick messages / Privacy / Memory / Errors / Speed / Ease of use / Negative |
| **Priority** | P1 / P2 |
| **What could go wrong if this fails** | e.g. The clinician's chosen value is lost |

## Before you start (preconditions)
- Logged in as: e.g. Test clinician 1
- Patient / encounter: e.g. Testpatient Alpha, unsigned Admission H&P
- Form state: e.g. Weight empty

## Steps

| # | Do this | You should see |
|---|---|---|
| 1 | Click **AI Encounter** | Chat panel opens |
| 2 | Send "Wt 82 kg" | Weight card: 82 kg, reference "Wt 82 kg", with Accept / Alter / Reject for the value and Accept / Reject for the reference |
| 3 | Accept the Weight value and accept its reference | Weight field shows 82 kg; reference shows as accepted |
| 4 | Send "wt 79 kg" | Weight still 82 kg in the form; 79 kg shown next to it as a suggestion |

## Result
| | |
|---|---|
| Build number | |
| Date / tester | |
| Result | Pass / Fail / Blocked |
| Evidence | Screenshot names |
| Bug ID | |
| Notes | |
