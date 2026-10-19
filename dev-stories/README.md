# dev-stories — ticket workspace

Everything specific to **one ticket or epic** lives here, so people on different tickets never edit the same files.
The shared, mostly-read-only baseline lives in `../docs/` and `../context/`.

```
dev-stories/
├── _templates/ticket/        copy this folder to start a ticket (6 files)
├── Work-In-Progress/
│   ├── <Epic-or-Area>/
│   │   └── <JIRA-ID>-<slug>/ one folder per ticket (00-ticket … 05-pr)
│   ├── Epic-02/              existing, grandfathered layout (PacEHR_AI data layer)
│   └── Epic-05/              existing, grandfathered layout (PacEHR_AI guardrails)
├── Done/                     move a ticket folder here after its PR merges
├── Tickets-Original-JS/      reference: the Node PacEHR_AI epic specs (read-only benchmark)
├── Tickets-Original-Python/  reference: the earlier Python spec set (read-only)
├── Refine-Docs/              working notes that are not tied to one ticket
└── Extra_Resources/          diagrams and one-off artefacts
```

## Start a ticket
```bash
cp -R dev-stories/_templates/ticket dev-stories/Work-In-Progress/<Epic-or-Area>/<JIRA-ID>-<slug>
```
Then follow TEAM-WORKFLOW.md §7 (features) or §8 (bugs). Fill the files in order; each one is a gate for the next.

## Rules
- Folder name starts with the literal Jira key, so it is searchable and matches the branch.
- One ticket = one folder = one PR (per repo). A cross-repo ticket has one folder and one PR per repo, each listed in `05-pr.md`.
- `00-ticket.md` copies the Jira text verbatim. If Jira changes, add a dated note.
- Never put secrets, credentials, connection strings or patient data in these files.
- `Tickets-Original-*` are references. Do not edit them; copy what you need into a ticket folder.
