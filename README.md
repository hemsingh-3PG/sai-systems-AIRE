# sai-systems-AIRE

The team's agentic workspace for PacEHR, PacEHR_API and PacEHR_AI: the AIRE framework, the analysis of how the system works, the shared context, and the working notes for every ticket. The product repos are the client's; nothing here is ever committed to them.

**Start here: [TEAM-WORKFLOW.md](TEAM-WORKFLOW.md)** — process, folder structure, setup, ticket and bug flows, parallel work, open decisions.
**Then: [AIRE-WORKFLOW-GUIDE.md](AIRE-WORKFLOW-GUIDE.md)** — running the AIRE workflows on a story from start to end, with a worked example.

| Folder | What |
|---|---|
| `context/` | Shared brief per repo — read before any ticket |
| `docs/` | Baseline analysis (`architecture/current/`), design, plans, status |
| `dev-stories/` | One folder per ticket (`_templates/ticket` to start) |
| `local_deployment/` | Run UI + API + AI on Podman |
| `tools/` | `check-workspace.sh`, `guard.sh`, `install-aire-cli.sh` |
| `SPEC/` | AIRE framework — read-only |

Quick check of your machine: `tools/check-workspace.sh`
