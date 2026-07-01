# Roadmap / Backlog — U&F

Tareas pendientes derivadas de lo documentado en `docs/ARCHITECTURE.md` (§12) y `docs/GAME_DESIGN.md` (§12). No es diseño nuevo: es la brecha entre lo documentado y lo implementado.

Leyenda: [ ] pendiente · [~] parcial · [x] hecho.

## 1. Módulos pendientes

- [ ] **`grid`** (log `GRD`) — pathfinding `AStarGrid2D` + reglas de `z`/`max_climb` sobre la API de `WorldModule`. No leer `TileMapLayer` desde fuera del módulo `world`.
- [ ] **`player`** (log `PLR`) — extraer input y movimiento por rejilla desde `scenes/world/main_character_controller.gd`. Jugador = NPC + grupo `"player"`.
- [ ] **`faction`** (log `FAC`) — `FactionDef` (Resource) y relaciones entre grupos; separado de arquetipo (ver `npc-entities.mdc`).
- [ ] **`equipment`** (log `EQP`) — `ItemDef`, `EquipmentVisualDef`, `EquipmentState`.
- [ ] **`status`** (log `STS`) — `StatusEffectDef`, `MaladyDef`, `TraitDef`.
- [ ] **`combat`** (log `CMB`) — resolución de daño; consumidor natural del `EventBus`.

Cada nuevo módulo: código de log de 3 letras, `LOG_<MODULO>_LEVEL` en `venv.ini`, fila en `ARCHITECTURE.md` §12 y pasar `tools/check_architecture.gd`.

## 2. Contratos pendientes

- [ ] **Spawn `world_gen` → `npc`** — tablas de spawn por bioma (`BiomeDef.spawn_table`) y contrato de colocación; hoy no existe enlace generador→npc.
- [ ] **`SpawnPoint`** — recurso/nodo para puntos de aparición pintables desde `uf_map_editor`.
- [ ] **Persistencia formal de `WorldModule`** — el editor sincroniza `height_field`/`tile_catalog` accediendo a propiedades del nodo (`_sync_session_to_scene_root`). Definir API pública de import/export de estado de mapa en vez de tocar campos directamente.
- [ ] **Contrato de colocación en `NpcModule.spawn`** — hoy `_world` casi no se usa (solo `apply_actor_y_sort`); definir cómo el spawn resuelve celda transitable y altura vía `grid`/`world`.

## 3. Refactors pendientes (deuda de acoplamiento)

- [ ] **Extraer `player`** desde `scenes/world/main_character_controller.gd` a `modules/player/`; la escena solo instancia y cablea.
- [ ] **Adoptar `AppearanceModule` en escenas** — `main_character_controller.gd` y `world_demo.gd` aún acceden a `body.get_node("MotionPivot/Appearance")`; migrar a `AppearanceModule.set_orientation/set_moving(body, ...)`.
- [ ] **Inyectar `npc_base.tscn`** — eliminar la excepción allowlist `modules/npc/` → `res://scenes/npc/npc_base.tscn`: pasar la escena por `NpcArchetype.scene` / config en vez de `preload` en `npc.gd` y `human_factory.gd`.
- [ ] **Reducir orquestación en escenas demo** — mover la lógica de bootstrap de `world_demo.gd` (generar + spawn + cámara) a un flujo de arranque explícito una vez existan `grid`/`player`.
- [x] **Fuga por `class_name` a `_private/`** — `PlaceholderTileSet` ya no registra `class_name`; el editor usa `WorldModule.build_tileset()` / `build_modifier_overlay_pack()` / `assign_tile_mapping()`. Lint ampliado (reglas D/E) para prohibir `class_name` en `_private/` y detectar referencias al identificador global.

## 4. EventBus — ampliar catálogo

Declarar en `core/events.gd` (`GameEvents`) a medida que existan los emisores:

- [ ] `world.cell_entered` — `{ uid: int, cell: Vector3i }` (al mover un actor de celda).
- [ ] `npc.died` — `{ uid: int, cause: StringName }`.
- [ ] `combat.hit` — `{ attacker: int, target: int, amount: float }`.
- [ ] `inventory.item_added` — `{ owner: int, item_id: StringName, count: int }`.

Cada evento nuevo: constante + `GameEvents.all()` + fila en `ARCHITECTURE.md` §6.1.

## 5. Estado actual (hecho)

- [x] `EventBus` autoload + catálogo `core/events.gd` con `world.generated` y `npc.spawned`.
- [x] Fachadas `AttributesModule` y `AppearanceModule`.
- [x] Matriz de dependencias documentada (§4.1) y lint `tools/check_architecture.gd`.
- [x] Separación mapa ↔ generador (`WorldGenModule.generate(request, world)` escribe solo por API pública).
