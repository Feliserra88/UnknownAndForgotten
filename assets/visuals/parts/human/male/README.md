# Male humanoid cutout (`human/male/`)

Modular cutout rig for the `humanoid` archetype — loincloth base layer v1.

## Layout

```
human/male/
  loincloth/<part>/{front,back,side_right}_{idle,walk}.png
  defs/loincloth_<part>.tres          # PartVisualDef per anatomical part
  README.md
```

Godot import: **Nearest** filter, no lossy compression.

## Offsets (from `humanoid.tres`)

| Part | offset | z_index |
|------|--------|---------|
| body | (0, 0) | 0 |
| head | (0, -22) | 2 |
| arm_left / arm_right | (±13, -2) | 1 |
| leg_left / leg_right | (±6, 22) | 0 |

Tune in `uf_npc_editor` preview after swapping art.

## Pipeline tools

| Script | Purpose |
|--------|---------|
| `tools/generate_human_loincloth_cutout.gd` | Prototype PNGs (dev fallback) |
| `tools/build_loincloth_part_defs.gd` | Rebuild `defs/*.tres` from PNG folders |
| `tools/import_pixellab_cutout_object.gd` | Import completed PixelLab 8-dir object |

Regenerate defs after replacing PNGs:

```bash
godot --headless --path . --script res://tools/build_loincloth_part_defs.gd
```

## PixelLab jobs (loincloth v1)

Queued via MCP `create_8_direction_object` (`view=low top-down`, `size=64`).

| Part | Object ID | animate (pending) |
|------|-----------|-------------------|
| body | `6c624467-0808-441b-becd-c64b87f7290d` | — |
| head | `b29b6b0f-2230-4f02-99bc-74332e78135d` | — |
| arm_left | `99802fd1-a4f0-4216-9288-28f4a273e284` | — |
| arm_right | `75f86b86-155c-4499-8bf9-4669f6604034` | — |
| leg_left | `0be0caa8-b596-41d5-b5b7-43946ae80597` | — |
| leg_right | `90a4bee6-1789-4b81-a5de-07b7381aa8e2` | — |

When `get_object` returns **completed**, run:

```bash
godot --headless --path . --script res://tools/import_pixellab_cutout_object.gd -- <object_id> <part_id>
```

Then `animate_object` with `directions=["south","north","east","west"]` and re-import walk strips.

**PixelLab → Godot orientation keys:** south=`front`, north=`back`, east=`side_right`, west=`side_left` (or flip east).

## Variant: naked (later)

Duplicate `loincloth/` structure under `naked/`; regenerate body + legs only; same offsets.
