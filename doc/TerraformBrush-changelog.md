# Terraform Brush Changelog

Release history for the Terraform Brush map-editing suite.

Version numbers follow the `tf-brush-improvements-N` branch scheme: branch `N` corresponds to release `1.N`. Only versions merged into the upstream Beyond All Reason repository are listed as releases. Intermediate development branches that were folded into a later release are noted separately.

## 1.10 - 2026-08-08

### New

- Added the Prototemperate biome preset.

### Improvements

- Terraform Brush now remembers the positions of its main panel and all floating windows, including asset libraries, environment configurations, settings, and capture windows.
- The heightmap browser can be refreshed without reloading LuaUI, allowing PNG files copied into `Terraform Brush/Heightmaps/` to appear immediately.
- The heightmap browser now lists externally named PNG files as well as Terraform Brush exports.
- Project heightmap imports use the project manifest's height range when replacement PNG metadata is unavailable, preserving the intended terrain scale.
- Custom heightmap export ranges now initialize from the current terrain extremes instead of the unusable `0..1` default.
- Splat channel swatches refresh immediately after changing biome presets.
- Terrain edits outside unit vision now render immediately for the editing allyteam.

### Fixes

- Fixed loaded map projects incorrectly requiring the optional DNTS library pack when the project contains its own textures.
- Fixed tools failing to re-arm correctly after restoring input passthrough.
- Fixed the FILE dropdown being covered by the Tileset status strip.
- Fixed the main close button failing to close Terraform Brush while the Tileset tool was active.
- Reduced repeated console and infolog messages when terraform actions are rejected by game-state gates.
- Replaced the malformed heightmap-browser chevron and unclear refresh symbol with the established rotation icon.

## 1.9 - 2026-08-06

Sources: [PR #8642](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/8642), [hotfix PR #8658](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/8658)

### New

- Added scrollable panel bodies with pinned headers to every Terraform suite window. Available content height now follows window position and viewport size.
- Added a Tileset shader master switch that returns rendering to the engine for maps with hand-authored textures.
- Added independent per-layer albedo tiling and normal strength controls.
- Added talus scatter, splat punch-through, parallax depth, macro softness, height blending, specular AA, wet gloss, and metal-apron controls.
- Extended layer scale controls for very large maps.
- Added the Protodesert biome and a dedicated Teizer texture set.
- Added configurable talus slope-angle bands and cliff splat protection in the 1.9 hotfix.

### Fixes

- GL splat previews now clip to their scrolling panel instead of drawing over pinned headers.
- Locked brush sliders no longer fight panel scrolling for the mouse wheel.
- Feature-selection and reroll rows no longer remain visible after leaving the Feature Placer.
- Corrected the header version badge to 1.9 in the hotfix.

## 1.8 - 2026-07-30

Source: [PR #8545](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/8545)

### Feature Placer

- Added WYSIWYG feature ghosts using a new GL4 feature renderer. Previewed positions and rotations are the exact placements applied.
- Added deterministic layouts, `R` rerolling, remove previews, correct brush-shape containment, and one undo step per stamp.
- Added map selection, box selection, and a reusable 3D transform gizmo for moving and rotating features.
- Added optional pitch, roll, and elevation fields to `features.lua`; map projects now preserve off-screen feature rotations through synced export.
- Fixed collapsed random scatter layouts, incorrect group rotation, duplicate same-tick layouts, feature tilt loss, and unusable gizmos on large selections.
- Cached feature thumbnails are now reused between sessions.

### Map Projects And Capture

- Added Terraform Brush Capture via `/tfcapture` and the camera button: orthographic top-down map photos plus Figma-ready SVG unit and map-label layers.
- Added optional unit loadouts to map projects, including team, rotation, neutral state, and synced collection outside player LOS.
- Added world-anchored map comments with colors, text, draggable pins, project persistence, and capture export.
- Reworked the Open Project browser with explicit selection, load, and confirmed deletion.
- Added `Keep match alive` and `Remove all units` editor controls.
- New Map canvases now allow start positions anywhere and remain alive without units or commanders.
- Fixed project-loaded terrain becoming unclickable above the blank canvas base height.

### Other Fixes

- Smooth/Level and Raise/Lower now retain separate curve, intensity, and clay settings.
- Runtime fog now survives skybox and biome changes. This work came from the closed 1.7 branch and shipped in 1.8.
- Terraform suite widgets added after a player's saved widget order now enable without a fresh game start.
- Fixed the GL4 feature-instance offset argument.
- Added the visible tool version badge, establishing the numbered release scheme.

## 1.7 - not released separately

[PR #8538](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/8538) was closed without merge. Its runtime-fog preservation fix was carried into 1.8.

## 1.6 - 2026-07-27

Source: [PR #8501](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/8501)

- Fixed the Tileset toolbar button not showing its active highlight.

## 1.5 - 2026-07-27

Source: [PR #8500](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/8500)

### Tileset Tool

- Integrated Tileset Terrain controls into Terraform Brush with collapsible tuning sections and live splat-channel texture previews.
- Added a biome library for Namaqualand, Teizer-5, Enborelde, Bismuth, and Pale Hang, with optional matching skyboxes.
- Added soil, gravel, and plateau height bands, cliff-border blending, metal-spot materials and glow lights, and named Tileset presets.
- Added fractal edge and frequency controls for organic splat painting.
- Added a height-cap master toggle while preserving configured min/max values.

### Workflow And Fixes

- Heightmap saves from regenerated canvases of the same size now share a browser pool; legacy filenames remain discoverable.
- Added custom, sanitized names to the New Map wizard.
- Metal Brush now restores shared shape, radius, and snap settings when leaving the tool.
- Generated maps no longer start with dense near-camera fog.

## 1.3 and 1.4 - development branches

GitHub has no separately merged PRs for these versions. Their stacked Tileset and splat work was merged together in 1.5, so no independent release entries are claimed here.

## 1.2 - 2026-07-24

Source: [PR #8423](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/8423)

- Enabled Splat Painter on generated blank maps by recognizing the engine's editable 1x1 fallback distribution texture when DNTS normals are available.

## 1.1 - 2026-07-23

Source: [PR #8420](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/8420)

- Replaced Smooth mode's single brush-wide mean with per-cell local-neighbor blur.
- Removed hard seams at brush boundaries while retaining the existing falloff curve.
- Scaled blur spacing with intensity so low values preserve broad forms and high values flatten larger bumps efficiently.

## 1.0 - 2026-07-21

Source: [PR #7219](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/7219)

- Introduced the RmlUi Terraform Brush map-editing suite with Raise, Lower, Level, Smooth, Ramp, Restore, and procedural Noise modes.
- Added Circle, Square, Triangle, Hexagon, Octagon, and Ring brushes with clay, stamp, height-cap, rotation, length, curve, and intensity controls.
- Added shared instruments: grid and angle snapping, protractor, measure splines, symmetry, terrain overlays, and tablet-pressure controls.
- Added Feature, Metal, Grass, Splat, Decal, Light, Weather, Clone, and Start Position tools with shared smart terrain filters.
- Added the live Environment editor for skybox, sun, fog, lighting, rendering, and water settings.
- Added heightmap import/export, environment export, presets, searchable asset libraries, customizable keybinds, contextual guidance, and UI sounds.
- Added merged-stroke undo/redo with history scrubbing and bounded snapshot memory.
- Added the first full Terraform Brush feature reference and tool architecture documentation.