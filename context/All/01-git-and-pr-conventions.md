# Raising a PR on PacEHR (UI and API) — branch, sync, description, checklist gate

Last verified: 2026-10-19. Source: 3Pillar's PR guide (supplied by the lead, 2026-10-19), cross-checked against `pacEHR_API/CLAUDE.md` and each repo's `pipelines/`.

The same process applies to the UI and API repos.

| Repo | Target branch |
|---|---|
| UI (`PacEHR`) | `PacEHR-DevelopUI-Main` |
| API (`pacEHR_API`) | `PacEHR-DevelopAPI-Main` |
| AI (`PacEHR_AI`) | `PacEHR-AI-Develop-Main` — **not covered by the 3Pillar guide.** Branch and commit format below apply by analogy; the checklist gate does not exist in that repo (its pipelines are `pr-validation.yml` and the image build only). Confirm with the lead. |

> **Two sources, one difference.** `pacEHR_API/CLAUDE.md` (a client-side file we do not edit) shows `PAC-835-slug` / `PAC-835 add …` / `PAC-835 | release | …`. 3Pillar's guide, which the team follows, uses the formats below, and the `3p-dev/` prefix was agreed with the Sai Systems team. **Follow this file.** Both sources agree on the one thing that matters: the **literal Jira key** goes in the branch, every commit and the PR title — Jira's Development panel matches only the literal key and fails silently otherwise.

---

## 1. Branch name

```
3p-dev/<JIRA ID>-<short-title-slug>
```

Example: `3p-dev/AITP-35-guided-workflow-feature-flag`

- Always start from a Jira ticket. **Never invent an ID.**
- Short lowercase slug, not the full Jira title (those can be 80+ characters and contain `/`).
- The `3p-dev/` prefix was agreed with the Sai Systems team so our work is easy to find and trace to Jira.

**First push fails with `TF401027: You need the Git 'CreateBranch' permission`?** Your account cannot create branches yet. Ask the client admin for the permission. Do not work around it with a different prefix.

---

## 2. Before you raise the PR

### 2.1 Bring in the latest Develop
The client team **merges** Develop into feature branches (they don't rebase), so we do the same.

```bash
git fetch origin --prune
git merge --no-edit origin/PacEHR-DevelopUI-Main      # API: origin/PacEHR-DevelopAPI-Main
```

`--no-edit` accepts the default merge message. Without it Git opens an editor (usually vim): press `Esc`, type `:wq`, press `Enter`.

To see what is new on Develop first, and whether it touches your files:

```bash
git log --oneline HEAD..origin/PacEHR-DevelopUI-Main
git diff --name-only $(git merge-base HEAD origin/PacEHR-DevelopUI-Main) origin/PacEHR-DevelopUI-Main
```

### 2.2 Build and test
UI: `npx ng build`. API: build `pacEHR.sln` and run `PacEHR.Tests.UnitTests`. AI: `npm test` (plus `npm run eval` when agent behaviour changed — the pre-push hook enforces it).

**UI unit tests:** the full suite **does not compile on Develop** (a type error in a client spec: `add-edit-patient.component.spec.ts:72`, missing `msg`). Once patched, about **353 client tests already fail on Develop**. So:
- Do **not** fix client specs in your PR — they belong to the client team.
- Run your own specs, or run the full suite on a scratch copy of Develop and on your branch and compare the **lists of failing test names**. Identical lists = no regression from your change.

### 2.3 Don't commit these
- **`package-lock.json` changes for `bootstrap-icons`.** Develop lists `bootstrap-icons` in `package.json` but not in the lock file; the client team owns that fix. Install it locally without saving:
  ```bash
  npm install --no-save --legacy-peer-deps bootstrap-icons@1.13.1
  ```
- **Local `environment.ts` edits**, such as pointing your machine at QA.
- `.env.local`, anything from `sai-systems-AIRE` — run `sai-systems-AIRE/tools/guard.sh` before you push.

### 2.4 Commits
- Jira key in every commit message: `<JIRA ID> : <description>` — e.g. `AITP-35 : Guided Workflow flag: models and feature service`.
- One concern per PR. Release scripts, feature code and documentation are separate PRs.

---

## 3. Creating the PR

### Title
```
<JIRA ID> : <JIRA Title>
```
Example: `AITP-35 : Introduce Feature Flag / Account based flag for Guided Encounter Workflow`

- A space on both sides of the colon. The full Jira title is fine here.
- Add ` | Fix Version Date (27 Sept 2026)` **only when your lead asks** for a specific release.

### Description
Paste the checklist **already ticked** when you create the PR (section 4 explains why). Use this shape — it is also `dev-stories/_templates/ticket/05-pr.md`:

```markdown
## Summary
What this PR does and why, in two or three sentences.

Jira: AITP-35

## Changes
- models and feature service
- admin toggles on account and user settings
- ...

## Testing
Build passes. 66 new specs pass. Full suite compared with Develop: no new failures.

## Notes
DB script: not applicable (UI only).

## PR Checklist
- [X] Unit test cases
- [X] DB script
- [X] Technical documentation
- [X] AI usage
```

---

## 4. The checklist gate — read this, it is strict (UI and API repos)

Every PR in both repos runs `pipelines/pr-checklist-validation.yml`, which runs two scripts:
1. **`add-pr-checklist.ps1`** — if the description has no `PR Checklist`, it appends an **unticked** one.
2. **`validate-pr-checklist.ps1`** — fails the PR unless the checklist is exactly right.

| Rule | What fails |
|---|---|
| All four items present with this exact text | Rewording, or text added to a line, e.g. `- [X] DB script (N/A)` |
| All four ticked | Any `[ ]` left |
| **Exactly 4 checkbox lines in the whole description** | Any other checkbox anywhere, e.g. your own `- [x] Build passes` |

In practice:
- **No other checkboxes** in the description. Write testing notes as plain text.
- **Avoid `[` followed by a space anywhere**, even in code like `arr[ 0 ]` — the script counts any line containing `[ ` as a checkbox.
- **There is no N/A option.** Tick the item and explain in **Notes**, e.g. "DB script: not applicable (UI only)". Never change the checklist line itself.
- `[X]` and `[x]` both work (PowerShell's `-contains` is case-insensitive).
- If you let the pipeline add the checklist, the first run fails because the boxes are unticked. Tick them and re-run the check from the PR page. Whether editing the description re-runs it automatically is not confirmed — pasting the ticked checklist up front avoids the problem.

---

## 5. What else runs on your PR

| Pipeline | What it does | Blocks the PR? |
|---|---|---|
| `pr-checklist-validation.yml` | Section 4 | Fails the check if the checklist is wrong |
| `ai-pr-review.yml` | Sends the diff to Azure OpenAI and posts **one** review comment thread; skips if it already posted, so later pushes are not re-reviewed | No — it is a comment |
| `deploy-pacehrui.yml` / `deploy-pacehrapis.yml` | Deploys only from `release/dev`, `qa`, `uat`, `production`, `automation` | Not triggered by feature branches or PRs — pushing your branch deploys nothing |
| `PacEHR_AI`: `pr-validation.yml` | `npm test` + build on Node 22. No eval (it needs VPN and the DEV database) | Depends on branch policy |

Whether these checks are **required** for merging depends on the repo's Azure DevOps branch policies. **Not checked.**

PacEHR_AI also has a **pre-push hook** that requires a passing eval for pushed `src/` changes. Install once: `npm run hooks:install`. Never `--no-verify` to get around it.

---

## Quick reference

```bash
# 1. branch
git checkout -b 3p-dev/AITP-00-short-slug

# 2. before the PR
git fetch origin --prune
git merge --no-edit origin/PacEHR-DevelopUI-Main     # API: origin/PacEHR-DevelopAPI-Main
npx ng build                                         # API: build the solution

# 3. push (first time)
git push -u origin 3p-dev/AITP-00-short-slug
```

Then in Azure DevOps:
- **Target:** `PacEHR-DevelopUI-Main` (UI) or `PacEHR-DevelopAPI-Main` (API)
- **Title:** `AITP-00 : Jira title`
- **Description:** paste the template with the 4 checklist items ticked and no other checkboxes.
