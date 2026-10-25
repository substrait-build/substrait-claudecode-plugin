---
description: Fix the linked Substrait app's Dev blocking security findings — fix the code, file false-positive claims with Infosec, then redeploy
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

You are clearing the **Dev blocking findings** of the **Substrait** app this project is
linked to — the findings that stop it going live. They come from the app's Dev security
scans, and *which* findings block is the organisation's policy, decided by the server:
the list you read below is exactly what the Go live gate counts, so never second-guess
it, re-rank it, or decide a finding "doesn't really block". Your job is to fix what can
be fixed in this codebase, file a false-positive claim with Infosec for what you are
confident is safe (only on the user's "y"), report what can't be fixed, and offer the
redeploy that proves it.

All reads go through one script:
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/substrait-security.sh" <command>`
(`status`, `findings`, `submit-fp --file F`, `source-hash`; `-h` for help).

1. **Preflight — stop at the first check that fails, and say why.**
   - **Linked?** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/substrait-link.sh" status`. Not
     linked → stop and point at `/substrait:link`.
   - **Where Dev stands:** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/substrait-security.sh" status`
     prints `blocking_total`, `scans_running`, `scans_errored`, `commit_sha`,
     `source_hash` (one `key=value` per line; an empty value means none).
     - `scans_running` not empty → the scan isn't finished: name the scanners, tell the
       user to run `/substrait:fix` again when they finish, and stop.
     - `scans_errored` not empty → name them: they must be retried on the app's
       **Security** tab in the portal first. Stop.
   - **Is the scanned code the code on disk?** The findings belong to what is
     *deployed*; fixing them against a different tree fixes the wrong thing. Get the
     app's deploy mode from
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/substrait-link.sh" modes` (`app_mode`):
     - `connect` (GitHub): `git rev-parse HEAD` must equal `commit_sha`, **and**
       `git status --porcelain` must print nothing.
     - anything else (zip upload): run, from the project root,
       `bash "${CLAUDE_PLUGIN_ROOT}/scripts/substrait-security.sh" source-hash` — it must
       equal `source_hash`. An **empty** `source_hash` (deployed before the platform
       recorded one, or the code was never uploaded from a folder) counts as a mismatch.
     On any mismatch, say: **"Deploy your changes first, then run /substrait:fix"** —
     you are looking at findings for code that is no longer what's on disk — and stop.
     Don't deploy from here: that is the user's call (`/substrait:deploy --watch`).
   - **`blocking_total` is 0** → "Nothing is blocking in Dev — the app is clear to go
     live." Stop.

2. **Summarise** —
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/substrait-security.sh" findings` prints the full
   set as JSON (for a long list, redirect it to `.substrait/findings.json` and Read that
   instead): `scanners[]`, each with a `display_name`, a `blocking_count` and its
   `findings[]`. Each finding carries `finding_id`, `name`, `severity`, `file`/`line`
   (or `file_path`), a `description`, scanner-specific fields where they apply
   (`rule_id`, `credential`, `engine`, `solution`, `cve_id`, `pkg_name`,
   `installed_version`, `fixed_version`, `container_target`, `dockerfile_path`,
   `no_fix`) and `fp` — Infosec's false-positive state (`status`, `decision_note`,
   `reviewer_name`, `rejection_count`, `locked`). Tell the user in plain language,
   grouped by scanner `display_name` (never the internal scanner id), what blocks and
   where. Then list separately:
   - **Awaiting Infosec** — `fp.status` is `pending`: a claim is already open. Leave
     these findings alone.
   - **Infosec asked a question** — `fp.status` is `info_requested`: quote
     `fp.decision_note`. The builder answers it by filing a claim on that finding again
     (step 4) whose reason answers the question; it goes onto the open claim.
   - **Rejected** — `fp.status` is `rejected`: quote `fp.decision_note` (and who decided
     it). The reviewer's note is the brief for the fix.
   - **Locked** — `fp.locked` is true: no further false-positive claim is possible; it
     can only be fixed.
   - **No fix available** — `no_fix` is true: no upstream release fixes it yet.

3. **Fix** every actionable finding in one pass, working from each finding's fields —
   **never from the scanner's name**:
   - **`no_fix: true`** → no workaround. Don't remove, pin around or vendor the
     component to dodge the scanner; report it as **still blocking** until a fixed
     version ships (or Infosec accepts the risk in the portal).
   - **A hardcoded credential** (the finding has a `credential`, the type of secret
     found) → take the value out of the code and read it from an environment variable
     instead, then store it as a Substrait **secret** following `/substrait:env`: pipe
     the value on stdin so it stays off the argument list —
     `… substrait-env.sh set NAME --secret` — for the environment that runs it (`--env
     dev`; production gets its own copy at go-live — secrets are never copied between
     environments). **Never print the secret** in your reply, a summary or a commit
     message; if you can't move it without echoing it, give the user the exact command
     with a placeholder and let them run it. Tell the user plainly that the credential
     **must still be rotated** — it was exposed in the code (and, for a git repo, in its
     history), so moving it is not enough.
   - **Found on the running app** (the finding has an `engine`, or its `file` is a URL —
     a dynamic scan of the deployed app) → fix the cause in code or configuration, and
     label it **"verified after deploy"**: only the next Dev scan of the running app can
     confirm it.
   - **A vulnerable component with a `fixed_version`** → update `pkg_name` to at least
     `fixed_version` in the manifest/lockfile it came from (`file_path`), or the base
     image when the finding names a `container_target`/`dockerfile_path`; keep the
     update as small as the fix needs.
   - **Code findings** → fix the code at `file:line` in the way `description` (and
     `rule_id`) call for — the real fix, not a rewrite that merely stops the pattern
     matching.
   - **Awaiting Infosec** → leave untouched. **Infosec asked a question** → no code
     change for it; answer it in step 4. **Rejected** → fix it, using the
     reviewer's note.
   - Never add scanner-suppression comments or ignore files (`nosemgrep`,
     `gitleaks:allow`, `.trivyignore`, …), and never delete a file just to make a finding
     disappear. Suppression is Infosec's decision, through a claim (step 4).
   - When done, run the project's own tests and build if it has them (and say if it has
     none). Fix what you broke before going on.

4. **False-positive claims** — only for **unlocked** findings that you are confident are
   not real problems (test fixtures, example values, unreachable code, a scanner
   misreading the code), and only those you did not fix. Claims are reviewed by
   Infosec, so each one needs a concrete, checkable reason.
   - Show the user every claim you propose — the finding (scanner, `name`, `file:line`)
     and your reason — and ask whether to file them. **File only after the user types
     "y"**; anything else means don't file.
   - A finding whose claim was rejected may be claimed again only if the new reason
     **answers the reviewer's `decision_note`** directly; otherwise fix it.
   - To file, write the claims to `.substrait/fp-claims.json` (the folder is never
     deployed or committed):
     `{"items":[{"finding_id":123,"agent_reason":"…"}],"user_note":null}`
     (`user_note`: anything the user wants Infosec to read, else `null`), then run
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/substrait-security.sh" submit-fp --file .substrait/fp-claims.json`
     and delete the file afterwards. The reply lists each submission; `"duplicate": true`
     means a claim for that finding was already with Infosec — tell the user, it is not
     an error. `"answered": true` means the reason was added to the claim Infosec had
     asked about, which is back in review — tell the user their answer was sent.
   - Filing needs the **account** link: on "not signed in to an account", the fix is
     `/substrait:login` (an app deploy token can't file claims — it isn't a person). A
     refusal (the finding is no longer blocking, the claim is locked, the reason is
     empty) is relayed as is, never retried.

5. **Close out** — report in four short lists: **fixed** (with "verified after deploy"
   where it applies), **filed with Infosec**, **not fixable** (still blocking, and why),
   and **secrets to rotate**. Nothing you fixed counts until it is deployed and Dev is
   re-scanned, so ask **"Deploy now?"** On "y", run the `/substrait:deploy --watch` flow
   (its steps, preflight included — for a GitHub-connected app that means committing and
   pushing first, with the user's go-ahead); its Dev verdict says whether the app is then
   clear to go live. On anything else, tell the user to run `/substrait:deploy --watch`
   when ready.

**Hard rules**
- Never deploy, and never file a false-positive claim, without the user's "y".
- Never bypass or work around the deploy preflight or its gates.
- Never print a secret — not in replies, summaries, commit messages or command lines you
  show.
- The blocking list is the server's: don't drop, re-rank or argue with a finding; fix it,
  claim it, or report it as still blocking.
