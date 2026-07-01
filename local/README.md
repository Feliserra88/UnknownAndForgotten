# Local workspace

Everything under `res://local/` is **personal** and is not tracked by git.

Use it for:

- WIP maps saved from **UF Map Editor → Save session map** (`world/maps/`)
- Scratch UI scenes (`ui/`)
- One-off experiments
- **Archived map art** (`art/`) — PixelLab outputs that failed tileability rules (3D water blocks, tall props baked into ground, etc.). Strip `art_texture` from the matching `.tres` in `assets/`; salvage sprites manually from here.

Canonical game assets live under `res://assets/` and `res://scenes/`.

**Workflow:** open `scenes/world/world_root.tscn` (thin shell). The editor reloads `world/maps/editor_session.tscn` when present. After painting or generating, use **Save session map** — do not rely on saving `world_root` to keep tile data.
