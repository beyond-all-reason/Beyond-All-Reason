# Tileset terrain prototype — setup

This branch carries the shader-driven tileset terrain prototype: slope/height-based auto-texturing with triplanar cliffs, live re-texturing under terraform, and an in-game tuning panel.
Design docs live in `doc/tileset-terrain/`.

## Requirements

- An engine with the `Spring.SetMapShader` fixes from [RecoilEngine PR #3127](https://github.com/beyond-all-reason/RecoilEngine/pull/3127).
  The widget checks `Engine.FeatureSupport.reliableLuaMapShaders` and disables itself with a message on engines without the fixes.
- The `DrawGroundPreForward/PostForward/PreDeferred/PostDeferred` widget callins — already included on this branch (`luaui/barwidgets.lua`).
- `AllowDeferredMapRendering = 1` in `springsettings.cfg` for the deferred pass (the forward-only path works without it).

## Textures (not in the repo)

The layer textures are CC0 but not committed, to keep the branch lean.
Download the Poly Haven "namaqualand" assets below (JPG, the exact resolutions shown) and place them in this folder; the filenames must match exactly.

| Asset page | Files (download as JPG) |
|---|---|
| https://polyhaven.com/a/sandy_gravel_02 | `sandy_gravel_02_diff_4k.jpg`, `sandy_gravel_02_nor_gl_2k.jpg`, `sandy_gravel_02_arm_2k.jpg` |
| https://polyhaven.com/a/gravelly_sand | `gravelly_sand_diff_4k.jpg`, `gravelly_sand_nor_gl_2k.jpg`, `gravelly_sand_arm_2k.jpg` |
| https://polyhaven.com/a/cliff_side | `cliff_side_diff_4k.jpg`, `cliff_side_nor_gl_2k.jpg`, `cliff_side_arm_2k.jpg` |
| https://polyhaven.com/a/tiger_rock | `tiger_rock_diff_4k.jpg`, `tiger_rock_nor_gl_2k.jpg`, `tiger_rock_arm_2k.jpg` |

`diff` = diffuse, `nor_gl` = OpenGL-handedness normal, `arm` = packed AO (R) / roughness (G) / metalness (B).
See `SOURCES.md` for the full sourcing record.

Optional extras (the widget degrades gracefully without them):

- `quarry_cliff_chunky_nor_gl_2k.png` — chunky cliff/foothills normal. The prototype used a textures.com asset that is NOT redistributable (see SOURCES.md); a CC0 replacement is TODO. Without it the foothills band is disabled.
- `abstract_stagger_mask.png` — 1024² tileable grayscale mask that staggers the layer transition bands. Any abstract grayscale cloud/ink mask works; without it stagger falls back to neutral.

## Usage

- Enable "Tileset Terrain Prototype" (widget list; `dev_tileset_terrain.lua`, disabled by default).
- `/tileset` toggles the tuning panel (all look knobs are live uniforms; values persist).
- `/tileset dump` echoes current knob values as a Lua snippet; `/tileset palette` re-extracts the old-map cliff palette; `/tileset minimap` toggles the minimap/grass composite; `/tileset splat` toggles splat-paint override; `/tileset chunky` swaps the chunky cliff normal.
- `dev_map_shader_smoke.lua` is a minimal `Spring.SetMapShader` diagnostic (green striped terrain) — useful to isolate engine issues from prototype issues. Don't enable both at once; they both set the map shader.
