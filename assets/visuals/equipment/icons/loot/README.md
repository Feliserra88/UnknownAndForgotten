# Loot weapon icons

Pixel art inventory icons (64×64), dark medieval fantasy.

## Layout

```
loot/
  <weapon>/
    type01/icon.png
    type02/icon.png
    ...
    type16/icon.png
```

Each `typeNN` is a **distinct weapon design** (not a quality variant). Six weapon categories × 16 types = 96 icons.

| Folder | Weapon |
|--------|--------|
| `long_sword` | Espada larga |
| `short_sword` | Espada corta |
| `greatsword` | Mandoble (2 manos) |
| `woodcutter_axe` | Hacha leñador |
| `wooden_shield` | Escudo madera |
| `war_dagger` | Daga de guerra |

## Quality tiers (per type, future)

When generating condition variants via PixelLab `create_object_state`, use five files per type:

| Index | File | Meaning |
|-------|------|---------|
| 1 | `pristine.png` | Pulida, brillante, como nueva |
| 2 | `good.png` | Limpia, poco uso |
| 3 | `worn.png` | Usada, desgaste neutro |
| 4 | `rusty.png` | Oxidada, descuidada |
| 5 | `battered.png` | Mellada, astillada, dañada |

The current `icon.png` in each type folder is the **seed sprite** from the initial batch. Its visual condition may not match `worn`; assign it to the correct tier (rename or copy), then generate the missing tiers from that seed.

Example workflow for one type:

1. Decide seed state: `long_sword/type03` → seed looks rusty → rename `icon.png` → `rusty.png`.
2. `create_object_state` from that object → `pristine`, `good`, `worn`, `battered`.
