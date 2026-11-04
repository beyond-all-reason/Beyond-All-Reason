# Terraform Brush — Feature Reference

Custom terrain editing tool replacing BAR's default terraform commands with a unified brush-based workflow.

**Files:** `luaui/Widgets/cmd_terraform_brush.lua` · `luaui/RmlWidgets/gui_terraform_brush/`

> Development trackers and design notes live in the `realtime-terraformer` branch history (PR #7219), not in master.

---

## Getting Started

First-run orientation. The Terraform Brush is active in **skirmish, singleplayer, and replay sessions** (or any game where the host enabled the dev terraform modoption). Open the panel via the **Terraform Brush** button in the build/utility tray, or run `/terraformup` in chat to activate raise mode and pop the panel open.

### Tool Row (top of the panel)

Each icon switches the panel into a different tool. All tools share the same brush size/shape/rotation/curve sliders directly below the row.

| Tool | Purpose |
|------|---------|
| **Terraform** | Raise/Lower/Level/Smooth/Ramp/Restore/Noise — the core terrain modes (this is the default tool). See [Modes](#modes). |
| **Feature Placer** | Scatter trees, rocks, wreckage, decorations with random / regular / clustered distribution + smart filters. |
| **Grass Brush** | Paint GL4 grass density. LMB paint, RMB erase. |
| **Weather Brush** | Place CEG-based weather effects (rain, snow, dust, ambient sounds). |
| **Light Placer** | Place dynamic map lights (radius, color, rotation). |
| **Splat Painter** | Paint per-channel splat textures into the SSMF splat distribution map. |
| **Decal Placer** | Stamp ground decals (cracks, scorches, custom PNGs). |
| **Clone Tool** | Region copy/paste across all map layers (terrain, metal, features, grass, splats, decals, lights). |
| **Units** | Place real units from the unit library: click or drag formations, pick several to cycle through, undo a whole placement. See [Units](#units). |
| **Environment** | Skybox, fog, sun, water, atmosphere, scene presets — see below. |

Tools that are not currently active hide their sub-panel; click the icon to expand.

### Environment Panel & Skybox Library

Click the **Environment** icon in the tool row (rightmost group). The env panel opens with sections for:

- **Skybox Library** — click the **SKYBOX LIBRARY** button at the top of the env panel. A floating window opens with thumbnail tiles for every skybox in `LuaUI/Images/skyboxes/`. Click a tile to apply it instantly. Toggle the **Fade** chip to crossfade between skyboxes instead of hard-cutting.
- **Sun / fog / atmosphere** — sliders for sun direction, fog color/start/end, ambient/diffuse light, exposure, bloom.
- **Water** — water type (0–4), color, foam, reflection/refraction toggles.
- **Scene presets** — save/load named environment snapshots (`.env.lua` in your writeable data dir).

To return to terrain editing, click any other tool icon (e.g. the mountain) — the env panel collapses automatically.

### Map Transform (SCENE → Dimensions)

**MAP TRANSFORM** at the top of the Dimensions window turns, flips, resizes and duplicates the whole map with everything on it: terrain, splat and SURFACE paint, diffuse art, metal, features, units, decals, lights, comments, start positions, start boxes, grass and weather.

The section has two modes, sharing one preview and one APPLY.

**TURN & SIZE** moves the map you have:

- **Rotate left / rotate right** step the map a quarter turn at a time, and the target size follows the turn (a 12×16 map rotated once wants a 16×12 canvas).
- **FLIP ↔ / FLIP ↕** mirror the map the way you see it on screen, whatever rotation is already set.
- **width / depth** set the new canvas in map units (512 elmos each, even numbers, 4–32).
- **STRETCH** scales the map onto the new canvas: the composition is kept, the scale changes. **KEEP SCALE** holds one elmo to one elmo and places the map by the 3×3 **anchor**, which is how you crop a map or add a strip of new ground. Anything outside the new canvas is dropped, and ground that reaches past the old map continues its border height.
- The preview says the rest: the outlined box is the new canvas, the filled box is where the current map lands in it, and the dot marks the corner that is the map's north-west today. The line under it names what the transform costs, e.g. `Rotate 90°, 12x12 units at true scale, kept centred, cuts 11% of the map`.
- **APPLY** asks for a second click, then saves the session, rewrites every layer and restarts the engine onto the new canvas. Map size and orientation are fixed when a map is loaded, so the restart is not optional.

**EXPAND** doubles the canvas along one axis instead:

- **← W / E → / ↑ N / S ↓** pick the side the map grows into. The map keeps its ground and its scale and stays on the opposite side.
- **EMPTY** leaves the new half a flat canvas at the height a New Map starts at, ready to sculpt.
- **COPY** fills it with the map itself: **PLAIN** repeats it, **MIRROR** reflects it across the seam (the one that makes a symmetric map, and the only one whose terrain meets exactly at the join), **FLIP** reflects it along the seam, **BOTH** turns it half way round. Everything on the map is duplicated with the ground: features, metal, paint, decals, lights, start positions: and the copies of the start positions and boxes are renumbered onto fresh ally teams so a doubled map has somewhere for the extra players to stand.
- Doubling again grows the map the same way, so a small hand-made piece can be grown into a large symmetric map in two or three steps. 32 units is the blank map generator's ceiling, and APPLY reads TOO BIG when a doubling would pass it.
- The preview draws the copy in its own colour with its own corner dot, so which way it was turned over is visible before anything runs.

The **width** and **depth** steppers are in map units (512 elmos each); the line under them states the same canvas in elmos. APPLY greys out when there is nothing to apply.

The transform does **not** write to your project: the session comes back transformed with the same project still as the Save target, so `FILE > Save` commits it and quitting without saving throws it away. The sun turns with the map, so the light keeps falling on the terrain the way it was authored. The skybox itself does not turn with it, so a rotated map can want its sky re-picked.

The tileset's automatic placement turns with the map as well. Where nothing was painted, the shader picks the material from height, slope and a set of patterns anchored to the world: the stagger mask behind the cliff and foothill blends, the noise fields behind the intermediate scatter and the large-scale tone drift, and the wind the automatic deposit blows from. A transform records how the map was turned and the shader reads those patterns through that record, so a turned map comes back looking like the map that went in rather than with its paint right and everything between it re-rolled. It is kept in the project's `tileset.lua` and composes across transforms, so turning a map back the way it came restores the original exactly. A map that was never transformed carries no record and renders as it always did.

Tilted features keep their lean, and mirrored features keep their silhouette rather than their handedness (a model cannot be mirrored without a mirrored mesh). A transform with no rotation, no flip and the current size is refused: the APPLY button reads NO CHANGE.

### Key Shortcuts (cheat sheet)

| Key | Action |
|-----|--------|
| `C` `S` `T` `H` `O` | Shape: Circle / Square / Triangle / Hexagon / Octagon |
| `R` `E` `N` `L` `X` | Ramp / Restore / Noise / Smooth(→Level) / Clay |
| `Ctrl+Scroll` | Brush radius |
| `Shift+Scroll` | Curve (edge falloff) |
| `Alt+Scroll` | Rotation |
| `Space+Scroll` | Intensity (log scale) |
| `Ctrl+R+Scroll` | Ring inner-ratio |
| `Shift+drag` | Axis-lock + grid snap |
| `RMB drag` | Temporary Lower (restores previous mode on release) |
| `MMB` twice on a slider | Lock it to the mouse wheel; several can be locked at once. Twice again on it releases it, `ESC` releases all. The line under the status strip lists what is locked |
| `Ctrl+Z` / `Ctrl+Shift+Z` | Undo / Redo |

Full table in [Interaction → Keyboard](#interaction).

### Saving Your Work

- **Full map projects / team library**: **File > Save / Save As** saves a project; **File > Open Project** is one browser over this disk and the campaign team's private library, with a Sync column, a Team Sync line at the top and a start card for the companion. The team workflow is documented for the team in the library repository itself.
- **Autosave**: on by default (Settings > General). Every 10 minutes while the open project has unsaved changes, a snapshot lands under `MapProjects/_autosave/<project>-YYYYMMDDHHMM`; snapshots list under the Autosaves chip in **File > Open Project** and are swept after 3 days (the newest per project after 10). Opening one makes its project the Save target again.
- **Quitting with unsaved changes** asks first (Save, then continue / Don't save / Cancel) on the top bar's Quit and on New Map. The window's own close button cannot be caught; autosave covers that.
- **New Map** sets the canvas size and its **MEX RADIUS** (default 90 elmos), written into the generated mapinfo with a metal cap of 2 per square and saved with the project. Needs an engine with the blank map metal options (beyond-all-reason/RecoilEngine#3506); older engines keep the mapinfo defaults (radius 500, cap 0.02).
- **Terrain heightmap**: `/terraformexport` writes a PNG + metadata to your writeable data dir; `/terraformimport <file>` reloads it.
- **Features / grass / splats / decals**: each tool has its own Save/Load/Clear row in its sub-panel.
- **Environment**: Save/Load preset buttons in the env panel.

All saved files live under `<bar data dir>/luaui/terraform_brush/` and friends — survive across sessions and can be shared with other mappers.

### Getting Help

- Mapping help, feedback, and showing off your work: **[BAR Discord](https://discord.gg/beyond-all-reason)** → `#mapping` channel.
- Bug reports: tag `@BARb` (terraform brush maintainer) in `#mapping`, or open an issue against the realtime-terraformer branch on GitHub.

---

## Modes

### Raise / Lower
Elevate or depress terrain under the brush. Raise = LMB drag, Lower = RMB drag (temporary override — restores previous mode on release). Direction multiplier: `+1` / `-1`.

### Level
Flatten terrain to the height sampled at **drag start** (first LMB press). That height is pinned for the entire stroke — dragging does not resample. Auto-sets curve to max (5.0) for a sharp plateau edge. Disables ring shape.

`L` toggles between **Smooth** (primary, first press) and **Level** (sub-mode, second press). A sub-panel with **Smooth** / **Level** sub-mode buttons appears whenever either mode is active.

### Smooth
Continuously levels terrain toward the **running local mean** of the brush footprint. Each frame, a 5 × 5 sample grid (spacing ≈ radius × 0.4) is averaged and used as the level target, so dragging over uneven ground gradually pulls the surface toward the neighbourhood mean rather than a fixed height. Same gadget path as Level (`direction = 0`, `flattenHeight` = live mean).

Activated by `L` (first press) or the **Smooth** sub-button in the Smooth/Level sub-panel.

### Ramp
Two sub-modes selected via dedicated icon buttons in the Ramp tools row:
- **Straight ramp**: A→B line; Shift locks to nearest axis. Sent as `$terraform_ramp$`.
- **Spline ramp**: drag a curved path; points collected every 24 elmos (max 40). Uses a **progressive commitment** system — as the stroke extends, already-settled early path segments are smoothed and sent to the gadget incrementally, then locked into the displayed curve so they stop shifting. Only the trailing window of points remains live. Final smoothed path sent on mouse release. Sent as `$terraform_ramp_spline$`.

### Restore
Reverts terrain to the original heightmap within the brush footprint. Fires continuously during drag. Respects curve/intensity for gradual blending. A **Restore Strength** slider (0–100%) controls blend depth: 100% = fully restore in one pass; lower values give incremental softening.

### Noise
Applies procedural noise to terrain within the brush footprint. A dedicated sub-panel expands when Noise mode is active.

**Noise Types:**
| Type | Description |
|------|-------------|
| **Perlin** | Classic smooth gradient noise — rolling hills |
| **Voronoi** | Cell-based distance noise — cracked/plateau terrain |
| **FBM** | Fractal Brownian Motion — multi-octave Perlin for natural detail |
| **Billow** | Absolute-value Perlin — puffy, cloud-like mounds |

**Noise Parameters:**
| Param | Default | Range | Purpose |
|-------|---------|-------|---------|
| **Scale** | 64 | 8–512 | Cell/frequency size in elmos |
| **Octaves** | 4 | 1–8 | Detail layers (FBM/Billow/Voronoi) |
| **Persistence** | 0.50 | 0.10–0.90 | Amplitude decay per octave |
| **Lacunarity** | 2.0 | 1.0–4.0 | Frequency growth per octave |
| **Seed** | 0 | 0–9999 | Random seed (reseed button for quick randomization) |

The brush shape, radius, curve, intensity, and length scale all apply to noise mode as a falloff envelope. Sent as `$terraform_noise$`.

---

## Shapes

| Shape | Key | Segments | Notes |
|-------|-----|----------|-------|
| **Circle** | `C` | 64 | Default. Becomes ellipse when lengthScale ≠ 1.0 |
| **Square** | `S` | 4 | Rotatable rectangle with aspect ratio via lengthScale |
| **Triangle** | `T` | 3 | Equilateral triangle, rotatable |
| **Hexagon** | `H` | 6 | Disabled in ramp mode |
| **Octagon** | `O` | 8 | Disabled in ramp mode |
| **Ring** | `Ctrl+R+Scroll` to resize | 64×2 | Inner radius adjustable via `ringInnerRatio` (0.05–0.95, default 0.6). Disabled in level/smooth/ramp modes |

Each shape has a dedicated falloff curve renderer: per-radial (circle/ring), per-face edge distance (square), per-sector apothem (tri/hex/oct), mid-radius band (ring inner falloff).

---

## Brush Parameters

| Param | Default | Range | Scroll Modifier | Slider |
|-------|---------|-------|-----------------|--------|
| **Radius** | 100 | 8–2000 | `Ctrl+Scroll` | Linear |
| **Rotation** | 0° | 0–359° | `Alt+Scroll` | Linear (3°/step) |
| **Curve** | 1.0 | 0.1–5.0 | `Shift+Scroll` | Linear (×0.1) |
| **Intensity** | 1.0 | 0.1–100 | `Space+Scroll` | Logarithmic |
| **Length Scale** | 1.0 | 0.2–5.0 | `Ctrl+Alt+Scroll` | Linear (×0.1) |
| **Opacity** | 30% | 1–100% | — | Linear |

**Curve** controls falloff sharpness: `falloff = rawDistance ^ curvePower`. 1.0 = gentle dome, 5.0 = flat plateau with sharp edge.

**Intensity** uses a logarithmic slider mapping: `ln(max/min)` spread across 1000 steps → `min × e^(step × logRange / 1000)`.

### Height Caps

Constrain the brush output to a min/max height band.

- **Relative mode** (default): offset from ground height at brush center
- **Absolute mode**: world-space altitude values
- Range: −500 to +500 per cap
- **Visualization**: wireframe prism — orange for max cap, cyan for min cap, vertical struts at shape corners

#### Height Cap Sampling (Colormap Eyedropper)

When the **Height Colormap** overlay is active, each cap row shows a **SAMPLE** button. Clicking it enters **height sampling mode**: hover over any topo contour line or the peak label inside the brush footprint to highlight it, then click to set that exact height as the cap value. Hovered contour labels enlarge and turn gold; the contour ring itself brightens. Click outside the brush or press Escape to cancel without changing the cap.

### Clay Mode

"Flat buildup" — creates plateau-like terrain with a flat top at the brush's target height rather than the standard dome falloff. Toggle with `X`.

Each dab targets a **plane** at the stroke's reference height plus `INTENSITY × 8` elmos (raise) or minus it (lower); cells on the wrong side of the plane blend toward it by `falloff × opacity × intensity` per dab and never cross it. The reference is the **pre-stroke surface**: the heights every cell had when the stroke started, averaged over the dab centre and four taps half a radius out. A stroke therefore lays exactly one layer over the ground it started on, however slowly you drag or however much the dabs overlap, and the layer's edge follows the falloff. Measuring the plane on the live centre height instead stacked a new disc every tick, and the disc edges came out as concentric rings; that behaviour survives as **Settings > Stroke > Clay build-up** for anyone who wants a held brush to keep piling layers.

Sent as the clay flag in the terraform messages: `0` off, `1` clay, `2` clay with build-up.

Clay mode applies to **all terrain modes** (raise, lower, level, smooth, ramp, restore, noise) and **all shapes** (circle, square, triangle, hexagon, octagon, ring). In ramp mode the flattened profile applies along the full ramp length.

### Stamp Mode (Instant Apply)

When **intensity is maxed** (100.0) **and at least one height cap is set**, the brush enters stamp mode:

- **Single-click apply**: the full transform is applied in one step instead of building up gradually
- **Drag behavior**: re-applies once at each new cursor position (only when mouse moves), not continuously at the same spot
- **Raise + max cap**: terrain lerps toward `heightMax` within the falloff envelope
- **Lower + min cap**: terrain lerps toward `heightMin` within the falloff envelope
- **Level + caps**: terrain flattens to target, clamped by caps

Detection: `activeIntensity >= MAX_INTENSITY and (heightCapMin ~= nil or heightCapMax ~= nil)`

Sent as `instant` field (`0`/`1`) in the `$terraform_brush$` message (field 15).

---

## Interaction

### Mouse
| Input | Action |
|-------|--------|
| LMB drag | Apply active mode (raise by default) |
| RMB drag | Temporarily switch to Lower, restore previous mode on release |
| Shift+drag | Axis-lock (X or Z, determined after 25 screen-pixel threshold, zoom-independent) + grid snap |

While a stroke runs the camera holds still: the view does not ride the ground it changes. The hold lasts until you pan, zoom, rotate or switch camera; terrain raised into the camera still lifts it.

### Keyboard
While an editor tool is in use, the game's own hotkeys (unit orders, build keys, selection, groups) are held back so they cannot fight the editor's; the camera, chat (Enter), Esc, F1-F12 and screenshots still work. The **pause** button on the panel hands every key back to the game.

| Key | Action |
|-----|--------|
| `C` `S` `T` `H` `O` | Select shape (Circle / Square / Triangle / Hexagon / Octagon) |
| `L` | Smooth mode (primary); press again while in Smooth to switch to Level sub-mode |
| `R` `E` `N` | Ramp / Restore / Noise mode |
| `X` | Toggle Clay mode |
| `Ctrl+Z` | Undo (`$terraform_undo$`) |
| `Ctrl+Shift+Z` | Redo (`$terraform_redo$`) |
| `Ctrl+R+Scroll` | Adjust ring inner-ratio (hole size) |

### Commands
| Command | Purpose |
|---------|---------|
| `/terraformup [radius]` | Activate raise mode (optional radius) |
| `/terraformdown` | Activate lower mode |
| `/terraformlevel` | Activate level mode |
| `/terraformramp` | Activate ramp mode |
| `/terraformsmooth` | Activate smooth mode |
| `/terraformrestore` | Activate restore mode |
| `/terraformexport` | Export heightmap to PNG + metadata |
| `/terraformimport <file>` | Import heightmap from PNG |

---

## Tools

The panel exposes a **Tools row** of icon buttons. Each tool has its own sub-panel. All tools share the same brush shape, size, rotation, and curve controls.

### Feature Placer

Distribution mode (random/regular/clustered) · Size/rotation/count/cadence sliders · Scale variation · Undo/redo · Save/load/clear

**Picking features.** A click on a tile in the asset library picks that feature alone. `Ctrl+click` adds a feature to the pick or takes it out, and `Shift+click` adds every tile from the last one clicked to this one, in the list as it is filtered. Placement draws from all picked features.

**Files:** `luaui/Widgets/cmd_feature_placer.lua` · `luaui/RmlWidgets/gui_feature_placer/`

**Randomize alignment and tilt.** The last two CONTROLS rows. RANDOMIZE ALIGNMENT turns each placed feature's heading by up to ± that share of a full turn. RANDOMIZE TILT (0-45°) leans each feature up to that many degrees in a random direction; most stay close to upright and a few lean hard (`rollTilt` in `common/feature_scatter.lua`). The lean is rolled with the layout, so the ghost preview shows it, and it travels as the feature's pitch and roll, so undo, redo, saves and map projects keep it.

#### Scale Variation

Scale Min / Scale Max sliders (0.1-5.0x) roll a per-feature scale at placement
time, any size in between. The engine cannot scale a feature's model
(`Spring.SetFeaturePieceMatrix` discards its matrix, and only unit scripts can
scale pieces), so the size is drawn rather than simulated: the feature placer
gadget writes the scale into the feature's per-object uniform
(`userDefined[3].z`, buffer index 14) and the CUS vertex shader multiplies the
model by it, in every pass, shadows included. The gadget also scales the
collision volume, the selection radius and height, and the mid/aim points, and
keeps the scale in the public feature rules param `visualScale`. Brush
placements grow in over a third of a second.

A def can still ship **pre-baked model variants** (sibling defs tagged
`customParams.scale_base` and `scale_factor`); the roll then snaps to the
nearest variant and places that def instead. No variant sets ship at the moment.

Limits: the footprint keeps the def's size, and the engine culls a feature by
its unscaled model radius, so a feature scaled far above 1 can pop out early at
the screen edge.

- Rolls are bottom-heavy (many small, few large), matching a natural stand.
- With **Clustered** distribution, scale correlates with distance to the cluster
  nucleus: big features in the core, small ones at the fringe, and the minimum
  spacing scales per pair so small features pack tighter.
- Point mode rolls a scale per placement too.
- The scale rides the placement wire format and save files, so save/load,
  undo/redo and map projects keep it.

Why the shader rather than the engine: the engine has no feature-scale API.
`Spring.Set{Unit,Feature}PieceMatrix` looks like one, but
`LocalModelPiece::SetPieceSpaceMatrix` only validates the matrix and discards
the geometry, and piece scaling is reachable only from unit animation scripts.
So the size is drawn (the CUS per-object uniform) and the interaction is scaled
by the gadget (collision, radius and height, mid/aim). The scale rides the wire
as the 5th token (no tilt) or the 8th (with tilt).

#### WYSIWYG Preview

The brush draws the features it is about to place, as translucent instanced
models at their real positions and orientations, before you commit. What you see
is literally what gets created: the widget generates the layout
(`common/feature_scatter.lua`), previews it, and on click ships that same array
to the gadget. Layouts used to be rolled gadget-side, which made a truthful
preview impossible.

- The layout is brush-relative and cached, so it keeps its shape while the cursor
  moves rather than reshuffling every frame.
- The seed rerolls after every stamp, so dragging does not rubber-stamp one
  pattern. **Reroll Preview** in the panel shuffles it without placing.
- Smart-filter rejection is re-evaluated at the live cursor position, so ghosts
  disappear over water or cliffs exactly where placement would skip them.
- Remove mode has nothing to place, so it tints the features under the brush red
  instead.
- Ghosts render through `WG.DrawFeatureShapeGL4`
  (`luaui/Widgets/gfx_DrawFeatureShape_GL4.lua`), one instanced draw call per
  texture pair, so a 500-feature preview stays cheap.

#### Selection & Gizmo

Available on an **empty mouse** — with nothing picked in the asset library there
is nothing to place, so the left button manipulates what is already on the map.
Picking any library item switches straight back to placing. Remove mode is
excluded: an empty library is the normal way to use the erase brush.

| Input | Action |
|-------|--------|
| LMB on a feature | Select it |
| Shift + LMB | Add / remove from the selection |
| LMB drag on empty ground | Box select |
| LMB on empty ground | Clear the selection |
| Ctrl + A | Select everything on screen |
| Delete / Backspace | Remove the selection |
| Esc | Clear the selection; a second press leaves the tool |
| RMB | Drops the library pick (back to selecting); features come off only through Delete or REMOVE mode |

The gizmo has three translate arrows, three rotation rings and a centre handle
that slides the selection over the terrain. Multi-selections transform rigidly
about their centroid. Handles keep a constant on-screen size and are picked in
screen space, so a thin ring stays grabbable at any zoom. Grid Snap constrains
translation; the Protractor's angle snap constrains rotation.

**Vertical movement works.** `Spring.SetFeaturePosition` goes through
`CFeature::ForcedMove`, which does not put the feature back into the physics
update queue, so a lifted feature stays lifted. Features created above the ground
*are* queued and would fall, so the gadget zeroes their movement masks
(`SetFeatureMoveCtrl` with `enabled = false`) to hold them in place.

**The gizmo does not scale.** A feature keeps the scale it was placed with; the
gizmo moves and turns it, and its ghosts draw at that scale.

While dragging, the real features are hidden client-side
(`Spring.SetFeatureNoDraw`) and ghosts follow the cursor, so nothing goes over
the wire until the mouse comes up. One `$feature_transform$` stroke is one undo
entry.

#### Distribution Modes
| Mode | Behaviour |
|------|-----------|
| **Random** | Uniform random scatter inside the brush shape |
| **Regular** | Even spacing: Fibonacci spiral (circle), square grid, hex grid, octagon grid |
| **Clustered** | Organic natural distribution — see below |

#### Clustered Distribution
Simulates real-world ecological spacing patterns:

- **Cluster nuclei** (CLUMPS): anchor points seeded inside the brush. 0 = AUTO, 2–6 scaling with √featureCount; or set 1–24.
- **Cluster attraction** (CLUMP SIZE): features spawn near a nucleus via a Gaussian offset, σ ≈ radius / clumps × 1.2 × CLUMP SIZE (0.2–3).
- **Free scatter** (STRAGGLERS, default 25 %): this share is placed uniformly at random inside the brush for a sparse background.
- **CLUMP VARIETY** (0–100 %): how unlike each other the clumps are. Each clump rolls its share of the features (a few dense, most sparse), its own spread, and an age that shifts its sizes (young clumps of saplings next to old groves of large trees). At 0 every clump is alike, exactly the old behaviour.
- **Minimum separation**: each candidate position is rejected if it is closer than `featureDef.radius × 1.4` to an already-placed feature. This lets mixed selections self-regulate — large-radius objects (trees) space apart for "sunlight competition"; small-radius objects (bushes) cluster tightly. A safety clamp prevents deadlock when the count is high relative to the brush size.

#### Smart Filter
Independent of distribution mode — can be combined with any of the three. When enabled, each candidate position is tested against terrain constraints before placement.

| Filter | Default | Purpose |
|--------|---------|---------|
| **Avoid Water** | on | Reject positions where ground height < 0 |
| **Avoid Cliffs** | on | Reject positions steeper than Max Slope (default 45°) |
| **Prefer Slopes** | off | Additionally reject positions *flatter* than Min Slope (default 10°) |
| **Min Altitude** | off | Reject positions below a world-space height value |
| **Max Altitude** | off | Reject positions above a world-space height value |

The Smart Filter panel is revealed by a toggle below the distribution buttons.

**Brush visualization:** When Smart Filter is enabled, the brush cursor draws a terrain-following grid of small quads inside the footprint. Valid cells are tinted green (α 0.08), rejected cells are tinted red (α 0.14). Grid spacing is fixed at 24 elmos. When altitude caps are active, a wireframe prism is drawn — orange for max, cyan for min, with white vertical struts.

**Slider coupling:** The Min/Max Altitude sliders are coupled: dragging min above max automatically raises max, and dragging max below min automatically lowers min.

#### Asset Library Thumbnails
Each feature's 3D model is rendered to a 64×64 in-memory GL texture on first open. Process:
1. A shared depth texture is created once (`GL_DEPTH_COMPONENT24`)
2. Per-feature: create color texture (`fbo = true`) → temporary FBO → render with `gl.FeatureShape`/`gl.FeatureShapeTextures` at −30°/45° isometric view → delete FBO, keep texture
3. Generation is throttled to 3 features/frame in `DrawScreen` to avoid stutter
4. Progress bar shown in the asset list during generation
5. In `DrawScreen`, textures are drawn over RML placeholder divs using `gl.TexRect` with screen coordinates from `element.absolute_left`/`absolute_top`, clipped to the scroll area via `gl.Scissor`
6. Category-colored fallback boxes remain visible for features with no model (`modelpath == ""`)

**Note:** RML `<img src>` only resolves VFS archive paths, not the writeable data directory where `gl.SaveImage` stores files. This is why thumbnails use direct GL texture overlay instead of saved PNGs.

### Grass Brush

Brush-based grass density painting over the GL4 grass system.

- **LMB**: paint density up · **RMB**: erase
- Controls: shape, size, rotation, curve, density slider
- **Smart filters**: water, cliff, altitude — same filter UI as Feature Placer
- **Color filter**: sample terrain diffuse color under the brush; reject cells outside hue/value tolerance
- **Export**: TGA 8-bit grayscale for map packaging (compatible with `smf.grassmapTex` override)

**Files:** `luaui/Widgets/cmd_grass_brush.lua` (API extension via `map_grass_gl4.lua`)

### Weather Brush

Places CEG-based weather effects (particles, ambient sounds) with persistence and cadence controls. Similar panel layout to Feature Placer.

### Clone Tool

Region-based copy & paste across all map data layers. Select an area, capture its contents, and stamp it elsewhere with rotation, mirroring, and height offset.

**Files:** `luaui/Widgets/cmd_clone_tool.lua` · `luarules/gadgets/cmd_clone_tool.lua` · `luaui/Include/clone_preview_gl4.lua`

**Paste preview.** Once a region is copied, the paste shows as a lit, textured copy of the terrain at the cursor, following rotation, mirroring, height offset, symmetry and grid snap, with buried parts drawn through the ground. PASTE > PREVIEW OPACITY sets how solid it looks (0 leaves the outline only). On tileset maps the ghost wears the biome colour without the slope rock the shader adds per pixel.

**Paste mode.** PASTE MODE under INCLUDE LAYERS picks how the copy meets the ground. REPLACE lays it down as it is. RAISE ONLY keeps the higher of the copy and the ground (a heightmap max blend), so only what stands above the ground arrives; LOWER ONLY keeps the lower (a min blend). A copied hill and valley pasted on flat ground leave just the hill or just the valley. The other layers follow the terrain: features, metal, grass, decals, lights and weather spawners paste only where it does, standing features are cleared only there, and splats and surface paint blend in through a mask of the same cells (`luaui/Include/clone_paste_mask.lua`). Everything is judged against the ground as it is before the paste, with one elmo of slack. A masked paste always writes every 8-elmo vertex at full precision, whatever TERRAIN QUALITY says. The preview shows only what will paste: the ghost drops what is cut (keeping the box outline), LOWER ONLY draws the sunken part solidly through the ground, and feature and metal markers show only for what lands. Without copied terrain the mode has nothing to judge by and the paste replaces.

#### Layer Toggles

Each layer can be independently enabled/disabled. Only enabled layers are captured on copy and applied on paste.

| Layer | Read API | Write API | Status |
|-------|----------|-----------|--------|
| **Terrain** | `Spring.GetGroundHeight(x,z)` grid loop | `SetHeightMapFunc` batch via gadget | ✅ Full |
| **Metal** | `Spring.GetMetalAmount(x,z)` per square | `Spring.SetMetalAmount` via gadget | ✅ Full |
| **Features** | `GetFeaturesInRectangle` → defID, pos, heading | `CreateFeature` / `DestroyFeature` via gadget | ✅ Full |
| **Splats** | FBO blit of `$ssmf_splat_distr` sub-rect | Quad paste into splat FBO → `SetMapShadingTexture` | ✅ Full |
| **Surface** | `WG.SurfacePainter.region.copy()` of the tileset variant mask(s) | `region.paste()` onto the four destination corners | ✅ Full (needs the surface painter installed) |
| **Grass** | `WG['grassgl4'].getDensityAt(x,z)` per patch | `setDensityAt(x,z,val)` per patch | ✅ Full |
| **Decals** | `Spring.GetAllGroundDecals()` + per-decal queries | `Spring.CreateGroundDecal()` with transforms | ✅ Implemented (toggle disabled) |
| **Weather** | `WG.WeatherBrush.getPersistentSpawners()` (spawners centred in the box) | `addSpawnerRaw()` per spawner, shape angle turned with the paste | ✅ Full (no undo: the weather brush keeps none) |
| **Lights** | `WG.LightPlacer.getPlacedLights()` (height above ground kept) | `WG.LightPlacer.addLights()`, aim turned and mirrored, one undo step in LIGHTS | ✅ Full |
| **Terrain Texture (PBR)** | *Deferred* | *Deferred* | ⬜ Deferred |

**Surface** is the tileset shader's variant paint: the material a patch of ground wears under the new terrain shader. It travels with Splats so a cloned piece of map keeps the look it was painted with, not just its height. The painter owns the masks (there are two once variant 4 is in use), so the clone tool asks it to cut the patch out and lay it down again; the paste snapshots for undo on the painter's own stack, so Ctrl+Z in the SURFACE tool takes it back. The mask belongs to a write-dir widget, so the layer quietly carries nothing on an install without it.

Texture layers are pasted as a **quad**, not a rectangle: the four destination corners come from the same `transformPoint` every other layer uses, so a rotated or mirrored paste turns the paint with the terrain, and the patch lands centred on the cursor. (Before this, the splat patch pasted axis-aligned from the cursor, i.e. unrotated and half a box off.)

#### Workflow States

```
IDLE → [activate Clone tool]
  → SELECT (click+drag draws box on terrain)
    → BOX_DRAWN (box visible, resizable via corner/edge handles)
      → COPIED (Ctrl+C or button — data captured into CloneBuffer)
        → PASTE_PREVIEW (Ctrl+V — ghost follows cursor)
          → APPLY (click — writes all enabled layers)
          → can paste repeatedly from same buffer
```

#### SELECT Mode
- Click+drag draws an axis-aligned rectangle in world-space, corners follow terrain
- Rendered as terrain-following `GL.LINE_LOOP` with semi-transparent fill
- On mouse release → transition to BOX_DRAWN

#### BOX_DRAWN Mode
- Box persists on map with 4 corner handles + 4 edge handles
- **Corner drag**: resize (opposite corner anchored)
- **Edge drag**: resize one axis
- **Center drag**: translate the box
- **Layer toggles** update highlights in real-time:
  - Features: colored markers on each feature inside
  - Terrain: subtle height-color overlay
  - Metal: metal-colored dots at non-zero squares
  - Splats: tinted overlay of splat texture
  - Grass: green dots at grass patches
  - Decals/Lights/Weather: icon markers at positions

#### CloneBuffer Structure

```lua
CloneBuffer = {
    originX, originZ, sizeX, sizeZ,
    terrain = { baseHeight, grid = {{dh,...},...}, stepX, stepZ },
    metal = { {lx, lz, val}, ... },
    features = { {defName, lx, ly, lz, heading}, ... },
    splats = { fboHandle, pixelW, pixelH, u0, v0, u1, v1 },
    grass = { {lx, lz, density}, ... },
    decals = { {lx, lz, sizeX, sizeZ, rot, texName, alpha, ...}, ... },
    weather = { {cegName, lx, lz, params...}, ... },
    lights = { {lx, ly, lz, lightParams}, ... },
    enabledLayers = { terrain=true, metal=true, ... },
}
```

#### PASTE_PREVIEW Mode (Ctrl+V)
Ghost rendering follows mouse cursor showing what will be placed:
- Terrain: height-colored overlay offset from current ground
- Features: translucent colored dots at relative positions
- Splats: blended preview texture on ground
- Other layers: simple icon markers

**Keyboard modifiers while previewing:**
| Input | Action |
|-------|--------|
| `Alt+Scroll` | Rotate (free rotation in degrees) |
| `Shift+Scroll` | Raise/lower altitude offset |
| `Shift+X` | Mirror on X axis (east-west flip) |
| `Shift+Z` | Mirror on Z axis (north-south flip) |

#### APPLY (Click in paste preview)
Writes all enabled layers at target position.

**Execution order** (dependencies matter):
1. Terrain heightmap (features need correct ground height)
2. Splat distribution
3. Metal map
4. Grass density
5. Features (placed at updated ground height)
6. Decals
7. Lights
8. Weather

**Performance:**
- Terrain/Metal: chunked `SendLuaRulesMsg` to gadget (~500 points/message)
- Features: `$clone_features$` message → gadget loops `CreateFeature`
- Splats: client-side FBO compositing, instant
- Grass: coroutine-chunked `setDensityAt` for large regions
- Progress bar shown during large applies

#### Rotation & Mirror Math
All positions stored relative to buffer origin (0,0 = top-left). On paste:

```
transform(lx, lz):
  if mirrorX: lx = sizeX - lx
  if mirrorZ: lz = sizeZ - lz
  rotate (lx,lz) around (sizeX/2, sizeZ/2) by pasteRotation
  translate to target world position
  height values += heightOffset
  feature headings += rotation
```

### Units

**UNITS** on the tool row places real units on the map: to lay out a base, a battle or a scene to light and screenshot. It needs `/cheat`, like the rest of the editor.

Pressing it opens the **unit library** window, and the panel shows the tool's own controls: LIBRARY (reopens the window), TEAM (the team placed units join; `T` does the same), UNDO and REDO.

**Placing.** Pick a unit in the library, then on the map:

- **Click** places one; **drag** lays out several in the current shape. `Tab` cycles the shape (SINGLE, LINE, GRID, BOX) and `R` turns the units a quarter (`Shift+R` back).
- The preview and the layout are the game's own blueprint tool: footprints are outlined, red where the ground refuses, and a drag lays units out exactly as a build drag would.
- The tool **stays armed** after a placement, so one drag follows another. A **right click** lets go.
- `Ctrl+Z` / `Ctrl+Y` undo and redo a whole placement at a time.

**Picking several.** The same gestures as the asset library: `Ctrl+click` adds a tile to the set or takes it out, and `Shift+click` adds every tile from the last one clicked to this one, in the list as it is filtered and sorted. With the grid keys, `Shift` plus a key adds or removes that tile. The tiles show their order. Each placement then uses the next unit of the set, in order (A B C) or at random, as the CYCLE chips say.

**The library.** One window, shared with the mission editor.

| Part | What it does |
|------|--------------|
| Search | Names and tags as you type, e.g. `t2 arty cor`. Arrows move the highlight, `Enter` picks it, `Esc` closes. |
| FILTERS | A row per filter, labelled at the left: FACTION, TIER, MOBILE and BUILDING (the unit types, split into units and buildings), ROLE and DOMAIN. A click keeps that value alone (again clears the row), `Shift+click` adds or removes it, and a click on a row's label clears the row (the label lights while its row filters). Every chip shows how many units it would leave. Roles are inferred from stats against the other units of the same tier. |
| SORT | NAME, POWER (metal + energy / 60), TYPE, SIZE (footprint), TIER, SPEED, RANGE, HEALTH. Click the active one again to reverse it; the arrow shows the direction. |
| RECENT | The last units picked, one row; folded until opened. |
| BLUEPRINTS | Saved groups of units (`LuaUI/Config/UnitBlueprints/`), below the units and folded until opened. Picking one arms the whole group; `x` deletes the file. |

Units show four to a row, picture and name. Each section folds with its title row. The library remembers its filters, sort and folds between sessions.

---

## Instruments

Non-destructive overlay tools that operate independently of (or alongside) the active terraform mode. Toggled via the **INSTRUMENTS** collapsible section in the panel.

| Instrument | Toggle | Description |
|------------|--------|-------------|
| **Snap** | `btn-grid-snap` | Grid-snap during Shift+drag. Snap size configurable (16–128 elmos, default 48). |
| **Protractor** | `btn-angle-snap` | Snaps brush rotation to a configurable angle grid. |
| **Measure** | `btn-measure` | World-space ruler polylines with distance labels. |
| **Symmetry** | `btn-symmetry` | Mirror/radial stroke replication across one or more axes. |

### Protractor

Constrains brush rotation to a configurable angle grid. Works alongside any terraform mode.

#### Modes
| Mode | Behaviour |
|------|-----------|
| **Auto-snap** (default) | Every frame the active brush rotation snaps to the nearest spoke of the current angle grid. Rotation slider updates to match. |
| **Manual spoke** | `LALT+Scroll` cycles through spokes (requires 2 scroll ticks in the same direction to advance, preventing accidental steps). Auto-snap is disabled when a spoke is manually selected. |

#### Parameters
| Param | Range | Default | Notes |
|-------|-------|---------|-------|
| Angle Step | 0.5–90° | 15° | Selectable from preset stops: 1/5/10/15/22.5/30/45/90° via a 0–5 discrete slider |
| Active Spoke | 0 – (360/step − 1) | 0 | Only shown when Auto-snap is off |

#### Visual Overlay
While Protractor is active, evenly-spaced spokes radiate from the brush center outward. The currently active / nearest spoke is drawn longer and brighter. Spokes follow the terrain (world-space GL lines). Not shown during ramp mode.

#### API
`WG.TerraformBrush.setAngleSnap(bool)` — toggle  
`WG.TerraformBrush.setAngleSnapStep(degrees)` — set step size  
`WG.TerraformBrush.setAngleSnapAuto(bool)` — auto vs. manual  
`WG.TerraformBrush.setAngleSnapManualSpoke(index)` — lock a specific spoke  

### Measure Tool

A world-space **polyline ruler** that runs independently of the active terraform mode.

#### Drawing
- **LMB click** on terrain: place the first point of a new chain, or extend the active chain with a new segment.
- **LMB drag** near an existing endpoint: reposition that endpoint.
- **LMB click near segment body**: inserts a new intermediate point and splits the segment into a Bezier curve.
- **RMB**: cancel the in-progress segment (finalises the current chain without the pending point).
- **Shift+drag**: H/V constrain the pending segment to 0°/45°/90°.
- Multiple independent chains can be drawn; each is independent.
- **Clear** button removes all chains.

#### Bezier Curve Handles
Splitting a segment (clicking near its midpoint) promotes both endpoint handles to Bezier control points, rendered as orange ◇ diamonds. Drag a handle to reshape the curve. The segment length label updates in real time to reflect the arc length.

#### Distance Labels
Each committed segment shows its length at the midpoint: `NNN el  /  N.Nkm` (scale: 192 el = 1 km). Labels are drawn with a dark shadow for contrast and persist even when the main UI is hidden (F5 mode) via `DrawScreenEffects`.

#### Sub-modes

| Sub-mode | Behaviour |
|----------|-----------|
| **Ruler Mode** | Snaps any active terraform brush stroke to the nearest measure line segment (straight or Bezier-curved). Useful for precise linear ramps or roads along a drawn guide. |
| **Sticky Mode** | As the brush paints, every stroke is recorded parametrically relative to the nearest spline. If the spline is later reshaped, those strokes are re-applied along the new path automatically. |
| **Distort Mode** | Hidden by default; when active, dragging the Measure origin re-mirrors its chains instead of translating them. |

#### Symmetry Integration
When Symmetry is active, all drawn measure chains are rendered at their mirror/radial positions as ghost lines (lower alpha). Ruler Mode snapping applies to both the original and mirror-ghost segments.

### Symmetry / Mirror Tool

An **instrument** that replicates every brush stroke across one or more symmetry axes in real time. All symmetry copies from a single stroke collapse into one undo entry.

This tool operates entirely in the **horizontal plane (X/Z)**. There is no vertical (Y) axis component — keeping it flat avoids the axis-dependency complexity that arise in 3D sculpting tools such as ZBrush.

#### Origin Gizmo

A click-to-place control that sets the **symmetry center point** — the pivot around which radial copies are rotated and the intersection of the mirror axes.

- Activated via a toggle chip in the Instruments row.
- Default position: map center.
- While the instrument is active, LMB click anywhere on the terrain repositions the origin.
- Origin is rendered as a persistent crosshair/pin on the terrain.
- The origin persists independently of the active symmetry mode; it can be repositioned at any time without resetting the symmetry settings.

#### Symmetry Settings

| Setting | Type | Description |
|---------|------|-------------|
| **Radial** | Toggle | Enables rotational (N-way) symmetry around the origin. When active, **X and Y are automatically disabled** — radial and axial mirror are mutually exclusive. |
| **Radial Count** | Integer spinner (2–16) | Number of evenly-spaced rotational copies. Count = 2 is equivalent to 180° point symmetry. Only enabled when Radial is on. |
| **X** | Toggle | Mirror strokes across the **X axis** (reflects Z coordinate through the origin — left/right mirror). |
| **Y** | Toggle | Mirror strokes across the **Y axis** (reflects X coordinate through the origin — top/bottom mirror). The label "Y" refers to the second horizontal map axis (world-space Z), named Y here to match the 2D map-view orientation. |

**Combining X and Y** produces 4-way quad symmetry. Enabling **Radial** while X or Y is on will automatically uncheck both.

**Visual overlay:** guide lines radiate from the origin across the full map. Radial sectors shown as spokes at `360° / count`. Ghost brush cursors appear at every symmetric position in real time.

#### Mirror Button (One-Shot)

A **"Mirror"** action button that performs a one-shot copy-and-reflect of the terrain on one side of the active axis to the other side — without requiring the user to repaint.

- Only available when at least one axial setting (X or Y) is active.
- User confirms which side is the **source** via a directional icon or "flip" control next to the button.
- Applies the reflection across the full map extent relative to the origin in one operation.
- Sent as batched column messages to the gadget; undoable as one step.
- Not available in Radial mode.

#### Interaction Summary

| Action | Result |
|--------|--------|
| Toggle Symmetry instrument | Shows origin gizmo + settings sub-panel |
| LMB on terrain (while instrument active) | Reposition origin |
| Enable Radial | Disables X and Y, shows Count spinner |
| Enable X or Y | Disables Radial if it was on |
| Enable both X and Y | 4-way quad mirror |
| Paint brush stroke (any mode) | All copies applied simultaneously; one undo entry |
| Click **Mirror** button | One-shot reflect of source half across active axis |
| Toggle instrument off | Symmetry disabled; origin and settings preserved for next activation |

#### Implementation Notes

- Coordinate transforms happen entirely on the **widget side**: the widget computes all N symmetric positions/orientations and sends each as a separate message in the same frame. The gadget requires no changes.
- For radial copies, each copy is a rotation of the brush center by `k × (360° / count)` around the origin; brush rotation incremented by the same angle.
- For axial mirror, the reflected position negates the appropriate world-space coordinate relative to the origin; brush rotation reflected (`rot → −rot`).
- Ghost cursors rendered at reduced alpha (≈ 40%) in `DrawWorld`.
- One-shot **Mirror**: reads `GetGroundHeight` for the source half, sends batched `$terraform_import$`-style column messages for the destination half.

---

## Overlays & Effects

### Height Colormap

A topographic elevation colormap drawn over the terrain inside the brush footprint. Toggle via the **Height Colormap** checkbox in the Overlays section.

- Color ramp from deep blue (low) → teal → yellow-green → amber → dark red (high).
- 64×64 texture built in a `RenderToTexture` pass, refreshed when brush center moves > 96 elmos.
- Texture mapped onto a terrain-conforming quad mesh (64-elmo cells) at α 0.35.
- When active, cap rows show a **SAMPLE** button for the [height cap eyedropper](#height-cap-sampling-colormap-eyedropper).

### Dust Effects (DJ Mode)

When enabled, each successful terrain modification spawns a burst of **particle CEG effects** and plays a **rumble sound** at the brush center. Intended for cinematic / performance use.

**Particle Burst:** `count = max(6, floor(radius / 100 × 12))` puffs. Each puff is placed at a random angle + distance inside the brush footprint (0.9× radius factor) and picks a random CEG from: `dust_cloud` · `dust_cloud_dirt_light` · `dust_cloud_fast` · `dust_cloud_dirt` · `dirtpoof`. Scale ∝ brush radius.

**Rumble Sound:** One sound plays at brush center per op, randomly from `lavarumbleshort1/2/3.wav`. Volume: `min(4.0, radius / 100)` (scales with brush size, capped at 4.0).

**Toggle:** Overlays panel. API: `WG.TerraformBrush.setDustEffects(bool)`. Serialized as field 13 (`dust`) in `$terraform_brush$`.

### Velocity-Sensitive Intensity

When enabled, brush intensity is scaled by mouse drag speed — slow drags apply weaker effect, fast drags apply stronger. Toggle in the Overlays section. API: `WG.TerraformBrush.setVelocityIntensity(bool)`.

---

## UI

### Panel Controls

Mode buttons (raise/lower/level/smooth/ramp/restore/noise) · Shape buttons · Parameter sliders with ±buttons · Undo/redo with history slider · Presets · Export/import buttons.

**Toggle Options:**
| Toggle | Default | Purpose |
|--------|---------|---------|
| Clay mode | off | Flat buildup — all modes and shapes |
| Grid overlay | off | 48-elmo alignment grid — permanently visible when on; also auto-shows during Shift+drag |
| Height colormap | off | Topographic colormap + contour lines inside brush footprint |
| Dust effects | off | CEG particle bursts + rumble sounds on each op (DJ Mode) |
| Velocity intensity | off | Scale brush intensity by mouse drag speed |

### Performance Mode

**Settings > General > Performance mode** (persisted in `ui_prefs.lua`). For big maps and slower machines; the tools stay the same, sculpting just samples more economically:

| Lever | Default | Performance mode |
|-------|---------|------------------|
| Dab spacing along the stroke | 15 % of radius | 24 % for soft curves (≤ 1.0) and clay, 20 % up to curve 2.0, 15 % above |
| Dabs per 20 Hz tick (cap) | 48 | 32 |
| FOLLOW STROKE angle step | 2° | 6° (a third of the stamp builds on shaped brushes) |
| Panel terraform mirror | every frame (every 4th frame while dragging) | every 4th frame; frame rate again while the mouse is over the panel |

The spacing rule is falloff-aware: a soft dome sums smoothly at a quarter radius and a clay stroke converges on one plane whatever the spacing, while hard-edged curves keep the full density so they do not band.

Two free levers regardless of the toggle: pausing the game while sculpting spares the pathfinder's terrain updates, and Focus mode (the eye icon in the header) drops the rest of the HUD.

Always on, no toggle needed: the gadget commits a tick's dabs in one heightmap write and one undo entry (see Undo / Redo System), the falloff-stamp cache is rotation-invariant for circles and rings and budgeted by cells, and the ground mesh refresh is armed by the engine's heightmap-update event rather than per brush tick.

### Multi-Screen Editing

The suite works under the engine's dual-screen mode: set `DualScreenMode = 1` in springsettings and open a borderless window spanning two monitors, and the engine gives the world view one whole display while the other becomes a free screen for UI. `DualScreenMiniMapOnLeft` picks which side is which. The editor's panels then:

- scale for the free screen (its height), not for the world view, so a 1440p tool screen beside a 4K world reads the same as a single-screen session;
- keep their single-screen widths (the px/vw rules are replaced by dp pins while dual is active), so rows and tool grids hold their proportions;
- drag freely between the two screens, and on engines with the per-document dp override a panel dropped on the world screen takes that screen's scale, back and forth.

On mixed-DPI desks (for example a 150%-scaled 4K beside a 100% 1440p) the engine must declare per-monitor DPI awareness (RecoilEngine PR #3400); without it Windows bitmap-stretches the spanned window on the secondary monitor regardless of anything the UI does.

### Presets

Built-in presets (non-deletable) and unlimited user presets. Stored in `LuaUI/Config/TerraformPresets/*.lua`.

**Built-in presets:** Ditch Digger · Sandworm · Crater · Mesa · Ball · Moat · Badlands · Dunes

**Saved parameters include:** mode, shape, radius, rotation, curve, intensity, lengthScale, brushOpacity, heightCapMin/Max/Absolute, clayMode, flattenToCursor, and overlay toggles.

**Preset UI:**
- Name input field with keyboard text entry (`SDLStartTextInput` on focus)
- **Save** button — saves current state under the typed name
- **Toggle dropdown** button — opens scrollable, searchable preset list
  - Type in name field to filter the list in real time
  - Click a preset row to load it (populates name field)
  - Click **X** on a row to delete (user presets only)

### Dynamic Slider Animation (Transport Controls)

Most sliders have an optional **DYNAMIC** toggle button inline. When enabled, it reveals a mini transport control group: **◀ ⏵ ▶**.

| Control | Action |
|---------|--------|
| ◀ | Animate slider in reverse; click again to increase speed (1–4×) |
| ▶ | Animate slider forward; click again to increase speed |
| ⏵ | When stopped → start forward; when running → pause/resume |
| RMB on ◀ or ▶ | Decrease speed by 1 step; stops at 0 |

Rotation sliders wrap at 0°/360°. Used on: height cap sliders, metal brush sliders, grass brush sliders, and start-position sliders.

### Unmouse (Brush Auto-Reposition)

When the mouse cursor moves over the terraform UI panel while the brush is active, the drawn brush silently slides to the opposite side of the screen to prevent accidental edits behind the panel. On mouse exit it snaps back. The brush tries three candidate positions in order: screen center → left quarter → right quarter, picking the first that clears the panel by at least one brush radius.

---

## AI Disclosure

This feature was developed with AI assistance (GitHub Copilot, Claude). AI was used to help write production code and to draft this documentation. All AI-generated code was reviewed, tested in-game, and verified by a human contributor. This disclosure is provided per the [AI Usage Policy](../AI_POLICY.md).