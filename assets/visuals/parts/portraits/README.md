# NPC portraits (`portraits/`)

Shaded **character presets** from PixelLab — for NPC identity / editor preview, **not** inspection paper-dolls.

```
portraits/
  <archetype>/
    preset_pixellab_01.png   # first shaded batch (SW, detailed)
    preset_<name>.png        # future variants per NPC line
```

| Folder | Archetype | Notes |
|--------|-----------|-------|
| `humanoid/` | Humanoide | 240×300, SW pose |
| `beast/` | Bestia | Semi-erect wolf, mane, fangs |
| `horror/` | Horror | Horns, tail |
| `quadruped/` | Cuadrúpedo | (pending PixelLab job) |
| `winged_horror/` | Horror alado | (pending) |

Wire to `NpcArchetype` / instance data when portrait field exists. Job IDs: see `../art/README.md`.
