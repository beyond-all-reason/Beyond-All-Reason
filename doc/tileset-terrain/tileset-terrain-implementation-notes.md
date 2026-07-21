# Tileset Terrain Pipeline — Implementation Notes (P0–P2 complete)

Status: 2026-07-14. Prototype phases P0–P2 done and verified in-game; next up is P3 (tileset tooling + spec) and the reference's follow-up feedback (new session).
Companion docs: `tileset-terrain-plan.md` (the reviewed plan, v2), `tileset-engine-fixes.patch` (backup of the engine fixes).

## 1. What works right now

- A BAR widget fully replaces the terrain shader via `Spring.SetMapShader` on any unmodified map: 4-layer tileset (sand flats / gravel talus / biplanar cliff walls / striated plateau tops) driven by slope, height, curvature, and noise — no map textures used except the optional legacy SMT macro blend.
- Cliffs are biplanar-projected (iq 4-tap, `textureGrad` for stable mips) with per-plane reoriented detail normals — no vertical smearing.
- Layer placement: cliffs by slope band; talus accumulates at cliff feet via heightmap-Laplacian concavity + moderate slopes + noise-scattered scree fields; plateau by normalized height; transitions sharpened by weight-cubing + per-layer luminance ("features poke through").
- Full pass correctness: engine-matched shadow receive (see §5.4), infotex overlays (F4/metal etc.), water absorption (exact engine GetShadeInt port), fog, gamma (`SMF_INTENSITY_MULT`), deferred G-buffer variant (normals/albedo/spec written), reflection passes handled via `gl_ClipVertex`.
- Curvature shading (ridge lips + cavity shade) reacts live to terraforming; terraform brush strokes re-texture in real time with zero integration code (engine regenerates `$heightmap`+`$normals` same draw frame).
- Live tuning: RML slider panel (18 knobs as live uniforms — zero-latency, no reload), `/tileset` toggles, `/tileset dump` prints values, `/tileset mat` dumps the live shadow matrix; debug views 1–5 (curvature / normals / layer weights / shadow coeff / shadow UV footprint).
- Biome grading: single `biomeTint` applied to the whole composite; namaqualand set at 1/1/1 is the red-rock desert, other tints repaint the biome.

## 2. Engine changes (branch `novel-mapshader`, committed)

The feature's engine home is branch `novel-mapshader` (supersedes `engine-initblank-skybox-fix`; carries the refined `Spring.SetSkyBoxTexture` work on newer master).

- `77cdde699f` — SMFRenderState: select the current shader when Lua map shader programs load.
  Bug: the Lua render state's `currShader` starts null (`GLSL_SHADER_FWD_STD` is never created for it) and `Update()` never refreshed it, so `HasValidShader(Normal)` stayed false and a forward-only Lua map shader was never selected (only a deferred Lua draw repaired it as a side effect).
- `81a475f82e` — Shader: clear cached uniform states when a program is loaded from ID.
  Bug: `LoadFromID` swapped the GL program but kept the previous program's `uniformStates`; `GetNewUniformState` resolves locations once, so after a `SetMapShader` swap, `texSquare` targeted stale locations → all terrain big squares collapsed onto square (0,0).

Both are candidates for one upstream PR ("make Spring.SetMapShader actually work"), with the corner-collapse screenshots as repro evidence (stock engine reproduces, patched doesn't).

Deploy flow: build `ninja -C builddir-win spring` on `novel-mapshader` → `update-custom-engine.bat` (REQUIRED_BRANCH now `novel-mapshader`) → `run-custom-engine.bat` (`data/engine/recoil_custom/spring.exe`).
Gotcha that cost a session: deployments to `recoil_2026.06.13/` were never used — the launcher runs `recoil_custom`; verify via the in-game engine string.

## 3. BAR game-side changes (sdd, UNCOMMITTED — needs its own PR)

`Beyond-All-Reason.sdd/luaui/barwidgets.lua` (on the `realtime-terraformer` branch working tree — must NOT leak into PR #7219):
- Added `DrawGroundPreForward`, `DrawGroundPostForward`, `DrawGroundPreDeferred`, `DrawGroundPostDeferred` to `flexCallIns` + the four dispatch methods.
  The engine dispatches these to LuaUI but BAR's widget handler only forwarded `DrawGroundDeferred`; the gadget handler forwards none (fine — prototype is a widget).
Config prerequisites: `AllowDeferredMapRendering = 1` (already in user's springsettings.cfg), `AdvMapShading` default-on (safemode turns it off → whole Lua map shader path dies).

## 4. Prototype files

- `data/LuaUI/Widgets/dev_tileset_terrain.lua` — the pipeline widget (shaders + bindings + RML panel + actions + config persistence, `CONFIG_VERSION` guards stale saved knobs).
- `data/LuaUI/Widgets/dev_map_shader_smoke.lua` — P0 smoke test (trivial green-stripe fwd+dfr shader); keep for engine-regression testing, mutually exclusive with the main widget.
- `data/LuaUI/Widgets/tileset_dev/` — textures + `SOURCES.md` (CC0 provenance) + `tileset_panel.rml` / `tileset_panel.rcss` (slider ranges live in the RML).
- Active tileset: Poly Haven **namaqualand** collection (same-session red-rock desert photogrammetry, 4K diffuse + 2K nor/arm): `sandy_gravel_02` flats, `gravelly_sand` talus, `cliff_side` walls, `tiger_rock` plateau; `rock_face` spare.
- Retired on disk: first mixed-source set (laterite/rocky_terrain_03/rock_face_03/rock_boulder_dry, aerial_sand, rocks_ground_05) and the moon collection — see SOURCES.md for reasons.

## 5. Hard-won engine/API knowledge (the expensive lessons)

### 5.1 Lua map shader contract
- Engine binds only the SMT diffuse tile (TU0) and sets `uniform ivec2 texSquare` (must be exactly `ivec2` — `glUniform2i`); everything else is bound by the game in `DrawGroundPre*` via `$`-textures.
- The engine binds the Lua program (EnableRaw) BEFORE `DrawGroundPreForward` fires: set per-frame uniforms via `gl.ActiveShader(shader, fn)` (restores previous binding) — `gl.UseShader(0)` in the callin kills the draw.
- `DrawGroundPreForward` has no pass id and also fires for water-reflection/refraction and terrain-reflection passes; handle clip via `gl_ClipVertex`.
- VS obligations copied from `SMFVertProg.glsl`: heightmap texel-alignment magic, `texSquare*1024` world offset (VBO coords are big-square-local), fog varyings, `gl_ClipVertex`; `#version 130` compat profile with FFP matrices.
- `$normals` is RG16F sampled `.ra` (geometric normal, xz; reconstruct y); `specularTexGen` = 1/mapSize doubles as the heightmap/normals UV scale; `infoTexGen` uses next-pow2 map dims.
- Reset on shutdown: `Spring.SetMapShader(0, 0)` before shader deletion, or the render state dangles GL ids across `/luaui reload`.

### 5.2 Shadows (three separate lessons)
- Lua-bound `$shadow` sets up the depth-compare sampler itself (`SetupShadowTexSamplerRaw`), so engine-style `sampler2DShadow` + `shadow2DProj` is safe.
- `gl.UniformMatrix(loc, "shadow")` provides the same `viewMatrix[SHADOWMAT_TYPE_DRAWING]` the engine uses — BUT its xy output is centered on 0: the engine recenters with `vertexShadowPos.xy += vec2(0.5);` (SMFFragProg.glsl:367).
  Omitting that one line displaced all shadows by half a shadow map (symptoms: no terrain shadows, ghost mega-shadows, quadrant-only UV footprint in debug view).
  Porting lesson: extract engine shader blocks with a contiguous read (`sed -n a,bp`), never grep-with-context — the missing line sat exactly in a grep gap and cost three debug rounds.
- Guard out-of-frustum lookups (return unshadowed) and keep a small acne bias; the shadow map is view-fitted per frame (`ShadowProjectionMode`, default CAM_CENTER).

### 5.3 BAR widget sandbox
- Slash commands: `widgetHandler:AddAction("cmd", fn, nil, "t")` (proxy wrapper injects the widget); `widgetHandler.actionHandler` is nil in sandboxed widgets; the `TextCommand` callin does NOT receive chat slash-commands.
- Legacy `gl.Rect`/`gl.Text` `DrawScreen` panels do not render under BAR's current UI stack even with clean GL state — build tool UI in RmlUi (pattern: `RmlUi.GetContext("shared")` → `OpenDataModel` (event handlers get `ev.parameters.value`) → `LoadDocument` → `document:Show()`; shutdown = `document:Close()` + `RemoveDataModel`).
- Named file textures: `:a:path.jpg` = aniso + mips + repeat wrap; loaded uncompressed RGBA8 (4K diffuse ≈ 85 MB VRAM each — the P3 packer exists to fix this).
- Widget config: `GetConfigData`/`SetConfigData` persists automatically; version-stamp it so new defaults can supersede stale saved values.

### 5.4 Texture/art lessons for the tileset spec
- A tileset must be ONE same-session texture family plus a single biome grade; mixed-source photogrammetry never harmonizes and per-layer color surgery amplifies the clash.
- Featureless textures (moon dust) collapse into flat color at RTS zoom — every layer needs mid-frequency structure.
- Anti-tiling: dual-scale self-blend (irrational ratio) kills the repeat but must be distance-faded or it blurs close-ups; layer blends need sharpening (weight cubing + luma bias) or transitions read as watercolor mush.
- Curvature shading defaults must be gentle or it outlines geometric heightmap creases on angular maps.

### 5.5 Smart old-map blend (original-cliff palette transfer, 2026-07-21)
Problem: the plain old-map blend multiplied the whole composite by the original SMT diffuse, so freshly terraformed cliffs (flat ground in the original bake) got the old grass/sand color smeared over their tileset rock.
Design (critic-reviewed): keep the per-pixel old-map blend on flats only, and recolor the tileset cliff layer toward the ORIGINAL map's cliff palette with a constant gain — new cliffs then match the map's native rock while keeping tileset texture detail.
- Extraction: snapshot `$minimap` (1024 RGBA8 + `gl.GenerateMipmap`) and a slope/height terrain snapshot (`$normals`/`$heightmap` → RGBA16F) once; a 3×1 RGBA32F reduction pass (256² grid loop in one fragment, one-time) averages minimap color where the terrain snapshot is steep (and above water) vs flat, plus the tileset cliff diffuse's own mean via its top mip (`textureLod(…, 20.0)`); `gl.ReadPixels` inside the `RenderToTexture` callback reads all three pixels.
- Gain: `oldCliffGain = clamp(origCliffAvg / tilesetCliffMean, 0.2, 4.0)` computed Lua-side, one vec3 uniform; shader applies `dCliff.rgb *= mix(vec3(1), oldCliffGain, oldCliffBlend)` next to the tints — foothills follows automatically (shared diffuse), so does the minimap composite.
- Flats: `smtBlend` term now gated by `* (1 - rockness)` where `rockness = wA.z + wfoot` (post-splat albedo-sorted weights), so cliff pixels no longer inherit the smeared flat color; behavior on flats is bit-identical to before.
- Cliff-less maps: cliff fraction below 0.5 % of land keeps the gain neutral — degrades to plain tileset cliffs, never to smearing.
- Re-runnable: extraction reads only widget-owned snapshots (plus a temporary un-override of `$minimap` during the copy), re-triggers on `cliffStartDeg` changes (throttled — `ReadPixels` is a pipeline sync) and via `/tileset palette`.
API gotchas caught in review: engine SMT square textures have NO mips (`SMFGroundTextures.cpp` uploads level 0 only, `GL_LINEAR`), so `textureLod` blurring of `diffuseTex` is a silent no-op; `gl.TexRect` DEFAULT texcoords V-flip (pass `0,0,1,1` explicitly — the minimap texel space matches world uv, verified via the grass shader's `worldPos.xz * mapSize` sampling); disable `gl.Blending` inside reduction RTTs or fractional alpha outputs get blend-mangled; `Spring.SetMapShadingTexture("$minimap", "")` restores the engine texture (raw id is kept alongside the Lua override), so snapshot-under-override works any time.
New knob: `oldCliffBlend` ("Old cliff match", default 0.5); minimap top-down pass now binds the minimap snapshot to the diffuse slot with real uvs, so the old-map blend finally renders there too.

## 6. Open items

- Reference feedback (next session).
- Old-map blend v2 (if the v1 gate shows the need): per-pixel staleness mask from an original-height snapshot (`Spring.GetGroundOrigHeight`) so terraformed FLATS also stop using stale colors; regional cliff palette (low-res dilated cliff-color map) instead of the global average for maps with mixed rock biomes.
- Perf capture: FPS on/off (P1/P2 exit criterion, still unmeasured).
- `SHADOW_BIAS` retune now that the real bug is fixed (likely well below 0.0015); `SHADOW_MODE 2` (colored shadows) untested.
- Grass tint still uses old map colors (`$grass` replacement deliverable); map border skirt + minimap keep the old look (plan §3.3 checklist).
- P3: manifest-driven texture fetch + packing tool (compression — the 4K JPGs are a VRAM hog uncompressed), `tileset.lua` spec doc (cite DNTS as precedent, Beherith compiler-compat story from plan §6b).
- Upstream: file the two engine fixes as a PR; barwidgets callins as a small BAR PR (keep out of #7219).
- P4+: paint mask + `WG.TilesetTerrain` API for the terraformer, damage layer, engine-native Stage B (plan §4).
