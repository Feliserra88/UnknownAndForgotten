# Equipment slot icons (`icons/`)

Pixel art inventory icons, dark medieval fantasy, `top-down`, 64×64.

## Generic slot icons (`generic/`)

UI placeholders for equipment **slot types** (not specific loot items).

| id | File |
|----|------|
| sword | `generic/sword.png` |
| shield | `generic/shield.png` |
| armor | `generic/armor.png` |
| helmet | `generic/helmet.png` |
| bow | `generic/bow.png` |
| spell | `generic/spell.png` |
| scroll | `generic/scroll.png` |
| gold_coin | `generic/gold_coin.png` |
| ring | `generic/ring.png` |
| potion | `generic/potion.png` (pending) |

**Tool:** `create_1_direction_object` (size 64, view top-down).

## Loot item sprites (sibling folders)

Concrete loot art lives next to this folder — not under `icons/`:

| Folder | Content |
|--------|---------|
| `../weapons/` | Weapon sprites (`type01`…`type16` per category) — see `../weapons/README.md` |
| `../shields/` | Shield sprites — see `../shields/README.md` |

## Jobs

PixelLab job IDs: `local/pixellab_jobs.json`.
