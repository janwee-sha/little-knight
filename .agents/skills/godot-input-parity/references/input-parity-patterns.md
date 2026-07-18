# Godot Input Parity Patterns

## Action contract

Define actions by player intent rather than hardware: move, confirm, cancel, attack, pause, and so on. Keep gameplay code device-agnostic and map each supported family into the same action.

For a typical 2D action game, start with these conventions and adapt to the project:

- movement: WASD or arrows; left stick and D-pad
- primary action or jump: Space or a nearby key; gamepad south button
- attack: left mouse or nearby key; gamepad west button
- dodge or cancel: right mouse, Shift, or nearby key; gamepad east button
- pause: Escape; Start/Menu button
- UI accept/cancel: Enter/Space and Escape; south/east gamepad buttons

Do not overwrite a shipped layout merely to match this example.

## Mapping architecture

Prefer editor-persisted InputMap entries for stable bindings. Runtime registration is acceptable for generated projects or compatibility layers when it is idempotent, runs before consumers, and is covered by a live-engine audit. Do not infer runtime parity by reading empty `project.godot` event arrays.

Use physical keycodes for location-based gameplay layouts. Preserve logical keycodes when text meaning matters. Configure analog deadzones consistently; values around 0.2–0.3 are common starting points, not universal requirements.

## Active-device detection

- Switch to gamepad on pressed buttons or stick motion above a deliberate threshold.
- Switch to keyboard/mouse on pressed keys or mouse buttons.
- Ignore tiny mouse motion and stick drift.
- Track the most recently active joypad ID for prompts and rumble.
- On disconnect, clear the ID, stop vibration if necessary, and select a safe fallback prompt family.

## Prompt parity

Derive prompts from the same action model as gameplay. Update all visible hints on device changes, including HUD, tutorials, pause menus, and terminal screens. Distinguish Xbox and PlayStation labels only when the device name or mapping justifies it; provide a generic fallback.

Do not hard-code prompt text that contradicts remapped actions. When runtime rebinding exists, derive labels from `InputMap.action_get_events` or the binding store.

## UI focus and pause

- Register keyboard, D-pad, and left-stick UI actions.
- Assign deterministic focus neighbors when automatic layout order is ambiguous.
- Grab focus when opening a menu and restore a sensible target when closing a modal.
- Process pause controls and pause-menu navigation with an always-processing node.
- Let `ui_cancel` close the innermost modal before resuming the game.
- Prevent gameplay actions from leaking through focused menus.

## Runtime acceptance

Test at least:

1. keyboard movement and core actions
2. mouse actions where supported
3. stick and D-pad movement
4. gamepad face buttons and pause
5. prompt switching in both directions without drift flicker
6. pause-menu focus, accept, cancel, and modal ordering
7. disconnect fallback
8. rumble only for a connected controller and within clamped strength ranges

Record controller models actually tested; static automation cannot prove vendor-specific glyphs or physical hardware behavior.
