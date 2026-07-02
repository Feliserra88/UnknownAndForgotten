# Loot weapon sprites

Pixel art inventory sprites (64×64), dark medieval fantasy — **weapons only** (shields live under `../shields/`).

## Layout (after merge)

```
weapons/
  <weapon>/
    type01.png    # 320×64 strip — 5 quality columns
    type02.png
    ...
    type16.png
```

While curating tiers from PixelLab, use a staging folder per type:

```
<weapon>/typeNN/
  pristine.png | good.png | worn.png | rusty.png | battered.png
```

Then run `tools/merge_weapon_states.gd` (see below). It writes `<weapon>/typeNN.png`, deletes the staging folder and all loose tier PNGs.

### Strip column order (index 0 → 4)

| Index | Tier | Meaning |
|-------|------|---------|
| 0 | pristine | Pulida, brillante, como nueva |
| 1 | good | Limpia, poco uso |
| 2 | worn | Usada, desgaste neutro |
| 3 | rusty | Oxidada, descuidada |
| 4 | battered | Mellada, astillada, dañada |

Runtime slice:

```gdscript
func weapon_state_texture(states: Texture2D, quality_index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = states
	atlas.region = Rect2(quality_index * 64, 0, 64, 64)
	return atlas
```

## Merge tool

```bash
godot --headless -s res://tools/merge_weapon_states.gd -- \
  assets/visuals/equipment/weapons/long_sword type02

# multiple types at once:
godot --headless -s res://tools/merge_weapon_states.gd -- \
  assets/visuals/equipment/weapons/long_sword type01 type02 type03
```

Requires `pristine.png` … `battered.png` in each `<weapon>/typeNN/` folder.

## Weapon categories

| Folder | Weapon |
|--------|--------|
| `long_sword` | Espada larga |
| `short_sword` | Espada corta |
| `greatsword` | Mandoble (2 manos) |
| `woodcutter_axe` | Hacha leñador |
| `war_dagger` | Daga de guerra |

16 designs per category; seeds start as `typeNN/icon.png` from the initial PixelLab batch until tiers are generated.
