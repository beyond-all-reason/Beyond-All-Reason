# Terraform Brush 1.10

Released 2026-08-08.

## New

- Added minimum and maximum talus slope-angle controls to the Tileset tool.
- Added a cliff splat protection toggle to preserve steep-slope texturing.
- Added the Prototemperate biome preset.

## Improvements

- Terraform Brush now remembers the positions of its main panel and all floating windows, including asset libraries, environment configurations, settings, and capture windows.
- The heightmap browser can be refreshed without reloading LuaUI, allowing PNG files copied into `Terraform Brush/Heightmaps/` to appear immediately.
- The heightmap browser now lists externally named PNG files as well as Terraform Brush exports.
- Project heightmap imports use the project manifest's height range when replacement PNG metadata is unavailable, preserving the intended terrain scale.
- Custom heightmap export ranges now initialize from the current terrain extremes instead of the unusable `0..1` default.
- Splat channel swatches refresh immediately after changing biome presets.
- Terrain edits outside unit vision now render immediately for the editing allyteam.

## Fixes

- Fixed loaded map projects incorrectly requiring the optional DNTS library pack even when the project contains its own textures.
- Fixed tools failing to re-arm correctly after restoring input passthrough.
- Fixed the FILE dropdown being covered by the Tileset status strip.
- Fixed the main close button failing to close Terraform Brush while the Tileset tool was active.
- Reduced repeated console and infolog messages when terraform actions are rejected by game-state gates.
- Replaced the malformed heightmap-browser chevron and unclear refresh symbol with the established rotation icon.