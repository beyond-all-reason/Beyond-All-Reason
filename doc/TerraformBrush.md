# Terraform Brush — Feature Reference

Custom terrain editing tool replacing BAR's default terraform commands with a unified brush-based workflow.

**Files:** `luaui/Widgets/cmd_terraform_brush.lua` · `luaui/RmlWidgets/gui_terraform_brush/`

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

"Flat buildup" — creates plateau-like terrain with a flat top at the brush's target height rather than the standard dome falloff. Sent as a flag (`0`/`1`) in the terraform message. Toggle with `X`.

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

Distribution mode (random/regular/clustered) · Size/rotation/count/cadence sliders · Undo/redo · Save/load/clear

**Files:** `luaui/Widgets/cmd_feature_placer.lua` · `luaui/RmlWidgets/gui_feature_placer/`

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
| **Splats** | FBO blit of `$ssmf_splat_distr` sub-rect | Shader paste into splat FBO → `SetMapShadingTexture` | ✅ Full |
| **Grass** | `WG['grassgl4'].getDensityAt(x,z)` per patch | `setDensityAt(x,z,val)` per patch | ✅ Full |
| **Decals** | `Spring.GetAllGroundDecals()` + per-decal queries | `Spring.CreateGroundDecal()` with transforms | ✅ Implemented (toggle disabled) |
| **Weather** | Widget Lua table (weather brush state) | Re-emit via weather brush message | ⬜ Stub (awaiting `WG.WeatherBrush` API) |
| **Lights** | `WG.LightPlacer` API state | `Spring.AddMapLight` with rotation/offset | ✅ Implemented (toggle disabled) |
| **Terrain Texture (PBR)** | *Deferred* | *Deferred* | ⬜ Deferred |

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
| `$terraform_ramp$` | `startX startZ startY endX endZ endY radius clay dust` |
| `$terraform_ramp_spline$` | `radius pointCount [x1 z1 x2 z2 ...] clay dust` |
| `$terraform_restore$` | `x z radius shape rot curve intensity lengthScale` |
| `$terraform_noise$` | `x z radius shape rot curve intensity lengthScale noiseType scale octaves persistence lacunarity seed` |
| `$terraform_import$` | `columnX height1 height2 ...` |
| `$terraform_undo$` | (no args) |
| `$terraform_redo$` | (no args) |
| `$terraform_merge_end$` | (no args) — sent by widget on mouse release to finalize the drag-stroke undo entry |
| `$terraform_stroke_end$` | (no args) — marks the end of a distinct stroke for diagnostics |

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
| 12 | `clay` | 0/1 | Clay mode |
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

#### Stroke Merge (Drag → Single Undo Entry)

Each brush stroke fires many `$terraform_brush$` messages per second while the mouse is held. Rather than creating hundreds of separate undo entries, all changes during a single drag are merged into **one entry**:

- On each push during an active drag, new vertices are added to the current snapshot — duplicates (same x/z already snapshotted) are skipped via a numeric hash set, so re-visiting a cell doesn't grow the snapshot.
- When the mouse is released the widget sends **`$terraform_merge_end$`**, which finalizes the snapshot and closes the merge window.
- Undo/redo each restore the entire drag stroke in a single step.

Ramp and spline operations always produce a new independent entry (no merge).

#### Storage Format

Snapshots are stored as **flat arrays** `{x, z, h, x, z, h, ...}` instead of sub-tables `{{x,z,h},...}`. This eliminates the tens-of-thousands of per-vertex sub-table allocations that caused `SetHeightMapFunc` heavy operations to spike GC.

#### Vertex Budget (Anti-OOM)

| Constant | Value | Meaning |
|----------|-------|---------|
| `MAX_UNDO` | 2000 | Maximum entries in undo or redo stack |
| `MAX_SNAPSHOT_VERTICES` | 8 000 000 | ~192 MB — total vertex budget across all stacked snapshots |

When `totalVertexCount` exceeds the budget, the **oldest** undo entries are evicted until under budget. If still over, the oldest redo entries are also evicted. This prevents OOM crashes with very large-radius restore/noise operations on wide maps.

---

## Known Constraints

- `Spring.Echo()` inside `SetHeightMapFunc` silently crashes — no debug logging in height callbacks
- OpenGL calls only valid in Draw call-ins, not action handlers
- `gl.CreateShader` returns `0` on failure (truthy in Lua) — must check `== 0`
- `gl.SaveImage` must be inside the same `RenderToTexture` binding where content was drawn
- A "clone window" system (drag toolbar buttons to spawn floating panel copies) was prototyped and removed — fundamental limitations in RmlUI's `Clone()` API (no event listener copying) and bidirectional sync complexity made it unmaintainable. See [TerraformBrush_CloneWindows.md](TerraformBrush_CloneWindows.md) for the write-up.

---

## Roadmap

Development is organized into **release milestones**.

> **MoSCoW**: M = Must have, S = Should have, C = Could have, W = Won't (this cycle).
> **Complexity**: 1 (trivial) – 10 (hardest item on the list).

### Pending Backlog

| # | Item | MoSCoW | Complexity | Notes |
|---|------|--------|:----------:|-------|
| 1 | **Full WYSIWYG preview** | S | 8 | Show actual resulting terrain deformation in real-time under the brush cursor before committing. Requires a scratch heightmap buffer + shader-based preview mesh. |
| 2 | **Feature placement preview** | S | 5 | Render ghost/translucent 3D models at candidate positions before committing. |
| 3 | **Feature gizmo tool** | S | 7 | Select already-placed features (click/box-drag) and manipulate with a 3D gizmo: translate, rotate, scale, delete. Post-placement fine-tuning without remove-and-replace. |
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

---

## AI Disclosure

This feature was developed with AI assistance (GitHub Copilot, Claude). AI was used to help write production code and to draft this documentation. All AI-generated code was reviewed, tested in-game, and verified by a human contributor. This disclosure is provided per the [AI Usage Policy](../AI_POLICY.md).