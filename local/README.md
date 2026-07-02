# Local workspace

Everything under `res://local/` is **personal** and is not tracked by git.

Use it for:

- WIP maps from **UF Map Editor** (`world/maps/*.tscn`)
- Scratch UI scenes (`ui/`)
- One-off experiments
- **Archived map art** (`art/`) — PixelLab outputs that failed tileability rules (3D water blocks, tall props baked into ground, etc.). Strip `art_texture` from the matching `.tres` in `assets/`; salvage sprites manually from here.

Canonical game assets live under `res://assets/` and `res://scenes/`.

**Map editor workflow:** use the **UF Map** dock → **New map** or **Open map** (opens `scenes/world/map_editor_workspace.tscn` automatically). Paint/generate there; **Save map** writes baked tiles to `local/world/maps/`. Copy finished maps to `assets/world/maps/` for git. Runtime play still uses `world_root.tscn`, which can load a baked map via `WorldModule.editor_baked_map` when needed.
