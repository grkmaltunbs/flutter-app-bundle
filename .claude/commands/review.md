Review code: $ARGUMENTS

Delegate to the **flutter-reviewer** agent.

If $ARGUMENTS is empty, review uncommitted changes (`git diff`). Otherwise
review the named files / feature.

The agent returns a prioritized list (Blockers / Important / Nits / Analyzer
output). Address blockers automatically — delegate to the appropriate agent
(developer for code fixes, tester for missing tests). Surface Important and
Nits to the user as a final summary, do not auto-fix them.

If any Blocker involves Firebase project mis-targeting (any reference to
the wrong project ID), stop and surface to user immediately — do not auto-fix
infrastructure issues.
