Add or improve tests: $ARGUMENTS

Delegate to the **flutter-tester** agent.

If $ARGUMENTS is empty, target the most recent uncommitted changes
(`git diff`).

After the agent finishes:
- Run `flutter test` (full suite)
- Report coverage delta on the changed files only (not the whole project)
- Surface any production-code defects discovered during test writing —
  do NOT silently fix them; let the user route them to the debugger.

For integration tests, the agent uses Firebase emulators (NEVER hits live
`<YOUR_PROJECT_ID>` project). The emulator command is:
`firebase emulators:exec --only auth,firestore,functions,storage "flutter test integration_test/"`
