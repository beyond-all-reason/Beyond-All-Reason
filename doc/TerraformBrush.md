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
| `MMB` on a slider | Lock it to the mouse wheel (click it again, or any click on it, to release; `ESC` clears all) |
| `Ctrl+Z` / `Ctrl+Shift+Z` | Undo / Redo |

Full table in [Interaction → Keyboard](#interaction).

### Saving Your Work

- **Full map projects / team library**: **File > Save / Save As** saves a project; **File > Open Project** is one browser over this disk and the campaign team's private library, with a Sync column, a Team Sync line at the top and a start card for the companion. The team workflow is documented for the team in the library repository itself.
- **Autosave**: on by default (Settings > General). Every 10 minutes while the open project has unsaved changes, a snapshot lands under `MapProjects/_autosave/<project>-YYYYMMDDHHMM`; snapshots list under the Autosaves chip in **File > Open Project** and are swept after 3 days (the newest per project after 10). Opening one makes its project the Save target again.
- **Quitting with unsaved changes** asks first (Save, then continue / Don't save / Cancel) on the top bar's Quit and on New Map. The window's own close button cannot be caught; autosave covers that.
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

### Keyboard
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

**Files:** `luaui/Widgets/cmd_feature_placer.lua` · `luaui/RmlWidgets/gui_feature_placer/`

#### Scale Variation

Scale Min / Scale Max sliders (0.1-3.0x) roll a per-feature scale at placement
time. The roll is realised by snapping to the nearest **pre-baked model
variant** of the chosen def and placing that variant instead: a def opts in by
shipping sibling defs tagged `customParams.scale_base` (the def they vary) and
`scale_factor` (their size), with the model, collision cylinder, wood value and
mass all baked at that size. Variant defs are hidden from the asset library --
the placer reaches them only through snapping.

**No variant sets ship yet**, so the sliders are currently inert: a def with no
variants ignores the roll and places at its normal size, and the ghost preview
shows exactly that. The fir tree variants that drove this feature are shelved on
the `feature-densification` branch along with the tree clump work, together
with the offline script that bakes them.

- Rolls are bottom-heavy (many small, few large), matching a natural stand.
- With **Clustered** distribution, scale correlates with distance to the cluster
  nucleus: big features in the core, small ones at the fringe, and the minimum
  spacing scales per pair so small features pack tighter.
- Point mode rolls a scale per placement too.
- Variants are ordinary defs, so save/load, undo/redo, gizmo, and map projects
  need no special handling.

Why baked variants rather than scaling at runtime: the engine has no
feature-scale API. `Spring.Set{Unit,Feature}PieceMatrix` looks like one, but
`LocalModelPiece::SetPieceSpaceMatrix` is only
`return blockScriptAnims = mat.IsRotOrRotTranMatrix();` -- it validates the
matrix, sets a flag, and **discards the geometry entirely** (no member stores
it; a piece's transform comes solely from `CalcPieceSpaceTransform(pos, rot,
scale)`, and `SetPosition`/`SetRotation`/`SetScaling` are reachable only from
unit animation scripts). Features therefore cannot be scaled -- or have their
pieces posed at all -- from Lua. The gadget still understands a per-entry scale
token on the wire (4/5/7/8-token forms) and applies collision/radius/mid-aim
scaling, but only when the engine reports the matrix accepted, so on current
engines that path is a clean no-op and it lights up automatically if a real API
ever lands.

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
| RMB | Unchanged — erase brush, in every mode |

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

**Scale is not available.** The engine exposes no feature-scale setter.

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

- **Cluster nuclei**: 2–6 anchor points are randomly seeded inside the brush (count scales with √featureCount).
- **Cluster attraction**: ~75 % of features spawn near a randomly chosen nucleus via a Gaussian offset (σ ≈ radius / numClusters × 1.2).
- **Free scatter**: remaining ~25 % are placed uniformly at random inside the brush for a natural sparse background.
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

#### Terrain Meshes

A **terrain mesh** is a feature whose model becomes part of the map. Place it,
move it, rotate, tilt or lift it with every Feature Placer control, and the
ground under it follows: every heightmap vertex the model covers is set to the
height of the model's upper surface, so units path and drive over the model
exactly, its walls stop them by slope the way a cliff does, and a sloped top is
a ramp. The typemap cells under it switch to a terrain type with hardness 1000
(`Spring.SetTerrainTypeData` takes hardness as its sixth argument and the
engine divides crater depth by it), so explosions leave the ground alone, and a
synced reconcile pins the heights against anything that still moves them, the
tail of an explosion or a brush stroke under the mesh. Removing the feature
gives the ground back.

The first asset is the **Concrete Block** in the new Structures category
(128 x 128 x 48 elmos, generated together with its PBR textures and the
category icon by `c:/BAR-Github/tools/tf_mesh_block.py`). Any s3o built in a 3D
package works the same way: a feature def opts in with
`customparams.terrainmesh = "1"` (`features/terraformbrush_meshes.lua` lists the
other tags), and `luarules/gadgets/cmd_terrain_mesh.lua` reads the geometry
straight from the model file, rasterises the upper envelope of its triangles at
the feature's live transform (`GetFeatureDirection` hands back the engine's own
matrix columns, so no Euler convention is involved) and stamps it. Models
should carry a skirt below their origin, and `terrainmesh_inset` (default and
floor 8 elmos, one heightmap cell) only raises a vertex when the mesh also
covers that much ground around it. The terrain climbs to the top over the one
cell after the last raised vertex, so the foot of that climb sits `inset - 8`
elmos inside the wall; a half-cell inset put it outside for any mesh not
aligned to the 8-elmo grid, a berm climbing half the wall. Keep a model's
walls a couple of elmos outside its stamped footprint (the block's base is
132 elmos for a 128-elmo stamp).

The raised plateau sits exactly on the model's top face, so the two would
z-fight. The CUS GL4 gadget gives terrain meshes their own uniform bin
(`terrainmesh`, PBR like `featurepbr`) and draws it with
`gl.PolygonOffset(-2, -2)` in the forward and deferred passes: a hair of depth
toward the camera, enough to win the tie against the ground it sits on and
nothing more, so a hill in front still occludes it and units stand exactly on
the model. `terrainmesh_sink` (default 0) can still stamp the ground below the
surface for models that want it.

Why the feature is pinned with `SetFeatureMoveCtrl(enabled = true)` and zero
vectors rather than the masks-only lock used for lifted features:
`CFeature::UpdatePosition` lifts any feature the ground rises over, unmasked,
and `CFeatureHandler::TerrainChanged` re-queues every feature in a changed
area, so a block would pop onto its own top the frame after the stamp and the
re-stamp would chase it upward forever. The enabled branch never consults the
ground. Terrain meshes also skip the placement wobble, which would re-stamp
the ground on every frame of tilt.

Two more tags shape what counts as ground. `terrainmesh_clearance` (default 16
elmos) is head room measured from the model's placement plane: where the
mesh's lowest surface is higher than that above the plane, the spot is open
air (a floorless arch, the underside of a bridge) and stays untouched. It is
measured against the model, not the map, so a model lifted with the gizmo
keeps pulling the ground up to it: one block lifted 100 elmos is a 148-elmo
cliff. `terrainmesh_cap` lists model-space
rectangles, `"x1 z1 x2 z2 cap; ..."`, inside which surfaces higher than `cap`
are ignored. That is the explicit answer for a roofed passage whose model has
its own floor under the roof: no vertical probe can tell a hollow pillar from
a roofed passage (both show a floor, then a ceiling), so the def says where
the passage is. The Sci-Fi Gate uses one rectangle with a 20-elmo cap: floor
and door still count, roof and hanging lamp do not.

Converted assets come from `c:/BAR-Github/tools/gltf2s3o.py`: it takes a glTF,
GLB or a Sketchfab download zip, flattens the node hierarchy into one piece,
scales (default 8 elmos per metre), re-centres, puts the origin at the largest
flat surface, and merges materials into one texture pair, either an atlas with
tiled regions (a low-poly kit whose wall texture repeats a few times) or a
single texture whose UVs keep tiling (a SketchUp city with one facade texture
repeated hundreds of times, flat-coloured faces pinned to the closest texel).
`tools/tf_mesh_dump.lua` rasterises a converted s3o offline the way the gadget
would, so a footprint can be checked before a game is started. The Structures
category ships two such conversions as examples, both CC-BY-4.0 with the
credit lines in `features/terraformbrush_meshes.lua`: the Sci-Fi Gate (Free
Models., 1088 triangles, atlas) and the Cyberpunk City (Pasha, 289k triangles,
about 6150 elmos wide at scale 0.332; the 17 MB model is a stress test as
much as an asset: its stamp pins some 600k vertices, sampled per vertex rather
than per half cell above 1.2M coverage cells). The city's own UVs are a
single photo projected from one camera and smear from any other angle, so it
is exported with `--uv-mode box`: the source UVs are dropped and a seamless
texture pair is projected along the world axes, walls taking the two axes
across their face and roofs and streets pinned to a plain texel. The pair is
`unittextures/tf_facade_*.png` from `tools/tf_facade_tex.py`, dark concrete
with a window grid, a share of the windows lit and emissive.

Overlapping meshes stack in placement order; removing one unwinds the stamps
above it and re-applies them. A mesh whose ground is not known to be real (a
project load, whose heightmap already carries the stamp, or a `/luarules
reload`) heals the ground on removal by relaxation from the surrounding ring
instead of restoring a snapshot. `/luarules tmesh` prints the status,
`/luarules tmesh restamp` recomputes every stamp.

### Grass Brush

Brush-based grass density painting over the GL4 grass system.

- **LMB**: paint density up · **RMB**: erase
- Controls: shape, size, rotation, curve, density slider
- **Smart filters**: water, cliff, altitude — same filter UI as Feature Placer
- **Color filter**: sample terrain diffuse color under the brush; reject cells outside hue/value tolerance
- **Export**: TGA 8-bit grayscale for map packaging (compatible with `smf.grassmapTex` override)

**Files:** `luaui/Widgets/cmd_grass_brush.lua` (API extension via `map_grass_gl4.lua`)

### Weather Brush

Places CEG-based weather effects (particles, ambient sounds) with persistence/cadence/frequency controls. Similar panel layout to Feature Placer.

### Clone Tool

Region-based copy & paste across all map data layers. Select an area, capture its contents, and stamp it elsewhere with rotation, mirroring, and height offset.

**Files:** `luaui/Widgets/cmd_clone_tool.lua` · `luarules/gadgets/cmd_clone_tool.lua`

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
| **Weather** | Widget Lua table (weather brush state) | Re-emit via weather brush message | ⬜ Stub (awaiting `WG.WeatherBrush` API) |
| **Lights** | `WG.LightPlacer` API state | `Spring.AddMapLight` with rotation/offset | ✅ Implemented (toggle disabled) |
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

## Protocol & Data

### Message Protocol

All terrain edits go through `SendLuaRulesMsg()` to the server-side gadget.

| Message | Format |
|---------|--------|
| `$terraform_brush$` | `dir x z radius shape rot curve capMin capMax intensity lengthScale clay dust opacity instant flattenHeight [ringInnerRatio]` |
| `$terraform_stroke$` | `dir radius shape curve capMin capMax intensity lengthScale clay dust opacity instant flattenHeight ringInnerRatio nDabs x1 z1 rot1 [x2 z2 rot2 ...]` — one per tick per symmetry copy, every dab of the tick; applied as one batch (one heightmap commit, one undo entry) |
| `$terraform_ramp$` | `startX startZ startY endX endZ endY radius clay dust` |
| `$terraform_ramp_spline$` | `radius pointCount [x1 z1 x2 z2 ...] clay dust` |
| `$terraform_restore$` | `x z radius shape rot curve intensity lengthScale` |
| `$terraform_noise$` | `x z radius shape rot curve intensity lengthScale noiseType scale octaves persistence lacunarity seed` |
| `$terraform_import$` | `columnX height1 height2 ...` |
| `$terraform_undo$` | (no args) |
| `$terraform_redo$` | (no args) |
| `$terraform_merge_end$` | (no args) — sent by the widget after every brush tick; closes the tick's undo entry |
| `$terraform_stroke_end$` | (no args) — sent on mouse release; advances the stroke id (`$terraform_undo_stroke$` pops all entries of the latest id) and drops the pre-stroke heights the clay plane measures against |

**Feature placer messages** (`luarules/gadgets/cmd_feature_placer.lua`). Every
mutating branch is gated on `Spring.IsCheatingEnabled()`.

| Message | Format |
|---------|--------|
| `$feature_place_list$` | `strokeId` then `name x z heading [pitch roll y] [scale]` per entry, joined by `\|`, 40 per message. Token count disambiguates: 4 plain, 5 scale, 7 tilt, 8 tilt+scale |
| `$feature_transform$` | `strokeId` then `fid x y z pitch yaw roll` per entry, joined by `\|` |
| `$feature_remove_ids$` | `fid` per entry, joined by `\|` |
| `$feature_remove$` | `x z radius shape rot` |
| `$feature_load$` | Same format as `$feature_place_list$`; one stroke id for the whole file, skips the placement wobble |
| `$feature_save$` | (no args) — gadget replies over `SendToUnsynced` |
| `$feature_undo$` / `$feature_redo$` / `$feature_clearall$` | (no args) |

The optional `pitch roll y` tail is only sent for features the gizmo tilted or
lifted, and the optional `scale` token only for features whose scale roll came
out different from 1. `strokeId` collapses one user action into one undo entry even when it is
split across several messages -- a 500-feature stamp is 13 batches, a gizmo drag
over a large selection several more -- the same way the terraform brush merges a
paint stroke. Only one stroke is open at a time, and the entry is pushed lazily
on the first real change, so a no-op message neither leaves an empty undo step
behind nor clears the redo stack.

`$feature_scatter$` and `$feature_point$` are **gone**. They asked the gadget to
roll its own positions, which is exactly what made a truthful placement preview
impossible; the widget generates layouts now and sends the result.

**Saved feature format** (`features.lua`, FeaturePlacer `setcfg`):

```lua
{ name = "treetype1", x = 1234.0, z = 5678.0, rot = 32768 }
{ name = "rock01", x = 900.0, z = 200.0, rot = 0, pitch = 0.2100, roll = -0.0800, y = 412.5 }
```

`pitch`/`roll`/`y` are written only when the feature is genuinely transformed, so
a map that was never gizmo-edited serialises byte-for-byte as it did before.
Files without them load exactly as they always did.

"Transformed" is **not** "pitch is non-zero". Non-upright feature defs are
ground-aligned by the engine, so a rock on any real slope carries a pitch and
roll nobody gave it. The test compares the feature's up-vector against its
expected resting up -- `(0,1,0)` for an upright def, the ground normal otherwise
-- which is the quantity `UpdateDirVectors` actually sets, and is free of gimbal
lock. Lift stays a plain 0.5-elmo threshold.

The data is collected **synced**, in the gadget. `Spring.GetFeatureRotation`
called from LuaUI reads `transMatrix[0]`, which `FeatureDrawerData` only
refreshes for features drawn that frame, so an unsynced walk reports zero
rotation for everything off screen and the saved bytes would depend on where the
camera was pointing. `WG.FeaturePlacer.requestFeatureData(callback)` wraps the
round-trip; the Map Project save uses it, falling back to a transform-free
unsynced walk when `/cheat` is off -- in which case nothing can have been
gizmo-transformed anyway.

**`$terraform_brush$` field reference:**

| # | Field | Type | Notes |
|---|-------|------|-------|
| 1 | `dir` | int | +1 raise, −1 lower, 0 level/smooth/restore |
| 2–3 | `x z` | float | World position |
| 4 | `radius` | float | 8–2000 |
| 5 | `shape` | string | circle / square / triangle / hexagon / octagon / ring |
| 6 | `rot` | float | Degrees |
| 7 | `curve` | float | 0.1–5.0 |
| 8–9 | `capMin capMax` | float or empty | Height cap bounds |
| 10 | `intensity` | float | 0.1–100 |
| 11 | `lengthScale` | float | 0.2–5.0 |
| 12 | `clay` | 0/1/2 | Clay mode (`2` = with per-tick build-up) |
| 13 | `dust` | 0/1 | Dust/DJ mode |
| 14 | `opacity` | float | 0.01–1.0 |
| 15 | `instant` | 0/1 | Stamp mode |
| 16 | `flattenHeight` | float or `nil` | Level/smooth target height; `nil` = sample live |
| 17 | `ringInnerRatio` | float (optional) | 0.05–0.95; only sent when changed |

### Heightmap Export/Import

#### Export
1. Reads `GetGroundHeight()` for every grid cell
2. Normalizes to 0–1 grayscale
3. Renders quads into an FBO, calls `gl.SaveImage()` **inside** the RenderToTexture callback (required — separate binding reads blank)
4. Writes companion `.txt` with min/max altitude range

#### Import
1. Loads PNG as texture → renders to FBO → reads pixels
2. Reads metadata for min/max range
3. Converts grayscale → height: `minH + grey × heightRange`
4. Sends 32 columns/frame via `$terraform_import$` messages (throttled to avoid network flood)

---

## Internals

### Rendering

#### Draw Cache
GL display list cached and only rebuilt when any parameter changes. Validated via `isDrawCacheValid()` comparing a snapshot of all active params.

#### Brush Visuals
Each frame draws in two passes:

**Animated glow (outside cache):** Two overlapping outlines — a wide (9px) outer halo and a narrower (4px) inner ring — both in the mode colour and alpha-pulsed at ~1.3 Hz via `GetDrawFrame()`. This fires every frame before the cached pass so the pulse animates even when the brush is stationary.

**Static cached pass** (rebuilt only when params change):
| Element | Description |
|---------|-------------|
| **Footprint fill** | Terrain-following semi-transparent polygon (α 0.07) tinted in the mode colour; uses `GetGroundHeight` per vertex for correct hill-hugging |
| **Outline** | 1.5 px line in mode colour (α 0.78) |
| **Prism / height-cap** | Wireframe prism when caps are set — orange top plane, cyan bottom plane, white vertical struts |
| **Falloff arc** | Closed 3D arc showing the falloff profile; drawn in each mode's *bright* accent colour |
| **Curtain drops** | Sparse vertical lines dropping from arc vertices to the base plane; reinforces the volume of effect at a glance |
| **Center post** | Vertical ruler shaft from ground to max effect height; peak cross-tick + mid-height minor tick give a quick scale reference |

#### Falloff Visualization
Each shape type computes per-vertex height using its distance metric raised to `curvePower`. The arc + curtain combo shows both the profile shape and where the effect drops to zero. Color-coded by mode: green (raise), red (lower), cyan (level), yellow (ramp), purple (restore), orange (noise).

#### Mode Color Palette
| Mode | Outline | Falloff / post |
|------|---------|----------------|
| Raise | `0.2 0.8 0.2` (green) | `0.45 1.0 0.45` (bright green) |
| Lower | `0.8 0.2 0.2` (red) | `1.0 0.45 0.45` (bright red) |
| Level | `0.3 0.5 0.9` (blue) | `0.5 0.78 1.0` (bright blue) |
| Restore | `0.7 0.3 0.9` (purple) | `0.88 0.58 1.0` (bright purple) |
| Noise | `0.96 0.62 0.04` (amber) | `1.0 0.82 0.3` (bright gold) |
| Ramp | `0.9 0.7 0.2` (yellow) | `1.0 0.88 0.4` (bright yellow) |

#### Tessellation Dirty Tracking
After each terraform op, `tessellationDirtyFrames` is set to 10. Counter decrements per frame, ensuring the engine re-tessellates the terrain mesh over the affected area.

### Undo / Redo System

History is maintained as a **server-side stack** in the gadget. All terrain modifications snapshot the previous state before applying.

#### Stroke Entries (One Per Tick)

Each brush tick sends one `$terraform_stroke$` message per symmetry copy carrying every dab of that tick. The gadget applies the dabs in order against a working copy of the cells they touch (read from the engine once, on first touch) and commits **once per message**: one `SetHeightMapFunc` (so one engine terrain recalculation) and **one undo entry** built straight from the pre-tick heights of the cells it wrote. Dab k still sees dab k-1's writes, so the result is what sequential commits produced, at a fraction of the engine work.

Entries of one drag share a stroke id: `$terraform_merge_end$` closes the tick, `$terraform_stroke_end$` (mouse release) advances the id, and `$terraform_undo_stroke$` pops every entry with the latest id in one step. Cross-tick merging is deliberately not done (it produced striped leftovers on undo).

Ramp and spline operations always produce a new independent entry.

#### Storage Format

Snapshots are stored as a **bbox grid**: a mask and a height grid over the entry's bounding box (`minX`, `minZ`, `w`, `h`, `ss`). Cells still at their map-original height store a mask bit only (`2`) and no height; edited cells store `1` plus the pre-edit height. Brush ticks build the grid directly from their working copy; the ramp, noise, erode and fill ops convert a flat `{x, z, h, ...}` buffer, which itself replaced per-vertex sub-tables that used to spike GC.

#### Vertex Budget (Anti-OOM)

| Constant | Value | Meaning |
|----------|-------|---------|
| `MAX_UNDO` | 10000 | Maximum entries in undo or redo stack |
| `MAX_SNAPSHOT_VERTICES` | 8 000 000 | ~192 MB — total vertex budget across all stacked snapshots |

When `totalVertexCount` exceeds the budget, the **oldest** undo entries are evicted until under budget. If still over, the oldest redo entries are also evicted. This prevents OOM crashes with very large-radius restore/noise operations on wide maps.

---

## Known Constraints

- `Spring.Echo()` inside `SetHeightMapFunc` silently crashes — no debug logging in height callbacks
- OpenGL calls only valid in Draw call-ins, not action handlers
- `gl.CreateShader` returns `0` on failure (truthy in Lua) — must check `== 0`
- `gl.SaveImage` must be inside the same `RenderToTexture` binding where content was drawn
- A "clone window" system (drag toolbar buttons to spawn floating panel copies) was prototyped and removed — fundamental limitations in RmlUI's `Clone()` API (no event listener copying) and bidirectional sync complexity made it unmaintainable. The write-up lives in the branch history (doc/TerraformBrush_CloneWindows.md before it was pruned for merge).

---

## Roadmap

Development is organized into **release milestones**.

> **MoSCoW**: M = Must have, S = Should have, C = Could have, W = Won't (this cycle).
> **Complexity**: 1 (trivial) – 10 (hardest item on the list).

### Pending Backlog

| # | Item | MoSCoW | Complexity | Notes |
|---|------|--------|:----------:|-------|
| 1 | **Full WYSIWYG preview** | S | 8 | Show actual resulting terrain deformation in real-time under the brush cursor before committing. Requires a scratch heightmap buffer + shader-based preview mesh. |
| 6 | **Ramp width taper** | C | 4 | Allow radius to vary along the ramp path for natural road-like shapes. |
| 9 | **Per-axis radius sliders** | C | 3 | Replace single radius + lengthScale with independent X/Z radius controls. |
| 14 | **Light animations** | S | 6 | Timed/looped animations: pulsing, flickering, color cycling. `animation` field already reserved. Presets for torch flicker, alarm strobe, slow breathe. |
| 15 | **Light gizmo tool** | S | 6 | Select placed lights (click/box-drag), manipulate with 3D gizmo: translate, rotate direction, adjust radius, delete. `selectedLight` state already stubbed. |
| 17 | **Drawing pad / tablet support** | C | 4 | Map pen pressure to brush intensity/radius, pen tilt to rotation. Requires detecting tablet input events and exposing pressure-curve settings in UI. |
| 18 | **Direct map-file workflow** | S | 9 | Work directly with a map file (`.sd7`/`.smf`), saving and loading all changes and configurations into it. Explore whether full map compilation/decompilation is possible within the tool or engine. |
| 19 | **Brush color sampling** (Smart Filter) | C | 5 | Sample the terrain/splat color under the brush as a smart-filter criterion. Extends the Smart Filter panel with a color-pick eyedropper and adjustable hue/value tolerance. |
| 22 | **Brush alpha masks** | C | 6 | *Post-1.0.* Texture-based brush shapes: load grayscale PNG/TGA masks to drive per-pixel intensity falloff. Mask library with thumbnails; rotation + scale + flip; intensity remap curve. Applies to terraform, grass, splat, and decal brushes. |

### QoL / Future Instruments

| Instrument | Notes |
|---|---|
| **Contour lines** | Elevation isolines at configurable intervals drawn world-space (like topo maps). |
| **Slope/gradient overlay** | Color terrain by steepness: flat=green, moderate=yellow, cliff=red. |
| **Aspect map** | Color terrain by face direction (N/S/E/W) — useful for ramp orientation and drainage. |
| **Water depth overlay** | Below-zero terrain colored by depth gradient (shallow=turquoise, deep=dark blue). |
| **Normal/curvature map** | Highlight ridges vs. valleys via surface curvature coloring. |
| **Passability grid** | Show engine mobility-map per unit class as a color-coded per-cell overlay. |
| **LoS shadow map** | Given an observer height, shade terrain outside line-of-sight — design dead ground intentionally. |
| **Metal density heatmap** | Overlay the raw metal distribution map for metal-map terraform. |
| **Running distance HUD** | Display current drag distance in elmos as you paint a ramp stroke. |
| **Terrain cross-section profile** | Draw a line → pop up a miniature elevation graph showing height vs. distance along the transect. |
| **Height dropper** | Click to lock exact ground height at a point as the Level brush target (explicit eyedropper). |
| **Exact coordinate entry** | Number-field to teleport the brush center to a typed X/Z/(H) world position. |
| **Guide lines** | Drag out persistent reference lines (H/V or arbitrary angle) that snap the brush to their intersections. |
| **Stakeout pins** | Alt+click to place named height-target pins; brush can optionally snap to pin height. |
| **Radial range rings** | Concentric circles at configurable intervals centered on a fixed point or the brush. |
| **Optimal path planner** | Given start/end and max-grade constraint, compute and preview a minimum-cut ramp path. |
| **Lazy mouse** | Configurable cursor-lag / path smoothing for clean hand-painted ramps without jitter. |
| **Height isolines snap** | Snaps Level mode's target height to the nearest N-elmo contour. Pairs with contour overlay. |

### Release Plan

#### Pre-release — Stabilization

- Full QA pass: verify every feature, button, and mode still works; fix regressions
- Review config outputs and texture files; determine how (and if) remaining items should wire into maps for a clean workflow and integration path

#### Release 1.0 — "We have a map editor at home"

Ship a stable, usable tool so mappers can start using it instead of Springboard abandonware. Goal: replace the need for an external editor for day-to-day terrain work.

- All existing features stable and documented
- Gather mapper feedback, address most glaring issues and low-hanging-fruit requests
- Start chipping away at remaining backlog items (game, infra, possibly some engine work) — large effort but can progress async

#### Release 2.0 — "MOAR FEATUR!"

Major feature expansion. Key themes: **preview**, **manipulation**, **integration**.

- **Full WYSIWYG support** — see resulting terrain/feature placement before committing (backlog #1, #2)
- **Gizmo controls** — select any placed object (feature, grass patch, light, decal) and adjust with a 3D gizmo: translate, rotate, scale, delete (backlog #3, #15)
- **Light animations** — keyframes, pulsing, flickering, color cycling presets (backlog #14)
- **Direct map-file workflow** — all configs and textures save/load in the map file itself (backlog #18)
- **Dev tool integrations** — interop with other BAR dev tools and, most importantly, the mission API
- **UI polish** — sleek icons for all buttons and panels, general visual cleanup
- …and 100 other things that will come along the way

#### Release 3.0 — "Look at me, I'm the map editor now"

When the engine provides a **triplanar shader** for nice cliffs without World Machine assistance, this release pursues full replacement of external map-editing tools.

- **Texture painting** — brush-based terrain texture application with blend modes
- **Erosion simulation** — procedural hydraulic/thermal erosion passes on the heightmap
- **Advanced terrain sculpting** — all the fancy stuff that makes external tools unnecessary
- More fancy stuff TBD as the engine capabilities solidify

#### Release 4.0 — "Brooo this is like a 4D map editor, man"

Temporal dimension: **record and playback** brush strokes for dynamic, time-varying maps.

- **Stroke recording** — capture any brush tool's strokes (terraform, CEGs, features, skybox, and anything else configurable in real-time in Recoil — which is *almost everything*) into a config file
- **Playback engine** — replay recorded strokes with adjustable playback speed
- **Mission API integration** — trigger map-change playback sequences from the mission API for dynamic in-game scenarios (terrain shifts mid-mission, evolving battlefields, scripted environmental events)

### Completed Features

<details>
<summary>Backlog items already shipped — click to expand</summary>

| # | Item | Notes |
|---|------|-------|
| 2 | **Feature placement preview** | WYSIWYG ghosts: the exact features about to be placed, at their exact positions and orientations, drawn as instanced translucent models under the cursor. Remove mode tints what the brush would destroy. See [Feature Placer → WYSIWYG Preview](#wysiwyg-preview). |
| 3 | **Feature gizmo tool** | Click / shift-click / box-drag to select placed features; 3D gizmo with X/Y/Z translate arrows, pitch/yaw/roll rings and a free-move centre handle. Groups transform rigidly about their centroid; per-feature visual scale is rolled at placement time (see [Feature Placer → Scale Variation](#scale-variation)). See [Feature Placer → Selection & Gizmo](#selection--gizmo). |
| 4 | **Symmetry tool** | Full implementation. Mirror X/Y modes with axis angle rotation; N-way radial mode (2–16 copies); draggable origin gizmo; Flipped mode (mirror + invert heights); one-shot Mirror Terrain button. See [Instruments → Symmetry / Mirror Tool](#symmetry--mirror-tool). |
| 5 | **Velocity-sensitive intensity** | Toggle in Overlays section; scales brush strength by mouse drag speed. See [Velocity-Sensitive Intensity](#velocity-sensitive-intensity). |
| 7 | **Partial restore slider** | Slider in restore mode; 0–100% blend target sent to gadget. See [Restore](#restore). |
| 8 | **Triangle shape** | Keybind T, widget + gadget + RML button. See [Shapes](#shapes). |
| 10 | **Height cap filled preview** | TRIANGLE_FAN fill at low alpha behind LINE_LOOP outlines for caps. See [Height Caps](#height-caps). |
| 11 | **Import progress bar** | `getState()` exposes progress; RML bar + label update per frame. |
| 12 | **UI panel keyboard shortcut** | `terraformpanel` action toggles panel visibility. |
| 13 | **Grass editor** | Brush-based grass painting (LMB/RMB), density slider, shape/size/rotation/curve controls, smart filters (water/cliff/altitude), color-based filtering, TGA export. Widget: `cmd_grass_brush.lua`, API extension in `map_grass_gl4.lua`. Pipette feature deferred (FBO axis-mapping issues). |
| 16 | **Copy & paste → Clone Tool** | Full region clone tool with terrain, metal, features, splats, grass, decals, and lights layers. Rotation, mirroring, height offset. Weather layer stubbed (awaiting `WG.WeatherBrush` API). See [Clone Tool](#clone-tool). |
| 20 | **Protractor** | Angle-snap instrument with configurable degree grid, spoke overlay, auto/manual modes. See [Instruments → Protractor](#protractor). |
| 21 | **Measure tool** | World-space ruler with chainable polylines, Bezier handle curves, Ruler/Sticky/Distort sub-modes, symmetry integration. See [Instruments → Measure Tool](#measure-tool). |

</details>

---

## Technical Notes — Terrain Color Sampling

> Written: 2026-04-16
> Relevant to: Grass Brush color filter, Splat Painter terrain preview swatch

### The Problem: `$minimap` gives wrong colors

The naive approach — sampling terrain color from `$minimap` via world-space UV — produces colors that **do not match what the player sees**. The minimap is rendered by a separate, simplified shading pipeline (no deferred lighting, no PBR, different gamma and texture blending). Even with perfect UV math the RGB values are fundamentally different from the viewport.

### Failed Approaches (history)

All of these were tried before the working solution was found:

| # | Approach | Why it failed |
|---|----------|---------------|
| 1 | **NxN FBO batch render of `$minimap` region + batch ReadPixels** | Distortion increasing from the center of the viewport. The world-space UV to minimap TexRect region mapping is unreliable — pixel positions shift depending on viewport angle/zoom. |
| 2 | **Per-cell `RenderToTexture` calls inside a single outer `RenderToTexture`** | Mirror/axis flip artefacts persisted. Nested FBO binds do not work reliably in the Spring GL layer. |
| 3 | **Per-cell `RenderToTexture` calls, each in its own top-level call** | Still produced mirrored/wrong colors. Root cause was `$minimap` itself, not the mapping. |
| 4 | **`gl.RenderToTexture` + `gl.ReadPixels` in the same callback** | ReadPixels is unreliable when called inside the same RenderToTexture callback as the render. GPU has not flushed yet. Results were garbage or zero. |
| 5 | **All FBO operations in `DrawWorld`** | GL context is wrong. Deferred G-buffer textures are only valid during the screen-space pass (`DrawScreen`). Calls silently failed or sampled stale data. |
| 6 | **Viewport-sized FBO (full screen bbox, no size cap)** | Worked for small brushes but caused **LuaUI OOM crash** for large brushes. `gl.ReadPixels` for an 800x800 px bbox returns 640,000 Lua table entries per frame. LuaUI heap (1.5 GB) exhausted in seconds. Error: `gl.RenderToTexture: error(4) = not enough memory`. |
| 7 | **Deferred ReadPixels (frame N+1) without the OOM fix** | Eliminated the `SwapBuffers` 81ms stall, but the heap exhaustion crash persisted because the FBO was still screen-sized. |

**Other ideas investigated but not pursued:**

- `Spring.GetGroundDiffuseColor(x,z)` — no such function exists in Recoil.
- `gl.SaveImage` to dump `$minimap` to disk once, load as regular texture — would still give wrong colors (it is the wrong texture).
- Render `$minimap` to a large FBO once at widget init — same wrong-color problem, plus not live.
- `gl.ReadPixels` on `$minimap` directly without FBO — not supported by the engine API.

### The Solution: `$map_gbuffer_difftex`

`$map_gbuffer_difftex` is the **terrain G-buffer diffuse texture** — the actual output of the terrain deferred renderer, in **screen space**. Its UV goes from `(0,0)` at the bottom-left of the viewport to `(1,1)` at the top-right.

To sample the color at a world position:

```lua
local vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
local sx, sy = Spring.WorldToScreenCoords(wx, Spring.GetGroundHeight(wx, wz), wz)
local u = (sx - vpx) / vsx   -- clamp to [0,1]
local v = (sy - vpy) / vsy
-- then TexRect into a small FBO using u,v
```

For the **mouse cursor** (e.g. splat painter terrain swatch), the mouse is already at a screen position — no WorldToScreenCoords needed:

```lua
local mx, my = Spring.GetMouseState()
local vsx, vsy = Spring.GetViewGeometry()
local u = mx / vsx
local v = my / vsy
```

### Batch Cache (Grass Brush — `buildDiffuseCache`)

For the grass brush, we need terrain color at every cell of a 48x48 world grid, once per frame. Individual per-cell FBO calls would be catastrophically slow. Strategy:

1. **Project all grid cells** to screen via `WorldToScreenCoords` — compute screen bounding box (minSX, maxSX, minSY, maxSY).
2. **Render the bbox** from `$map_gbuffer_difftex` into a single **capped FBO** (max 96x96) using one `gl.TexRect` call. The FBO is smaller than the screen bbox — scaled down, but 48x48 grid resolution is more than enough for grass placement decisions.
3. **Deferred ReadPixels**: render on frame N, call `gl.ReadPixels` on frame N+1. This eliminates the synchronous GPU-to-CPU stall that caused ~81ms `SwapBuffers` spikes.
4. **Per-cell lookup**: convert each cell's screen offset to FBO pixel coords using `scaleX = capW / bboxW`.

### FBO Size Cap — OOM Fix

`gl.ReadPixels(0, 0, W, H)` returns a nested Lua table: `W x H` entries, each `{r,g,b,a}`. For a large brush on a 1440p display the raw bbox can exceed 1000x1000 pixels — 1 million+ Lua table allocations per frame — LuaUI Lua heap (1.5 GB limit) exhausted in seconds — crash.

**Fix:** cap the FBO at `DIFFUSE_GRID_MAX * 2 = 96` pixels on each side. Max ReadPixels allocation: 9,216 pixels = completely safe.

### Two-Pass Rule

`gl.ReadPixels` inside a `gl.RenderToTexture` callback is unreliable when called in the same pass as rendering. Always split into two separate `gl.RenderToTexture` calls:

```lua
-- Pass 1: render
gl.RenderToTexture(fbo, function()
    gl.Texture("$map_gbuffer_difftex")
    gl.TexRect(-1, -1, 1, 1, u0, v0, u1, v1)
    gl.Texture(false)
end)
-- Pass 2: read (separate call)
local pixels
gl.RenderToTexture(fbo, function()
    pixels = gl.ReadPixels(0, 0, w, h)
end)
```

### GL Context Rule

All FBO operations (`gl.RenderToTexture`, `gl.ReadPixels`, `gl.CreateTexture`) must run inside `widget:DrawScreen()`, never `DrawWorld()`. The deferred G-buffer textures (`$map_gbuffer_difftex`) are only valid during the screen-space render pass.

### RmlUI Icon Rendering Rule

BAR's RmlUI path is picky about PNG icon pixels. Semi-transparent white source art can render as flat white, pick up fringe artifacts, or even show boxy backgrounds if transparent pixels carry color.

**Safe icon export recipe for Terraform Brush toolbar/panel icons:**

- Visible pixels: avoid pure white RGB. Use a neutral gray instead, while preserving the intended alpha shape.
- Fully transparent pixels: force them to true transparent black: `RGBA(0,0,0,0)`.
- If edges still look ragged, use alpha-weighted grayscale for visible pixels rather than a constant white fill.
- Prefer fixing the PNG pixel data directly. Do **not** rely on RCSS `image-color` to rescue bad source art; it can introduce mismatched brightness and extra artifacts.

**Practical rule of thumb used here:**

- For each visible pixel, keep or slightly tune alpha as needed for crispness.
- Set RGB to a gray value that tracks alpha, instead of leaving it at `255,255,255`.
- For any pixel with `alpha == 0`, zero all channels.

This rule fixed repeated issues with Terraform Brush shape, paint, distribution, light, ramp, and environment icons.

---

## Future Work — Metal Spot As Decal (Post-1.0)

Groundwork has been laid for a "metal spot as decal" pipeline that lets mappers
capture an in-engine top-down render of a metal patch (or any small area of
terrain) and reuse it as a custom ground decal via the standard
`gamedata/resources.lua` `graphics.decals` registration path.

Pieces already in place on the `realtime-terraformer` branch:

- `luaui/Widgets/cmd_decal_capture.lua` — `/decalcapture <name> [radius]`
  console command. Runs a fullscreen-quad fragment shader on `DrawScreen` that,
  per output texel, reconstructs world XZ from the cursor-centered capture
  rect, samples `$heightmap` for Y, projects through the current view-projection
  matrix, and reads `$map_gbuffer_difftex`. Off-screen / behind-camera texels
  go transparent; a radial feather is applied at the edge. Output is a 512×512
  PNG written to `LuaUI/Cache/decal_captures/<name>.png`.
- `luaui/Widgets/cmd_decal_placer.lua` — custom decals registered in
  `gamedata/resources.lua` are picked up automatically by the existing decal
  list (engine assigns them `maindecal_<i>`), and Point mode now defaults to
  `decalCount = 1` / `cadence = 1` so single-shot placement works without
  knob fiddling.
- `luaui/RmlWidgets/gui_decal_placer/gui_decal_placer.lua` — the picker
  honors `entry.displayName` for filter/label so user-friendly names show up
  alongside the engine's `maindecal_<i>` keys.

Known limitations / explicitly **deferred to post-1.0**:

- Capture only includes what is currently on-screen — the user must frame the
  area before invoking the command.
- Diffuse channel only. Normal/specular capture not yet wired.
- Alpha is a flat radial feather; no smart color isolation (e.g. "only metal-
  spot pixels") yet.
- No automatic atlas registration. After capture the user must manually:
  1. Move the PNG into `bitmaps/decals/`.
  2. Append the filename to `gamedata/resources.lua` `graphics.decals`.
  3. Restart the game so the engine atlas rebuilds.

The intent post-1.0 is to wire this into the Terraform Brush's decal-aware
flow so that metal spots placed through the brush can carry a custom
captured decal instead of relying solely on the shipped atlas tiles.

---

## AI Disclosure

This feature was developed with AI assistance (GitHub Copilot, Claude). AI was used to help write production code and to draft this documentation. All AI-generated code was reviewed, tested in-game, and verified by a human contributor. This disclosure is provided per the [AI Usage Policy](../AI_POLICY.md).