# Terraform Brush

The Terraform Brush is the map editor built into Beyond All Reason. It sculpts terrain, paints the ground, places features, units, lights, decals, start positions and weather, sets up the sky, sun, fog and water, and saves the whole map as a project you can open again later. Everything happens live in a running game, so you see the result exactly as players will.

What changed in each release is listed in [TerraformBrush-changelog.md](TerraformBrush-changelog.md).

## Getting started

### Opening the editor

The editor changes the map for everyone in the game, so it needs cheats. There are two ways in:

- **A map editor session.** A game started with the **Map Editor Session** game option opens the editor on its own once the game loads.
- **Any game where you can use cheats** (a skirmish or singleplayer game you host). Type `/cheat`, then `/terraformbrush`. The editor turns cheats on by itself when it can, so `/terraformbrush` alone usually works.

New Map and Open Project (in the FILE menu) restart the game onto the new canvas or the project and bring the editor up by themselves, already in RAISE. `/terraformpanel` shows or hides the panel.

### The panel

The panel is one window with a header and folding sections. Click a section title to fold or unfold it.

| Header button | What it does |
|---|---|
| Pause | Stops every editor tool and hands the keyboard and mouse back to the game. Click again (or any mode button) to resume |
| Eye (Focus mode) | Hides the game interface the way F5 does, but keeps the editor, its brush preview and overlays working. Click again, close the panel or press F5 to bring the interface back |
| X | Closes the editor |
| Folder (FILE) | New Map..., Save, Save As..., Open Project... |
| Map Labels | Shows the map comments and opens the Map Labels window |
| Camera | Opens the Capture window |
| Speaker | Turns the panel's sounds on or off |
| ? (Guide mode) | Shows a hint for whatever control is under the mouse |
| Gear | Opens Settings |

**Sections**

- **TERRAIN**: the sculpting modes RAISE, LOWER, MODIFY, RAMP, RESTORE and NOISE (see [Sculpting](#sculpting)).
- **TOOLS**: SURFACE (or DIFFUSE), LAYERS (or SPLAT), METAL, FEATURES, GRASS, DECALS, UNITS, WEATHER, LIGHTS, STARTS, CLONE and SCENE.
- Below these, the sections of whichever tool is active: usually PLACEMENT MODE, DISPLAY, INSTRUMENTS, FILTERS, CONTROLS, UNDO & REDO and SAVE & LOAD.

Under the header, the status strip shows what the active tool is doing and how a save is going.

Some tools open floating windows (the libraries, Noise Parameters, every SCENE window, TILESET, Settings, Capture). They stay open while you switch tools, drag by their title bar, and remember where you left them. The brush does not paint through the panel or any of these windows: it steps aside while the mouse is over them.

### Common controls

**Mouse wheel with a modifier** changes the brush while you work. The same modifier with `[` or `]` steps the value one notch.

| Hold | Wheel changes |
|---|---|
| Ctrl | Size |
| Alt | Rotation |
| Shift | Fall-off |
| Space | Intensity |
| Ctrl+Alt | Length |
| Ctrl+R | Ring width (ring shape) |
| Alt+Shift | Height cap maximum |
| Left Alt+A | Protractor spoke |

Some tools use the same modifiers for their own values; each slider's row shows its wheel shortcut. Every one of these keys can be changed in Settings > Keybinds.

**Sliders**

- Every slider has a number box: type a value and press Enter.
- **Wheel lock**: double middle click a slider to tie it to the mouse wheel. Several can be locked at once. Double middle click it again, or click it, to let go; Esc lets go of all of them. A line at the top of the panel lists what is locked.
- **DYNAMIC** (on many sliders) opens a small transport: the arrows animate the slider back or forward, a second click on the same arrow speeds it up (up to 4x), a right click slows it down, and the middle button starts or pauses it. Space pauses or resumes every running slider.
- **SAMPLE** (next to height and altitude sliders): click it, then click the map to copy that ground height into the slider. With the Height Map overlay on you can click a contour line or the peak number instead.

**Keyboard while editing**

- While an editor tool is in use, the game's own hotkeys (unit orders, build keys, selection, control groups) are held back so they do not fight the editor's keys. The camera, chat, Esc, the F-keys, screenshots, pause and the console still work. The Pause button in the header hands every key back.
- `Ctrl+Z` undoes and `Ctrl+Shift+Z` redoes in most tools. Each tool's UNDO & REDO section has buttons for both and a history slider you can drag back and forth.

**Camera.** While a sculpt stroke runs, the camera holds still instead of riding the ground you are changing. It moves again as soon as you pan, zoom, rotate or switch camera.

### Projects and saving

A **project** is the whole map in one folder: terrain, paint, metal, features, units, lights, decals, start positions and boxes, grass, weather, comments, the scene settings and the tileset settings. Projects live in `MapProjects/` in the game's data folder.

| FILE menu | Shortcut | What it does |
|---|---|---|
| New Map... | | Opens the New Map window (see [New Map](#new-map)) |
| Save | Ctrl+S | Saves into the project you opened or last saved. The menu item names it |
| Save As... | Ctrl+Shift+S | Saves under a new name or into another folder |
| Open Project... | Ctrl+O | Opens the Projects window |

The shortcuts work while the panel is up and no text field has the keyboard.

**Projects window.** One list of your projects with a search box, sortable columns, a folder tree and a details pane with the project's minimap, size and dates. Filter chips switch between all projects, those on this disk and the Autosaves. Rows drag between folders. RENAME (or F2), NEW FOLDER and DELETE (asks twice) work in place; Up, Down, Enter, Esc and double click work as in a file browser. Projects may sit in subfolders of `MapProjects/` up to four levels deep, so a cloned maps repository placed there lists as it is.

Opening a project restarts the game onto a blank map of the project's size and then rebuilds every part of it, which takes a moment.

**Save As window.** The same browser with a NAME box. Click a folder to save into it; the summary says whether the save creates a project or writes over one. The **Units loadout** switch saves every unit's position and team with the project. Plain Save keeps whatever the project already had.

**Unsaved changes.** The editor knows when the map has changed since the last save. Opening another project, New Map and the top bar's Quit ask first: save, don't save, or cancel. The game window's own close button cannot be caught; autosave covers that case.

**Autosave** (Settings > General, on by default). While the open project, or a New Map canvas, has unsaved changes, a snapshot is saved every 10 minutes into `MapProjects/_autosave/` as `<project>-YYYYMMDDHHMM`. Snapshots list only under the Autosaves chip of the Projects window. Opening one makes its project the Save target again. Old snapshots are deleted after 3 days, except the newest one of each project, which is kept for 10 days. All three numbers can be changed in Settings.

**Team Sync** (Settings > General, off by default) shows the BAR campaign team's private map library in the Projects and Save As windows. It needs access to the team's private repository; leave it off otherwise. The team's workflow is documented in the library repository.

## Sculpting

The TERRAIN section holds the sculpting modes. Left drag applies the mode; right drag lowers while held and goes back to the previous mode when you let go.

| Mode | Key | What it does |
|---|---|---|
| RAISE | LMB | Raises the ground under the brush |
| LOWER | RMB | Lowers the ground under the brush |
| MODIFY | L | SMOOTH, LEVEL or SMUDGE (L cycles them) |
| RAMP | R | Straight, Spline or Auto ramps (R switches between RAMP and AUTORAMP) |
| RESTORE | E | Puts the map's original height back |
| NOISE | N | Adds procedural noise |

### MODIFY: Smooth, Level, Smudge

- **Smooth** pulls the ground toward the average height around each point, flattening bumps while keeping the broad shape.
- **Level** flattens to the height where you first clicked. That height stays fixed for the whole stroke.
- **Smudge** drags the ground along the stroke like a finger through clay. Intensity sets how long the smear lasts.

### RAMP: Straight, Spline, Auto

- **Straight**: drag from the start to the end of the slope. Length sets how wide the ramp tapers.
- **Spline**: drag along any curved path; the ramp follows it.
- **Auto (AUTORAMP)**: click an existing cliff and it is rebuilt at a chosen angle, with wavy lips, erosion gullies and a scree fan at its base. Hold the mouse button and drag along a cliff to restyle the whole line in one stroke.

AUTORAMP controls: **Preview** shows the result under the cursor before you click (green where ground is added, orange where it is cut). **Cliff start**: Extend keeps the top lip, Subtract the bottom lip, Average pivots on the middle. **Angle** of the new face (10 to 85 degrees, default 60), **Falloff** (how softly it meets the ground above and below), **Edge noise** (how much the line meanders), **Erosion** (depth of the gullies) and **Buildup** (size of the scree fan).

### RESTORE

Brushes the map back toward its original heights. **RESTORE** (0 to 100%) sets how far each pass goes back. The **FULL RESTORE** button (click twice) puts the whole map back at once; it can be undone like any stroke.

### NOISE

Selecting NOISE opens the **Noise Parameters** window. The brush shape, size and fall-off shape where the noise lands.

| Control | Range | Default | What it does |
|---|---|---|---|
| NOISE TYPE | Perlin, Voronoi, FBM, Billow | Perlin | Perlin: smooth rolling hills. Voronoi: cells and cracks. FBM: layered natural detail. Billow: soft rounded mounds |
| SCALE | 8 to 512 | 64 | Size of a noise cell in elmos |
| OCTAVES | 1 to 8 | 4 | Layers of finer detail |
| PERSISTENCE | 0.1 to 0.9 | 0.5 | How strong each finer layer is |
| LACUNARITY | 1.0 to 4.0 | 2.0 | How much finer each layer is |
| SEED | 0 to 9999 | 0 | Picks a different pattern; RANDOM rolls a new one |

### Shapes

The SHAPE section is shared by the sculpting modes and most other tools.

| Shape | Key | Notes |
|---|---|---|
| Circle, Square | C, S | Stretch into an ellipse or rectangle with LENGTH |
| Hexagon, Octagon, Triangle | H, O, T | |
| Ring | | Hollow: only the band between RING WIDTH and the edge changes. Ctrl+R+Wheel sets the width |
| Fill | | Click inside an enclosed shape on the map to fill it: flat when the walls are level, a smooth surface when they vary |

S and T pick the square and triangle while a terrain mode is active; from any other tool they open SURFACE and LAYERS.

**CLAY** (X) lays flat layers of `INTENSITY x 8` elmos instead of a dome, so strokes build plateaus. With **Settings > Stroke > Clay build-up** on (the default), holding the brush keeps stacking layers; with it off, one stroke lays exactly one layer over the ground it started on.

**FOLLOW STROKE** turns the brush shape to face the direction you drag, so a square or hexagon leaves a ribbon with its flat side along the path. It is offered in the sculpting modes.

### CONTROLS

The chips at the top of CONTROLS show or hide each slider row.

| Slider | Range | Default | Wheel |
|---|---|---|---|
| ROTATION | 0 to 359 degrees | 0 | Alt |
| INTENSITY | 0.1 to 100 | 1.0 | Space |
| SIZE | 8 to 2000 elmos | 100 | Ctrl |
| RING WIDTH | 5 to 95% | 40% | Ctrl+R |
| LENGTH | 0.2 to 5.0 | 1.0 | Ctrl+Alt |
| FALL-OFF | 0.1 to 5.0 | 1.0 | Shift |

- Low FALL-OFF gives a gentle dome; high FALL-OFF gives a flat top with a sharp edge. **SHOW** draws the fall-off curve inside the brush.
- **~Velocity** scales intensity by how fast you drag.
- **Pen** chips appear on INTENSITY and SIZE when pen pressure is on (Settings > Stroke) and turn it on or off for that value.
- **STAMP** lights up when intensity is at its maximum and a height cap is set. The stroke then lands in one step: raise goes straight to the max cap, lower straight to the min cap, and dragging applies once per new position.

### HEIGHT CAP

Keeps the brush inside a height band.

- **Enabled** turns the caps on or off without losing the values.
- **Absolute** makes Max and Min real heights; without it they are offsets from where the stroke starts.
- **Max** and **Min** have SAMPLE buttons. The sliders follow the map's own height range.

### PRESETS

Type a name and press **Save** to keep the current brush settings. **Browse** opens the list (typing filters it, X deletes your own presets). **Restore Defaults** resets the brush.

Built-in presets: Ditch Digger, Sandworm, Crater, Mesa, Ball, Moat, Badlands, Clay Sculpt, Dunes, DuneMaker.

### HEIGHTMAP

- **Save Heightmap** writes a 16-bit greyscale PNG (black is the lowest point, white the highest) with a small `.txt` file holding the height range, into `Terraform Brush/Heightmaps/`.
- **Load Heightmap** lists the PNGs in that folder and applies one. PNGs copied there from elsewhere list too.
- The range chip cycles **AUTO** (the terrain as it is now), **INITIAL** (the map as it loaded) and **CUSTOM** (your own MIN and MAX; **FIT** snaps them to the terrain's exact extremes).

### Erode (console only)

`/terraformerode` starts a thermal erosion brush and shows its EROSION section: slopes steeper than **REPOSE ANGLE** (10 to 60 degrees) shed material downhill.

## Painting the ground

Which pair of painting tools leads the TOOLS grid depends on how the ground is drawn:

- On maps drawn by the **tileset shader**: **SURFACE** and **LAYERS**, plus the **TILESET** window in SCENE.
- On maps with their own baked textures: **DIFFUSE** and **SPLAT**.

The tileset shader is not part of the game download. When it is installed, the editor switches it on together with itself; its master switch is ACTIVATE SHADER in the TILESET window.

### SURFACE

Paints the soft top materials of the active biome (sand, grass, gravel and so on) over the automatic ground. Cliffs and the intermediate layer belong to LAYERS; SURFACE never touches them.

- **SURFACE PALETTE**: BASE plus seven variant slots. Click a slot to paint with it, PICK opens the texture library for that slot, x clears it. **FLIP** flips the selected slot's normal map. Alt-click the map to pick up the material under the cursor.
- **BRUSH**: DOT (small and light, for dotting variants in), WASH (large and faint), FILL (full strength, hard edge) and ERASE (gives the ground back to the shader's automatic choice; right click always erases). Size, Strength, Falloff, **Spacing** (0 paints continuously, otherwise one stamp every N elmos) and **Scatter**, Sc Size, Sc Str (random position, size and strength per stamp; with spacing near one and a half brush widths one drag lays a field of dots).
- **FILTERS**: Avoid Water, Avoid Cliffs, Alt Min, Alt Max (with SAMPLE), Max slope. Filtered ground is skipped point by point.
- **INFLUENCE**: an altitude band and a slope band, each with a feather, that fade a stroke out instead of cutting it. SURFACE remembers a profile per texture; **Copy to all** stamps it onto every slot.
- **FILL AND SEED**: **FILL WITH NOISE** seeds the whole map from the tileset's noise field using the slots whose V chip is on, as a starting point to erase and adjust. CLEAR VARIANT and CLEAR ALL ask for a second click.
- **AUTOMATIC DEPOSIT**: picks a slot that collects on its own like wind-blown sand: on slopes facing away from **Wind from** (0 is north, 90 east) and in hollows, wherever nothing was painted. 0 turns it off.
- **SCULPTED FEATURES**: notes for tilesets that tag their sculpted layers.
- **GRADING**: a tint for the selected slot only, and tint and desaturate controls for all tops together and for the rock (intermediate and cliff) together.
- **Ctrl (sneak peek)**: hold Ctrl to see the selected material inside the brush ring as if the stroke had landed.

### LAYERS

Forces a hard material anywhere through the tileset shader's override channels.

| Channel | Key | What painting it does |
|---|---|---|
| AUTO | 1 | Removes the override: the shader's slope-based choice returns |
| INTERMEDIATE | 2 | Intermediate (scree) material, whatever the slope |
| CLIFF | 3 | Cliff rock, whatever the slope |
| PLATEAU | 4 | Plateau material, whatever the height |

Left drag paints the selected channel, right drag erases it. FILTERS and INFLUENCE work as in SURFACE (LAYERS keeps one influence profile per channel). The DISPLAY row adds a **Layer Map** chip. **SAVE SPLATS** exports the override texture to `Terraform Brush/Splats/`.

### TILESET window

Opened from SCENE. It holds the tileset shader's settings and stays open while you use any tool. Every section has its own RESET.

| Section | What it holds |
|---|---|
| Top row | ACTIVATE SHADER (off hands the ground back to the map's own textures), PAINT SURFACES (opens SURFACE), OLD SORT and NEW SORT (3 LAYERS): two ways of placing the layers. Each biome opens in the sort it was tuned for |
| BIOME LIBRARY | Swaps all four terrain layers to another biome live. **Skybox matches biome** also changes the sky |
| PERFORMANCE | HIGH, MEDIUM and LOW quality presets, and the individual levers under them |
| METAL SPOTS | The look of the ground wherever METAL laid metal: style, a glow light per spot (intensity, radius, height, colour) and the band of rubble around each spot |
| SCALE, NORMALS | Texture scale and normal map strength of each layer |
| INTERMEDIARY / CLIFF NORMALS, INTERMEDIARY / CLIFF COLOR, ANGLE: NORMALS, ANGLE: ALBEDO / ROUGHNESS, TOP COLOR | NEW SORT only: flips, strengths, colour shifts and the slope angles where each layer starts |
| CLIFFS & FOOTHILLS, LAYER PLACEMENT, EXTRA LAYER | OLD SORT only: where cliffs, foothills and the intermediate layer begin, and an optional fourth material |
| BLEND & DETAIL | How painted layers punch through, parallax depth, large-scale variation, height blending |
| CURVATURE, LIGHTING | Light on ridges and shade in hollows; shadow mode |
| WATER | Shallow water tint and clarity, walkable depth, a glow on deep floors |
| OLD-MAP BLEND | How much cliffs borrow the colours of the map's own texture |
| BIOME TINT, LAYER TINTS | One tint over the whole biome; a tint per layer |
| WORLDSPACE TINT (WIP) | Tinting by world height: WET SHORE, AXIS, GRADE, STRATA, GRADIENT STOPS, COLOUR, RAMP (a gradient image from `LuaUI/Config/TilesetRamps/`), SATURATION, TIDE RINGS, SNOW LINE |
| DEBUG | Debug views of the shader's inputs |
| CONFIG & PRESETS | Save and Browse presets (one file each in `Terraform Brush/TilesetPresets/`, loading one also switches to its biome), Restore Defaults, Dump Config (prints the settings to the console) |

The tileset settings are saved with a project.

### DIFFUSE

Paints the map's own colour texture in layers, like an image editor. Picking the tool opens the **Material Library** (textures from `Terraform Brush/textures/`, an optional texture pack).

- **BRUSH**: SIZE, STRENGTH, FALL-OFF, FRACTAL EDGE and FRACTAL FREQ (a ragged brush edge), Erase.
- **BLEND & EFFECTS**: blend mode (Normal, Multiply, Screen, Overlay, Soft Light, Color Dodge, Hard Light, Difference), MATERIAL CHANNELS (also paint the material's Normals, Specular and Emissive), SPEC INTENSITY, LAYER GLOW, HYDRO EROSION and THERMO EROSION (weathering effects on the paint).
- **LAYERS**: up to 8 paint layers. + ADD LAYER, REMOVE. GRASS with **Attach** plants grass along each stroke.
- **ACTIONS**: CLEAR TEXTURE (paint flat colour), BAKE FULL MAP, RESET PAINT, EXPORT SQUARES (PNG) for repacking into a map file.

### SPLAT

Paints the four detail-texture channels of a map's splat distribution.

- **TEXTURE CHANNEL** 1 to 4 (keys 1 to 4). **SPLAT TEX PARAMS** opens a window with each channel's texture multiplier and scale.
- DISPLAY adds a **Splat Map** chip.
- CONTROLS: STRENGTH, INTENSITY, SIZE, ROTATION, FALL-OFF, FRACTAL EDGE, FRACTAL FREQ.
- **SAVE SPLATS** writes the texture to `Terraform Brush/Splats/`; the chip beside it cycles PNG, DDS and TGA.
- On a New Map canvas SPLAT needs a detail texture pack (DNTS) in `Terraform Brush/textures/dnts/`.

### METAL

Paints where metal extractors earn.

- **PLACEMENT MODE**: **Paint** (left adds, right removes), **Stamp** (one click lays a complete metal spot; right click erases one) and **Remove**.
- **Metal Value**: 0.01 to 50, default 2.0 (a standard spot).
- CONTROLS: SIZE, ROTATION, LENGTH, FALL-OFF. When the brush is wider than an extractor can reach, Stamp draws an inner circle where the metal actually lands.
- **DISPLAY** adds **Metal Map**, **Inspector**, **Clusters** (with GRANULARITY), **Lasso** (draw a loop to total the metal inside it) and **Balance Axis** (X Axis, Z Axis or a placed axis at any ANGLE; shows the metal on side A, side B and the balance).
- **SAVE & LOAD** writes metal maps to `Terraform Brush/MetalMaps/`. The clean button removes all metal (click twice).

New spots are found by the game's extractor tools a moment after a stroke ends. The look of the ground at metal spots on tileset maps is set in TILESET > METAL SPOTS.

### GRASS

- **PLACEMENT MODE**: **Paint** (left grows grass toward DENSITY, right removes), **Fill** (one click sets the whole brush area), **Remove**.
- **FILTERS** add a **Color** filter: pick a ground colour with the pipette and grass only grows where the ground matches it. **EXCLUDE** picks a colour to keep clear; TOLERANCE and EDGE PAD set how strict it is.
- CONTROLS: Density (0 to 100%), SIZE, LENGTH, ROTATION, FALL-OFF.
- **GRASS CONFIG** opens a window for grass colouring (Map Color Factor, Map Color Base, Grass Brightness), the blade and colour-mod textures, and EXPORT CONFIG (to `Terraform Brush/GrassConfig/`).
- **SAVE GRASS MAP** writes `<map>_grassDist.tga` into the data folder, ready to ship with a map. LOAD GRASS MAP reads it back; CLEAN GRASS removes all grass.

## Placing things

The placing tools share a pattern: pick something in a library window, choose a PLACEMENT MODE (Scatter, Point or Remove), and set the brush in CONTROLS. With nothing picked, FEATURES and UNITS select and move what is already on the map instead.

### FEATURES

Trees, rocks, crystals, wrecks and other props. Picking the tool opens the **Asset Library**: category chips, a search box, and `Ctrl+click` to add or remove a tile from the pick, `Shift+click` to add every tile from the last one clicked. Placement draws from all picked features. Geothermal vents are in the library too (search `geovent`): they make working geo spots on any map.

The brush shows the exact features it is about to place as see-through models. The layout keeps its shape while you move and re-rolls after each stamp; **Reroll Preview** re-rolls it without placing.

**PLACEMENT MODE**: **Scatter** places COUNT features inside the brush with each stamp, repeating at RATE while you drag. **Point** places one at the cursor per click. **Remove** erases features under the brush.

**DISTRIBUTION**: Random, Regular (even spacing) or Clustered. Clustered adds CLUMPS (0 picks a number from the count), CLUMP SIZE, STRAGGLERS (the share scattered between clumps) and CLUMP VARIETY (how different the clumps are, from dense thickets to open groves). Large features gather in the clump cores, small ones at the edges.

**FILTERS**: Avoid Water, Slope (Avoid Slopes above MAX SLOPE, or Prefer Slopes above MIN SLOPE) and Altitude (Min and Max with SAMPLE). With filters on, the brush shows a grid of where placement is allowed (green) and refused (red).

| CONTROLS | Range | Wheel |
|---|---|---|
| SIZE | 8 to 2000 | Ctrl |
| ROTATION | 0 to 359 degrees | Alt |
| SCALE MIN, SCALE MAX | 0.1x to 5x | Shift sets one fixed scale for both |
| COUNT | 1 to 500 | Ctrl+Alt |
| RATE | how often a drag stamps | |
| RANDOMIZE ALIGNMENT | 0 to 100% of a full turn | |
| RANDOMIZE TILT | 0 to 45 degrees | Alt+Shift |
| HEIGHT OFFSET | -500 to 500 elmos | Ctrl+Shift |

Most scaled features come out small with a few large, like a natural stand. Tilt leans each feature in a random direction, most nearly upright. Scale, tilt and height are kept by undo, saves and projects.

**Selecting and moving.** With nothing picked in the library:

- Click a feature to select it, Shift+click to add or remove one, drag on empty ground to box select, click empty ground to clear.
- Ctrl+A selects everything on screen; Delete or Backspace removes the selection; Esc clears it, a second Esc leaves the tool.
- Right click drops the library pick, so the mouse selects again.

A gizmo on the selection moves it (arrows and the centre handle) and turns it (rings). Grid Snap limits the move and the Protractor limits the turn. SELECTION also has Select Visible, Clear and Delete buttons.

**SAVE & LOAD** writes feature layouts to `Terraform Brush/FeatureMaps/` (see [File formats](#file-formats)). CLEAR removes every feature placed this session and cannot be undone.

### UNITS

Places real units, to lay out a base, a battle or a scene. Picking the tool opens the **Unit Library**.

**The panel**

- **PLACEMENT MODE**: Scatter, Point or Remove, **Library** (reopens the window) and the **TEAM** chip (click to cycle the team new units join).
- **Live units / Mission units**: live units are normal units. Mission units are stand-ins for a mission: frozen, neutral, taking no orders, each with a mission team number (0 to 15) that the TEAM chip cycles and a coloured ring under it. A project saves them with their team for the mission editor. **All to mission** and **All to live** convert every unit on the map in one undo step.
- **SELECTION**: Select Visible, Clear, Delete, TURN. **FORMATION**: Tighter and Looser pack or spread a selection, or set the spacing of the next drag (Alt+Z and Alt+X do the same).
- DISPLAY, INSTRUMENTS (Grid Snap, Measure, Symmetry), FILTERS, DISTRIBUTION and CONTROLS work as in FEATURES. **SAVE & LOAD** writes unit layouts to `Terraform Brush/UnitMaps/`.

**Placing**

- Click places one unit; drag lays out several. **Tab** cycles the layout (SINGLE, LINE, SNAPLINE, GRID, BOX) and **R** turns the units a quarter turn (Shift+R back).
- The game's build-drag keys apply: Shift drags a line, Shift+Alt a grid, Shift+Alt+Ctrl a box. Footprints are outlined, red where the ground refuses.
- The tool stays armed after each placement. A right click lets go.
- With nothing picked, units select and move as in a game. A selection of two or more gets a loop; press inside the loop to drag the group.
- Ctrl+Z undoes a whole placement; Ctrl+Y or Ctrl+Shift+Z redoes.
- On a selection: Ctrl+C, Ctrl+X and Ctrl+V copy, cut and paste; Ctrl+A selects all visible; Delete or Backspace deletes; R and Shift+R turn it.
- Esc clears the selection, then drops the pick.

**The Unit Library** (shared with the mission editor)

| Part | What it does |
|---|---|
| Search | Names and tags as you type, for example `t2 arty cor`. Arrow keys move, Enter picks, Esc closes |
| FILTERS | Rows for FACTION, TIER, MOBILE, BUILDING, ROLE and DOMAIN. Click a chip to keep only that value, Shift+click to combine values in a row, click the row's label to clear it. Each chip shows how many units it would leave |
| SORT | NAME, POWER (metal plus energy divided by 60), TYPE, SIZE, TIER, SPEED, RANGE, HEALTH. Click the active sort again to reverse it |
| Grid keys | Q W E R, A S D F, Z X C V pick from the first three rows. The pause button in the window gives those letters back to the game |
| Several units | Ctrl+click adds or removes a tile, Shift+click adds a range. Each placement then uses the next unit, in order (A B C) or at RANDOM |
| RECENT | The units picked last |
| BLUEPRINTS | Saved groups of units (`LuaUI/Config/UnitBlueprints/`). Picking one arms the whole group; x deletes the file |

The library remembers its filters, sort and folded sections.

### STARTS

Start positions and start boxes.

| Submode | What it does |
|---|---|
| Express | Click to place start positions, drag a marker to move it, right click removes the last one. With symmetry on, each copy takes the next player |
| Shape | Lays out positions in a shape: Ally Teams (2 to 32), Teams / Ally (1 to 16), Positions, Size, Rotation, SHAPE (Circle, Square, Hex, Tri), RANDOM POSITIONS |
| Startbox | Draws start boxes. **Box**: drag a rectangle. **Polygon**: click vertices, right click to finish. **Free**: draw freehand. Drag vertices to reshape |
| Roles | Gives each start position a role: left click for the next role, right click for the previous |

- **SAVE** and **LOAD** use `Terraform Brush/StartPositions/` and `Terraform Brush/Startboxes/`.
- **COPY** puts `!bset` commands for the start boxes and position suggestions on the clipboard, to paste into a lobby.
- **EXPORT** writes the start position suggestions to `Terraform Brush/StartPositions/Suggestions/`.
- CLEAR ALL removes every start position and start box. Ctrl+Z undoes within the current submode.

### LIGHTS

Places map lights.

- **LIGHT TYPE**: Point, Cone, Beam. **PLACEMENT MODE**: Single, Scatter, Remove. **DISTRIBUTION** for Scatter.
- **CONTROLS**: BRIGHTNESS (Space+Wheel), LIGHT RADIUS (10 to 5000), ELEVATION above the ground (0 to 2000, Shift+Wheel), DIRECTION (N, E, S, W, Pitch and Yaw for cones and beams: Alt+Wheel turns yaw, Ctrl+Alt+Wheel pitch), Spread (cone), Length (beam), and the SCATTER count and brush radius.
- **COLOR**: swatches and red, green, blue sliders.
- **LIGHT LIBRARY** opens built-in presets and your own. Placed lights can be saved there as a user preset.
- **SAVE** writes all placed lights to `lightmaps/` in the data folder; **LOAD** reads one back; CLEAR ALL removes every light.
- Ctrl+Z undoes, Ctrl+Y or Ctrl+Shift+Z redoes.

### DECALS

Ground decals: scars, scorch marks, tracks, footprints and more.

- Picking the tool opens the **Decal Library**: category chips, search, `Shift+click` to pick several.
- **PLACEMENT MODE**: Scatter, Point, Remove.
- **CONTROLS**: SIZE, ROTATION, RANDOMIZE ALIGNMENT, COUNT (Shift+Wheel), RATE, DECAL MIN and DECAL MAX (size of each decal, 4 to 1024), ALPHA, **Align to terrain normal**.
- **SAVE & LOAD** uses `Terraform Brush/DecalMaps/`. Ctrl+Z undoes, Ctrl+Y or Ctrl+Shift+Z redoes.
- `/decalcapture <name> [radius]` captures a top-down picture of the ground as a new decal. Restart the game to use it.

### WEATHER

Persistent weather effects: rain, snow, dust and others.

- Picking the tool opens the **Weather Library**: PRESETS, ALTITUDE, and a CEG BROWSER for any effect in the game.
- **PLACEMENT MODE**: Scatter, Point, Remove.
- **CONTROLS**: SIZE, LENGTH, ROTATION (the direction the weather moves), COUNT, RATE, **PERSISTENCE** (from Off to Permanent).
- **CLEAR ALL EFFECTS** removes every effect. The weather tool has no undo.

### CLONE

Copies a part of the map, with everything on it, and pastes it elsewhere.

1. Drag a box on the map.
2. **COPY** (Ctrl+C) takes what is inside it.
3. **PASTE** (Ctrl+V) shows the copied terrain at the cursor, lit and textured. Click to place it; you can paste as many times as you like.

| While pasting | Action |
|---|---|
| Alt+Wheel | Rotate (ROTATION slider) |
| Shift+Wheel | Raise or lower (HEIGHT OFFSET, -500 to 500) |
| Shift+X, Shift+Z | Mirror east-west or north-south |
| Esc | Cancel |
| Ctrl+Z, Ctrl+Shift+Z | Undo, redo |

- **INCLUDE LAYERS** picks what travels: Terrain, Metal, Features, Splats, Surface (the SURFACE paint), Grass, Decals, Weather, Lights.
- **PASTE MODE**: **Replace** lays the copy down as it is. **Raise only** keeps only what stands above the ground at the target, **Lower only** only what lies below; the other layers then come along only where the terrain does.
- **TERRAIN QUALITY**: Full (every point at full precision), Balanced (whole-elmo heights), Fast (a coarser grid, filled in).
- **PREVIEW OPACITY** sets how solid the paste preview looks (0 shows the outline only).
- Symmetry and Grid Snap apply to the paste.

## Scene

The **SCENE** tool (V) is a menu of floating windows for everything that is not painted on the ground. Each window stays open while you switch tools, and each section has a RESET.

| Window | What it holds |
|---|---|
| SKYBOX LIBRARY | Click a thumbnail to change the sky. **Fade transition** crossfades. SKYBOX ROTATION (angle and axis), DYNAMIC SKYBOX ROTATION (speed per axis, PLAY, PAUSE, **Sync sun to skybox**). Add your own DDS skyboxes to `Terraform Brush/SkyBoxes/` |
| SUN & SHADOWS | SUN DIRECTION as azimuth (0 is north, 90 east) and elevation, or as a vector; SUN INTENSITY; PRESETS; SHADOW DENSITY for ground and units; SUN COLOR |
| FOG & ATMOSPHERE | FOG DISTANCE (start, end), FOG COLOR, SKY COLOR, CLOUD COLOR, SNOW (density, speed, size, wind, opacity, auto-reduce for frame rate) |
| GROUND LIGHTING | Ground ambient, diffuse and specular colours |
| UNIT LIGHTING | Unit ambient, diffuse and specular colours |
| MAP RENDERING | Render toggles (sky, water, ground), deferred rendering, map parameters (detail normals, void water, void ground) |
| WATER | WATER TYPE (Default, Ocean, Lava, Acid, Swamp, Ice), FLUID LEVEL, toggles, WATER COLORS, SURFACE, MATERIAL, FRESNEL, PERLIN NOISE, BLUR & WAVES |
| DIMENSIONS | MAP TRANSFORM, HEIGHT EXTREMES, WATER LEVEL, HEIGHT RANGE (see below) |
| TILESET | The tileset shader's settings (see [TILESET window](#tileset-window)) |

**Sun PRESETS.** Sun-only presets are times of day. Map moods and your own saved files also carry fog, sky, water and skybox; **SUN ONLY** applies just their sun, **FULL ENVIRONMENT** all of it. **Save** writes the whole live environment under a name to `Terraform Brush/Environments/`, so a look carries to any map.

**SAVE SCENE / LOAD SCENE** (at the bottom of the SCENE tool) write the current environment to `Terraform Brush/Lightmaps/<map>_environ_<time>.lua`, and load the newest one for this map.

The scene is saved with a project.

### DIMENSIONS

**MAP TRANSFORM** turns, flips, resizes and duplicates the whole map with everything on it: terrain, all paint, metal, features, units, decals, lights, comments, start positions and boxes, grass and weather. It has two modes sharing one preview and one APPLY.

**TURN & SIZE**

- The rotate buttons turn the map a quarter turn at a time; the target size follows the turn.
- **FLIP ↔** and **FLIP ↕** mirror the map as you see it on screen.
- **width** and **depth** set the new canvas in map units (512 elmos each), 4 to 32 in steps of 2.
- **STRETCH** scales the map onto the new canvas. **KEEP SCALE** keeps one elmo to one elmo and places the map by the 3x3 **anchor**: this is how you crop a map or add a strip of new ground. Ground past the old edge continues the border height.

**EXPAND** doubles the canvas toward one side (**← W**, **E →**, **↑ N**, **S ↓**):

- **EMPTY** leaves the new half flat, ready to sculpt.
- **COPY** fills it with the map: **PLAIN** repeats it, **MIRROR** reflects it across the seam (the join meets exactly, which makes a symmetric map), **FLIP** reflects it along the seam, **BOTH** turns it half way round. Copied start positions and boxes go onto new ally teams.
- Doubling again grows the map further, up to 32 map units.

The preview shows the new canvas (outlined), where the current map lands in it (filled) and which corner is north-west today, with a line naming what the transform costs. APPLY reads NO CHANGE or TOO BIG when there is nothing it can do.

APPLY asks for a second click, then restarts the game onto the new canvas, because a map's size and orientation are fixed when it loads. Your project file is not changed until you save: FILE > Save keeps the result, quitting without saving discards it. The sun turns with the map; the skybox does not.

**HEIGHT EXTREMES** shows the lowest and highest point now and when the map loaded.

**WATER LEVEL**: drag the slider to preview the new shoreline on the map, then APPLY moves the terrain so the water lands there. CURRENT reads the present level, RESET goes back to the map's own. The WATER window's FLUID LEVEL is the same control.

**HEIGHT RANGE**: set a new min and max height. **RESCALE** stretches the whole relief onto it; **CLAMP** only cuts what sticks out. Both can be undone.

### New Map

FILE > New Map... creates a fresh map and restarts the game onto it. Unsaved changes are lost unless you save when asked.

| Control | What it does |
|---|---|
| MAP NAME | Optional. Saved heightmaps of this name group together |
| GENERATE TERRAIN | OFF gives a flat canvas. ON generates terrain from the TERRAIN (hilliness, roughness, terrain scale, jaggedness), WATER (coverage, coastline or island), RESOURCES (metal density) and LAYOUT (symmetry, seed) settings. RANDOMIZE rolls a new set |
| WIDTH, HEIGHT | 4 to 32 map units each, default 12 |
| MEX RADIUS | How far an extractor reaches, 24 to 200 elmos, default 90 (what most BAR maps use). Needs an engine with the blank map metal options |
| SPLAT SET | Detail textures for the canvas |
| ENVIRONMENT | Sky, light and water to start with |
| CREATE & RELOAD | Makes the map |

## Instruments and overlays

Every brush tool has a **DISPLAY** row and an **INSTRUMENTS** row. Click **Active** on a row's title to turn its effects on or off together.

### DISPLAY

| Chip | What it shows |
|---|---|
| Grid | A measurement grid over the whole map |
| Height Map | A colour height map with contour lines inside the brush. SAMPLE buttons can pick a contour's height |
| Passability | Click to cycle **BOT**, **VEH**, **HOVER**, **AMPH**, **SHIP** and off. The slope classes tint ground too steep for that kind of unit in purple (they need the tileset shader). SHIP shows the game's own view of where ships can sail |
| Image | A reference image laid over the whole map (see below) |

Some tools add their own chips: Metal Map and its instruments in METAL, Splat Map in SPLAT, Layer Map in LAYERS.

**Image Overlay.** Put a PNG, JPG, TGA, BMP or DDS file into `Terraform Brush/Overlays/`. Right click the **Image** chip (or click it before an image is loaded) to open the Image Overlay window: pick the file, then set Opacity, Offset X and Y (a share of the map), Scale, Stretch or Keep aspect, Flip H and Flip V. Transparency in the image is kept, so a sheet of guide lines shows only the lines. A left click on the chip shows or hides the image. `/tfimage <file>` picks a file, `/tfimage` toggles it, `/tfimage off` unloads it. The overlay needs `AllowDeferredMapRendering` on in `springsettings.cfg`.

### INSTRUMENTS

**Grid Snap** snaps positions to a grid. SNAP SIZE is 16 to 128 elmos (default 48).

**Protractor** snaps the brush rotation to an angle step: 7.5, 15, 30, 45, 60 or 90 degrees. Normally the brush snaps to the nearest spoke; Left Alt+A+Wheel steps through the spokes by hand (two notches per step) and holds that LOCKED AXIS. **Auto-Snap** goes back to automatic.

**Measure** draws rulers on the map.

- Click to start a line and to add points; drag a point to move it; drag the middle of a segment to bend it into a curve.
- Right click on a curve handle removes it, on a line removes the whole line, and anywhere else goes back to the brush.
- **Enter** switches between drawing and using the brush.
- **Ruler Mode** makes brush strokes follow the nearest line.
- **Sticky** remembers strokes made along a line and redoes them along the new path when the line is reshaped.
- **Show Length** labels each segment.
- **Auto Ramp** adds a line along every ramp you finish; **Clear Ramps** removes those, **Clear All** removes every line.

**Symmetry** repeats every stroke around an origin. All copies of a stroke are one undo step.

| Control | What it does |
|---|---|
| Radial | Rotational copies around the origin; COPIES sets how many (2 to 16) |
| Mirror X, Mirror Y | Mirror across one or both axes; both together give four-way symmetry. AXIS ANGLE turns the mirror line (0 to 360 degrees) |
| Flipped | Copies do the opposite: raising here lowers there |
| Distort | When Measure is on too: dragging the origin re-mirrors the measure lines instead of moving them |
| Set Origin | Click the map to place the origin. The origin can also be dragged |
| Center | Moves the origin to the middle of the map |

Ghost brushes show where every copy will land. Symmetry also applies to features, units, start positions and clone pastes.

## Capture and Map Labels

### Capture

The camera button opens the **Capture** window. It flies the camera over the map tile by tile and writes a top-down photo of the whole map, plus SVG layers you can drop into Figma or similar tools, into `Terraform Brush/Captures/`.

| Section | Controls |
|---|---|
| OUTPUT | detail: 0.5x, 1x or 2x |
| PHOTO | Water, Shadows, Bloom, Fog, Features: what to keep in the photo. Units are never in the photo |
| UNITS | Export unit layer: one image per unit, as **Portraits** (build pictures, constant size) or **Top-down** (models at true scale, experimental), with size, scale, By team grouping and Name labels |
| EXTRA LAYERS | Features .svg, Comments .svg |

**CAPTURE** starts; Esc or CANCEL stops it. `/tfcapture` starts a capture from the console (`/tfcapture <detail>` sets the detail first, `/tfcapture cancel` stops it).

### Map Labels

The Map Labels button shows the map's comments: coloured pins with an author and a note, for planning and review. Switching it off hides them all.

- In the Map Labels window, set your AUTHOR name and press **+ NEW LABEL**, then click the map to place it (right click cancels).
- Click a pin to read or edit it; drag a pin to move it; each comment has a colour.
- The LABELS list shows every comment on the map.

Comments are saved per map in `Terraform Brush/map_labels/` and with a project, and Capture can export them as an SVG layer.

## Settings

The gear button opens **Settings**, with four tabs.

**Keybinds.** Every editor key and wheel modifier. Click a binding and press the new key (Esc cancels). SAVE, APPLY, DEFAULTS, CANCEL. Bindings are stored in `Terraform Brush/keybinds.lua`.

**DJ Mode.** Effects for show: **Dust Visual Effects** (dust clouds while sculpting) and **Seismic Sound Effects** (ground rumble). The DJ Mode switch turns them on together. Other players in the game see and hear them too.

**Stroke**

| Setting | What it does |
|---|---|
| Pen Pressure | Tablet pressure changes intensity, size or both. Sensitivity 10 to 300%; Curve Linear, Quad, Cubic, S or Log |
| Clay build-up | On (default): a held clay brush keeps stacking layers. Off: one stroke lays exactly one layer |
| Brush Wiggle | Moves the brush in a small wave while painting, with four amplitudes and four speeds |

**General**

| Setting | What it does |
|---|---|
| Performance mode | For big maps and slower machines: wider stamp spacing where the fall-off allows, fewer stamps per tick, coarser FOLLOW STROKE steps, slower panel readouts. Pausing the game and Focus mode also help |
| Disable tips/tool recommendations | Hides the blue dots on folded section titles |
| Keep match alive (sandbox) | Turns off win conditions for this session, so teams survive with no units. On from the start on New Map and project canvases |
| Remove all units | Deletes every unit on the map |
| Autosave | On or off, every 5, 10, 15, 30 or 60 minutes, keep snapshots 1, 3, 7 or 14 days, keep each project's newest 3, 10, 30 or 90 days |
| Team Sync | See [Projects and saving](#projects-and-saving) |

Settings and window positions are kept between sessions.

## Multi-screen editing

The editor works with the game's dual-screen mode (`DualScreenMode = 1` in `springsettings.cfg`, or the dual screen option in the game's settings): one borderless window across two monitors, the map on one and the editor's windows on the other.

- The panels scale for the screen they are on, not for the map view, and keep their proportions.
- Every window drags freely between the two screens.

On desks that mix display scaling (for example a 150% 4K beside a 100% 1440p screen), the engine must support per-monitor DPI, or Windows stretches the window on the second monitor.

## Experimental (dev-only)

These are in the panel for the people building them. They are unfinished, may change or disappear without notice, and need assets that are not part of the game download, so on a normal install they show little or nothing.

- **BLOCKOUT** (SCENE > BLOCKOUT): a backdrop around the map, up to three layers of large scenery (near, middle and far ring), each picked from a list of blockout models and turned and scaled with its own sliders. The layers sit behind the map at sea level, are never culled or selected, and are covered by fog like the rest of the world. The game itself ships no blockout models, so the list only offers None. Layers are not saved with a project.
- **Osemo** (the Osemo chip in the Asset Library): a separate feature pack for a biome in development. The chip only appears once that pack is installed.

## Reference tables

### Keys

All keys in the first table can be changed in Settings > Keybinds.

| Key | Action |
|---|---|
| L | MODIFY: cycles Smooth, Level, Smudge |
| R | RAMP: switches between RAMP and AUTORAMP |
| E | RESTORE |
| N | NOISE |
| C, S, T, H, O | Circle, Square, Triangle, Hexagon, Octagon (in a terrain mode) |
| X | CLAY on or off |
| S, T | SURFACE, LAYERS (outside a terrain mode) |
| P, M, F, K, G | SPLAT, METAL, FEATURES, GRASS, DECALS |
| U, W, J, V | UNITS, WEATHER, CLONE, SCENE |
| (unbound) | LIGHTS, STARTS |
| Wheel modifiers | See [Common controls](#common-controls) |

| Fixed key | Action |
|---|---|
| Left drag | Apply the active mode |
| Right drag | Lower while held (terrain); erase or let go of the pick in most tools |
| Shift while dragging | Lock the stroke to the X or Z axis |
| Modifier + `[` or `]` | Step the value that modifier's wheel changes |
| Ctrl+Z, Ctrl+Shift+Z | Undo, redo (in the terrain modes, hold to repeat faster) |
| Ctrl+S, Ctrl+Shift+S, Ctrl+O | Save, Save As, Open Project |
| Enter | Measure: switch between drawing and the brush |
| Esc | Let go of every wheel-locked slider; in tools, clear the selection or cancel |
| Space | Pause or resume the DYNAMIC sliders |
| 1 to 4 | LAYERS and SPLAT channel |
| Double middle click on a slider | Wheel lock |

### Console commands

| Command | What it does |
|---|---|
| `/terraformbrush` | Open the editor in RAISE, or turn the terrain brush off |
| `/terraformpanel` | Show or hide the panel |
| `/terraformsuite` | Load the editor without opening a tool |
| `/terraformup [radius]`, `/terraformdown`, `/terraformlevel`, `/terraformsmooth`, `/terraformsmudge`, `/terraformramp`, `/terraformautoramp`, `/terraformrestore` | Switch to that mode |
| `/terraformerode` | Erode brush |
| `/terraformbrushoff` | Turn the terrain brush off |
| `/terraformexport` | Save a heightmap PNG to `Terraform Brush/Heightmaps/` |
| `/terraformimport <file.png>` | Load a heightmap PNG |
| `/mapproject save <name> [units]` | Save a project (`units` includes the units loadout) |
| `/mapproject open <name>`, `/mapproject delete <name>`, `/mapproject list` | Open, delete or list projects |
| `/mapproject autosave`, `/mapproject prune` | Take an autosave snapshot now, delete old snapshots now |
| `/tfcapture [detail \| cancel]` | Start or cancel a Capture |
| `/tfimage [file \| off]` | Image overlay: pick a file, toggle, or unload |
| `/splatpaint`, `/splatpaintoff` | SPLAT on, off |
| `/splatexport` | Save the splat texture |
| `/diffusepaint`, `/diffusepaintoff` | DIFFUSE on, off |
| `/diffusepaintbake`, `/diffusepaintexport`, `/diffusepaintundo`, `/diffusepaintredo` | DIFFUSE: bake the full map, export the squares, undo, redo |
| `/decalcapture <name> [radius]` | Capture the ground as a new decal |
| `/tfsliders` | Print the panel's slider state, if a slider ever stops responding |

The sub-tool commands (`/splatpaint`, `/diffusepaint` and so on) work once the editor has been opened.

### Folders in the data folder

All paths are relative to the game's data folder (the folder the game writes its settings and screenshots to; on Windows this is usually the install folder).

| Folder or file | What is in it |
|---|---|
| `MapProjects/` | Your projects, one folder each, in subfolders if you like |
| `MapProjects/_autosave/` | Autosave snapshots |
| `Terraform Brush/Heightmaps/` | Heightmap PNGs and their range files |
| `Terraform Brush/Presets/` | Your brush presets |
| `Terraform Brush/keybinds.lua` | Your key bindings |
| `Terraform Brush/FeatureMaps/`, `UnitMaps/`, `MetalMaps/`, `DecalMaps/` | Saved feature, unit, metal and decal layouts |
| `Terraform Brush/Splats/` | Exported splat and LAYERS textures |
| `Terraform Brush/StartPositions/`, `Startboxes/` | Saved start positions (exported suggestions in `StartPositions/Suggestions/`) and start boxes |
| `Terraform Brush/GrassConfig/` | Exported grass settings |
| `Terraform Brush/Environments/` | Sun and environment presets you saved |
| `Terraform Brush/Lightmaps/` | SAVE SCENE files |
| `Terraform Brush/SkyBoxes/` | Your own DDS skyboxes for the Skybox Library |
| `Terraform Brush/TilesetPresets/` | TILESET presets |
| `Terraform Brush/Overlays/` | Images for the Image Overlay |
| `Terraform Brush/Captures/` | Capture output |
| `Terraform Brush/map_labels/` | Map comments, one file per map |
| `Terraform Brush/textures/` | Optional texture packs: DIFFUSE materials, and DNTS detail sets in `dnts/` |
| `lightmaps/` | Saved LIGHTS layouts, and `presets/` for your light presets |
| `<map>_grassDist.tga` | A saved grass map |
| `LuaUI/Config/UnitBlueprints/` | Unit blueprints |
| `LuaUI/Config/TilesetRamps/` | Gradient images for WORLDSPACE TINT > RAMP |

### File formats

**A project folder** holds one file per part of the map, all plain Lua or images, so a project works well in version control:

| File | Contents |
|---|---|
| `project.lua` | The manifest: name, map size, dates and the list of parts. Written last, so a folder with it is a complete save |
| `heightmap.png`, `minimap.png` | The terrain, and the picture shown in the Projects window |
| `metal.lua`, `features.lua` | Metal, features |
| `units.lua` | Units, when the project has a units loadout (mission units carry `mission = <team>`) |
| `lights.lua`, `decals.lua`, `weather.lua` | Lights, decals, weather |
| `startpos.lua`, `startboxes.lua` | Start positions and boxes |
| `labels.lua` | Map comments |
| `grass_dist.tga`, `grass_config.lua` | Grass and its settings |
| `splat.png` | The splat or LAYERS texture |
| `surface.lua`, `surface.png` | SURFACE paint |
| `tileset.lua` | The TILESET settings, biome and metal spot style |
| `environment.lua` | The scene: sun, fog, lighting, water, skybox |
| `diffuse/` | DIFFUSE paint |

**A saved feature layout** (`Terraform Brush/FeatureMaps/`) uses the feature placer format that map feature placer gadgets read:

```lua
local setcfg = {
	unitlist = {},
	buildinglist = {},
	objectlist = {
		{ name = "rock1", x = 1024, z = 2048, rot = 16384 },
		{ name = "tree3", x = 1100, z = 2000, rot = 0, pitch = 0.1, roll = 0, y = 12, scale = 1.4 },
	},
}
return setcfg
```

`rot` is the heading. `pitch`, `roll` and `y` appear only for tilted or raised features, `scale` only for scaled ones.

## AI disclosure

This feature was developed with AI assistance (GitHub Copilot, Claude). AI helped write production code and draft this documentation. All AI-generated code was reviewed, tested in game and verified by a human contributor, as described in the [AI Usage Policy](../AI_POLICY.md).
