# Substrait plugin for Claude Code

Build apps to the Substrait upload/deploy contract and ship them without leaving the
terminal. The plugin bundles:

- the **`substrait-app`** skill — scaffolds a contract-compliant app (FastAPI `backend/`
  on port 8000, `cicd/` Dockerfiles, optional React+Vite+Tailwind `frontend/`, Flyway
  migrations); and
- twelve slash commands:
  - **`/substrait:init`** — initialize the current folder as a Substrait project: scaffold
    a new app in an empty folder, or audit and convert an existing codebase to the deploy
    contract — then link it to an app.
  - **`/substrait:login`** — authenticate this machine with your Substrait account (mints
    the personal access token; one browser authorization, no copy/paste). Each login is a
    saved **profile** — one installation as one org — so you can hold several.
  - **`/substrait:switch`** — pick which saved login the machine acts under: lists your
    profiles and activates the one you choose (a linked folder keeps its own login unless
    you move it).
  - **`/substrait:logout`** — sign out of one login again: revokes the login-minted token on
    the portal and drops the stored credential (`--profile` picks a saved login,
    `--project` also unbinds this folder).
  - **`/substrait:link`** — link this project to one of your apps (pick or create it), so
    deploys know where to ship. Headless/CI falls back to pasting a token.
  - **`/substrait:deploy`** — deploy the project to the linked app: source-only zip upload,
    or a pushed-branch trigger for GitHub-connected apps (`--watch` to follow the build).
  - **`/substrait:env`** — view and set the linked app's environment variables and secrets
    (secrets are write-only; changes live-apply to a running app).
  - **`/substrait:logs`** — read the linked app's runtime logs (backend or frontend pods)
    to debug a deployed app that misbehaves.
  - **`/substrait:fix`** — clear the app's Dev blocking security findings: fixes what it
    can in the code, files false-positive claims with Infosec (only on your "y"), lists
    what can't be fixed and any secrets to rotate, then offers to redeploy.
  - **`/substrait:library`** — browse the platform's API Library and design an app against
    existing APIs.
  - **`/substrait:slate`** — create, change, pull and push back **slates** (AI-made
    documents, decks and interactive pages): ask for one from a brief, ask it to change,
    fetch its HTML to edit by hand, save it back as the next version, open it — and ask
    a question about one (what it says, what a figure means) without changing it, and
    read, write and resolve the comments its readers leave on it.
    The page is written by Substrait's AI (on your organisation's AI key) or right here by
    Claude Code (on your own usage) — whichever your organisation is set to; `mode` says which.
  - **`/substrait:ping`** — prints the installed plugin version and checks each saved login
    (read-only). If your Substrait installation has moved to a new address, this also
    updates your saved logins to it.

## Install

```
/plugin marketplace add substrait-build/substrait-claudecode-plugin
/plugin install substrait@substrait
```

**Using the Claude desktop app?** The `/plugin` commands are terminal-only. Run the two
commands above once from the `claude` CLI in any terminal — CLI and desktop share the same
plugin store (`~/.claude/plugins`), so the plugin is immediately available in desktop
sessions too. (Alternatively, use the desktop plugin manager: the **+** button next to the
prompt box → **Plugins**.) Projects scaffolded by Substrait also ship a
`.claude/settings.json` that pre-registers this marketplace and enables the plugin, so
opening such a project offers the plugin automatically on every surface, including the
desktop app and claude.ai/code.

**Staying current.** Claude Code leaves auto-update **off** for third-party marketplaces, so
by default a bundled `SessionStart` hook just checks once a day and nudges you to run
`claude plugin update substrait@substrait` in a terminal. To skip the nudge and have updates
land on their own, run `/plugin` → **Marketplaces** → `substrait` → **Enable auto-update**.

Two things that catch people out:

- **The desktop app has no Update button.** Its plugin manager only enables, disables and
  uninstalls. Open the built-in terminal with **Ctrl+`** and run the command there.
- **`claude plugin update` defaults to `--scope user`.** If `claude plugin list` shows a row
  with `Scope: project`, that copy is a separate install and the plain command will not touch
  it — it keeps running the old code while telling you the update succeeded. Update it with
  `claude plugin update substrait@substrait --scope project`, run from that project's folder.

## Set up & deploy

1. In your project, run `/substrait:link`. It opens the portal in your browser (you're
   already logged in), where you **pick the app** to link — the deploy token is minted for
   that app and returned to the CLI automatically. The app must already exist.
2. Run `/substrait:deploy` to ship (add `--watch` to follow the build to the live URL; for a
   `dev` deploy it then waits for the security scans and says whether the app is ready to
   go live).
3. Something blocking go-live? Run `/substrait:fix`.

**Headless / CI?** If there's no browser, mint a token by hand: portal → your app → its
**Deploy** tab → **Create deploy token**, copy the `sbd_…` value (shown once), then run
`/substrait:link` and paste it.

Config is **per project** in `./.substrait/config.json` (chmod 600, gitignored) — the app
slug and the login profile it was linked under (or, with a per-app token, portal URL + the
app-scoped token). Logins are **profiles** in `~/.substrait/profiles/<name>.json`, one per
installation-and-org; `~/.substrait/config.json` is the active one. You can override with
`SUBSTRAIT_PORTAL_URL` / `SUBSTRAIT_TOKEN` / `SUBSTRAIT_ORG` in the environment, or force a
saved profile with `SUBSTRAIT_PROFILE=<name>` (handy in CI).

**Several installations or orgs?** Log in to each (`/substrait:login`, with `--org <slug>`
for an org other than your default — the profile is named after the portal's host, or
`<org>@<host>`), then switch with `/substrait:switch`. A folder linked under one
profile keeps deploying there whichever profile is active; `/substrait:logout --profile
<name>` signs out of just that one.

**Portal URL.** Substrait is multi-tenant, so there is no default — the URL is always
explicit. Supply it once with `/substrait:login --portal-url <URL>`, or answer the plugin's
**Substrait portal URL** option when you install it and every command picks it up from there.

## Maintainers

**This repository is published, not edited here.** It is generated from canonical sources
in the Substrait monorepo and pushed by `scripts/publish-plugin.sh`:

- `skills/substrait-app/` is assembled from `portal-backend/app/resources/` by
  `scripts/sync-plugin.sh` (the same sources the portal and agent-runner image build from).
- the plugin glue (`.claude-plugin/plugin.json`, `commands/`, `scripts/`) is authored in the
  monorepo under `substrait-plugin/`.

To ship a change, edit the sources in the monorepo, run `bash scripts/sync-plugin.sh`, then
`bash scripts/publish-plugin.sh`. Direct commits here will be overwritten on the next
publish.

## License

MIT — see [LICENSE](LICENSE).
