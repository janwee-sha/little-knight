---
name: godot-gameplay-qa
description: Run and assess Godot gameplay quality checks, including headless smoke tests, scene and resource validation, input or pause regressions, rendered screenshot capture, HUD and overlay review, and post-change verification. Use for Godot projects when Codex is asked to test gameplay, verify a refactor, diagnose test output, add a QA harness, inspect visual regressions, or determine whether a game change is ready to hand off.
---

# Godot Gameplay QA

Build an evidence-backed QA loop that separates deterministic logic checks from rendered visual review. Never infer success from the Godot process exit code alone.

## Workflow

1. Inspect `project.godot`, repository instructions, existing test scripts, and the engine version before choosing commands. Prefer the project's own test entrypoints.
2. Match the check to the request:
   - Run headless smoke tests for scene construction, state transitions, input mappings, resource availability, and cleanup.
   - Run a real renderer for screenshots, HUD layout, animation alignment, pause overlays, and other visual claims.
   - Do both after gameplay or UI implementation when visual behavior is part of acceptance.
3. Preserve request scope. For a test or review request, do not edit the game. Add or repair the QA harness only when the user asks to build or fix it.
4. Run logic checks through `scripts/run_godot_qa.py`. Require an explicit success marker such as `PASS`, reject known Godot error markers even when the process exits with code 0, and retain the full log.
5. For visual QA, obtain any required GUI approval, generate deterministic captures, and inspect every relevant image. Do not treat file creation alone as visual approval.
6. Report the exact command, explicit pass/fail evidence, captured-image paths, issues found, and checks that could not be performed.

## Logic Checks

Make smoke tests deterministic and self-terminating. Cover only invariants material to the change, commonly:

- main scene instantiation and required nodes
- input actions and device mappings
- gameplay state transitions and pause/resume behavior
- animation and resource availability
- anchor, collision, or viewport invariants
- shutdown cleanup, restored time scale, and released transient resources

Print one unambiguous success marker and exit nonzero on accumulated failures. Treat `SCRIPT ERROR`, parse errors, crashes, and invalid property access as failures regardless of exit status.

## Visual Checks

Capture stable states rather than hoping normal gameplay reaches them. Wait for scene import and rendering, position actors deliberately when useful, trigger the target animation or overlay, and save output outside tracked source directories.

Inspect captures for ground contact, scale changes, clipping, focus indication, readable HUD hierarchy, overlay coverage, and viewport edge collisions. Read [references/godot-qa-patterns.md](references/godot-qa-patterns.md) before creating or repairing smoke and visual-capture scripts, or when selecting platform-specific rendering flags.

## Runner

Run a project's smoke script:

```bash
python3 .agents/skills/godot-gameplay-qa/scripts/run_godot_qa.py \
  --project . \
  --smoke-script tests/smoke_test.gd
```

Add rendered capture validation when authorized:

```bash
python3 .agents/skills/godot-gameplay-qa/scripts/run_godot_qa.py \
  --project . \
  --smoke-script tests/smoke_test.gd \
  --visual \
  --visual-script tests/visual_capture.gd \
  --capture-dir /private/tmp/game-visual
```

Pass `--godot` when discovery cannot find the engine. Use `--visual-headless` only after confirming that the platform's offscreen renderer can return viewport images.

## Failure Policy

- Do not call a run successful without the configured success marker.
- Do not suppress Godot engine or script errors to make a run pass.
- Do not use headless screenshots as evidence when the renderer returns a null image.
- Do not fix issues during a diagnostic-only request.
- Preserve logs and captures until the result has been reviewed.
