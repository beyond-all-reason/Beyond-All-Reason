# Terraform Brush — Save/Load/Export Config Tracking

> **Purpose:** Track every category of map data that can be saved/loaded/exported from the Terraform Brush
> system. Determine what's ready for mappers, what needs verification, and what needs architecture work.
>
> **Context:** This is a new workflow — much more feature-rich than SpringBoard. Many of these exports
> are novel and haven't been used by the mapping community yet. Each must be verified independently.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| **Confidence** | |
| `HIGH` | Format matches engine mapinfo.lua spec exactly; mappers can drop-in replace |
| `MEDIUM` | Data is correct but format may need conversion before use in map archive |
| `LOW` | New/experimental — untested with actual map compilation pipeline |
| `NONE` | No save exists; needs architecture work |
| **Novelty** | |
| `STANDARD` | Maps already ship this data in .sd7 archives (see mapinfo.lua spec) |
| `EXTENDED` | Engine supports it, but few/no maps use it; or BAR-specific extension |
| `NEW` | Terraform Brush invention — no prior workflow existed |
| **Mapper Readiness** | |
| `READY` | A mapper could use the export today with minimal effort |  
| `CONVERT` | Export works, but mapper must convert format before packaging into .sd7 |
| `VERIFY` | Needs human testing to confirm output is usable |
| `BUILD` | Needs code/architecture work before it's useful |

---

## MASTER TABLE: All Save/Load Configs

### A. TERRAIN DATA (Binary/Image Exports)

| # | Config Category | Has Save? | Save Format | mapinfo.lua Section | Engine File in .sd7 | Confidence | Novelty | Mapper Ready | Notes |
|---|----------------|-----------|-------------|--------------------|--------------------|------------|---------|-------------|-------|
| 1 | **Heightmap** | YES | PNG 16-bit + `.txt` metadata (minH/maxH) | `smf.minHeight`, `smf.maxHeight` | Embedded in `.smf` binary (uint16 per vertex) | **HIGH** | STANDARD | **CONVERT** | PNG needs to be compiled into SMF via MapConv/MapConvNG. The `.txt` sidecar preserves height range. All maps have this. Proven workflow. |
| 2 | **Metal Map** | YES | Lua table `{x, z, mx, mz, amount}` per spot | `maxMetal`, `extractorRadius` | Embedded in `.smf` binary (uint8 per half-square) | **MEDIUM** | STANDARD | **CONVERT** | Output is spot-list, not raw image. Mappers traditionally use a grayscale image. Would need a script to convert spot-list → grayscale PNG for MapConv. Alternatively, spot list can feed into BAR's runtime metal system. |
| 3 | **Splat Distribution Texture** | YES | PNG / TGA / BMP (RGBA) | `resources.splatDistrTex` | `maps/splat_distr.{png,tga,dds}` in .sd7 | **HIGH** | STANDARD | **READY** | Direct drop-in replacement for the splat distribution image. All modern BAR maps use this (confirmed: ATG, Folsom, Eye of Horus). RGBA channels = 4 texture blend weights. |
| 4 | **Grass Distribution** | YES | TGA 8-bit grayscale | `smf.grassmapTex` (override) | Embedded in `.smf` (uint8 per quarter-square) OR override image | **HIGH** | STANDARD | **CONVERT** | TGA output is correct format. Can be referenced directly via `smf.grassmapTex` override (engine 99.0+). Maps like Eye of Horus ship `_grassDist.tga`. Compile-time or override path. |
| 5 | **Feature Positions** | YES (Decal Exporter) | Lua table `{name, x, z, rot}` | — | `mapconfig/featureplacer/set.lua` + `config.lua` | **MEDIUM** | STANDARD | **CONVERT** | Output format is close to BAR's featureplacer format but not identical. All BAR maps use `mapconfig/featureplacer/` with `set.lua` defining feature lists and `config.lua` placing them. Needs format alignment verification. |
| 6 | **Feature Positions** | YES (Feature Placer gadget) | Synced save via LuaRulesMsg | — | Same as above | **LOW** | NEW | **VERIFY** | Runtime feature placer with undo/redo — completely new workflow. Saves go through gadget protocol. Export to mapper-friendly format needs verification. |

### B. ENVIRONMENT / LIGHTING (Lua Table Exports)

| # | Config Category | Has Save? | Save Format | mapinfo.lua Section | Used by Maps? | Confidence | Novelty | Mapper Ready | Notes |
|---|----------------|-----------|-------------|--------------------|--------------|-----------|---------|----|-------|
| 7 | **Sun Direction** | YES (in environ bundle) | Lua table `{x, y, z}` | `lighting.sunDir` | ALL maps (e.g. ATG: `{0.5, 0.4, -0.5}`) | **HIGH** | STANDARD | **READY** | Direct 1:1 match with mapinfo.lua `lighting.sunDir`. Every map defines this. Values confirmed readable via `gl.GetSun("pos")`, writable via `Spring.SetSunDirection()`. |
| 8 | **Ground Shadow Density** | YES (in environ bundle) | Lua float (0-1) | `lighting.groundShadowDensity` | ALL maps (e.g. ATG: `0.7`) | **HIGH** | STANDARD | **READY** | Direct match. |
| 9 | **Model/Unit Shadow Density** | YES (in environ bundle) | Lua float (0-1) | `lighting.unitShadowDensity` | ALL maps (e.g. ATG: `0.7`) | **HIGH** | STANDARD | **READY** | Direct match. |
| 10 | **Ground Ambient Color** | YES (in environ bundle) | Lua RGB `{r, g, b}` | `lighting.groundAmbientColor` | ALL maps | **HIGH** | STANDARD | **READY** | |
| 11 | **Ground Diffuse Color** | YES (in environ bundle) | Lua RGB | `lighting.groundDiffuseColor` | ALL maps | **HIGH** | STANDARD | **READY** | |
| 12 | **Ground Specular Color** | YES (in environ bundle) | Lua RGB | `lighting.groundSpecularColor` | ALL maps | **HIGH** | STANDARD | **READY** | |
| 13 | **Unit Ambient Color** | YES (in environ bundle) | Lua RGB | `lighting.unitAmbientColor` | ALL maps | **HIGH** | STANDARD | **READY** | |
| 14 | **Unit Diffuse Color** | YES (in environ bundle) | Lua RGB | `lighting.unitDiffuseColor` | ALL maps | **HIGH** | STANDARD | **READY** | |
| 15 | **Unit Specular Color** | YES (in environ bundle) | Lua RGB | `lighting.unitSpecularColor` | ALL maps | **HIGH** | STANDARD | **READY** | |

### C. ATMOSPHERE (Lua Table Exports)

| # | Config Category | Has Save? | Save Format | mapinfo.lua Section | Used by Maps? | Confidence | Novelty | Mapper Ready | Notes |
|---|----------------|-----------|-------------|--------------------|--------------|-----------|---------|----|-------|
| 16 | **Fog Start / End** | YES (in environ bundle) | Lua floats | `atmosphere.fogStart`, `atmosphere.fogEnd` | ALL maps (e.g. ATG: `0.5`, `1.0`) | **HIGH** | STANDARD | **READY** | |
| 17 | **Fog Color** | YES (in environ bundle) | Lua RGBA | `atmosphere.fogColor` | ALL maps (e.g. ATG: `{0.65, 0.6, 0.5}`) | **HIGH** | STANDARD | **READY** | |
| 18 | **Sun Color (atmosphere)** | YES (in environ bundle) | Lua RGB | `atmosphere.sunColor` | ALL maps (e.g. ATG: `{0.6, 0.3, 0.2}`) | **HIGH** | STANDARD | **READY** | |
| 19 | **Sky Color** | YES (in environ bundle) | Lua RGB | `atmosphere.skyColor` | ALL maps (e.g. ATG: `{0.7, 0.6, 0.4}`) | **HIGH** | STANDARD | **READY** | |
| 20 | **Cloud Color** | YES (in environ bundle) | Lua RGB | `atmosphere.cloudColor` | Most maps (e.g. ATG: `{0.7, 0.5, 0.4}`) | **HIGH** | STANDARD | **READY** | |
| 21 | **Skybox Path** | PARTIAL (stored transiently) | String path to .dds | `atmosphere.skyBox` | Most maps (e.g. ATG: `AllThatGlitters-Skybox-TBv2.dds`) | **MEDIUM** | STANDARD | **VERIFY** | Skybox DDS is stored in map archive `maps/` dir. Terraform brush can switch skyboxes at runtime but the **selected skybox path is NOT reliably exported** in the environ Lua table yet. Mapper must manually note which skybox .dds to include. |
| 22 | **Skybox Axis Angle** | YES (in environ bundle) | Lua `{x, y, z, angle}` | via `Spring.SetAtmosphere({skyAxisAngle})` | Rare — most maps don't set this | **MEDIUM** | EXTENDED | **VERIFY** | Engine supports it but few maps customize. Terraform brush exposes full rotation controls. Need to verify export format matches `atmosphere` custom section expectations. |
| 23 | **Dynamic Skybox Rotation** | NO | — | NOT in engine spec | NONE — BAR invention | **NONE** | NEW | **BUILD** | Terraform brush has play/pause skybox rotation with speed per axis. This is a runtime-only BAR feature driven by widget code. No mapinfo.lua equivalent. Would need to be saved as a custom section or separate config. |

### D. WATER RENDERING

| # | Config Category | Has Save? | Save Format | mapinfo.lua Section | Used by Maps? | Confidence | Novelty | Mapper Ready | Notes |
|---|----------------|-----------|-------------|--------------------|--------------|-----------|---------|----|-------|
| 24 | **Water Basic Colors** (absorb, base, min, surface, plane, diffuse, specular) | YES (in environ bundle) | Lua RGB triplets × 7 | `water.absorb`, `water.baseColor`, `water.minColor`, `water.surfaceColor`, `water.planeColor`, `water.diffuseColor`, `water.specularColor` | MOST maps (ATG has absorb, baseColor, minColor, surfaceColor, planeColor, specularColor) | **HIGH** | STANDARD | **READY** | Direct 1:1 mapinfo matches. Well-established. |
| 25 | **Water Surface Physics** (surfaceAlpha, fresnel×3, reflectionDistortion) | YES (in environ bundle) | Lua floats × 5 | `water.surfaceAlpha`, `water.fresnelMin/Max/Power`, `water.reflectionDistortion` | MOST water maps (ATG: all 5 set) | **HIGH** | STANDARD | **READY** | |
| 26 | **Water Lighting** (ambientFactor, diffuseFactor, specularFactor, specularPower) | YES (in environ bundle) | Lua floats × 4 | `water.*Factor`, `water.specularPower` | MOST water maps | **HIGH** | STANDARD | **READY** | |
| 27 | **Water Perlin Noise** (startFreq, lacunarity, amplitude) | YES (in environ bundle) | Lua floats × 3 | `water.perlinStartFreq`, `water.perlinLacunarity`, `water.perlinAmplitude` | MOST water maps (ATG: all 3 set) | **HIGH** | STANDARD | **READY** | |
| 28 | **Water Blur** (blurBase, blurExponent) | YES (in environ bundle) | Lua floats × 2 | `water.blurBase`, `water.blurExponent` | Some maps (ATG: both set) | **HIGH** | STANDARD | **READY** | |
| 29 | **Water Repeat** (repeatX, repeatY) | YES (in environ bundle) | Lua floats × 2 | `water.repeatX`, `water.repeatY` | Some maps | **HIGH** | STANDARD | **READY** | |
| 30 | **Water Toggles** (shoreWaves, hasWaterPlane, forceRendering) | YES (in environ bundle) | Lua bools × 3 | `water.shoreWaves`, etc. | MOST water maps | **HIGH** | STANDARD | **READY** | |
| 31 | **Water Bump Textures** (custom bump map paths) | NO | — | `water.normalTexture`, `water.texture`, `water.foamTexture` | Some maps (ATG: foamTexture, Folsom: waterbump×5) | **NONE** | STANDARD | **BUILD** | Engine supports per-map water bump textures. Maps like Folsom ship custom `waterbump.png` files. Terraform brush cannot currently save/select these. Would need file picker + path serialization. |
| 32 | **Water Caustics Textures** | NO | — | `water.caustics` (array of paths) | Rare | **NONE** | EXTENDED | **BUILD** | Engine supports custom caustics texture array but very few maps use it. |
| 33 | **Water Advanced BAR Params** (waveOffset, waveLen, foamDist, foamIntensity, causticsRes, causticsStrength) | PARTIAL (in environ bundle UI sliders) | Lua floats × 6 | NOT in engine mapinfo spec | NONE — BAR extension | **LOW** | NEW | **VERIFY** | These are BAR-specific water rendering extensions exposed in the environment panel. Not part of standard mapinfo.lua. Need to verify: (a) are they actually serialized in environ export? (b) do they persist correctly on load? |

### E. MAP RENDERING PARAMS

| # | Config Category | Has Save? | Save Format | mapinfo.lua Section | Used by Maps? | Confidence | Novelty | Mapper Ready | Notes |
|---|----------------|-----------|-------------|--------------------|--------------|-----------|---------|----|-------|
| 34 | **Splat Tex Multipliers** (×4 RGBA) | YES (in environ bundle) | Lua floats × 4 | `splats.texMults` | ALL modern maps (ATG: `{0.7, 0.4, 1.0, 0.15}`) | **HIGH** | STANDARD | **READY** | Direct mapinfo match. Critical for texture blending appearance. |
| 35 | **Splat Tex Scales** (×4 RGBA) | YES (in environ bundle) | Lua floats × 4 | `splats.texScales` | ALL modern maps (ATG: `{0.015, 0.017, 0.01, 0.015}`) | **HIGH** | STANDARD | **READY** | Direct mapinfo match. Controls UV tiling density. |
| 36 | **splatDetailNormalDiffuseAlpha** | YES (in environ bundle) | Lua bool | `resources.splatDetailNormalDiffuseAlpha` | MOST modern maps (ATG: `1`) | **HIGH** | STANDARD | **READY** | |
| 37 | **Void Water / Void Ground** | YES (in environ bundle) | Lua bools × 2 | `voidWater`, `voidGround` | Rare (space maps like Apophis) | **HIGH** | STANDARD | **READY** | |

### F. BRUSH PRESETS (Widget-Internal)

| # | Config Category | Has Save? | Save Format | mapinfo.lua Section | Used by Maps? | Confidence | Novelty | Mapper Ready | Notes |
|---|----------------|-----------|-------------|--------------------|--------------|-----------|---------|----|-------|
| 38 | **Terraform Brush Presets** (26 params: mode, shape, radius, rotation, curve, intensity, etc.) | YES | Lua table → `Terraform Brush/Presets/{name}.lua` | N/A — widget config, not map data | N/A | **HIGH** | NEW | **READY** | Portable across maps. User workflow tool. Not relevant to map compilation — purely for the artist's convenience. 8 built-in presets + unlimited custom. |

### G. COMBAT / ANALYTICS EXPORTS

| # | Config Category | Has Save? | Save Format | mapinfo.lua Section | Used by Maps? | Confidence | Novelty | Mapper Ready | Notes |
|---|----------------|-----------|-------------|--------------------|--------------|-----------|---------|----|-------|
| 39 | **Decal Heatmap** (explosion density) | YES | PGM image (grayscale) | N/A | N/A | **LOW** | NEW | **VERIFY** | Exports combat intensity heatmap. 64-elmo grid resolution. Useful for map balance analysis, not for map compilation. Completely new — no prior tool did this. |

---

## THINGS THAT DON'T HAVE SAVE BUT COULD

### H. Engine-Readable Data with No Export Yet

| # | Config Category | Read API | Set API | mapinfo.lua Section | Used by Maps? | Effort to Add Save | Priority | Notes |
|---|----------------|----------|---------|--------------------|--------------|--------------------|----------|-------|
| 40 | **Specular Exponent** | `gl.GetSun("specularExponent")` (if available) | Unknown | `lighting.specularExponent` | ALL maps (default 100) | LOW | Medium | Single float. Easy to add to environ export. Rarely tweaked but available. |
| 41 | **Wind Min/Max** | `Spring.GetWind()` | NOT runtime-settable | `atmosphere.minWind`, `atmosphere.maxWind` | ALL maps (ATG: 0, 16) | N/A — READ-ONLY | Low | Cannot be changed at runtime. Only useful as reference data in export. |
| 42 | **Cloud Density** | `gl.GetAtmosphere("cloudDensity")` ? | `Spring.SetAtmosphere({cloudDensity})` ? | `atmosphere.cloudDensity` | Some maps | LOW | Low | If runtime-settable, trivial to add. |
| 43 | **Map Hardness** | Readable via mapinfo | NOT runtime-settable | `maphardness` | ALL maps (ATG: 500) | N/A — READ-ONLY | Low | Compile-time only. Could export as reference note. |
| 44 | **Gravity** | `Game.gravity` | NOT runtime-settable per-map | `gravity` | ALL maps (ATG: 80) | N/A — READ-ONLY | Low | Affects projectiles. Compile-time. Reference only. |
| 45 | **Tidal Strength** | `Spring.GetTidal()` | NOT runtime-settable | `tidalStrength` | Some maps | N/A — READ-ONLY | Low | |
| 46 | **Max Metal** | Game config | NOT runtime-settable | `maxMetal` | ALL maps | N/A — READ-ONLY | Low | |
| 47 | **Extractor Radius** | Game config | NOT runtime-settable | `extractorRadius` | ALL maps | N/A — READ-ONLY | Low | |
| 48 | **Terrain Types** (typemap) | NO public read API | NO public write API | `terrainTypes[N]` = hardness + moveSpeeds | MOST maps (ATG: type 0 + 255) | VERY HIGH — no API exists | Medium | Typemap is baked at compile time. Controls movement speed multipliers per terrain cell. Would need engine-level support to read/write at runtime. Currently impossible via Lua. |
| 49 | **Sound Preset** (reverb) | No read API | `/tset snd_eaxpreset name` | `sound.preset`, `sound.passfilter`, `sound.reverb` | ALL maps (usually "default") | MEDIUM — command-only | Low | Could export the preset name string. Reverb sub-params have 20+ fields. |
| 50 | **Start Positions** | `Spring.GetMapStartPositions()` | Not directly | `teams[N].startPos = {x, z}` | ALL maps (ATG: 16 positions) | LOW | Medium | Already partially supported in terraform brush (L2922). Could be expanded to full import/export for mapper use. Currently limited scope. |
| 51 | **Custom Fog** (BAR volumetric) | Widget-internal read | Widget-internal set | `custom.fog` = {color, height, fogatten} | MOST BAR maps (ATG: `{0.71, 0.5, 0.34}`, height="40%") | MEDIUM | Medium | BAR's custom fog system (clouds widget) reads from `custom.fog` and `custom.clouds`. Could export current fog settings as custom section. Needs integration with cloud widget state. |
| 52 | **Custom Clouds** (BAR volumetric) | Widget-internal | Widget controls | `custom.clouds` = {speed, color, height, bottom, fade_alt, scale, opacity, ...} | MOST BAR maps (ATG: 12 cloud params) | MEDIUM — many params | Medium | ATG has 12 cloud parameters. These are BAR-specific. Would need to read current cloud widget state and serialize. Not trivial — cloud widget is separate from terraform brush. |
| 53 | **Custom Precipitation** | Widget read | Widget config | `custom.precipitation` = {density, size, speed, windscale, texture} | Some maps (commented out in ATG) | MEDIUM | Low | Snow/rain config. Read from mapinfo custom section. Could add save if runtime modification is supported. |
| 54 | **NightMode Config** | `_G["NightModeParams"]` | `/luarules NightMode r g b azimuth altitude` | Per-map configs in `luarules/configs/Atmosphereconfigs/` | Some BAR maps | MEDIUM | Medium | Day-night cycle config is BAR-specific. Complex schedule (nightFactor, dayDuration, nightDuration, transitionDuration). Would need to serialize full nightmode config as .lua file for map's Atmosphereconfigs folder. |
| 55 | **Ground Decal Properties** (tint, glow, alpha per decal) | `Spring.GetGroundDecalTint()`, `GetGroundDecalAlpha()`, `GetGroundDecalGlowParams()` | `Spring.SetGroundDecalTint()`, `SetGroundDecalAlpha()` | N/A — runtime engine state | N/A | MEDIUM | Medium | Recoil engine exposes per-decal tint/glow. Current decal exporter only saves position + type. Could extend to save visual properties. New capability — no prior tool. |
| 56 | **Splat Detail Normal Textures** (paths) | Via mapinfo resources | Path strings only | `resources.splatDetailNormalTex1..4` | ALL modern maps (ATG: 4 DNTS textures) | LOW — just strings | High | Maps ship 4 DNTS texture files (e.g. `gold_dnts.tga`, `sand_dnts.tga`). Terraform brush shows channel previews but doesn't export which texture files were used. Saving the 4 texture path strings would help mappers replicate the setup. |
| 57 | **Detail Texture** (path) | Via mapinfo | Path string | `resources.detailTex` | ALL maps (ATG: `detailtexblurred.bmp`) | LOW | Low | Just a path string. |
| 58 | **Specular Texture** (path) | Via mapinfo | Path string | `resources.specularTex` | MOST maps (ATG: `ATG2_speculartex.dds`) | LOW | Low | Just a path string. |
| 59 | **Normal Map** (path) | Via mapinfo | Path string | `resources.detailNormalTex` | MOST maps (ATG: `ATG2_normals.dds`) | LOW | Low | |
| 60 | **Grass Blade Config** | No runtime read | No runtime set | `grass.bladeWaveScale/Width/Height/Angle/Color/maxStrawsPerTurf` | Maps with grass | N/A — compile-time | Low | 6 grass appearance params. Baked at map load. Would need engine support for runtime changes. grass_gl4.lua has hardcoded shader params that override some of these. |
| 61 | **Light Emission Texture** (path) | Via mapinfo | Path string | `resources.lightEmissionTex` | Rare | LOW | Low | |
| 62 | **Parallax Height Texture** (path) | Via mapinfo | Path string | `resources.parallaxHeightTex` | Rare | LOW | Low | |
| 63 | **Sky Reflect Mod Texture** (path) | Via mapinfo | Path string | `resources.skyReflectModTex` | Rare | LOW | Low | |
| 64 | **Diffuse Ground Texture** (full map texture) | `Spring.GetMapSquareTexture()` exists but limited | Not writeable as bulk | Compiled into .smf/.smt | ALL maps (the main visual texture) | VERY HIGH — GPU readback needed | Low | The main map texture is baked into SMF+SMT binary format. Extracting it at runtime would require GPU framebuffer readback. Extremely complex. Not a save target. |
| 65 | **Water Plane Level** | `Spring.GetWaterPlaneLevel()` ? | NOT settable | Derived from terrain | ALL water maps | N/A — engine-derived | Low | Water level is determined by terrain. Cannot be independently set. |
| 66 | **Infotex / LOS / Pathmap** | Computed at runtime | N/A | N/A | N/A | N/A — ephemeral GPU state | None | These are frame-by-frame computed textures (fog of war, pathing overlay). Not map data. Cannot and should not be saved. |

---

## SUMMARY BY READINESS

### Ready for Mappers Today (HIGH confidence, direct mapinfo match)
| # | What | Export Location |
|---|------|----------------|
| 3 | Splat Distribution Texture | `Terraform Brush/Splats/` |
| 7-15 | All Lighting (sun, ground, unit × ambient/diffuse/specular, shadows) | `Terraform Brush/Lightmaps/` |
| 16-20 | All Atmosphere (fog, sun color, sky color, cloud color) | `Terraform Brush/Lightmaps/` |
| 24-30 | All Water Parameters (colors, physics, perlin, blur, toggles) | `Terraform Brush/Lightmaps/` |
| 34-37 | Map Rendering Params (splat mults/scales, void, normal-diffuse-alpha) | `Terraform Brush/Lightmaps/` |
| 38 | Brush Presets | `Terraform Brush/Presets/` |

### Needs Format Conversion Before Map Packaging
| # | What | Issue |
|---|------|-------|
| 1 | Heightmap | PNG needs MapConv compile into SMF |
| 2 | Metal Map | Spot-list format, mappers expect grayscale image |
| 4 | Grass Distribution | TGA is correct format but needs compile or override path setup |
| 5 | Feature Positions | Close to featureplacer format but needs alignment check |

### Needs Human Verification
| # | What | Why |
|---|------|-----|
| 6 | Feature Placer (runtime gadget) | Completely new workflow, undo/redo via gadget |
| 21 | Skybox Path | Path may not be exported reliably in environ bundle |
| 22 | Skybox Axis Angle | Rarely used by maps, untested round-trip |
| 33 | Water Advanced BAR Params | BAR-specific, not in engine spec |
| 39 | Decal Heatmap | Novel analytics output, no prior tool |

### Needs Architecture Work (No Save Feature Yet)
| # | What | Difficulty | Why |
|---|------|-----------|-----|
| 23 | Dynamic Skybox Rotation | MEDIUM | Runtime-only BAR feature, no mapinfo equivalent |
| 31 | Water Bump Textures | MEDIUM | Need file picker + path serialization |
| 48 | Terrain Types / Typemap | VERY HARD | No Lua API to read/write typemap at runtime |
| 51 | Custom Fog (BAR volumetric) | MEDIUM | Need to read cloud widget state |
| 52 | Custom Clouds | MEDIUM | 12+ params from separate widget |
| 54 | NightMode Config | MEDIUM | Complex schedule serialization |
| 55 | Ground Decal Visual Props | MEDIUM | Extend existing decal exporter |
| 56 | Splat DNTS Texture Paths | LOW | Just 4 path strings to save |
| 60 | Grass Blade Appearance | HARD | No runtime API — engine/shader level |
| 64 | Diffuse Ground Texture | VERY HARD | GPU readback from SMF/SMT |

### Read-Only Reference Data (Cannot Modify at Runtime)
| # | What | Notes |
|---|------|-------|
| 41 | Wind Min/Max | Could export as mapinfo reference |
| 43 | Map Hardness | Compile-time only |
| 44 | Gravity | Compile-time only |
| 45 | Tidal Strength | Compile-time only |
| 46 | Max Metal | Compile-time only |
| 47 | Extractor Radius | Compile-time only |

---

## QUICK WINS — Recommended Next Saves to Add

1. **Splat DNTS Texture Paths (#56)** — Just 4 strings. Read from mapinfo resources, save alongside environ export. Helps mappers recreate the texture setup.
2. **Start Positions (#50)** — Already partially supported. Expand to export full `teams[0..15].startPos` array matching mapinfo format.
3. **Skybox Path (#21)** — Ensure the currently active skybox .dds filename is reliably included in environ export.
4. **Custom Fog/Clouds (#51, #52)** — Read current cloud widget state, add to environ export as `custom.fog` + `custom.clouds` tables. Many BAR maps use these.
5. **Metal Map as Grayscale Image (#2 enhancement)** — Add PNG export option alongside spot-list. Mappers can drop the PNG into MapConv.
