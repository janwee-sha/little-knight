---
name: godot-input-parity
description: Audit, implement, and verify equivalent Godot controls across keyboard, mouse, and gamepad, including InputMap actions, stick and D-pad coverage, deadzones, active-device switching, platform-aware prompts, UI focus navigation, pause input, controller disconnect fallback, and rumble. Use when Codex is asked to add controller support, fix missing bindings, review control conventions, synchronize prompts with mappings, test menu navigation, or prevent input regressions in a Godot game.
---

# Godot Input Parity

Treat input parity as a semantic contract: every required gameplay and UI action must be reachable on each supported device family, while prompts and focus behavior reflect the active device.

## Workflow

1. Inspect `project.godot`, Autoload input services, gameplay input calls, UI `_input` handlers, and existing tests. Determine whether mappings are persisted or registered at runtime.
2. List gameplay and UI actions by meaning before changing bindings. Confirm the genre's expected layout and preserve established project bindings unless the user requests remapping.
3. Create or select a JSON action contract. Use `references/action-game-contract.json` only as a starting point for 2D action games; remove irrelevant actions and rename project-specific ones.
4. Run `scripts/run_input_audit.py` to validate the live `InputMap` after Autoload initialization. Repair missing actions, devices, event types, or deadzones without duplicating existing events.
5. Verify behavior that static mappings cannot prove: active-device switching, prompt refresh, menu focus, pause/resume input, controller disconnect fallback, and vibration guards.
6. Add regression assertions to the project's smoke tests and visually inspect device prompts or focused controls when those surfaces changed.
7. Report the contract used, mappings observed, runtime behaviors exercised, unsupported hardware, and remaining gaps.

## Implementation Rules

- Read gameplay through named actions, not raw keys or joypad buttons.
- Add events idempotently with `InputEvent.is_match` or persist them once in `project.godot`; do not append duplicates on every launch.
- Treat keyboard and mouse as one active prompt family but audit their bindings separately when an action requires both.
- Support both left stick and D-pad for digital movement and menu navigation when appropriate.
- Apply deadzones to analog actions and ignore small motion when detecting the active device.
- Switch prompts only on meaningful pressed or moved input; ignore mouse jitter and stick drift.
- Keep menu navigation available while paused and grab a deterministic first focus target when an overlay opens.
- Stop vibration or fall back safely when the active controller disconnects.

Read [references/input-parity-patterns.md](references/input-parity-patterns.md) before implementing device detection, prompt glyphs, focus behavior, or runtime tests.

## Audit Runner

Run the bundled action-game contract against the current project:

```bash
python3 .agents/skills/godot-input-parity/scripts/run_input_audit.py \
  --project . \
  --contract .agents/skills/godot-input-parity/references/action-game-contract.json
```

Pass `--godot` if engine discovery fails. The runner rejects nonzero exits, Godot error markers, and missing explicit `PASS` output.

Contract action fields are:

- `devices`: required `keyboard`, `mouse`, or `gamepad` coverage
- `event_types`: required `key`, `mouse_button`, `mouse_motion`, `joy_button`, or `joy_axis`
- `deadzone_min` / `deadzone_max`: optional inclusive bounds

Use the audit as structural evidence, not proof of hardware behavior. A complete handoff also exercises focus, prompts, disconnects, and representative controller input in-engine.

## Scope Policy

- For audit or diagnosis requests, do not rewrite bindings.
- Do not impose the bundled action-game layout on another genre.
- Do not claim PlayStation, Xbox, Nintendo, or generic glyph correctness without device-name or mapping evidence.
- Do not claim controller support from InputMap entries alone when menus or prompts remain keyboard-only.
