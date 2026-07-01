# Dark medieval wood — building kit

Fantasy oscura, medieval, predominio madera. **Dos pipelines PixelLab separados** (nunca mezclar en un solo `create_tiles_pro`).

## Layout de carpetas (igual que `props/` y `tiles/`)

Norma del proyecto: `.cursor/rules/world-assets-layout.mdc`.

```
dark_medieval_wood/
├── README.md
├── dark_medieval_wood_catalog.tres      # StructureCatalog (piezas verticales)
├── dark_medieval_wood_floor_catalog.tres # TileCatalog (suelos rombo)
├── floors/
│   ├── floor_interior.tres              # TileDef
│   ├── floor_porch.tres
│   ├── floor_rotten.tres
│   └── art/*.png                        # PNG seamless (PixelLab thin tile)
└── pieces/
    ├── wall_straight.tres               # StructurePieceDef
    ├── wall_corner.tres
    ├── door_closed.tres
    ├── window_shuttered.tres
    ├── roof_slope.tres                  # sin textura hasta tener arte bueno
    └── art/*.png                        # PNG vertical (PixelLab map_object)
```

**Regla:** cada `.tres` vive junto a su categoría; el PNG va en `art/` del mismo nivel. No usar `art/pieces/` suelto ni mezclar PNG con `.tres` en la misma carpeta.

Arte descartado → `res://local/art/` (gitignored). Sustituir `sprite_texture` / `art_texture` en el `.tres` del kit.

---

## Parte A — Suelos (rombo / tile suelo)

| Tool | Parámetros fijos | Prompt |
|------|------------------|--------|
| **`create_isometric_tile`** | `thin tile`, 64, `lineless`, seed 4206x | `flat top face only`, `seamless tileable`, tablones oscuros |

Descargar a: `floors/art/<id>.png` → `TileDef` en `floors/<id>.tres`.

Integración: añadir tiles del `dark_medieval_wood_floor_catalog.tres` al `field_catalog.tres` cuando estén curados (modo Paint tile en editor).

---

## Parte B — Piezas verticales

| Tool | Parámetros | Prompt |
|------|------------|--------|
| **`create_map_object`** | `low top-down`, transparente, tamaño explícito | un solo elemento; evitar *house/shack/building* |

Descargar a: `pieces/art/<id>.png` → `StructurePieceDef` en `pieces/<id>.tres`.

Integración: `dark_medieval_wood_catalog.tres` → editor modo *Place structure piece*.

---

## Qué NO usar

| Tool | Por qué no |
|------|------------|
| `create_tiles_pro` batch mixto | Variaciones aleatorias inútiles |
| `create_isometric_tile` block | Bloque 3D, no sprite vertical |

---

## Estado del batch

| Pieza | Archivo PNG | `.tres` |
|-------|-------------|---------|
| Suelos ×3 | `floors/art/` | `floors/*.tres` |
| Pared / esquina / puerta / ventana | `pieces/art/` | `pieces/*.tres` |
| Tejado | pendiente bueno → `pieces/art/roof_slope.png` | `roof_slope.tres` (sin textura por ahora) |

Coherencia: `create_1_direction_object` + `style_images` desde la mejor pared.
