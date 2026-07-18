# Godot Gameplay QA Patterns

## Repository discovery

- Read `project.godot`, repository instructions, and documented run commands.
- Locate smoke tests, capture scripts, main scenes, autoloads, and configured viewport size.
- Resolve the engine from `--godot`, `GODOT_BIN`, `godot4`, `godot`, or the standard macOS application path.
- Confirm whether QA is read-only or whether adding tests is in scope.

## Smoke-test contract

- Instantiate the smallest scene that proves the requested behavior.
- Wait enough process frames for `_ready`, deferred calls, imports, and signals.
- Accumulate failures so one run reports multiple useful issues.
- Print a unique success marker only after all assertions pass.
- Exit nonzero on assertion failures.
- Stop audio, free transient nodes, restore `Engine.time_scale`, unpause the tree, and release the scene before quitting.

Useful assertions include:

- nodes, signals, collision shapes, and animation names exist
- InputMap actions contain keyboard, mouse, axis, and joypad events
- pause/resume and modal focus behave correctly
- state machines enter the intended windup, active, recovery, hurt, or death state
- required resources exist and textures use expected dimensions
- sprite anchors match collision or ground baselines within a documented tolerance

## Log validation

Godot may return status 0 after a script parse or runtime error. Require all of the following:

1. process exit status is zero
2. no fatal engine or script marker is present
3. the expected success marker is present for smoke tests

Treat these as fatal by default: `SCRIPT ERROR`, `Parse Error`, `Invalid access`, `handle_crash`, `Segmentation fault`, and lines beginning with `ERROR:`. Warnings are evidence to review but are not automatically fatal unless the project says otherwise.

## Visual-capture contract

- Use a deterministic viewport and wait for at least one rendered frame before capture.
- Force the relevant gameplay states and keep actors inside the camera.
- Capture gameplay, combat, overlays, and edge cases as separate images.
- Check that `ViewportTexture.get_image()` is non-null and propagate save failures to the process exit code.
- Write captures to a temporary or explicitly requested artifact directory.
- Inspect the resulting images; existence and file size do not prove correctness.

Review ground contact, sprite scale, animation clipping, hit effects, HUD occlusion, focus rings, pause dimming, text readability, and responsive edges.

## Renderer selection

- Use `--headless` for deterministic logic tests.
- On macOS, headless mode may use the dummy renderer and return null viewport images. Run visual capture with a real renderer, commonly `--rendering-method gl_compatibility` without `--headless`.
- In Linux CI, use a proven offscreen renderer or a virtual display such as Xvfb; do not assume headless capture works.
- Treat GUI launch as an external side effect and obtain approval when the execution environment requires it.

## Handoff

Report the tested revision, commands, success marker, error scan result, capture paths, inspected states, remaining warnings, and any untested platform or controller behavior.
