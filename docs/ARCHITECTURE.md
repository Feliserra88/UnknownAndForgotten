# Arquitectura — U&F (Unknown & Forgotten)

Documento de referencia obligatorio para añadir o modificar módulos de código.
Objetivo: **desacoplar módulos y mecánicas** para que el proyecto escale sin acoplamientos frágiles.

---

## 1. Visión general

Juego **2,5D** en Godot 4.7. La lógica vive en módulos independientes; las escenas orquestan nodos y delegan comportamiento a scripts de módulo.

Principios:

| Principio | Descripción |
|-----------|-------------|
| Un módulo, una responsabilidad | Cada módulo cubre un dominio claro (personaje, combate, inventario…). |
| API pública explícita | Solo la API pública es accesible desde fuera del módulo. |
| Comunicación indirecta | Los módulos no llaman implementación interna de otros módulos. |
| Config y log centralizados | `venv.ini` y el módulo `Log` son la única vía para opciones runtime y trazas. |
| Parametrización sobre especialización | Preferir APIs configurables antes que duplicar módulos o scripts. |
| Motor primero | Consultar la documentación oficial de Godot antes de implementar; usar sus APIs y convenciones de proyecto. |

---

## 2. Documentación oficial de Godot

**Obligatorio** ante cualquier petición de cambio (nueva mecánica, escena, recurso o refactor técnico): consultar primero la documentación existente de Godot para la versión del proyecto (**4.7**) y basar la implementación en ella.

### 2.1 Priorizar APIs del motor

- Usar clases, nodos, recursos y sistemas que Godot ya proporciona (`CharacterBody3D`, `AnimationTree`, `Resource`, señales, grupos, etc.) antes de reinventar soluciones propias.
- Revisar la API concreta (métodos, propiedades, señales) en la documentación de clase correspondiente.
- No reimplementar utilidades que el motor ya cubre (carga de recursos, serialización, física, input, timers, tweening…) salvo requisito explícito documentado.

### 2.2 Respetar la metodología y organización del motor

- Seguir las guías oficiales de **estructura de proyecto**, **escenas vs scripts**, **autoloads**, **recursos** y el patrón recomendado para el dominio (p. ej. 2D/3D, animación, UI, física).
- Ubicar escenas, recursos y scripts según las convenciones de Godot **dentro** de la estructura de este proyecto (`res://modules/`, `res://scenes/`, etc.): la arquitectura U&F adapta el layout del motor, no lo ignora.
- Preferir `.tscn` + scripts pequeños para composición visual; lógica de dominio en módulos según sección 3.

### 2.3 Fuentes de consulta

| Recurso | URL |
|---------|-----|
| Documentación general | https://docs.godotengine.org/en/stable/ |
| GDScript | https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html |
| Organización del proyecto | https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html |
| TileSets / isométrico | https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html |
| TileMaps / terrains | https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html |
| TileMapLayer (API) | https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html |
| Camera2D | https://docs.godotengine.org/en/stable/classes/class_camera2d.html |
| AStarGrid2D | https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html |
| FastNoiseLite | https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html |
| Búsqueda de clases | https://docs.godotengine.org/en/stable/classes/index.html |

Si la documentación oficial recomienda un enfoque distinto al habituado, **prevalece el enfoque de Godot**, salvo conflicto directo con una regla explícita de este documento (en cuyo caso documentar la excepción).

---

## 3. Estructura de directorios

```
res://
├── autoload/              # Servicios globales (Config, Log, EventBus)
├── core/                  # Tipos base, contratos, utilidades compartidas
├── modules/               # Módulos de dominio (un directorio = un módulo)
│   └── <nombre>/
│       ├── <nombre>.gd    # Fachada pública (API del módulo)
│       ├── _private/      # Implementación interna (no importar desde fuera)
│       └── ...
├── scenes/                # Escenas (.tscn): composición de nodos, mínima lógica
├── assets/                # Arte, audio, recursos (tilesets/, world/)
├── locale/                # Traducciones (CSV/PO): claves → en, es, …
└── ui/                    # GUI: theme/, widgets/, panels/, domain/ (ver GAME_DESIGN §10)

addons/                    # Plugins de editor (uf_map_editor, uf_npc_editor, uf_gui_tools)
│   ├── uf_map_editor/     # Editor de mapas → API world / world_gen
│   ├── uf_npc_editor/     # Editor de NPCs → API npc / appearance
│   └── uf_gui_tools/      # Composición paneles GUI

docs/
└── ARCHITECTURE.md        # Este documento

venv.ini                   # Config runtime (clave=valor), raíz del proyecto
```

**Regla de ubicación:** si la funcionalidad pertenece a un dominio ya existente, extiende ese módulo. Crea un módulo nuevo solo si el dominio es distinto y no encaja en ninguno actual (justificación obligatoria en el PR o commit message).

---

## 4. Capas y dependencias

```
┌─────────────────────────────────────────┐
│  scenes / ui  (presentación, nodos)     │
├─────────────────────────────────────────┤
│  modules/*    (mecánicas de dominio)    │
├─────────────────────────────────────────┤
│  core         (contratos, helpers)      │
├─────────────────────────────────────────┤
│  autoload     (Config, Log, EventBus)   │
└─────────────────────────────────────────┘
```

**Dependencias permitidas (solo hacia abajo):**

- `scenes` → `modules`, `core`, `autoload`
- `modules` → `core`, `autoload`, **API pública** de otros `modules`
- `core` → `autoload` (mínimo; preferir sin dependencias)
- `_private/` → solo recursos dentro del mismo módulo

**Prohibido:**

- Importar desde `_private/` de otro módulo
- Lógica de negocio pesada dentro de `.tscn` o scripts de escena (usar módulos)
- `print()` / `push_warning()` directos (usar `Log`)
- Leer config fuera del autoload `Config`

---

## 5. Anatomía de un módulo

Cada módulo tiene:

1. **Identificador** — nombre en snake_case (`character`, `combat`, `inventory`).
2. **Código de log** — 3 letras mayúsculas (`CHA`, `CMB`, `INV`). Registrar en `venv.ini` como `LOG_<MODULO>_LEVEL`.
3. **Fachada pública** — script principal (p. ej. `character.gd`) con métodos y señales expuestos.
4. **Implementación privada** — carpeta `_private/` con lógica interna.

### 5.1 API pública vs privado

| Ámbito | Convención GDScript | Acceso |
|--------|---------------------|--------|
| Público | Sin prefijo `_` en métodos/propiedades exportadas | Cualquier capa superior |
| Privado | Prefijo `_` en funciones, variables y clases internas | Solo dentro del módulo |
| Interno | Archivos bajo `_private/` | Solo el módulo propietario |

La fachada delega en `_private/` y **no expone** tipos internos salvo que formen parte del contrato público documentado.

### 5.2 Contrato de API

Toda función pública debe:

- Tener doc comment con propósito actual (sin historial de cambios).
- Aceptar parámetros que cubran variantes razonables (evitar clones del método).
- Documentar efectos secundarios (señales emitidas, estado modificado).
- Evitar devolver referencias mutables a estado interno.

Ejemplo de fachada:

```gdscript
## Gestiona el ciclo de vida y estado jugable del personaje.
class_name CharacterModule
extends Node

## Aplica daño al personaje identificado por [param id].
## Emite [signal health_changed] si el personaje sigue vivo.
func apply_damage(id: StringName, amount: float, source: StringName = &"") -> void:
	_private.apply_damage(id, amount, source)
```

---

## 6. Comunicación entre módulos

Orden de preferencia:

1. **API directa parametrizada** — llamada a la fachada pública del otro módulo (referencia inyectada o autoload registrado).
2. **EventBus (autoload)** — eventos de dominio (`combat.hit_landed`, `inventory.item_added`) cuando hay muchos suscriptores o desacoplamiento temporal.
3. **Señales de Godot** — entre nodos de una misma escena o subárbol; no sustituyen la API de módulo para lógica cross-domain.

No usar singletons globales ad hoc fuera de `autoload/` aprobados.

### EventBus (cuando se implemente)

- Payload tipado (Dictionary con claves documentadas o Resource).
- Emisor registra evento en `Log` nivel 1; detalle en nivel 2.
- Los módulos no asumen orden de recepción entre listeners.

---

## 7. Autoloads del sistema

| Autoload | Responsabilidad |
|----------|-----------------|
| `Config` | Lee y expone `venv.ini`; recarga en caliente si se define soporte. |
| `Log` | Única salida de trazas; respeta gates por módulo. |
| `Version` | Lee `VERSION` (major/minor/bump) y expone `get_string()` como `X.Y.B`. |
| `WindowPlacement` | Coloca/redimensiona la ventana del juego al arrancar según `GAME_WINDOW_*` en `venv.ini` (solo runtime). |
| `EventBus` | Bus de eventos de dominio (opcional al inicio; reservar nombre). |

Registrar en `project.godot` bajo `[autoload]`. Ningún otro autoload sin actualizar este documento.

---

## 8. Configuración (`venv.ini`)

- Formato: `clave=valor`, una clave por línea; comentarios con `#`.
- **Única fuente de verdad** para opciones modificables en runtime (debug, niveles de log, toggles de mecánicas, etc.).
- Valores por defecto embebidos en `Config` si falta la clave en archivo.
- Las claves de log siguen: `LOG_<MODULO>_LEVEL=0|1|2` (módulo en MAYÚSCULAS, p. ej. `LOG_CHARACTER_LEVEL`).

No duplicar estas opciones en `project.godot` salvo settings editor-only (render, input map).

### Versión del proyecto (`VERSION`)

- Archivo en la raíz: **`VERSION`** (`major`, `minor`, `bump` como `key=value`; también acepta una línea `X.Y.B`).
- Formato mostrado: **X.Y.B**.
- Leer solo vía autoload **`Version`** (no parsear el archivo en módulos).
- Comandos del agente: **`BC`** = incrementar `bump` + commit; **`BCP`** = lo mismo + push (regla `.cursor/rules/bump-commit.mdc`).

---

## 9. Logging

Formato de traza:

```
YYYY/MM/DD hh:mm:ss [COD] tipo mensaje
```

- **COD**: 3 letras del módulo (`CHA`, `CFG`, `LOG`…).
- **tipo**: categoría breve (`init`, `warn`, `err`, `evt`…).
- **Niveles** (gate en `venv.ini`):
  - `0` — silencio
  - `1` — resumen (inicio/fin, errores, eventos relevantes)
  - `2` — detalle (1 traza por evento interno)

API esperada (módulo `Log`):

```gdscript
Log.info("CHA", "evt", "spawn id=%s" % id)      # respeta gate del módulo
Log.detail("CHA", "move", "pos=%s" % pos)         # nivel 2
Log.warn("CFG", "missing key=%s, using default" % key)  # siempre visible si gate >= 1
```

---

## 10. Escenas y 2,5D (stack Godot)

Vista isométrica y mapa según documentación oficial ([Using TileMaps](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html), [GAME_DESIGN.md §2–4](GAME_DESIGN.md)):

| Ámbito | Nodo / API Godot | Notas |
|--------|------------------|-------|
| Mapa isométrico | `TileMapLayer` + `TileSet` (`TILE_SHAPE_ISOMETRIC`) | `TileSet` como recurso externo `.tres` compartido |
| Profundidad 2,5D | `y_sort_enabled` en capas y contenedor `Node2D` | Obligatorio en isométrico |
| Cámara | `Camera2D` en rig `Node2D` | Pan/rotación; zoom e inclinación fijos |
| Coordenadas | **`Vector3i(x, y, z)`** + `MapHeightField` + `map_to_local()` | x/y en `TileMapLayer`; **z** = altura por celda en módulo `world` |
| Pathfinding | `AStarGrid2D` + reglas de **z** en `grid` | Plano x/y nativo; escalado/ desnivel en lógica custom |
| Generación | `FastNoiseLite`, `set_cells_terrain_connect()`, `TileMapPattern`, **`MapHeightField`** | Módulo `world_gen` orquesta tiles + alturas |
| Colisión mapa | Physics layers del `TileSet` en `TileMapLayer` | Preferir colisión 2D de tiles para rejilla |

- Escenas: composición de nodos; lógica de dominio en módulos.
- El proyecto declara **Jolt** (3D) en `project.godot`; reservado para mecánicas 3D futuras. El **mundo isométrico en rejilla** usa el stack 2D anterior salvo decisión documentada en contrario.

Estructura de assets:

```
res://assets/tilesets/     # TileSet .tres, atlas, terrain definitions
res://assets/world/        # Máscaras de bioma, heightfields, TileMapPattern, estructuras
res://assets/data/         # Resources de juego (.tres)
│   ├── archetypes/        # NpcArchetype
│   ├── factions/          # FactionDef
│   ├── items/             # ItemDef
│   ├── effects/           # StatusEffectDef, MaladyDef, TraitDef
│   └── attributes/        # AttributeSet, VitalsTemplate
├── visuals/               # Apariencia modular NPC
│   ├── parts/             # PartVisualDef (base por slot)
│   ├── equipment/         # EquipmentVisualDef
│   └── injuries/          # InjuryVisualDef
res://scenes/npc/          # npc_base.tscn, variantes por PackedScene
res://scenes/world/        # Escena raíz del mapa (capas TileMapLayer + Camera2D)
```

---

## 11. Checklist al añadir o modificar un módulo

Antes de merge:

- [ ] ¿Consultada la documentación oficial de Godot para la funcionalidad (API del motor + metodología recomendada)?
- [ ] ¿Se usan APIs/herramientas nativas de Godot en lugar de soluciones custom equivalentes?
- [ ] ¿Existe ya un módulo con esa responsabilidad? Si sí, extender en lugar de crear.
- [ ] ¿API pública documentada y separada de `_private/`?
- [ ] ¿Sin imports desde `_private/` ajeno?
- [ ] ¿Clave `LOG_<MODULO>_LEVEL` en `venv.ini` (y ejemplo en comentario)?
- [ ] ¿Trazas solo vía `Log`?
- [ ] ¿Opciones runtime solo en `venv.ini`?
- [ ] ¿Alto reuso + fine-tuning artístico? → herramienta de editor planificada (`GAME_DESIGN.md` §11, `editor-artist-tools.mdc`).
- [ ] ¿Actualizado este documento si cambian capas, autoloads o convenciones?

---

## 12. Registro de módulos

Mantener tabla actualizada al crear módulos:

| Módulo | Carpeta | Código log | Clave config | Descripción |
|--------|---------|------------|--------------|-------------|
| Config | `autoload/config.gd` | CFG | `LOG_CONFIG_LEVEL` | Lectura de `venv.ini` |
| Log | `autoload/log.gd` | LOG | `LOG_LOG_LEVEL` | Sistema de trazas |
| World | `modules/world/` | WLD | `LOG_WORLD_LEVEL` | Tile (`TileDef`, flags, reglas por lado, modificadores), `MapHeightField`, capas `TileMapLayer`, consultas de paso/visión/cobertura |
| World gen | `modules/world_gen/` | WGN | `LOG_WORLD_GEN_LEVEL` | `BiomeDef`, `WorldGenRequest`, generador con solver de restricciones (agua redondeada, caminos conectados); bioma `field` placeholder |
| Camera | `modules/camera/` | CAM | `LOG_CAMERA_LEVEL` | Rig `Node2D` + `Camera2D` (pan/rotación; actores erguidos). Rotación inicial: `CAMERA_DEFAULT_ROTATION_DEG` o auto desde `WORLD_TILE_*`. |
| NPC | `modules/npc/` | NPC | `LOG_NPC_LEVEL` | `NpcArchetype` (cadena de datos), `NpcInstanceData`, spawn; cadena `npc`→`humanoid`→`human` |
| Appearance | `modules/appearance/` | APP | `LOG_APPEARANCE_LEVEL` | `BodyPartMap`, `PartVisualDef`, `NpcAppearanceController` (rig modular por slot) |
| Attributes | `modules/attributes/` | ATR | `LOG_ATTRIBUTES_LEVEL` | `AttributeSet`, `VitalsTemplate`, `NpcVitals` |
| GUI | `modules/gui/` | GUI | `LOG_GUI_LEVEL` | `UfPanel` movible + especializados (`UfInfoPanel`, `UfDialogPanel`, `UfTabbedPanel`), widgets `Uf*` (`modules/gui/widgets/`), theme; fachada `GuiModule` que crea paneles y carga assets de `ui/domain/` |
| Editor de mapas | `addons/uf_map_editor/` | — | — | `EditorPlugin` sobre API `world`/`world_gen`: generar, pintar tiles, editar altura, guardar presets/mapas |
| Herramientas GUI | `addons/uf_gui_tools/` | — | — | `EditorPlugin` sobre API `gui`: compone paneles de dominio (`UfPanel` + widgets) y los guarda como `PackedScene` en `res://ui/domain/` |

Core compartido: `core/direction.gd` (`Direction`, enum N/E/S/W). Herramienta de build de assets placeholder: `tools/asset_builder.tscn` (genera `.tres` reutilizables en `res://assets/`).

---

## 13. Referencias

- Reglas Cursor: `.cursor/rules/` (coding, módulos, config, log).
- Documentación Godot 4.x: https://docs.godotengine.org/en/stable/
- Diseño de juego y herramientas de artista: `docs/GAME_DESIGN.md` §11
