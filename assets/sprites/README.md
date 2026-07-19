# Little Knight sprite pipeline

Gameplay art starts from approved 64×64 bottom-center, right-facing seed frames. Generated strips are chroma-keyed, repacked, globally normalized per animation, then rebuilt from `runtime_manifest.json` into shared bottom-centered runtime canvases. Every animation uses one fixed nearest-neighbor scale for its entire strip, so character proportions stay stable without per-frame drift.

## Approval gate

The first production checkpoint is a three-character seed sheet containing:

1. Little Knight — silver closed helmet, cyan eye slit, blue tunic, red cape, short sword.
2. Melee Guard — dark hooded plate armor, amber eyes, muted crimson armor cloth, chipped short blade.
3. Ranged Guard — dark hood, amber eyes, muted violet armor cloth, compact crescent bow with a small ember focus.

The sheet was approved before strip production. `source/`, `raw/`, `canvases/`, `previews/`, `frames/`, and `seeds/` retain the reproducible production trail and are excluded from Godot import with `.gdignore`; only `runtime/` ships into the animation library.

## Frame counts

- Player: idle 4, run 6, jump 4, attack-one 6, attack-two 6, heavy-attack 8,
  guard 4, perfect-guard 4, riposte 8, dash 4, hurt 2, death 6.
- Melee Guard: idle 4, walk 6, normal attack 6, yellow attack 8, red attack 8,
  hurt 2, death 6.
- Ranged Guard: idle 4, walk 6, normal attack 6, red attack 8, hurt 2, death 6.
- Projectile: flight 4.

Every strip must preserve character identity, facing, palette, proportions, outfit details, transparency, and bottom-center anchoring. Render a preview sheet and inspect it in Godot before updating any animation library.

Generated combat additions retain their chroma-key and transparent sources under
`source/generated/`. `tools/import_generated_strip.py` divides the evenly spaced
source strip, applies one strip-wide scale, writes bottom-anchored frame canvases,
and produces the packed and preview artifacts used for review.

## Runtime rebuild

Run `python3 tools/rebuild_runtime_sprites.py` with Pillow available. The manifest is the source of truth for canvas sizes and strip-wide scale factors. Scaling always transforms the full authored canvas around its bottom-center anchor; attack effects are never used as per-frame scale or anchor inputs.
