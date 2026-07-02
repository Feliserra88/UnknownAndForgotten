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

## Offsets and display scale

| Part | offset | z_index | `display_size` |
|------|--------|---------|----------------|
| body | (0, 0) | 0 | 24×28 |
| head | (0, -22) | 2 | 18×18 |
| arm_left / arm_right | (±13, -2) | 1 | 8×20 |
| leg_left / leg_right | (±6, 22) | 0 | 9×20 |

`PartVisualDef.display_size` + `resolve_base_scale()` map PixelLab canvas (~32–68 px) to rig size. Tune offsets in `uf_npc_editor` after swapping art.

## PixelLab — no native cutout API

PixelLab has **no modular body-part rig endpoint**. Each `create_8_direction_object` call is independent (pose/animation not shared). See `.cursor/rules/pixellab-character.mdc` for full rules.

### Workflows (preference order)

| ID | Steps | When |
|----|-------|------|
| **A** | Crop PNG per slot → `reference_image_base64` → idle → walk | Best pose lock for cutout |
| **B** | `create_character` + walk → slice parts manually | Best full-body coherence |
| **C** | 6× `create_8_direction_object` + `style_image_base64` from body | Cheapest; fragile assembly (v1) |

Always **pilot one part** (e.g. `arm_left`, `size=32`) before batch jobs.

## Pipeline tools

| Script | Purpose |
|--------|---------|
| `tools/generate_human_dummy_cutout.gd` | Regenerate `_dummy` placeholder PNGs |
| `tools/build_human_cutout_part_defs.gd -- naked` | Rebuild `defs/naked_*.tres` |
| `tools/import_pixellab_cutout.gd -- manifest.json` | Import PixelLab idle or walk frames |

```bash
godot --headless --path . --script res://tools/build_human_cutout_part_defs.gd -- naked
```

## PixelLab pipeline (workflow C)

1. **Pilot:** one part → `get_object` → cribar before batch.
2. `create_8_direction_object` per part (view=`low top-down`) → idle rotations.
3. Import idle → `{view}_idle.png` (south/north/east only).
4. **Only after idle approved:** `animate_object` mode=v3, `directions=[south,north,east]`, `frame_count=8`.
5. Import walk strips → `{view}_walk.png`.
6. Rebuild defs; tune offsets in editor.

### Canvas size per part

| Part | PixelLab `size` | Why |
|------|-----------------|-----|
| body | 48–64 | Torso fills canvas reasonably |
| head | 32–48 | Smaller than body |
| arm_* / leg_* | **32** | Avoids boots/gloves filling a 64×64 canvas |

With `reference_image_base64` or `style_image_base64`, output size follows the reference image.

### Prompt structure

`[common block] + [part] + [pose] + [negatives]`

**Common block** (same on all 6 parts):

> fantasy RPG male humanoid, low top-down isometric pixel art, lineless, basic shading, medium detail, muted earth tones, transparent background, single isolated body part only, neutral idle standing pose facing camera

| Part | Extra |
|------|-------|
| body | bare chest, simple leather loincloth only, no head no arms no legs |
| head | male head short dark hair only, no neck no torso |
| arm_* | bare skin upper arm forearm and open hand, limb only |
| leg_* | bare skin thigh calf and bare foot, limb only |

**Negatives** (always append):

> NO armor NO boots NO gloves NO bracers NO greaves NO sleeves NO clothing except loincloth on torso only

**PixelLab → Godot:** south=`front`, north=`back`, east=`side_right`, west=flip east.

### Pre-flight checklist

- [ ] One part per API call
- [ ] Canvas matches part (32 for limbs)
- [ ] Idle cribado before `animate_object`
- [ ] Walk only 3 directions; `frame_count=4` for tests, `8` for production
- [ ] Update `curation_status.json` before promoting to `naked/`

## PixelLab jobs (naked v1, 8-frame walk)

| Part | Object ID | Walk group |
|------|-----------|------------|
| body | `94b4cf33-4ee5-45f4-9bbe-8ead919f9e29` | `60e39fb2-6cbd-4a97-9aea-3f0d401d738d` ✓ |
| head | `631723ae-b945-4d30-9711-1da007134fb3` | `bb598f53-53e9-4efd-bb7c-9c5552c20be8` ✓ |
| arm_left | `767f7691-310a-4570-9559-dfa69af88221` | `e29ea847-f224-41f0-a3f4-20b945280cd1` ✓ |
| arm_right | `983b377e-0200-4c79-8f5c-d9fdab824369` | `8c6a136a-1399-4f3f-8471-e6a4dc1efe6f` ✓ |
| leg_left | `52e1a633-54d6-4115-a801-140a5b053f70` | `5f5ff146-4ef3-4525-aa43-9f03a39fcf3a` (east pending) |
| leg_right | `47c4f359-12ef-4b59-b11f-a4b454f58f46` | `1d859d77-fbcd-434a-a4d7-1ac63b3dbcb3` (pending) |

## Asymmetry (injuries, equipment, tattoos)

Symmetric base body uses **flip** for west (`side_left`). Overlays that break symmetry need either:

- **4 extra views** on disk (`side_left` + optional diagonals), or
- **Full 8 directions** of unique art per asymmetric layer

Plan this when adding injury/equipment layers that are not mirrorable.

## Cribado manual (neutral base)

PixelLab a veces añade **equipo** (guanteletes, botas, etc.) aunque el prompt pida piel desnuda. **No promover a `naked/` sin revisar.**

### Flujo

1. Lote crudo en `_pixellab_inbox/v1/` (copia de referencia).
2. Revisar cada PNG; actualizar `curation_status.json` (`approved` | `derived` | `reject` | `missing`).
3. **Aprobado** → `naked/<part>/`
4. **Derivado** (sirve para equipo/variante) → `derived/equipment_ref/`
5. **Huecos** → regenerar solo esa parte con prompt estricto (nuevo object_id).
6. `build_human_cutout_part_defs.gd` cuando `naked/` esté completo.

### Sospechas lote v1 (pre-cribado)

| Parte | Riesgo |
|-------|--------|
| body, head | Probablemente OK (taparrabos / cabeza neutra) |
| arm_left, arm_right | Previews con bracer/guante — **revisar todo el set** |
| leg_left, leg_right | Previews con bota/greba — **revisar todo el set** |
| leg_right walk | **Faltan 3 PNG** (job PixelLab falló en cola) |

### Prompts regeneración (más estrictos)

Añadir siempre: `NO armor NO boots NO gloves NO bracers NO clothing except loincloth on torso`

| Part | Prompt extra |
|------|----------------|
| arm_* | bare skin arm and open hand only, NO gloves NO bracers NO sleeves |
| leg_* | bare skin leg and bare foot only, NO boots NO greaves NO wraps |


Legacy coloured rectangles for editor/tests. **Not final art.** Kept so the project runs before PixelLab import completes.
