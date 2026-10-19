# context — the shared brief every person and every AI session starts from

The product repos' READMEs are unedited templates, so this folder is where the team's shared understanding lives.
Open a Claude Code session in `sai-systems-AIRE` and it reads `.claude/CLAUDE.md`, which sends it here first.
Humans should read it too — a ticket done from different context produces different code.

| Folder | Holds |
|---|---|
| `All/` | Facts that apply to every repo: system map, environments, Jira keys, git/PR conventions, glossary |
| `PacEHR/` | Angular SPA: how to build, test, where things live, traps |
| `pacEHR_API/` | .NET 8 API + SQL Server: how to build, test, release scripts, traps |
| `pacEHR_AI/` | Node/TypeScript AI service: how to run, eval gate, scope rules |

## What goes in a project context file
Keep each to two pages. If it is longer, it belongs in `docs/architecture/current/`.
1. What the repo is, and the base branch.
2. How to build, run and test — the exact commands, and what "green" means today (including known failing tests).
3. Where code lives (folders that matter) and the 5–10 rules people break.
4. Known traps, each with the evidence and a date.
5. Links to the deep-dive modules for depth. Do not duplicate them.

## Keeping it true
- Every fact carries a source or "unverified". Dates are absolute.
- Header of each file: `Last verified: <date> against <repo>@<sha>`.
- Whoever finds a context file wrong fixes it in the same PR as their ticket (a one-line change is fine).
- Refresh all of it at each release (TEAM-WORKFLOW.md §11).
- **Never put secrets, keys, connection strings, patient data or personal data here.** Name the setting, not the value.
