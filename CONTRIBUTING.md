# Contributing to How to Hunt

## Workflow
1. Branch from `main` (`feat/...`, `fix/...`, `chore/...`, `docs/...`). Never push straight to `main`.
2. Keep pull requests small, roughly 400 changed lines or fewer where practical.
3. Add or update tests for any change to economy, progression, save/load or spawn logic.
4. Run the tests locally before opening the PR (see below).
5. Write a PR description with: **what changed**, **why**, and **how to test it**.
6. CodeRabbit reviews every PR. Resolve or explicitly answer every comment before merging.
   Do not dismiss security, performance or correctness findings.

## Running tests
Requires Godot 4.4.x.

```
godot --headless --path . -s tests/run_tests.gd
```

The runner exits with a non-zero code if any test fails.

## Code rules
- Game logic stays separate from UI and from Steam. Steam is reached only through `SteamService`.
- Game data (animals, tools, zones, quests, prices) lives in `data/`, not in code.
- Use a seedable `RandomNumberGenerator` for anything random, so tests are deterministic.
- Use static typing in GDScript.
- User-facing text goes through the localization system, not string literals in UI code.

## Assets
Only add assets you may legally ship. List every third-party asset and its license in
`ASSETS_LICENSES.md`. Mark placeholders clearly.

## Secrets
Never commit API keys, Steam credentials or login details.
