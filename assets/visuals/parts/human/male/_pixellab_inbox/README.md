# PixelLab inbox — cribado manual

Lotes crudos importados desde PixelLab **antes** de promover a `naked/`.

## Flujo

1. Revisar PNGs en `v1/` (o el lote activo).
2. Por cada archivo, decidir:
   - **base** → copiar/mover a `../naked/<part>/`
   - **derivado** → mover a `../derived/equipment_ref/` (u otra carpeta)
   - **descartar** → borrar o dejar aquí
3. Anotar huecos en `curation_status.json`.
4. Regenerar solo las piezas/vistas que falten (nuevo object_id en README).
5. `godot --headless --path . --script res://tools/build_human_cutout_part_defs.gd`

`naked/` solo debe contener arte **aprobado** para el modelo base (taparrabos, piel desnuda, sin armadura).

## Lotes

| Lote | Origen | Notas |
|------|--------|-------|
| `v1/` | Jobs PixelLab jul 2026 | Snapshot; brazos/piernas sospechosos de llevar equipo |
