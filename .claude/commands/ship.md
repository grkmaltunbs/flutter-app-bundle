Prepare a release: $ARGUMENTS

Workflow:

1. Delegate to the **flutter-reviewer** for an audit of uncommitted changes.
   Do not proceed if there are uncommitted changes — ask the user to commit
   or stash first.

2. Run the full test suite. Block on failure.

3. Delegate to the **flutter-releaser** agent. They will:
   - Run pre-flight Firebase + signing guardrail checks (project ID is
     `<YOUR_PROJECT_ID>`, rules locked, key.properties `.gitignored`).
   - Confirm version bump with the user
   - Propose a CHANGELOG entry from git log since last tag
   - Build artifacts (after explicit confirmation per platform)

4. Output:
   - Artifact paths (APK, AAB, IPA)
   - File sizes
   - Submission checklist (the user uploads to stores — agent does not)

This is the one workflow where confirmations are required at every irreversible
step. Even with aggressive autonomy enabled, releases are gated.
