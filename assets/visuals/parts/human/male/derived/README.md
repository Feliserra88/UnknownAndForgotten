# Derived art (salvaged from base generation)

Sprites cribados del lote PixelLab que **no sirven** para `naked/` pero pueden reutilizarse:

- Referencia de equipo (`EquipmentVisualDef` futuro)
- Variantes temáticas (guerrero, etc.)
- Retratos / iconos

**No** enlazar desde `humanoid.tres` hasta que haya un slot de equipo o variante explícita.

Estructura sugerida:

```
derived/
  equipment_ref/     # brazaletes, botas, etc. extraídos del lote
  variant/           # sets alternativos completos (futuro)
```
