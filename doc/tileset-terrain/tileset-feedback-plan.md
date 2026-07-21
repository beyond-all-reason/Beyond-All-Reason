# Tileset Terrain — Reference Feedback Round (P2.8–P2.11): Two-Phase Angle Sorting

Status: plan v2 (critic-reviewed, 12 findings folded in), 2026-07-14.
Source material: the reference's Discord notes + 7:35 UE walkthrough (transcript + 31 frames + 3 material-graph screenshots in `terrain_shader_notes/`), `Abstract_1.PNG` stagger mask (Dropbox), `TCom_Rock_QuarryCliff10_3x3_2K_normal.tif` chunky test normal.
Target: `dev_tileset_terrain.lua` (P2.7) — shader + widget changes only, no engine changes.
Companion docs: `tileset-terrain-plan.md` (v2 master plan), `tileset-terrain-implementation-notes.md` (P0–P2 record).

## 1. The technique (distilled from all sources)

Order of operations (reference, verbatim): 1. Sample textures 2. Project textures 3. Sort textures (angles etc) 4. Flavor outputs (color etc).

1. Blend the layer NORMAL maps first, sorted by the geometric vertex normal (our `$normals` geoN).
2. Derive the per-pixel normal — geoN + blended detail normals; our `s.normal` is the exact stand-in for UE's `PixelNormalWS` (critic-confirmed: no circularity; UE also forbids PixelNormalWS→Normal but allows it →BaseColor).
3. Blend the layer ALBEDOS with the SAME sort logic fed by that pixel normal, so color scatters along normal-map detail down cliff faces instead of forming flat vertex-slope bands. This split is the entire requirement; node/formula choices are free.
4. Explicit "Foothills" intermediary layer between base and cliff: a parameterized surface-angle band around the base/cliff meeting angle, triplanar-projected like the cliff.
5. REALLY chunky normals on BOTH foothills and cliff layers — the intense normals are what make the pixel-normal scatter read as rock strata.
6. Stagger every angle-sort lerp with a grayscale abstract mask (world-projected, one scale per lerp ~1000/3000, HeightLerp contrast ~0.2) so transitions break into staggered organic shapes.
7. Only cliff + foothills triplanar; base layers stay planar/UV (perf).

### UE reference wiring (from the material-function screenshots)

- mask1 = CheapContrast(N.z − 0.2, C=1.0) = 3·N.z − 1.6 → cliff lerp phase.
- mask2 = CheapContrast(N.z − 0.43, C=2.2) = 5.4·N.z − 4.522 → foothills-vs-base lerp phase.
- Output = HeightLerp(A=cliff, B=HeightLerp(A=foothills, B=base, phase=mask2, height=abstract@3000), phase=mask1, height=abstract@1000, contrast 0.2).
- Identical function twice: fed `VertexNormalWS` for the normal output, `PixelNormalWS` for base color.
- Main graph flavor: albedo result ×0.6; normal result ×(1,1,3) (softens the combined normal — our `normalStrength` covers this degree of freedom).

### Band math (corrected in review — do not "retune from 78°")

CheapContrast(In, C) = saturate(In·(1+2C) − C).
- Cliff lerp transitions over N.z 0.867→0.533 = slope **30°→58°** (full cliff at 58°).
- Foothills lerp: full foothills at 33°, and flat ground retains ~12% foothills (phase 0.878 at N.z=1).
- So the UE demo bands nearly MATCH our current cliff band (smoothstep(0.25,0.45) on slope ≈ 41°→57°); defaults start near current values, knobs cover the reference's spoken "~10°" span AND the ~24° span its graph actually implies.

## 2. Gap analysis vs current widget (P2.7)

| Reference requirement | Current state | Gap |
|---|---|---|
| Normals sorted by vertex normal | weights from geoN, detail deltas blended | already compliant |
| Albedo sorted by pixel normal | albedo reuses the SAME geoN weights | **core gap** |
| Explicit foothills angle band, parameterized degrees | talus is concavity/noise-driven, not an angle band | **new layer** |
| Chunky normals on foothills AND cliff | cliff normal is photogrammetry-subtle | new asset + per-layer strength knobs |
| HeightLerp stagger via abstract mask | weight-cubing + luma bias + nPatch threshold dither | **new mechanism** |
| Triplanar only cliff+intermediary | cliff biplanar, others planar XZ | compliant; foothills also biplanar |
| Mask sampled once, reused (macro breakup) | procedural fbm macro | swap to mask tap |

## 3. Phases

### P2.8 — two-phase angle sorting (the core trick) — DONE, gate PASSED in-game 2026-07-14

Restructure `composite()` around an `angleWeights(n, ...)` function called twice — `wN = angleWeights(geoN)` sorts the normal blend, `wA = angleWeights(pixelN)` sorts albedo + ARM.

Scoping (critic finding 5 — follow exactly):
- Hoist and pass in everything normal-independent: `curv`/`cavity`, `hNorm`, the four noise samples, the per-layer albedo lumas, and (P2.10) the mask taps.
- EVERYTHING from `wCliff` downward recomputes inside `angleWeights(n)`: cliff mask, plateau (its `(1−wCliff)` factor is slope-coupled), talus (contains a slope smoothstep), soil remainder.
- `angleWeights` includes the weight-cubing + luma reweight + renormalization (luma vec passed in), applied identically to both calls; `s.weights = wA` feeds debug view 3.
- Consequence accepted: the normal sort keeps the diffuse-luma sharpening (current look depends on it; the reference's "identical function twice" is satisfied).

Threshold parameterization:
- `cliffStartDeg` knob (default ≈ current band midpoint ~49°); masks evaluated in degree space via `cos(radians(...))` against `n.y`.
- Existing smoothstep constants re-expressed from the knob; look preserved at defaults.

Verification aid (critic finding 1 — the gate must be passable this phase):
- Convert + load the quarry TIF NOW and add `cliffNormalStrength` (separate from `normalStrength`), so pixelN can be made aggressively chunky for the A/B test before the foothills layer exists.
- New knob `albedoSortMode` (0 = pixel normal, 1 = vertex normal) — the live A/B proof toggle.
- New debug view 6: albedo sort classes as flat R/G/B (cliff/foothills-placeholder/base), mirroring the reference demo for direct frame comparison.

Gate: flipping `albedoSortMode` produces a visible scatter-vs-bands difference in debug view 6 with the chunky cliff normal cranked (frames 05m15s–06m00s vs 06m15s–06m30s); exact frame-match is deferred to P2.9.

### P2.9 — foothills intermediary layer — implemented 2026-07-14, awaiting gate
Implementation notes: foothills shares the cliff's biplanar diffuse/ARM samples per §5.3 (only TU18 = chunky normal added, `wFoot > 0.004`-branched); `footEnabled` graceful degrade via `gl.TextureInfo`; `Abstract_1.PNG` already fetched to `tileset_dev/abstract_stagger_mask.png` (P2.10 asset secured early).
Also in this round: `chunkyCliff` promoted to a persisted panel knob (default ON — the reference wants chunky on BOTH cliff and foothills; first `KNOB_LUA` texture-bind knob); panel "Reset to defaults" button (`DEFAULT_KNOBS` snapshot); retessellation-pop fix — all height-derived shading terms (biplanar projected y, curvature center tap, `hNorm` grade, wet band, water absorption) re-anchored from the interpolated `vertexWorldPos.y` to `heightAt()` texture height (`hTrue`), so the surface pattern is stable across ROAM LOD changes; shadow lookups and the specular view vector intentionally stay on rasterized geometry (else acne). Residual pop = geometric silhouette only (mesh drawer's, same as stock).

Weight composition (critic finding 2 — the formula, explicitly):
- `m1` = cliff mask, `m2` = foothills-vs-inner mask (both from `n`, both degree-parameterized, both staggered in P2.10).
- `wCliff = 1−m1`; `wFoot = m1·(1−m2)`; `inner = m1·m2` distributed to the existing plateau/talus/soil logic (plateau moves INSIDE the inner group, resolving the plateau-vs-foothills overlap on high maps: the angle sort wins).
- Five weights = `vec4 ws` + `float wFoot` (GLSL 130 has no vec5); cube/luma/renorm and `Surf.weights` restructured accordingly; debug view 3 remapped (foothills shown in the R channel alongside 6).
- Foothills diffuse is sampled unconditionally (its luma participates in the reweight) — the tap cost is map-wide, not in-band (see §5).

Band parameterization (reference, verbatim requirement):
- `foothillsSpanDeg` (default 10°, range 4–30° — his graph implies ~24°, his words say 10°; the knob covers both) centered on `cliffStartDeg`.
- Flat-ground residue: the UE graph leaves ~12% foothills everywhere; expose as `footFloor` knob (default 0 = off, since our talus already occupies flats).

Assets & bindings:
- Foothills = TU18/19/20 (diff/norm/arm), biplanar like cliff, `foothillsNormalStrength` knob (intended HIGH).
- Chunky normal: quarry TIF → 8-bit PNG conversion (16-bit TIF via DevIL is an untested failure mode; pillow `--user` install in WSL); EXPECT a DirectX→GL green-channel flip (textures.com convention) — flip during conversion, verify in debug view 2.
- Foothills diffuse: reuse a namaqualand diffuse initially (user decision below); real tileset textures supplied later.
- `unbindCommon()` loop extended 1→21; `gl.TextureInfo` checks at Initialize with echo + graceful degrade (missing foothills textures → `wFoot` forced 0).
- SOURCES.md: TCom asset is textures.com — NOT license-safe to ship, PoC only.

Gate: strata band visible between flats and cliffs; width tracks `foothillsSpanDeg` live; cliff faces + band now scatter like frames 06m45s–07m30s.

### P2.10 — height-lerp stagger mask — implemented 2026-07-14, awaiting gate
Implementation: `stagger(phase, h) = clamp(phase + (h-0.5)*staggerAmount, 0,1)` shifts each angle-sort lerp phase by the mask; `staggerAmount` 0 = plain smoothstep (A/B), default 0.35. Mask `abstract_stagger_mask.png` on TU19, three `textureGrad` taps (scale1→cliff lerp, scale2→foothills lerp, 9000-elmo macro tap replacing the retired `nMacro` fbm octave). `nPatch` threshold dither scaled by `(1-staggerAmount)` so it fades out as stagger takes over. `staggerEnabled` graceful-degrade (neutral 0.5) via `gl.TextureInfo`. Mask sampled planar-XZ (known: vertical stretch on cliff faces — evaluate at gate).

Deferred/parked this session: the camera-motion "breathing" (texture sharpness pulsing on pan/stop) — chased through height-anchoring, analytic mip footprints, deferred-normal softening, and an engine shadow-projection texel-snap patch; NONE fixed it and it reproduces with the widget OFF (stock terrain), so it is an engine-wide artifact unrelated to this shader. User parked it. Shadow patch saved to `doc/design/shadow-texel-snap.patch` (engine reverted to HEAD + rebuilt). The three shader-side hardenings were kept — they fixed real tessellation couplings even though none was the breathing culprit.

### P2.10 — OLD notes

- `heightLerp(phase, h, contrast)` GLSL helper returning the staggered alpha (UE-equivalent; exact formula free per the reference).
- `staggerAmount` knob 0–1 mixing plain smoothstep ↔ full stagger (contrast=0 in the raw formula is a hard step, NOT off — the mix is the A/B control).
- Mask (`Abstract_1.PNG`, Dropbox `dl=1` fetch → `tileset_dev/`) on TU21, sampled planar-XZ at TWO scales, hoisted OUTSIDE `angleWeights` and passed in: scale1 (~1000 elmos) staggers the cliff lerp, scale2 (~3000) the foothills lerp — matching the UE graph's one-scale-per-HeightLerp wiring.
- Known limitation, accepted for the prototype: planar-XZ stretches the mask 1.3–2× exactly on the 40–60° transition band it decorates; evaluate whether the vertical smear reads as strata (fine) or smear (upgrade mask sampling to biplanar).
- Retire the `nPatch` cliff-threshold dither as stagger takes over: scale it by `(1−staggerAmount)` (two independent perturbations on one threshold = mush).
- Macro breakup: third mask tap at a huge scale (planar) replaces the fbm macro lighten/darken — the reference's "one mask, used everywhere"; keep `lumaBlend` knob, expect to lower it once stagger sharpens transitions.
- Fallback if the Dropbox fetch fails: procedural stand-in via existing `fbm` while keeping the TU21 plumbing.

Gate: transitions staggered/organic at `staggerAmount` 1 vs gradient-smooth at 0; no watercolor mush; close zoom clean; terraform live re-texture still works.

### P2.11 — freeze + docs

- `/tileset dump` to freeze new defaults; bump `CONFIG_VERSION` (4).
- Perf capture on/off (closes the outstanding P1/P2 exit criterion) — see budget §5.
- Update `tileset-terrain-implementation-notes.md` §6 + memory + SOURCES.md.

## 4. Evaluation criteria (up front)

1. Core-trick proof: `albedoSortMode` toggle reproduces the reference scatter-vs-flat-bands comparison in debug view 6 (frames 05m15s–06m00s vs 06m15s–06m30s). Pass/fail for the whole round.
2. Foothills reads as a strata band whose width visibly follows `foothillsSpanDeg`; cliff faces scatter, not band.
3. Transitions staggered by the mask at `staggerAmount` 1, plain at 0; no new tiling artifacts at close zoom.
4. No regressions: shadows, infotex, water, deferred G-buffer (`s.normal` path unchanged), terraform live re-texture.
5. Perf delta captured and within budget (§5).

## 5. Perf budget (quantified model, measurement protocol, thresholds)

### 5.1 What multiplies the cost

- `composite()` runs TWICE per terrain pixel per frame on land maps: deferred G-buffer pass + forward pass, both full resolution (SMFGroundDrawer.cpp:322-331; deferred is skipped only for reflection/refraction passes, :210-217).
- Water maps add forward-only extras: water reflection (small FBO, minor) + refraction (near screen-res).
- The multiplier applies equally to baseline and increment, so the terrain-cost RATIO below is multiplier-independent; it matters only when converting to absolute ms.

### 5.2 Tap inventory per `composite()` call (from code, not hand-waved)

Cost classes: A = biplanar `textureGrad` pair on 2K/4K uncompressed RGBA8 (two divergent UV regions, cache-hostile, weight ×2); B = planar tap on 2K/4K uncompressed RGBA8 (weight ×1); C = small cached texture — heightmap, $normals, 1K mask, shadow (weight ×0.25).

| | A taps | B taps | C taps | raw | weighted |
|---|---|---|---|---|---|
| Current P2.7 | 6 (cliff d/n/a) | 9–11 (soil/rocky/plat + detile far) | 5–6 | 20–23 | ~23.5 |
| Planned MITIGATED | 8 (+foothills norm) | 9–11 | 8–9 (+2 mask +1 macro) | 25–28 | ~28.3 (**+20%**) |
| Planned NAIVE (own foothills d/a) | 12 | 9–11 | 8–9 | 29–32 | ~36.3 (**+54%**) |

ALU is roughly flat: `angleWeights` runs twice but is pure math on already-sampled data; the macro mask tap RETIRES the fbm macro octave (~30 ALU ops) — a wash or small win.

### 5.3 The mitigation IS the design (not a compromise)

The reference conclusion, verbatim: the intermediary layer "is only there so that you can add a specific, intense normal to it."
So foothills borrows the cliff's already-computed biplanar diffuse+ARM samples (same texture per the user's cliff_side decision, same projection) and adds ONLY its own chunky-normal biplanar pair: +2 A taps, not +6.
Dedicated foothills diffuse/ARM becomes an optional later upgrade (returns to the naive column) if the shared look fails visually.
Additional lever, applied in P2.9: `if (wFoot > 0.005)` branch around the foothills norm taps — SAFE because gradients are explicit (`textureGrad` with `dFdx/dFdy` hoisted outside the branch, no quad-derivative hazard); the band covers ~5–15% of terrain pixels, so most quads skip the +2 entirely, pulling the mitigated increment toward **+5–10%** map-wide.

### 5.4 VRAM delta

- Quarry chunky normal 2K RGBA8 + mips ≈ 22 MB; stagger mask 1K ≈ 5.6 MB; foothills diffuse/ARM shared with cliff = 0.
- Total ≈ +28 MB on the current ~510 MB uncompressed set (+5%) — noise; the P3 packer remains the real VRAM fix.

### 5.5 Measurement protocol (folded into the P2.8/P2.9/P2.10 gate sessions)

1. GPU-bound check first: compare FPS at 100% vs 50% resolution scale; if FPS barely moves, the scene is CPU-bound and shader deltas are invisible there — pick a heavier camera.
2. Three fixed cameras (cliff close-up, mid RTS, far zoom-out), empty skirmish, 30s FPS average each, widget ON vs OFF (F11 toggle).
3. Convert to frame time: Δms = 1000/fps_off − 1000/fps_on (FPS deltas alone mislead at high framerates).
4. Session 1 (P2.8 gate): P2.7 vs stock engine shader = the BASELINE terrain cost T (closes the outstanding P1/P2 perf item). Sessions 2–3: each increment vs P2.7.
5. Worked example for reading results: if T ≈ 2 ms at 1440p, mitigated ≈ +0.4 ms (143→135 fps at a 7 ms frame), naive ≈ +1.0 ms (143→125 fps); at a CPU-bound 60 fps battle, likely no visible change.

### 5.6 Acceptance thresholds (agreed up front)

- Mitigated plan ships if terrain Δ ≤ 0.5 ms at the mid-RTS camera on the user's GPU at native res.
- 0.5–1.2 ms: acceptable for the prototype, but the `wFoot` branch becomes mandatory before P3.
- > 1.2 ms: stop, profile which taps dominate (drop mask to 1 scale, or gate foothills taps harder) before proceeding.
- Sampler count → 22 (widget already exceeds the GL3 minimum of 16 at 18; desktop reality is 32 — note for the eventual spec).

## 6. Risks

- Pixel-normal albedo weights are per-fragment → possible distance shimmer; normal-map mipping naturally decays pixelN→geoN, watch in test.
- Foothills-vs-talus visual crowding on the cliff approach; talus weights may need retune after P2.9.
- TIF/PNG conversion and G-flip verified via debug view 2 before any look judgement.
- Dropbox fetch may fail (link age) → procedural fallback path in P2.10 keeps the phase testable.

## 7. Decisions confirmed with user (2026-07-14)

- Foothills is a NEW 5th layer (TU18–20); the concavity talus layer stays.
- Foothills placeholder diffuse: `cliff_side` (band reads as stratified rock continuing out of the cliff).
- Verification cadence: gate per phase — three in-game test rounds (P2.8 core-trick A/B, P2.9 foothills band, P2.10 stagger).
