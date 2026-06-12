---
description: Prepare a release — audit, full tests, version bump, changelog, artifacts
argument-hint: [platform or version]
disable-model-invocation: true
---

Prepare a release: $ARGUMENTS

Workflow:

1. Check `git status`. If the tree is dirty, stop and ask the user to commit
   or stash first. Once clean, delegate to the **flutter-reviewer** to audit
   the changes since the last release tag (`git diff <last-tag>..HEAD`, or a
   full review if no tag exists).

2. Run the full test suite. Block on failure.

3. Run the full `/qa` sweep — **both platforms**, all flows, plus the
   multi-size visual pass (this is the pre-release home of the checks the
   per-step gates skip). Block on FAIL.

4. Delegate to the **flutter-releaser** agent. They will:
   - Run pre-flight Firebase + signing guardrail checks (project ID is the
     Firebase project ID recorded in CLAUDE.md (Project overview → "Firebase
     project"), verified at runtime via `firebase use`; rules locked,
     key.properties `.gitignored`).
   - Confirm version bump with the user
   - Propose a CHANGELOG entry from git log since last tag
   - Build artifacts (after explicit confirmation per platform)

5. Output:
   - Artifact paths (APK, AAB, IPA)
   - File sizes
   - Submission checklist (the user uploads to stores — agent does not)

This is the one workflow where confirmations are required at every irreversible
step. Even with aggressive autonomy enabled, releases are gated.
