---
description: No-op test command — confirms the installed plugin version (used to verify plugin updates take effect)
---

This is a deliberate no-op used to verify that a plugin update has taken effect. Do
**not** run any scripts, make any network calls, or modify any files.

Read the `"version"` field from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` and
reply with exactly one short line:

> Substrait plugin is alive — release version `<version>`.

Nothing else.
