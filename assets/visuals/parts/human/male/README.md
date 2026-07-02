# Male humanoid cutout (`human/male/`)

Modular cutout rig for the `humanoid` archetype.

## Layout

```
human/male/
  naked/<part>/{front,back,side_right}_{idle,walk}.png   # production (PixelLab)
  _dummy/<part>/...                                       # dev placeholder only — do not ship
  defs/naked_<part>.tres                                  # PartVisualDef (production)
  defs/dummy_<part>.tres                                  # PartVisualDef (_dummy fallback)
  README.md
```

Godot import: **Nearest** filter, no lossy compression.

## Walk cycle

- **8 frames** per direction (`walk_hframes = 8`, `walk_fps = 8.0`)
- One walk cycle ≈ 1.0 s at 8 FPS
- PixelLab v3 `frame_count=8` yields 9 stored frames (reference + 8); import keeps the last 8

## Runtime directions

8-way movement at runtime; art on disk uses **3 views** (`front`, `back`, `side_right`). `side_left` = horizontal flip of `side_right`. Diagonals reuse cardinal art.

**Asymmetric overlays** (wounds, tattoos, one-sided armor) cannot use flip — see §Asymmetry below.

## Offsets

| Part | offset | z_index |
|------|--------|---------|
| body | (0, 0) | 0 |
| head | (0, -22) | 2 |
| arm_left / arm_right | (±13, -2) | 1 |
| leg_left / leg_right | (±6, 22) | 0 |

Tune in `uf_npc_editor` after swapping art.

## Pipeline tools

| Script | Purpose |
|--------|---------|
| `tools/generate_human_dummy_cutout.gd` | Regenerate `_dummy` placeholder PNGs |
| `tools/build_human_cutout_part_defs.gd -- naked` | Rebuild `defs/naked_*.tres` |
| `tools/import_pixellab_cutout.gd -- manifest.json` | Import PixelLab idle or walk frames |

```bash
godot --headless --path . --script res://tools/build_human_cutout_part_defs.gd -- naked
```

## PixelLab pipeline

1. `create_8_direction_object` (size=64, view=`low top-down`) per part → idle rotations
2. Import idle → `{view}_idle.png` (south/north/east only)
3. `animate_object` mode=v3, `directions=[south,north,east]`, `frame_count=8`, seamless walk
4. Import walk strips → `{view}_walk.png`
5. Rebuild defs; tune offsets in editor

### Prompt base

> fantasy RPG male humanoid, low top-down isometric pixel art, lineless, basic shading, medium detail, muted earth tones, transparent background, single isolated body part only

| Part | Extra prompt |
|------|----------------|
| body | torso with simple leather loincloth, bare chest, no head/arms/legs |
| head | male head, short dark hair, no body |
| arm_left / arm_right | isolated arm + hand |
| leg_left / leg_right | isolated leg + foot |

**PixelLab → Godot:** south=`front`, north=`back`, east=`side_right`, west=flip east.

## PixelLab jobs (naked v1, 8-frame walk)

| Part | Object ID | Walk anim |
|------|-----------|-----------|
| body | `94b4cf33-4ee5-45f4-9bbe-8ead919f9e29` | pending |
| head | `631723ae-b945-4d30-9711-1da007134fb3` | pending |
| arm_left | `767f7691-310a-4570-9559-dfa69af88221` | pending |
| arm_right | `983b377e-0200-4c79-8f5c-d9fdab824369` | pending |
| leg_left | `52e1a633-54d6-4115-a801-140a5b053f70` | pending |
| leg_right | `47c4f359-12ef-4b59-b11f-a4b454f58f46` | pending |

## Asymmetry (injuries, equipment, tattoos)

Symmetric base body uses **flip** for west (`side_left`). Overlays that break symmetry need either:

- **4 extra views** on disk (`side_left` + optional diagonals), or
- **Full 8 directions** of unique art per asymmetric layer

Plan this when adding injury/equipment layers that are not mirrorable.

## `_dummy` set

Legacy coloured rectangles for editor/tests. **Not final art.** Kept so the project runs before PixelLab import completes.
