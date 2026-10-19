# 2 · Before you start

Use this as a checklist. Ask the development lead for anything you don't have yet.

## Access

- [ ] Login to the **test environment** (QA) where the AI assistant is switched on
- [ ] A **clinician** test login
- [ ] A **scribe** (non-clinician) test login
- [ ] A login for a **second test account** (a different practice), for privacy checks
- [ ] A login for an account where the AI assistant is **switched off**
- [ ] Access to **Azure DevOps Test Plans** (for test cases and results) and to the team's **bug board**
- [ ] A shared folder for screenshots and scorecards

## Test data in the system

- [ ] At least **10 made-up test patients** (names like "Testpatient Alpha"), including a mix of age groups and sexes
- [ ] Open (unsigned) encounters for those patients on the **pilot forms**
- [ ] One **signed** encounter and one **deleted** encounter, to check the AI is not offered there
- [ ] One encounter where some fields are **already filled in**, to check nothing is overwritten

## Information about the forms

- [ ] The names of the **2–3 pilot forms** the AI will be tested on first
- [ ] For each pilot form, the **list of sections and fields**. For each field, its type (number, text, date, dropdown, multi-choice, tick box) and the options for dropdowns. Ask for a spreadsheet export
- [ ] The expected **unit** for each number field (e.g. Weight: kg or lb; Temperature: °F or °C)
- [ ] The list of **important fields** (see [01](01-about-the-product.md))

## For every test session

- [ ] The **build number** you are testing. Ask the team where it is shown, or get it from the release note
- [ ] The **release note** for the build: what changed and what is new
- [ ] Known issues, so you don't raise duplicates

## People

- [ ] Who to ask about rules (architect)
- [ ] Who the **clinical reviewer** is, and when they are available (see [04](04-how-to-judge-results.md) §6)

## Ready to test when

- You can log in, open a test encounter and see the **AI Encounter** button.
- You have at least 5 test notes with answer sheets ready ([03](03-creating-test-data.md)).
- You have a blank scorecard and know where to save evidence ([06](06-recording-results-and-evidence.md)).
