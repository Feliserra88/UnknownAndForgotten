# Loot shield sprites

Pixel art inventory sprites (64×64), dark medieval fantasy.

## Layout

```
shields/
  <shield>/
    type01/icon.png
    type02/icon.png
    ...
    type16/icon.png
```

Each `typeNN` is a **distinct shield design** (not a quality variant).

| Folder | Shield |
|--------|--------|
| `wooden_shield` | Escudo de madera |

Same as `../weapons/README.md`: staging folder with five tier PNGs → `merge_weapon_states.gd` → `<shield>/typeNN.png` (320×64).
