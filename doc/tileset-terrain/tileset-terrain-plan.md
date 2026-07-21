# Tileset Terrain Pipeline — Implementation Plan (v2)

Status: v2 + P0–P2 EXECUTED AND VERIFIED IN-GAME (2026-07-14) — see `tileset-terrain-implementation-notes.md` for what was built, the engine fixes (committed on `novel-mapshader`), and the accumulated engine/API lessons. Next: P3 tooling/spec + reference feedback round. Author: PtaQ + Claude, 2026-07-14.
Scope: shader-driven, tileset-based terrain rendering for Recoil per the terrain revamp proposal; asset sourcing; terraform-tool integration; phased delivery.

## 1. Goals

1. Terrain look is driven by one global shader + per-biome "tilesets" (texture suites + parameters), not per-map baked megatextures.
2. Triplanar/biplanar projection kills stretched monoplanar cliffs.
3. Layer selection is automatic from surface angle and world height, broken up by macro noise; height-based hue/sat/brightness grading on top.
4. Additional layers paintable via a map-space mask (authored in the BAR terraformer editor suite, PR #7219).
5. Client-side persistent damage layer accumulated from explosions.
6. Works on any existing map unmodified; eventual goal: maps ship without SMT megatextures.
7. Terraformed terrain re-textures itself live (the tileset shader derives layers from heightmap+normals at runtime, so PR #7219 needs no per-stroke texture work).
8. All bundled tileset textures redistribution-safe (CC0) until bespoke artist sets arrive; the tileset spec doubles as the standardization proposal ivand asked for.

## 2. Engine reality (verified against source; corrections from adversarial review in bold)

- Terrain vertices are position-only (`VA_TYPE_0`); height is sampled in the VS from `heightMapTex` (R32F); world position is available per-fragment → triplanar + angle/height masking are fragment-shader work. No per-vertex color exists; paint/damage must be map-space textures.
- `Spring.SetMapShader(fwdID, dfrID)` replaces the terrain shader for forward + deferred passes; the engine binds only the SMT tile (TU0) and sets `uniform ivec2 texSquare` (must be ivec2 — `glUniform2i`); everything else the game binds in `DrawGroundPreForward`/`DrawGroundPreDeferred` via `$`-textures.
- **BUG (blocker, needs engine patch): a forward-only Lua map shader never activates.** The Lua render state's `currShader` starts null (`SMFRenderState.cpp:48-64`) and `SetLuaShader→Update()` never refreshes it; `SelectRenderState` therefore skips the Lua state, and `DrawGroundPreForward` never fires (gated on `HaveLuaRenderState()`). `currShader` is only repaired after a *deferred* Lua draw (`SMFGroundDrawer.cpp:255`). Regression from the FWD_STD/FWD_ADV split (commit `984e1d8ebc`). Fix: refresh `currShader` in `SMFRenderStateGLSL::Update()` — small upstream PR, P0.
- **Config gates: `AllowDeferredMapRendering` defaults false** (`SMFGroundDrawer.cpp:47`); when the deferred pass runs but the state can't draw deferred, the engine clears the G-buffer (SSAO/CUS then read empty). **`AdvMapShading` (safemode false) gates the whole Lua shader path** (`SMFRenderState.cpp:357-361`). BAR must pin both configs.
- Shadow-cast, map border, and shading/normal precompute passes are NOT Lua-replaceable; geometry is unchanged so shadow casting stays correct; **shadow receive should use a plain `sampler2D` with manual depth compare** — `GL_TEXTURE_COMPARE_MODE` on `$shadow` is toggled around engine passes and its state at Lua-draw time is incidental (`ShadowHandler.cpp:600-623`).
- `$normals` is **RG16F** at `(mapx+1)×(mapy+1)`, sampled `.ra`, and holds the *geometric* normal field; per-pixel detail comes from tileset normal maps.
- **Texture loading limits (blocker for the original format spec): the DDS loader is DXT1/3/5 only** — no BC7/BC5, no DX10 header, no arrays (`nv_dds.cpp:394-402`); `gl.CreateTexture` can allocate `GL_TEXTURE_2D_ARRAY` but only empty, and no Lua path uploads pixels into layers. Stage A must use DXT 2D atlases; a compressed-array loader is a scheduled engine PR (needed by Stage B anyway).
- Gamma policy: the map pipeline is gamma-space with `SMF_INTENSITY_MULT ≈ 0.82` (`GlobalRendering.h:405`, `SMFFragProg.glsl:206`); the tileset shader must replicate it or terrain shifts ~20% brighter than everything else. Document as gamma-space now; linear is a separate future fight.
- SMF shaders are compat-profile `#version 130` with FFP matrices; VS obligations a custom shader must replicate: heightmap texel-alignment (`SMFVertProg.glsl:21-30`), `gl_ClipVertex` for water reflection/refraction clip planes, fog varyings; `infoTexGen` uses pow2 map dims, not map dims.
- `DrawGroundPreForward` has no pass identifier and also fires for water-reflection/refraction and terrain-reflection passes; track pass context via `DrawWorldReflection`/`DrawWorldRefraction` brackets. Gadget-side availability of these callins must be confirmed in BAR's gadget handler (open item).
- `Spring.SetMapShadingTexture` live-swaps every SSMF input texture (incl. `$minimap`, `$grass`); `Spring.SetMapSquareTexture` replaces per-1024-elmo diffuse tiles.
- Deform propagation: `SetHeightMapFunc` → `RecalcArea` → unsynced rects processed in `CReadMap::UpdateDraw` (≤128 rects/frame); each rect updates `$heightmap` AND regenerates `$normals` in the same pass, *before* `UnsyncedHeightMapUpdate` fires for that rect (`ReadMap.cpp:504-511`). Unsynced rects outside LOS are deferred unless spec-fullview/globallos.
- June 2025: decal shaders are game-overridable (`shaders/GLSL/groundDecals.lua`) → triplanar decals are game-side shippable already.
- No SMT-less map path exists; `BlankMapGenerator` is the precedent. No Lua *deferred map* shader has ever shipped in any game — P2 is unproven engine territory, not a checkbox. No triplanar/tileset issue exists in the tracker — greenfield.

## 3. Architecture

### 3.1 Two-stage strategy

- Stage A (BAR-side prototype): full visual pipeline via `Spring.SetMapShader`, textures bound in `DrawGroundPre*`. Requires a forward-activation bugfix carried as a *local engine patch* (decision 2026-07-14; upstreamed later, likely bundled with Stage B) and a compressed texture-array loader PR developed in parallel — "zero engine changes" is retired as a claim, "no engine architecture changes" stands.
- Stage B (engine-native upstream): a `SMF_TILESET` define path *inside* `SMFVertProg/SMFFragProg` + `SMFRenderStateGLSL`, replacing only the diffuse/splat sampling block while keeping engine shadow/infotex/water/fog/deferred plumbing; declared via a mapinfo `tileset` table. RFC first — maintainers may push back that new investment should target a modern GL4 map renderer instead of the legacy `#version 130` stack; the tileset *spec* is renderer-agnostic either way.
- The tileset spec (3.2) is shared by both stages and is the standardization deliverable.

### 3.2 Tileset spec (the standardization artifact)

A tileset = one directory + one Lua def file:

```
tilesets/mars_canyon/
  tileset.lua           -- parameters (below)
  atlas_albedo.dds      -- Stage A: DXT1 2D atlas, grid of N layer tiles, padded for mip bleed
  atlas_normal.dds      -- DXT5 (or DXT5nm-style), same grid
  atlas_orh.dds         -- DXT1: R=AO, G=roughness, B=height (height drives blend weighting)
  macro_noise.dds       -- tiling FBM/variation texture
  SOURCES.md            -- per-layer provenance + license citation
```

- Stage A carrier: fixed-grid DXT atlases sampled with `textureGrad` (mandatory anyway for hex-tiling) and half-texel-inset UV transforms per layer; mips capped at the safe level for the pad width.
- Stage B carrier: BC7/BC5 2D texture arrays once the engine loader PR lands (DX10-header DDS or KTX2); `tileset.lua` is carrier-agnostic (layers referenced by index).
- `tileset.lua` per layer: world tiling scale (m/repeat), projection (planar | biplanar | triplanar), slope band (min/max/softness), height band (normalized to live `mapHeights` + absolute override), hex-tiling on/off, tint, edge-noise params.
- Global: height-gradient color stops (hue/sat/brightness by world height), macro variation scales/strengths, damage-layer and paint-layer texture indices, gamma/intensity constants.
- Layer roles v1: 0 flat ground, 1 rough ground, 2 cliff wall, 3 scree/transition, 4 plateau top; + up to 4 paint layers; + 1 damage layer.
- The mask vocabulary from `cmd_diffuse_painter` (altitude/slope bands with lo/hi falloffs, hydro Laplacian concavity, thermo repose band) is adopted as the parameter naming so mapper muscle memory carries over.

### 3.3 Shader design

- VS: replicate engine SMF vertex work (height sampling with texel alignment, `gl_ClipVertex`, fog varyings) — copyable but not "nothing new"; treat as a real task.
- Normals: geometric normal from `$normals` (RG16F, reconstruct Y) blended with per-face slope for cliff crispness; per-pixel detail from tileset normal maps.
- Projection: biplanar (Quilez, 4 taps/material) default; triplanar (6 taps) as per-layer quality toggle; whiteout normal blending.
- Compositing: slope/height weights → top-2 layer selection → ORH-height-weighted blend → macro noise modulates boundaries and albedo tint/sat → optional hex-tiling on unstructured layers (with `textureGrad`).
- Tap budget worst case (top-2 × biplanar × 3 maps × hex 3-tap) = 36 taps/fragment before masks — this is the P1 measurement target, with hex-tiling and triplanar as the first knobs to pull.
- Paint mask: RGBA8 map-space texture (heightmap UV), one paint layer per channel, composited after auto layers, suppressed on cliff-slope fragments; pattern copied from `cmd_splat_painter` (FBO + stamp shader + undo + PNG export).
- Damage mask: R8/RG8 map-space texture (0.25 texel/elmo; 4096² = 16 MB covers the largest 32×32 BAR maps), drives damage layer + scorch darkening.
- Legacy blend mode: optionally use the SMT diffuse (TU0) as a macro color layer under tileset detail — migration aid for the existing roster, explicitly not the end state (reference guidance: "don't hybridize, go all the way").
- Gamma: apply `SMF_INTENSITY_MULT`-equivalent, shade in gamma space to match units/decals/water.
- Passes: forward implements shadow receive (manual depth compare), infotex composite (`$info`), fog, void water, water absorption/plane tint, and clip-correct behavior in reflection/refraction passes; deferred variant writes the engine G-buffer layout (5×RGBA8 MRT, world-space normals `(n+1)*0.5`) so decals/CUS/SSAO keep working; MSAA G-buffer is an explicit test axis.
- Peripheral surfaces checklist (each a named deliverable, not an afterthought): minimap (render tileset composite → `Spring.SetMapShadingTexture("$minimap", tex)`), map border skirt (non-replaceable engine shader → mitigation: accept mismatch in prototype, engine hook or border-off in Stage B), grass tint (`$grass` replacement composite), feature/unit shadows unaffected (geometry unchanged).

### 3.4 Damage layer (client-side, persistent)

- Use the *unsynced* `Explosion` callin directly — it is LOS-filtered by the engine (`IsExplosionVisible`), so no fog-of-war leak; requires `Script.SetWatchExplosion` per weaponDef (register at gadget init).
- Rasterize falloff splats into a persistent Lua FBO texture; fine detail comes from the damage layer's textures + noise, so the mask stays low-res.
- Optional G channel: sediment/talus tint. Geometry craters are already handled by real heightmap deform.
- v1 persistence is per-session; replay-seek/reconnect rebuild is explicitly out of scope (documented limitation).
- Terraform interaction: never clear on `UnsyncedHeightMapUpdate` (battle damage fires it too); the terraformer calls `clearDamage(rect)` explicitly on Restore/undo strokes (it already tracks exact touched bboxes in undo snapshots).

### 3.5 Terraformer suite integration (PR #7219)

- Height edits need zero integration: brush → `SetHeightMapFunc` → same-frame `$heightmap`+`$normals` refresh → shader re-textures live. This retires the diffuse painter's stale-bake problem for procedural layers.
- Exposed WG API from the pipeline widget: `WG.TilesetTerrain = { getMaskTexture(), stampMask(x, z, radius, shape, rot, curve, lengthScale, ringRatio, channel, value), clearDamage(rect), version }` — parameters chosen to match the brush stamp messages the tool already sends, so the mask brush reuses `common/brush_shapes.lua` falloff math.
- Both masks are unsynced client textures; every client's tool performs the same stamp so visual symmetry follows the synced stroke traffic for free.
- Rect-incremental only: any baked intermediate re-bakes per `UnsyncedHeightMapUpdate` rect (fires after textures are current, before draw), never full-map per stroke; the import/mapgen path collapses to one full-map dirty and must be budgeted.
- Editor sessions require spec-fullview or `/globallos`, else out-of-LOS rects are deferred and re-texturing lags — document in the tool.
- UI consolidation: the splat painter UI re-points at the new mask channels; the diffuse painter reduces to hand-paint overrides + legacy-map workflow; the environment panel's SSMF splat controls are superseded on tileset maps.

### 3.6 Out of scope for v1 (tracked)

- Mesh/prop scattering, walkable meshes, map-edge mirroring + background mesh, gizmo tooling: later phases with the editor; the tileset spec reserves the reference's "mesh atlas + params" section.
- No-SMT map archives: Stage B follow-up (`BlankMapGenerator`-style synthesis or `CSMFGroundTextures` bypass).
- Linear-space lighting migration.

## 4. Phased delivery (reordered after review)

- P0 — Engine-reality spike (the riskiest unknowns first): reproduce the forward-activation bug and fix it as a local engine patch (decision: not upstreamed yet; keep the patch minimal and rebase-friendly); verify `DrawGroundPre*` reachability from BAR gadgets; confirm deferred-pass behavior under `AllowDeferredMapRendering` on/off; smoke-test a trivial Lua map shader (fwd+dfr pair — decision: both stages from day 0) that just tints the map. Exit: tinted map on screen through `SetMapShader` on a BAR install with pinned configs, findings written up.
- P1 — Look prototype: triplanar/angle/height shader on an unmodified BAR map using a handful of individually-bound 2D DXT textures (no tooling dependency); forward + deferred variants both live; shadows via manual compare; measure tap budget (RenderDoc/Nsight per-pass, named GPU). Exit: screenshot set vs the HLSL reference + perf numbers; go/no-go on look.
- P2 — Full-pass correctness: real deferred G-buffer variant (decals/CUS/SSAO verified, MSAA axis), infotex overlays, water reflection/refraction, void water, fog, gamma match, legacy SMT-macro blend mode; ≥3 unmodified maps. Exit: correctness checklist green, config matrix documented.
- P3 — Tileset tooling + spec v1: manifest-driven fetch from ambientCG/Poly Haven APIs, atlas packing (DXT, padded, ORH), `tileset.lua` schema, SOURCES.md; first full `mars_canyon` tileset; spec draft ready to hand to the proposal author/ivand as the standardization proposal (timing of sharing is PtaQ's call — no strict gate).
- P4 — Paint mask + editor integration: mask texture + `WG.TilesetTerrain` API + splat-painter-UI re-point + per-map mask persistence (PNG in map/mod archive).
- P5 — Damage layer: unsynced Explosion accumulation, terraformer `clearDamage` hook, minimap composite refresh cadence.
- P6 — Stage B upstream: RFC issue (tileset spec + prototype numbers + screenshots), engine `SMF_TILESET` path OR GL4-renderer variant per maintainer feedback, compressed texture-array loader PR, then no-SMT map support.
- P7+ — editor/mesh/background phases (separate plan).

Each phase ships something usable and can stop without stranding work.

## 5. Evaluation criteria

- Visual: no vertical smearing on cliffs at standard camera angles; tiling imperceptible at strategic/mid/close zoom (3 screenshot stations per map); look approximates the HLSL reference on the same heightmap.
- Performance: added GPU frame time vs same-map SSMF baseline ≤ ~1.5 ms at 1440p on a named mid-range GPU (RTX 3060 class), measured per-pass with RenderDoc/Nsight (engine `/debug` timers are frame-scoped — not the gate); no CPU regression; terraform brush strokes stay smooth (rect-incremental path verified).
- Correctness: shadows received; LOS/metal/height infotex overlays work; water reflection/refraction correct; deferred decals + CUS + SSAO unaffected (and G-buffer-clear fallback understood); terrain deform re-textures same-frame; minimap/border/grass items resolved or explicitly waived per phase.
- Compatibility: runs on ≥3 unmodified maps; clean on/off toggle (`SetMapShader(0,0)` incl. on gadget Shutdown — reload safety); config matrix (`AdvMapShading`, `AllowDeferredMapRendering`, safemode) documented and pinned by BAR.
- Legal: every bundled texture CC0 with SOURCES.md manifest entry.

## 6. Tileset sourcing (until bespoke art arrives)

- Primary: ambientCG + Poly Haven (true CC0, API-scriptable, 4K–8K, full PBR sets; Poly Haven ships pre-packed ARM).
- Mars biome: PH `red_laterite_soil_stones` (ground), `rock_face`/`rock_face_03`/`rock_06` (cliff), `rocky_terrain_03`/`sandy_gravel_02` (scree), `rock_boulder_dry` (plateau), moon collection (regolith/wasteland); aCG `Rock029` (red cliff), `Ground031` (cracked desert), `Rocks006` (scree); beige sets tinted red in-shader, HiRISE as color reference.
- Earthlike biome: PH `aerial_grass_rock`, `forest_leaves_03`, `rock_face_03`, `dirt_floor`; aCG `Grass004`, `Ground037`, `Rock030`, `Gravel022`.
- NOT safe to bundle: ShareTextures, FreePBR, Quixel/Fab Megascans, Poliigon, textures.com, OpenRA assets, Xonotic (GPL art); 0 A.D. only if CC-BY-SA is acceptable.
- Conventions: OpenGL normal maps (nor_gl/NormalGL); ORH packing (AO/roughness/height — terrain metalness ≈ 0, height drives blending).

## 6b. Compatibility with today's compiler flow (from Beherith's guide + pymapconv)

Sources: Beherith's World Machine mapping guide, `Beherith/springrts_smf_compiler` (pymapconv), BAR mapping guides, `beyond-all-reason/map_blueprint`.

- Compiler minimum: a 16-bit heightmap at `mapx*64+1 × mapy*64+1` (8-bit causes terracing) + a diffuse in multiples of 1024 px (512 px per map unit) → SMF+SMT; metal map (red channel), typemap (red = terrainTypes index), grass, minimap (fixed 1024² DXT1a, 9 mips) optional. Everything modern (DNTS, detailNormalTex, specular, skyReflectMod, grass) is already loose mapinfo-referenced files.
- Drop-in story for tileset maps: emit (a) a minimal or procedurally-baked diffuse for SMF+minimap+non-tileset-client fallback, (b) the tileset def + masks as loose `maps/` files, (c) the `map_blueprint` archive layout. The mapinfo tail merges every `mapconfig/mapinfo/*.lua` in sorted order — a tileset map can ship `mapconfig/mapinfo/tileset.lua` without touching the base mapinfo, and the BAR gadget can detect it. Bare minimum a mapper prepares stays: heightmap + metal + features (+ mask paints).
- Validated conventions to adopt: height range convention maxheight−minheight = 1000 elmos; maps ≤ 32×32; sharp material transitions are the BAR aesthetic (supports hard-ish layer boundaries, confirms weight sharpening); DNTS splat scales in the wild are `texScales 0.002..0.01` ≈ 100–500 elmo repeats (our SCALE_* sit in the same band); lighting norms groundAmbient ~0.5, groundDiffuse ~0.9, groundShadowDensity 0.75–0.85, sun from the north, terrain slightly darker than units; only `/water 4` is considered acceptable.
- Engine quirks his flow fights that we must not re-import: specularTex must exist (even all-black) just to enable DNTS; splatDetailTex must be declared though unused; DDS must be vertically flipped; DNTS normals ship as TGA because DDS mips destroy them; BC3 at diffuse resolution is "prohibitively expensive". The tileset spec should keep all textures in one origin/handedness convention and compress arrays once, correctly, in tooling.
- DNTS is the precedent to cite in the RFC: a runtime tiling detail layer selected by a low-res distribution texture is already accepted BAR practice; the tileset pipeline generalizes it (more layers, albedo not just normal+alpha-diffuse, slope/height auto-masks, per-biome standardized suites instead of per-map Drive-folder copies).
- BAR-side integration facts: official map pool metadata/startboxes live centrally in `beyond-all-reason/maps-metadata`; lava maps load `mapconfig/lava.lua` via the game's lava module (tileset biomes with lava need to compose with it); featureplacer config under `mapconfig/featureplacer/`.

## 7. Risks & open questions

- The forward-activation engine fix must land (or be carried as a local patch) before any Stage A work is testable — single hard dependency.
- Deferred-by-default: BAR pinning `AllowDeferredMapRendering=true` has its own perf cost for all users; needs a measured call (the G-buffer already exists for CUS users — quantify the delta for non-CUS configs).
- No game has ever shipped a Lua deferred map shader — P2 may surface unknown engine behavior; time-boxed spike, fallback is forward-only + engine-default deferred (accepting SSAO/decal degradation on tileset maps until Stage B).
- Tap/VRAM budget: atlases with padding waste some resolution; hex-tiling × biplanar worst case 36 taps — P1 gate.
- Stage B may be redirected by maintainers toward a GL4 map renderer; the spec survives either outcome, the GLSL port cost differs.
- Damage-layer persistence across replay-seek/reconnect unsolved in v1.
- Border skirt + minimap mismatch until their deliverables land (P2/P5).
- Terraformer PR #7219 is itself unmerged and conflicting with master; the WG API contract keeps the pipelines decoupled if it slips.

## 7b. Execution status (2026-07-14)

- P0 DONE: activation path proven; engine bug #1 (forward activation) found+fixed; BAR barwidgets DrawGround* callins added (sdd, uncommitted).
- P1 DONE: look validated on unmodified maps; engine bug #2 (LoadFromID stale uniform cache → texSquare corner collapse) found+fixed; live terraform re-texturing confirmed.
- P2 DONE: shadows (incl. the missing `+vec2(0.5)` shadow-UV recenter — root cause of all shadow artifacts), infotex, water absorption, gamma match, anti-tiling, curvature shading, specular, RML tuning panel, debug views. Tileset = Poly Haven namaqualand collection (same-session family + single biome grade — spec-level lesson).
- Both engine fixes committed on `novel-mapshader` (77cdde699f, 81a475f82e); deploy via update-custom-engine.bat → recoil_custom.
- Outstanding before P3 exit: perf capture, SHADOW_MODE 2 test, grass/border/minimap deliverables.

## 8. Decision log

- 2026-07-14 DECIDED: Stage A texture carrier = DXT 2D atlases now, compressed texture-array loader engine PR developed in parallel (Stage B format target).
- 2026-07-14 DECIDED: prototype writes forward + deferred shaders from day 0; BAR pins `AllowDeferredMapRendering=true` for prototype sessions.
- 2026-07-14 DECIDED: forward-activation engine bug fixed via local patch for now; upstream later (likely bundled with Stage B RFC work).
- 2026-07-14 DECIDED: spec/RFC socialization timing is PtaQ's discretion — no secrecy constraint anymore, no fixed gate in the plan.
- 2026-07-14: damage layer via unsynced LOS-filtered Explosion callin (no synced relay) — recommended in review, uncontested; treat as decided unless playtesting objects.
