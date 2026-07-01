# Wang terrain pipeline (field biome)

1. Generate chained tilesets with PixelLab `create_topdown_tileset` (see `local/pixellab_jobs.json`).
2. Download pairs into this folder: `*_metadata.json` + `*_image.png`.
3. Run converter (Godot 4.7):

```bash
godot --headless --path . -s res://tools/pixellab_wang_converter.gd -- \
  res://assets/world/terrains/wang/grass_water_metadata.json \
  res://assets/world/terrains/wang/grass_water_image.png \
  res://assets/world/terrains/wang/grass_path_metadata.json \
  res://assets/world/terrains/wang/grass_path_image.png \
  --output res://assets/world/terrains/field_combined.tres
```

4. Assign `field_combined.tres` to `TerrainSetDef.tileset` in `field_terrain_set.tres`.

Logical terrain names (`grass`, `water`, `dirt_path`, `stone_floor`, `cave_floor`, `wall`) map to Godot terrain indices in `terrain_ids`.
