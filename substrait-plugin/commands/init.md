---
description: Initialize this folder as a Substrait project — scaffold a new app or convert an existing codebase to the deploy contract, then link it to a Substrait app
allowed-tools: Bash, Glob, Grep, Read, Edit, Write, Skill
---

You are initializing the current working directory as a **Substrait** project. Two
starting points, one destination: a folder that meets the upload/deploy contract,
carries the project-memory contract block, and is linked to a Substrait app so
`/substrait:deploy` ships it. Load the **`substrait-app` skill** before writing or
changing any code — it is the contract's source of truth; this command only
orchestrates.

1. **Detect the starting point.**
   - `bash "${CLAUDE_PLUGIN_ROOT}/scripts/substrait-link.sh" status` and
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/substrait-deploy.sh" check` (audit-only:
     needs no link, touches nothing, reports every violation at once).
   - Already linked AND compliant → nothing to initialize. Report both facts and
     stop; the user wants `/substrait:deploy`.
   - Essentially empty folder (no app code — dotfiles, an empty git repo, a README
     don't count) → **Scaffold mode** (step 2).
   - Existing codebase → **Convert mode** (step 3).

2. **Scaffold mode — a new app from nothing.**
   - Ask what to build (unless already said): what the app does and who it's for
     (this becomes the `substrait.yaml` `description:` — write a real one, never the
     placeholder), backend-only or full-stack, and the stack (default: the skill's
     FastAPI + React scaffold from `reference/templates/`; any stack meeting the
     contract is fine).
   - Follow the skill's **Workflow** to scaffold: backend on port 8000 with
     `GET /health` and the API under `/api`, `cicd/` Dockerfile(s), Flyway
     migrations, `backend/.env.example` for custom config, no `k8s/`. Include the
     skill's step 7 — the CLAUDE.md contract block (`AGENTS.md` in Cursor) with the
     "not linked yet" placeholder; linking in step 4 fills in the real app.
   - Re-run `… substrait-deploy.sh check` and fix anything it flags.

3. **Convert mode — an existing codebase.**
   - **Audit first, change nothing yet.** Combine the `check` output with your own
     read of the code: where the backend lives and what stack it is, which port it
     listens on, whether it serves `GET /health` and mounts its API under `/api`,
     how the frontend (if any) is built and whether it calls the API via relative
     `/api` paths, where schema DDL lives today, and **which database it uses**.
   - **Present a conversion plan and get explicit consent before editing.** The
     mechanical items — add `cicd/Dockerfile.backend` (EXPOSE 8000) and, when a
     `frontend/` ships, `cicd/Dockerfile.frontend` (port 80); add `/health`; mount
     the API under `/api`; write `substrait.yaml` with a real description (declare
     redis/kafka/qdrant/object-storage under `services:` only if the app actually
     uses them); move DDL into `backend/resources/db/migration/V*.sql`; declare
     custom env vars in `backend/.env.example` (secrets marked `# secret`); remove
     any `k8s/` — apply these after the user approves the plan.
   - **The database line you do not cross silently:** the platform's only database
     is OceanBase (MySQL wire). If the app is on PostgreSQL (or anything
     non-MySQL-wire), converting means swapping the driver, rewriting placeholders
     and every migration's dialect — a migration project, not an init step. Say so
     plainly, size the work, and let the user decide; do not start rewriting the
     data layer on your own initiative. SQLite-for-local is the same conversation
     (see the skill's *Running locally*: local dev needs MySQL/MariaDB).
   - Structure moves (e.g. relocating code under `backend/`) are allowed but keep
     them minimal — the contract cares about Dockerfiles, ports and paths, not
     folder aesthetics.
   - Re-run `… substrait-deploy.sh check` until clean, and suggest a local run
     (skill → `reference/local-dev.md`) to prove the app still works before it
     ships.

4. **Link the project to an app** (skippable — headless/CI, or "later"; the project
   is still fully initialized, just unlinked).
   - Follow the `/substrait:link` flow: `… substrait-link.sh status`; establish the
     account link if missing (`account --portal-url <URL>` — the portal URL is
     REQUIRED, there is no default; ask the user for it, e.g.
     `https://api.pluto.substrait.build` for the Substrait cloud, or the installation's
     own API address such as `https://api.<installation>.substrait.build`). Then bind: for a brand-new app
     `… substrait-link.sh create --name "<NAME>"`; to deploy to an existing one,
     `… substrait-link.sh apps` and `… substrait-link.sh use --app <SLUG>`.
   - **GitHub-only workspaces:** where zip uploads are switched off, a new app must be
     born connected to a repo — `… substrait-link.sh create --name "<NAME>" --repo
     <owner/repo> [--branch <BR>]` (`… substrait-link.sh repos` lists the repos the
     Substrait GitHub App can reach; install it on the repo first if the list is
     empty). `apps` warns on stderr when this applies, and a bare `create` is refused
     with that same guidance. The code then has to be pushed to that repo — help the
     user `git init` / `gh repo create` / push if it isn't there yet.
   - With every deployment mode disabled, `create` is refused outright: relay the
     reason and fall back to linking an existing app (or leave unlinked).
   - A successful link also writes/updates the CLAUDE.md contract block with the
     real app — that is the link script's job, don't duplicate it.

5. **Finish.** Report what the project now is: mode taken, stack, compliance state,
   linked app + preview URL (or "not linked — run /substrait:link when ready").
   Point at `/substrait:deploy` (`--watch`) to ship, `/substrait:env` for secrets,
   and `/substrait:library` to design against existing APIs.
