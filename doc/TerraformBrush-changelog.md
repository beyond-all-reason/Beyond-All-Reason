# Terraform Brush Changelog

Release history for the Terraform Brush map-editing suite.

Version numbers follow the improvements-branch scheme (`tf-brush-improvements-N` up to 1.10, `tf-improvements-N` from 1.11): branch `N` corresponds to release `1.N`. Only versions merged into the upstream Beyond All Reason repository are listed as releases. Intermediate development branches that were folded into a later release are noted separately.

## 1.11 - 2026-08-14

### New

- Added the SURFACE and LAYERS tools for tileset maps. SURFACE paints soft-top variants of the active biome over the automatic base: two variant slots with per-slot pickers, a NOW PAINTING readout, coverage meter, dot/wash/fill presets, brush spacing, noise fill seeded from the tileset noise field, sculpted-feature layers, and group grading for tops and rock. LAYERS forces intermediate, cliff, or plateau material anywhere through the tileset shader's override mask, with smart filters, undo/redo, and splat export.
- The tileset shader now decides which surface-painting pair leads the TOOLS grid: SURFACE and LAYERS while it renders the ground, the legacy DIFFUSE and SPLAT otherwise. The two sets replace each other in the same leading slots.
- The Tileset panel is now a floating window opened from the SCENE menu instead of a tool tab, so shader knobs, the biome library and metal-spot styles can be tweaked while any tool is active.
- Every SCENE window (sun and shadows, fog, ground and unit lighting, map rendering, water, dimensions, skybox library, tileset) is now independent of the SCENE tab. Switching tools no longer closes them, so the scene can be tuned while painting.
- Added FILE > Save, which writes straight to the project the session was loaded from or last saved to and names that target on the menu item. Save As now prefills the name, lists existing projects as pick-to-overwrite rows, asks for a second click before overwriting a project that is not the current one, and closes on commit. A save in progress shows a green segment bar in the status strip, then holds SAVED for a few seconds before the tool readout fades back in.
- Map projects now round-trip the SURFACE variant mask, including biome and slot assignments.
- Added a FIT button that snaps the custom heightmap export range to the terrain's exact current extremes.
- Added Intermediate evidence and Cavity floor tuning knobs to the Tileset height layers.
- Added Exposure, Bias on tops and Surface claim to the Tileset window. Exposure is a final gain on the lit ground, for a dark set on a dimly lit map. Bias on tops decides whether the brightness bias also applies to the soft tops, so how much ground a top takes is authored rather than decided by whichever top is paler. Surface claim sets how strongly a SURFACE stroke decides which top belongs somewhere: at 1 a painted top outvotes the automatic plateau band, which is what made high flats unpaintable, and the plateau band now ships parked off to match.
- Every section of the Tileset window has its own RESET button, matching the SCENE environment windows. It restores just that section's knobs, to the global defaults overlaid with the active biome's recipe, instead of throwing away every knob in every section.
- Added placeable geothermal vents: game-side vent features make working geo spots (engine smoke, geo build placement, geo circles) available on blank canvases and map projects through the Feature Placer, with project round-tripping. Two variants under the new Geo catalog category: geovent+crack (Moose's flat black-crack vent, as shipped on his maps) and geovent+mesh (a selectable body for geo outputs with real geometry, no crack). The rock model is a placeholder pending a dedicated asset.
- Added a grayed-out UNITS entry to the TOOLS grid, reserving the slot for the unit placer.

### Improvements

- The height cap and all altitude-filter sliders now scale to the map's real height range instead of a hardcoded -500..500, so caps above 500 elevation are reachable by slider and by typing.
- Custom heightmap export ranges now seed from the map's actual terrain via an exact heightmap scan, re-seed after imports and project loads, and no longer leak from one map into another through saved preferences.
- The tileset shader re-anchors its intermediate and plateau height reference after heightmap imports and project loads.
- Cliff protection moved from the SURFACE brush into the Tileset window as a PROTECT CLIFFS button: it is a shader setting rather than a brush one, and it is now a labelled toggle instead of a 0/1 slider. The tileset shader switch reads as an ACTIVATE SHADER button for the same reason, with PAINT SURFACES greyed while it is off.
- Cliff protection is now one-way. Soft strokes still sweep around cliff bodies instead of eating them, but painting CLIFF forces cliff rock anywhere, including flat ground, which is what that channel is for.
- The metal brush cursor readout sits just below the brush outline and right-aligned to its edge, instead of over the area being painted.
- Slider rows across the suite share one label style, a size larger and slightly wider, and every window's close button draws the same rounded box as the header buttons.
- Decals and weather now fill the status strip like the other tools, so their readouts align instead of floating off the left edge.
- The TOOLS grid is reordered: SCENE sits last, after CLONE.
- Teizer-5 and Enborelde default to no old-map cliff blending, keeping their authored cliff palettes free of the host map's colours.
- The terrain layers are called BASE and INTERMEDIATE throughout the panel, instead of soil, gravel, rocky and talus. Those were the assets an early set happened to use, so a biome whose middle band is sand or ash had sliders labelled Gravel and a LAYERS channel reading TALUS. Knob keys, slider labels, the LAYERS channel and every hint now follow the shader's own naming.
- New maps start on the Clear Daylight environment preset instead of the engine's own lighting. The engine defaults are placeholder values, a flat 0.5 ground ambient and diffuse against roughly 0.99 diffuse on a real daylight map, so a fresh canvas received about 60% of the light it should. A baked map texture carries the mapper's own brightness and hides that; the tileset shader draws raw albedo and cannot, so new maps read as though the shader were broken. Default is still selectable in the wizard.
- The whole SURFACE slot chip opens that slot's variant library, and arms the slot's variant if it already has one. The small caret it replaces rendered as a missing-glyph box, and a filled chip offered no way back to the library at all.
- SURFACE erase readouts describe what erasing does now: it withdraws the painted claim so the shader chooses again, rather than returning the ground to the base surface. BASE is a paint target of its own since the paintability change.
- Refreshed the Enborelde and Teizer biome thumbnails, which still showed those sets as they looked several tuning passes ago.

### Fixes

- Fixed every slider in the SURFACE and LAYERS panels being inert. An echo guard meant to drop the change events raised by programmatic stamps was armed on every frame rather than on actual stamps, so it discarded the user's own input as well. Fill scale and seed never reached the painter, which is why the seed always read 0.
- FILL WITH NOISE now greys out and explains itself when no variant slot is assigned or enabled, instead of silently doing nothing.
- An enabled but idle Terraformer no longer swallows its tool hotkeys (F, M, G, K, P, W, V, J) from engine keybinds. Tool keys now require the editor to actually be in use; opening a tool from the header rail re-enables them.
- Fixed custom heightmap export ranges initializing to the blank canvas constants (-75..696) on map projects, which clipped all terrain above 696 in exports.
- Fixed height cap changes made with the Alt+Shift scroll combo not updating the panel's slider and readout.
- Fixed tileset tuning knobs drifting a little further on every biome swap (deferred slider-change echoes read stale values back into the knobs).
- Fixed a GL instance-table error when elements were removed while deferred pushes were pending (affected feature ghost previews).
- The legacy SPLAT tool no longer competes with the tileset shader for the splat texture: while the shader is on, SPLAT and DIFFUSE give up their slots to SURFACE and LAYERS.
- Removed stale "waiting on engine support" skybox notices; runtime skybox swaps now work on generated maps.
- Grass loaded from a map project now renders immediately instead of waiting for the Grass tool to be opened once.
- Grass undo/redo now reports what it did (or why it could not) instead of silently doing nothing.
- Tidied the custom export-range row layout.

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