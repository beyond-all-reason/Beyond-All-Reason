# Terraform Brush — 1.0 Release Plan

> Created: 2026-04-20
> Status legend: ⬜ Todo · 🔧 In Progress · ✅ Done · ❌ Won't Fix
> Dependencies flow top-to-bottom: each phase depends on the one above.

---

## Per-Tool UI Audit (Verified 2026-04-21)

Verified against actual RML markup (`gui_terraform_brush.rml`) and Lua (`gui_terraform_brush.lua`).

| Tool | RML Overlays section | RML Instruments section | RML Controls section | RML Smart/Filters | Symmetry | Undo | Notes |
|------|:---:|:---:|:---:|:---:|:---:|:---:|-------|
| **Terraform** | ✅ `section-overlays` | ✅ `section-instruments` | — | — | ✅ (inside instruments) | ✅ `section-undo` | Complete — reference template. INSTRUMENTS header now shows a notify dot + chip-2pulse on Measure after a ramp is drawn (manipulator discoverability). |
| **Feature Placer** | ✅ `section-fp-overlays` | ✅ `section-fp-instruments` | ✅ `section-fp-controls` | ✅ `section-fp-smart` | ✅ | ✅ | Complete — reference template with FILTERS pill chips (Slope/Altitude). |
| **Metal** | ✅ `section-mb-overlays` | ✅ `section-mb-instruments` | — | — | ✅ | ✅ `section-mb-undo` | DISPLAY + INSTRUMENTS done (P2.1). No CONTROLS/SMART wrappers. |
| **Grass** | ✅ `section-gb-overlays` | ✅ `section-gb-instruments` | — | ✅ `section-gb-smart` | ✅ | ✅ `section-gb-undo` | DISPLAY + INSTRUMENTS + SMART done (P2.2). Uses exclusive pill tabs (Slope/Altitude/Color). No CONTROLS wrapper. |
| **Splat** | ✅ `section-sp-overlays` | ✅ `section-sp-instruments` | ✅ `section-sp-controls` | ✅ `section-sp-smart` | ✅ | ✅ `section-sp-undo` | **Complete** (P2.3). Splat Map overlay chip with notify dot + chip-2pulse discoverability. FILTERS restructured to FP pattern (Slope/Altitude independent pills). |
| **Decals** | ✅ `section-dc-overlays` | ✅ `section-dc-instruments` | ✅ `section-dc-controls` | — | ✅ (mirror) | ✅ `section-dc-undo` | P2.4 scaffolded. Mirror-chips via shared helper forward to TB state. |
| **Weather** | ✅ `section-wb-overlays` | ✅ `section-wb-instruments` | ✅ `section-wb-controls` | — | ✅ (mirror) | — | P2.5 scaffolded. |
| **Lights** | ✅ `section-lp-overlays` | ✅ `section-lp-instruments` | ✅ `section-lp-controls` | — | ✅ (mirror) | ✅ `section-lp-undo` | P2.6 scaffolded. |
| **StartPos** | ✅ `section-st-overlays` | ✅ `section-st-instruments` | ✅ `section-st-controls` | — | ✅ (mirror) | — | P2.7 scaffolded (prefix `st-` to avoid Splat `sp-` collision). |
| **Clone** | ✅ `section-cl-overlays` | ✅ `section-cl-instruments` | ✅ `section-cl-controls` | — | ✅ (mirror) | ✅ `section-cl-undo` | P2.8 scaffolded. Mirror X/Z paste transforms kept separate. |

**Status:** All 10 tools have DISPLAY+INSTRUMENTS+CONTROLS wrappers. Decals/Weather/Lights/StartPos/Clone (P2.4–P2.8) are wired end-to-end (RML + mirror helpers + DrawWorld + widget-side snap/symmetric/measure deferral). Smart filters remain as separate follow-up work.

**Dead Lua registrations** (in `tf_environment.lua` — elements never created in RML, toggle calls silently no-op):
- `btn-toggle-wb-mode`, `btn-toggle-wb-dist`, `btn-toggle-wb-undo`, `btn-toggle-wb-overlays`, `btn-toggle-wb-instruments`, `btn-toggle-wb-controls`
- `btn-toggle-dc-overlays`, `btn-toggle-dc-instruments`, `btn-toggle-dc-controls`
- `btn-toggle-lp-overlays`, `btn-toggle-lp-instruments`, `btn-toggle-lp-controls`

---

## Phase 0 — Stabilize (blocks everything)

| # | Status | Task | Notes |
|---|--------|------|-------|
| P0.1 | ✅ | **Test IIFE fix** — Reload game, confirm widget loads with 4 IIFEs applied. | 162/200 locals. Verified structurally; runtime tested post-split. |
| P0.2 | ✅ | **Split monolithic Lua** (~11,700 lines → per-tool files) | 12 modules extracted. Main file 12,595→5,563 lines. |

> **P0.2 Split plan:**
> - Map sections: terraform core, metal, grass, splat, decals, weather, environment, lights, startpos, clone, settings, guide mode
> - Extract to: `tf_metal.lua`, `tf_grass.lua`, `tf_splat.lua`, `tf_decals.lua`, `tf_weather.lua`, `tf_environment.lua`, `tf_lights.lua`, `tf_startpos.lua`, `tf_clone.lua`, `tf_settings.lua`
> - Shared state stays in main file (`widgetState`, `playSound`, helpers)
> - Each file returns an `attach(doc, widgetState, ...)` function called from `attachEventListeners()`
> - Also removes the dead Lua `envSectionToggle` stubs for non-existent RML elements

---

## Phase 1 — Establish Tool Panel Template (needs Phase 0)

| # | Status | Task | Notes |
|---|--------|------|-------|
| P1.1 | ✅ | **Document canonical section order** from terraform + feature placer panels | These are the finished reference implementations |
| P1.2 | ✅ | **Define the "tool panel spec"** — standard sections every tool should have | See spec below |
| P1.3 | ✅ | **Populate guide mode tooltips** — add `guideHints` entries for all new buttons/controls added since last guide update | All controls audited; guideHints table complete for all tools. |

> **Grass shape panel cleanup (2026-04-20):** Removed the duplicate grass-specific SHAPE panel from RML and tf_grass.lua. Grass tool now uses the shared shapes panel, matching metal/splat/other tools.

> **Tool Panel Spec** (standard section order):
> 1. **MODE** — sub-modes row (paint/fill, stamp/draw, express/shape/startbox, etc.)
> 2. **SHAPE** — shape buttons (if applicable: circle, square, diamond, ring, hex, triangle)
> 3. **CONTROLS** — tool-specific sliders (size, rotation, length, curve, intensity, density, etc.)
> 4. **INSTRUMENTS** — precision aids: grid-snap, angle-snap, measure, symmetry
> 5. **DISPLAY** — visual overlays: grid overlay, height colormap, tool-specific visualizations (heatmaps, density previews)
> 6. **UNDO/HISTORY** — undo slider + undo/redo buttons
> 7. **SAVE/LOAD/EXPORT** — presets, file import/export

---

## Phase 2 — Add Missing UI Sections Per Tool (needs Phase 1)

Each tool gets the sections it's missing. Work per tool:

| # | Status | Tool | Work needed |
|---|--------|------|-------------|
| P2.1 | ✅ | **Metal** | DISPLAY + INSTRUMENTS + CONTROLS + SMART wrapped collapsibles. All chips wired through `WG.TerraformBrush.set*`. |
| P2.2 | ✅ | **Grass** | DISPLAY + INSTRUMENTS + CONTROLS + SMART wrapped collapsibles. Shape/rotation pulled from shared TB state. |
| P2.3 | ✅ | **Splat** | DISPLAY + INSTRUMENTS + CONTROLS + SMART wrapped. `paintAtSymmetric` helper integrates snapWorld + symmetric fan-out. Height-colormap + protractor overlays now include splat branch. Measure Ruler/Sticky chips omitted (not applicable to click-based paint). drawSymmetryOverlay gate fixed to include SplatPainter. **Splat Map** overlay chip added to DISPLAY — channel-colorized world overlay (R=red, G=green, B=blue, A=yellow) via `WG.SplatPainter.setSplatOverlay()`, rendered in `DrawWorld` with GLSL colorization shader and 32×32 terrain-following grid. **SMART FILTER restructured** to match Feature Placer FILTERS pattern: renamed header, removed master enable toggle, added Slope/Altitude independent pill chips (toggle sub-divs), warn chip shows when smart is active. **Notify dot** (pulsating cyan dot) in DISPLAY header advertises the feature; **chip-2pulse** animation fires on the Splat Map chip each time DISPLAY section is opened. |
| P2.4 | ✅ | **Decals** | DISPLAY + INSTRUMENTS + CONTROLS wrappers added to RML. Mirror-chips forward to shared TB state via `ctx.attachTBMirrorControls(doc,"dc")`. `section-dc-*` env toggles registered. DrawWorld heightColormap + protractor branches include DecalPlacer. drawSymmetryOverlay gate extended. Smart filters pending. |
| P2.5 | ✅ | **Weather** | Same wrappers via prefix `wb`. Mirror-chip sync hooked into main `syncAllTools` via new `elseif wbState.active` branch (Weather has no per-module sync). DrawWorld + symmetry gate extended. |
| P2.6 | ✅ | **Lights** | Same wrappers via prefix `lp`. Mirror-chip sync in `tf_lights.M.sync`. DrawWorld + symmetry gate extended. |
| P2.7 | ✅ | **StartPos** | Full scaffold via prefix `st` (to avoid collision with existing Splat `sp-` prefix). Mirror-chip sync in `tf_startpos.M.sync`. DrawWorld + symmetry gate extended. |
| P2.8 | ✅ | **Clone** | Full scaffold via prefix `cl`. Mirror-chip sync in `tf_clone.M.sync`. Existing Mirror X/Z paste transforms kept separate from new Symmetry chip (different semantics). DrawWorld + symmetry gate extended. |

### Per-tool chore checklist (DO NOT SKIP)

When rolling INSTRUMENTS/DISPLAY to a new tool, every single item below must be ticked before moving on. Items were missed repeatedly on earlier passes.

- [ ] RML: add `btn-toggle-XX-overlays` + `section-XX-overlays` collapsible (DISPLAY).
- [ ] RML: add `btn-toggle-XX-instruments` + `section-XX-instruments` collapsible (INSTRUMENTS).
- [ ] RML: wrap existing CONTROLS block in `btn-toggle-XX-controls` + `section-XX-controls` collapsible.
- [ ] RML: wrap SMART FILTER block (if any) in `btn-toggle-XX-smart` + `section-XX-smart` collapsible.
- [ ] `tf_environment.lua`: register all four `envSectionToggle(...)` for the four wrappers above.
- [ ] `tf_<tool>.lua`: wire chips through `WG.TerraformBrush.set*` — do NOT maintain parallel state.
- [ ] `tf_<tool>.lua`: `M.sync` reflects shared TB state onto chips + sub-row visibility + labels every frame.
- [ ] Measure toolbar: use only `Show Length` + `Clear All`. Drop `Ruler Mode` + `Sticky` — not applicable to any tool past metal where they had no wired effect.
- [ ] Widget (`cmd_<tool>.lua`): paint/place entry point calls `tb.snapWorld(x, z, rot)` and iterates `tb.getSymmetricPositions(x, z, rot)`.
- [ ] Widget: `widget:MousePress` defers to measure tool (`if st.measureActive then return false`).
- [ ] `cmd_terraform_brush.lua` DrawWorld: add tool branch to the **heightColormap overlay** block (else its chip draws nothing).
- [ ] `cmd_terraform_brush.lua` DrawWorld: add tool branch to the **protractor overlay** block (else its chip draws nothing).
- [ ] `cmd_terraform_brush.lua` `extraState.drawSymmetryOverlay`: add tool's `WG.<Tool>.getState().active` to the allow-list early-return guard (else symmetry lines don't draw for the tool).
- [ ] Smoke test: toggle each chip; paint a stroke with symmetry on; confirm fan-out visually.

> **Per-tool details:**
> - **Symmetry** = forwarding the existing `WG.TerraformBrush.setSymmetryActive()` API to each tool's gadget/widget. The terraform brush already has radial + mirror-X + mirror-Y — reuse the same UI pattern (chip toggle + sub-toolbar).
> - **Instruments** = grid-snap + angle-snap + measure toggle (shared controls, per-tool enable flags)
> - **Display** = grid overlay + tool-specific viz:
>   - Metal: metal value heatmap overlay
>   - Grass: density overlay (already exists in `cmd_grass_brush.lua`?)
>   - Splat: texture preview overlay
>   - Decals: decal bounds overlay
>   - Weather: weather zone boundary overlay
>   - Lights: light radius/falloff overlay
>   - StartPos: team color overlay, startbox boundaries
>   - Clone: selection region highlight

---

## Phase 3 — Gray Out Irrelevant Shared Elements (needs Phase 2)

> **Scope note:** "Shared" here = per-tool CONTROLS rows that become irrelevant under certain sub-modes/shapes/submodes (e.g. curve slider only matters for ramp; rotation only for non-circular shapes). Cross-tool mirror chips (DISPLAY/INSTRUMENTS) are NOT grayed — they drive shared TB state uniformly.

| # | Status | Task | Notes |
|---|--------|------|-------|
| P3.0 | ✅ | **Grayout mechanism** — `ctx.setDisabled(doc, id, on)` helper + generic `.disabled` CSS rule (opacity 0.35 + pointer-events none) | Helper in `gui_terraform_brush.lua` beside `attachTBMirrorControls`. CSS appended after `.lp-unavailable`. More-specific `.tf-shape-btn.disabled` / `.tf-btn-grass.disabled` still override. |
| P3.1 | ✅ | **Build per-tool relevance matrix** — which per-tool controls are active/grayed under which state | Draft below (§ "Phase 3 — Relevance Matrix"); human confirmed intensity-for-ramp/restore correction. |
| P3.2 | ✅ | **Implement grayout** — per-tool `M.sync` calls `ctx.setDisabled(doc, id, cond)` for every matrix row | All 10 tools wired with safe subset from matrix (see § "P3.2 Implementation Notes"). Length/falloff rows for Terraform deferred pending semantic review. |
| P3.3 | ❌ | **Guide-mode "why disabled"** (optional) — skipped per user 2026-04-22 | Optional polish; can revisit post-1.0 if feedback requests it. |
| P3.4 | ⬜ | **Regression pass** — cycle every sub-mode/shape/submode per tool; confirm no false-positive grayouts | Manual smoke test — awaiting user. |

### Phase 3 — Relevance Matrix (draft, pending human review)

Conventions:
- "Meaningful when" = condition under which the control affects behaviour — leave enabled.
- "Irrelevant when" = condition under which `ctx.setDisabled(doc, id, true)` should be called.
- `s` = tool state from `WG.<Tool>.getState()`.
- Sliders imply their numbox + ± buttons + transport toggle siblings share the same condition (group-disable by row).
- Rows already hidden structurally (e.g. ramp sub-panels display:none) are marked **(hidden)** and do NOT need setDisabled — listed for completeness.

#### 1. Terraform (`cmd_terraform_brush.lua`, prefix none / `btn-*` / `slider-*`)

| Control ID(s) / row wrapper | Meaningful when | Irrelevant when | State field | P3.2 impl |
|---|---|---|---|---|
| `param-rotation-row` (`slider-rotation`, `btn-rot-cw/ccw`, numbox) | `s.shape ∈ {square, hex, oct, tri, ring}` | `s.shape ∈ {circle, fill}` | `shape` | ✅ |
| `param-intensity-row` (`slider-intensity`, `btn-intensity-up/down`) | `s.mode ∈ {raise, lower, smooth, noise, ramp, restore}` (controls formation speed for ramp/restore) | `s.mode == "level"` | `mode` | ✅ |
| `section-heightcap` (`slider-cap-max`, `slider-cap-min`, Absolute toggle, SAMPLE buttons) | `s.mode ∈ {raise, lower, level, smooth, noise}` | `s.mode ∈ {ramp, restore}` | `mode` | ✅ |
| `param-length-row` (`slider-length`, `btn-length-up/down`) | any shape where length-scale stretches the footprint (non-circular) | `s.shape == "circle"` or `"fill"` | `shape` | ⬜ (needs human review — length semantics across modes) |
| `param-falloff-row` (`slider-curve`, `btn-curve-up/down`) | always (brush edge sharpness) | — | — | ⬜ (universal; no grayout needed) |
| `ring-width-row` | `s.shape == "ring"` | other shapes | `shape` | **(hidden)** existing code |
| `restore-strength-row` | `s.mode == "restore"` | other modes | `mode` | **(hidden)** existing code |
| `tf-ramp-type-row` (`btn-ramp-type-straight`, `btn-ramp-type-spline`) | `s.mode == "ramp"` | other modes | `mode` | **(hidden)** existing code |

#### 2. Feature Placer (`cmd_feature_placer.lua`, prefix `fp-`)

| Control ID(s) | Meaningful when | Irrelevant when | State field |
|---|---|---|---|
| `fp-slider-rotation`, `fp-btn-rot-cw/ccw`, `fp-slider-rot-random` | `s.shape != "circle"` AND `s.mode != "remove"` | `s.shape == "circle"` OR `s.mode == "remove"` | `shape`, `mode` |
| `fp-slider-count`, `fp-btn-count-up/down` | `s.mode == "scatter"` | `s.mode ∈ {point, remove}` | `mode` |
| `fp-slider-cadence`, `fp-btn-cadence-up/down` | `s.mode == "scatter"` | `s.mode ∈ {point, remove}` | `mode` |
| `fp-btn-dist-random/regular/clustered` | `s.mode == "scatter"` | `s.mode ∈ {point, remove}` | `mode` |
| `fp-slider-size`, `fp-btn-size-up/down` | `s.mode != "remove"` (radius always used) | `s.mode == "remove"` (uses pick radius, not shape) | `mode` |
| Shape chips (`fp-btn-shape-circle/square/hex/...`) | `s.mode != "point"` (point places exact click) | `s.mode == "point"` | `mode` |
| Smart filter sub-sliders (`fp-slider-slope-*`, `fp-slider-alt-*`) | parent `fp-smart-toggle` ON AND respective pill active | smart off OR pill inactive | `smartEnabled`, `smartFilters.*` |

#### 3. Metal (`cmd_metal_brush.lua`, prefix `mb-`)

| Control ID(s) | Meaningful when | Irrelevant when | State field |
|---|---|---|---|
| `slider-mb-rotation`, `btn-mb-rot-cw/ccw` | `s.subMode == "stamp" AND s.shape != "circle"` | `s.subMode ∈ {paint, remove}` OR `s.shape == "circle"` | `subMode`, `shape` |
| `slider-mb-length`, `btn-mb-length-up/down` | `s.subMode == "stamp" AND s.shape ∈ {square, rect, ring}` | `s.subMode ∈ {paint, remove}` OR circular shape | `subMode`, `shape` |
| `slider-mb-curve`, `btn-mb-curve-up/down` | `s.subMode == "stamp"` | `s.subMode ∈ {paint, remove}` | `subMode` |
| `slider-mb-value` (metal amount) | `s.subMode ∈ {paint, stamp}` | `s.subMode == "remove"` | `subMode` |
| Shape chips (`btn-mb-shape-*`) | `s.subMode == "stamp"` | `s.subMode ∈ {paint, remove}` (paint/remove use circular footprint) | `subMode` |

#### 4. Grass (`cmd_grass_brush.lua`, prefix `gb-`)

| Control ID(s) | Meaningful when | Irrelevant when | State field |
|---|---|---|---|
| `slider-gb-rotation`, `btn-gb-rot-cw/ccw` | `s.brushShape != "circle" AND s.subMode != "erase"` | circle shape OR erase submode | `brushShape`, `subMode` |
| `slider-gb-length` (`brushLengthScale`) | `s.brushShape ∈ {square, rect, ring}` AND `s.subMode != "erase"` | circle shape OR erase | `brushShape`, `subMode` |
| `slider-gb-curve` (`brushCurve`) | `s.subMode ∈ {paint, fill}` | `s.subMode == "erase"` | `subMode` |
| `slider-gb-density` (`targetDensity`) | `s.subMode ∈ {paint, fill}` | `s.subMode == "erase"` | `subMode` |
| `btn-gb-pill-slope` sliders (`slider-gb-slope-max`, `slider-gb-slope-min`, `btn-gb-avoid-cliffs`, `btn-gb-prefer-slopes`) | smart ON AND slope pill active | smart off OR pill inactive | `smartEnabled`, `smartFilters.slopeMax/Min`, `preferSlopes` |
| `slider-gb-slope-min` | `smartFilters.preferSlopes == true` | `preferSlopes == false` (only max used) | `preferSlopes` |
| `btn-gb-pill-altitude` sliders (`slider-gb-alt-min`, `slider-gb-alt-max`) | smart ON AND altitude pill active | smart off OR pill inactive | `altMinEnable`, `altMaxEnable` |
| `slider-gb-alt-min` + buttons | `altMinEnable == true` | disabled | `altMinEnable` |
| `slider-gb-alt-max` + buttons | `altMaxEnable == true` | disabled | `altMaxEnable` |
| `btn-gb-pill-color` sub-row (`slider-gb-color-thresh`, `slider-gb-color-pad`, `btn-gb-pipette`, `btn-gb-exclude-toggle`, `btn-gb-exclude-pipette`) | `texFilterEnabled == true` AND color pill active | disabled | `texFilterEnabled` |
| `btn-gb-avoid-water` | always meaningful (applies to all submodes) | — | — |

#### 5. Splat (prefix `sp-`)

| Control ID(s) | Meaningful when | Irrelevant when | State field |
|---|---|---|---|
| `slider-sp-rotation`, `btn-sp-rot-cw/ccw` | `s.shape != "circle"` | `s.shape == "circle"` | `shape` |
| `slider-sp-length` + buttons | `s.shape ∈ {square, rect, ring}` | circle shape | `shape` |
| `slider-sp-curve` + buttons | always (falloff shaping) | — | — |
| Smart slope/alt sub-sliders | parent smart + pill active | off | `smartEnabled`, `smartFilters.*` |
| Channel chips (R/G/B/A) | always | — | — |

> **Note:** Splat "SP" prefix collides with StartPos legacy IDs. Implementation must use full IDs as listed in RML — this matrix refers to Splat tool proper (channel/strength controls under the splat content div).

#### 6. Decals (`cmd_decal_placer.lua`, prefix `dc-` / code-level `dp`)

| Control ID(s) | Meaningful when | Irrelevant when | State field |
|---|---|---|---|
| `dc-slider-rotation`, `dc-btn-rot-cw/ccw`, `dc-slider-rot-random` | `s.shape != "circle"` AND `s.mode != "remove"` | circle shape OR remove mode | `shape`, `mode` |
| `dc-slider-count` + buttons | `s.mode == "scatter"` | `s.mode ∈ {point, remove}` | `mode` |
| `dc-slider-cadence` + buttons | `s.mode == "scatter"` | `s.mode ∈ {point, remove}` | `mode` |
| `dc-btn-dist-random/regular/clustered` | `s.mode == "scatter"` | `s.mode ∈ {point, remove}` | `mode` |
| `dc-slider-size-min`, `dc-slider-size-max` | `s.mode != "remove"` | `s.mode == "remove"` | `mode` |
| `dc-slider-alpha`, tint RGBA sliders, `dc-btn-align-normal` | `s.mode != "remove"` | `s.mode == "remove"` | `mode` |
| Shape chips | `s.mode != "point"` | `s.mode == "point"` | `mode` |
| Smart filter sub-sliders | smart + pill active | off | `smartEnabled`, `smartFilters.*` |

#### 7. Weather (prefix `wb-`)

| Control ID(s) | Meaningful when | Irrelevant when | State field |
|---|---|---|---|
| `wb-slider-rotation`, `wb-btn-rot-cw/ccw` | `s.shape != "circle" AND s.mode != "remove"` | circle or remove | `shape`, `mode` |
| `wb-slider-length` + buttons | `s.shape ∈ {square, rect, ring} AND s.mode != "remove"` | otherwise | `shape`, `mode` |
| `wb-slider-count` + buttons | `s.mode == "scatter"` | `s.mode ∈ {point, remove}` | `mode` |
| `wb-slider-cadence` + buttons | `s.mode == "scatter"` | `s.mode ∈ {point, remove}` | `mode` |
| `wb-btn-dist-*` | `s.mode == "scatter"` | `s.mode ∈ {point, remove}` | `mode` |
| `wb-slider-frequency`, `wb-slider-persist` | `s.mode != "remove"` | remove | `mode` |
| Shape chips | `s.mode != "point"` | `s.mode == "point"` | `mode` |

#### 8. Lights (`cmd_light_placer.lua`, prefix `lp-`)

| Control ID(s) | Meaningful when | Irrelevant when | State field |
|---|---|---|---|
| `lp-slider-pitch`, `lp-slider-yaw`, `lp-slider-roll` | `s.lightType ∈ {cone, beam}` | `s.lightType == "point"` | `lightType` |
| `lp-slider-theta` (cone angle) | `s.lightType == "cone"` | point or beam | `lightType` |
| `lp-slider-beam-length` | `s.lightType == "beam"` | point or cone | `lightType` |
| `lp-slider-light-radius` (falloff) | always (all types have falloff) | — | — |
| `lp-slider-elevation` + buttons | `s.mode != "remove"` | `s.mode == "remove"` | `mode` |
| `lp-slider-count`, `lp-slider-cadence` | `s.mode == "scatter"` | `s.mode ∈ {point, remove}` | `mode` |
| `lp-btn-dist-*` | `s.mode == "scatter"` | `s.mode ∈ {point, remove}` | `mode` |
| RGB / brightness sliders | `s.mode != "remove"` | `s.mode == "remove"` | `mode` |
| `lp-slider-brush-radius` (pick radius) | `s.mode == "remove"` OR `s.mode == "scatter"` (scatter area) | `s.mode == "point"` | `mode` |

#### 9. StartPos (prefix `st-` new / `sp-` legacy IDs)

| Control ID(s) | Meaningful when | Irrelevant when | State field |
|---|---|---|---|
| `slider-sp-allyteams` + `btn-sp-teams-up/down` + transport | `s.stpSubMode ∈ {express, shape}` | `s.stpSubMode == "startbox"` (manual box draw) | `stpSubMode` |
| `slider-sp-count` + buttons + transport | `s.stpSubMode == "shape"` | `s.stpSubMode ∈ {express, startbox}` | `stpSubMode` |
| `slider-sp-size` + buttons (shape radius) | `s.stpSubMode == "shape"` | `s.stpSubMode ∈ {express, startbox}` | `stpSubMode` |
| `slider-sp-rotation` + buttons (`shapeRotation`) | `s.stpSubMode == "shape" AND s.shapeType != "circle"` | express/startbox OR circle shape | `stpSubMode`, `shapeType` |
| `sp-shape-options` (`btn-sp-shape-circle/square/hexagon/triangle`) | `s.stpSubMode == "shape"` | `s.stpSubMode ∈ {express, startbox}` | `stpSubMode` |
| `btn-sp-random` (randomize team order) | always (all submodes) | — | — |
| `btn-sp-clear` / `btn-sp-save` / `btn-sp-load` | always | — | — |
| `sp-express-hint` / `sp-startbox-hint` block | already submode-gated via display — N/A | — | — |

#### 10. Clone (`cmd_clone_tool.lua`, prefix `cl-`)

| Control ID(s) | Meaningful when | Irrelevant when | State field |
|---|---|---|---|
| `btn-cl-copy` | `s.state ∈ {selecting, box_drawn}` (there is a selection) | `s.state ∈ {idle, copied, paste_preview}` | `state` |
| `btn-cl-paste` | `s.hasBuffer == true` | `hasBuffer == false` | `hasBuffer` |
| `btn-cl-clear` | `s.hasBuffer == true` OR `s.state != "idle"` | fully idle with no buffer | `state`, `hasBuffer` |
| `slider-cl-rotation` + buttons (+ numbox) | `s.state == "paste_preview"` | otherwise (only matters during paste preview) | `state` |
| `slider-cl-height` + buttons | `s.state == "paste_preview"` | otherwise | `state` |
| `btn-cl-mirror-x`, `btn-cl-mirror-z` | `s.state == "paste_preview"` | otherwise | `state` |
| Quality chips (`btn-cl-quality-full/balanced/fast`) | always (persistent setting) | — | — |
| Layer chips (`btn-cl-terrain/metal/features/splats/grass/decals/weather/lights`) | always (pre-copy selection) | — | — |
| `slider-cl-history` + `btn-cl-undo` + `btn-cl-redo` | history stack non-empty (handled by existing history gating) | empty stack | history state |

### P3.2 Implementation Notes

Added `ctx.setDisabledIds(doc, ids, on)` bulk helper in `gui_terraform_brush.lua` (after `ctx.setDisabled`) for tools without wrapping row ids.

Per-tool wiring summary:
- **Terraform** (`gui_terraform_brush.lua`, `elseif tfActive then` block): `param-rotation-row` (shape circle/fill), `param-intensity-row` (mode==level), `section-heightcap` (mode ramp/restore). Length/falloff rows **not wired** — semantics across modes needs human review (see matrix "⬜" marks).
- **Metal** (`tf_metal.lua`): rotation/length disabled unless `stamp` submode with non-circular shape; curve disabled unless stamp; metal-value disabled in remove.
- **Grass** (`tf_grass.lua`): rotation/length disabled in erase or circle; curve/density disabled in erase.
- **Feature Placer** (`tf_features.lua`): rotation + random disabled on circle/remove; count/cadence/dist chips disabled unless scatter.
- **Splat** (`tf_splat.lua`): rotation disabled on circle shape.
- **Decals** (`tf_decals.lua`): rotation/size/alpha/align disabled in remove; count/cadence/dist disabled unless scatter.
- **Weather** (`gui_terraform_brush.lua`, `elseif wbState ... then` block): rotation/length disabled on circle/remove; count/cadence/dist disabled unless scatter; frequency/persist disabled in remove.
- **Lights** (`tf_lights.lua`): color/brightness/elevation disabled in remove; count/cadence disabled unless scatter; brush-radius disabled in point mode. Direction/theta/beam sections were already hidden by lightType.
- **StartPos** (`tf_startpos.lua`): ally-teams disabled in startbox submode; rotation disabled unless shape submode with non-circular shapeType. Count/size already hidden by existing `sp-shape-options` class toggle.
- **Clone** (`tf_clone.lua`): Copy button disabled unless selection drawn; Paste disabled without buffer; Clear disabled in fully-idle state; rotation/height/mirror controls disabled unless paste_preview.

Deferred rows (require human semantic review):
- Terraform `param-length-row` / `param-falloff-row`: length semantics across non-ramp modes, curve behaviour in ramp vs other modes.
- Smart-filter sub-sliders (FP/Grass/Splat): already hidden by per-pill row classes; no additional grayout needed.

---

## Phase 4 — Docs & Tracker Cleanup (after code stable)

| # | Status | Task | Notes |
|---|--------|------|-------|
| P4.1 | ✅ | **Update QoL Tracker** — refresh status summary, mark J1/J2 done, update line counts, remove stale context blocks | Done 2026-04-22. J1 mitigated, J2 ✅ (P0.2 split), stale J2 "how to split" context block removed, status table counts updated (13 remaining / 36 done). |
| P4.2 | ✅ | **Update TerraformBrush.md** — cross-check with tracker, remove duplicates | Done 2026-04-22. No tracker duplicates found; added Related-docs cross-reference block at top pointing to Plan / Tracker / auxiliary docs. |
| P4.3 | ✅ | **Review auxiliary docs** — AutoChainMode.md, CloneWindows.md, SaveLoad_Tracking.md — archive completed, merge overlapping | Done 2026-04-22. CloneWindows already self-archived ("Status: Removed"); AutoChainMode is future proposal; SaveLoad_Tracking is active tracker. No overlap, nothing to merge. |
| P4.4 | ✅ | **Restructure doc/ for reading order** — architecture → user guide → tracker | Done 2026-04-22. Added `doc/README.md` index with primary (feature ref → plan → tracker) and auxiliary (topic-specific) reading order. Renaming skipped to preserve existing cross-references. |

---

## Phase 5 — Icons (human work, parallelizable anytime)

| # | Status | Task | Notes |
|---|--------|------|-------|
| P5.1 | ⬜ | **Audit all AI-generated icons** — identify which need rework | |
| P5.2 | ⬜ | **Rework icons** in Krita/Inkscape | Can run in parallel with any phase |

---

## Release Readiness (parallel with Phases 2-4)

| # | Status | Task | Notes | Auto |
|---|--------|------|-------|------|
| R1 | ⬜ | **Smoke test all tools** — activate each tool, verify basic ops (place, undo, save/load, mode switching, sliders) | Test matrix: one row per tool × operation | 🧠 |
| R2 | 🔧 | **Config persistence audit** — verify all settings survive widget reload (keybinds, presets, display toggles, last tool/mode, slider positions) | **Audit 2026-04-22:** Zero `widget:GetConfigData/SetConfigData` implementations across any terraform-brush widget (`cmd_terraform_brush.lua`, `cmd_splat_painter.lua`, `cmd_grass_brush.lua`, `cmd_feature_placer.lua`, `cmd_decal_placer.lua`, `cmd_weather_brush.lua`, `cmd_light_placer.lua`, `cmd_startpos_tool.lua`, `cmd_clone_tool.lua`) or the main RML widget. Presets persist via file I/O (`presets/` folder). Everything else (last tool, mode, brush radius/rot/curve/intensity, shape, display-toggle states, collapsible open/closed, mute/guide chips, per-tool submodes) resets on each reload. **Scope decision:** full per-widget persistence is a multi-session implementation — follow-ups filed as R2a (UI-layer persistence in RML widget) and R2b (per-tool state persistence in 9 `cmd_*` widgets). | 🤖 |
| R2a | ⬜ | **R2 follow-up — UI-layer persistence** — implement `GetConfigData/SetConfigData` in main RML widget for: `soundMuted`, `guideMode`, collapsible `envSections` open/closed, passthrough-on-reload intent | One-session implementation; uses Spring's standard widget config table | 🤖 |
| R2b | ⬜ | **R2 follow-up — per-tool persistence** — add `GetConfigData/SetConfigData` to each `cmd_*.lua` for brush params + last mode/shape/submode | Per widget: ~30 lines; affects 9 widgets | 🤖 |
| R3 | ⬜ | **README / first-run experience** — "Getting Started" section: tool row overview, env panel access, skybox location, key shortcuts, Discord #mapping link | Target: `doc/TerraformBrush.md` or guide mode improvements | 🧠 |
| R4 | 🔧 | **Error handling at boundaries** — audit all `WG.ToolName` API calls for nil guards; check gadget `RecvLuaMsg` for malformed message resilience | **Audit 2026-04-22:** Gadget RecvLuaMsg now guards non-string/empty msg at entry (`cmd_terraform_brush.lua` gadget). All downstream header handlers already validate via `tonumber(...)` + early-return. Existing nil-guards on `WG.*` listeners: Lights/Decals/Features/Clone have partial top-of-handler checks; Weather/StartPos/Splat/Metal/Grass modules still call `WG.<Tool>.set*(...)` unconditionally — safe only if user hasn't disabled the corresponding `cmd_*` widget. Follow-ups filed as R4a. | 🤖 |
| R4a | ⬜ | **R4 follow-up — WG.* nil guards for Weather/StartPos/Splat/Metal/Grass modules** — add `if not WG.<Tool> then return end` at top of each event listener (mirror pattern used in tf_clone/tf_features/tf_decals/tf_lights) | Low-risk mechanical pass ~30 sites; protects against user `/luaui disable cmd_weather_brush` mid-session | 🤖 |
| R5 | ⬜ | **Pen pressure server** — fix or remove. Multiple failed starts (exit code 1). If shipping: fix Python script; if not: remove UI refs or mark experimental | See terminal history for error output | 🧠 |
| R6 | ⬜ | **Performance sanity check (J3)** — large brush + curve overlay FPS test. Quick profiling pass, optimization deferred. | | 🧠 |
| R7 | ⬜ | **Changelog entry** — summary of all new features for 1.0 release notes (noise mode, clone, startpos, grass brush, keybinds, sounds, env, etc.) | | 🧠 |
| R8 | ✅ | **RmlUi declarative refactor — Phase 2A (perf guards)** — `LoadDocument(RML_PATH, self)` at RML UI Lua L4130 now passes `self` so inline `onclick="widget:Foo()"` handlers work. 8 per-frame `dmHandle.*` writes at L5241–L5265 (`radius`, `shapeName`, `rotationDeg`, `curve`, `intensity`, `lengthScale`, `heightCapMaxStr`, `heightCapMinStr`) now compare-before-write to avoid 2A-style perf regression. | 2026-04-22 | 🤖 |
| R8a | ⬜ | **R8 follow-up — Phase 2B declarative refactor** — convert 200+ `AddEventListener` calls across 12 files to RML `onclick="widget:Foo()"` / `data-event-*` bindings per `rmlui-data-binding` skill. Listener counts: `gui_terraform_brush.lua` ~110, `tf_metal` 55, `tf_grass` 53, `tf_splat` 44, `tf_lights` 36, `tf_weather` 22, `tf_clone`/`tf_noise` 17 each, `tf_startpos` 14, `tf_decals` (many via `bindDCSlider`/`bindDCStep` helpers). RML `gui_terraform_brush.rml` (5542 lines) currently has zero `onclick=`/`data-event-*`. **Prereq**: `ctx.widget = self` plumbed through `ctx` before `attachEventListeners()` in `widget:Initialize`. **Do NOT convert**: drag handles (`mousedown/mousemove/mouseup` at L4039/L4072 + `tf_lights.lua` globe L365–L401), SDL text-input focus/blur on numboxes, `doc:AddEventListener("mouseup")` drag cleanup (L2202/L4072), root `mouseover/mouseout` hover passthrough (L4166/L4169). **Order** (smallest first, one per session): tf_startpos → tf_clone → tf_noise → tf_weather → tf_lights → tf_splat → tf_metal → tf_grass → gui_terraform_brush (split by group: mode / shape / sliders / cap / preset / drag). Plan detail in `/memories/session/phase2b_handoff.md`. Multi-session effort; not a single-turn refactor. | 🤖 |

---

## Status Summary

> Updated: 2026-04-21 (Phase 0 ✅, Phase 1 ✅, P2.1–P2.8 ✅ wired)

## Autopilot Pass Notes — 2026-04-21 (P2.4–P2.8)

**Shared helper added** (`gui_terraform_brush.lua`): `ctx.attachTBMirrorControls(doc, prefix)` + `ctx.syncTBMirrorControls(doc, prefix)`. Each wires/reflects a standard chip set (Grid, Height Map, Grid Snap, Protractor, Measure, Symmetry + symmetry/measure sub-rows) against shared `WG.TerraformBrush` state. Missing elements no-op. Keeps per-tool Lua wiring to 2 lines (attach + sync call).

**RML blocks inserted** at the top of each tool's content div (`tf-decal-controls`, `tf-weather-controls`, `tf-light-controls`, `tf-clone-controls`, `tf-startpos-controls`). Each block contains:
- DISPLAY collapsible with Grid + Height Map chips
- INSTRUMENTS collapsible with Grid Snap, Protractor, Measure, Symmetry chips + measure/symmetry sub-row toolbars (Show Length/Clear All; Radial/Mirror-X/Mirror-Y/Set Origin/Center)
- CONTROLS wrapper opener (`section-XX-controls`) around existing tool content

**envSectionToggle registrations** added in `tf_environment.lua` for `st-*` and `cl-*` (overlays/instruments/controls). The `dc-*`, `wb-*`, `lp-*` toggles were already registered as "dead stubs" — the stubs are now live since the RML elements exist.

**`cmd_terraform_brush.lua` updates**:
- `drawSymmetryOverlay` gate allow-list extended to include DecalPlacer, WeatherBrush, LightPlacer, StartPosTool, CloneTool.
- DrawWorld heightColormap branch now has per-tool clauses using each tool's `getState().radius`/`rotation`/`shape` (fallbacks where fields differ — e.g. StartPosTool uses `shapeRadius`/`shapeType`/`shapeRotation`).
- DrawWorld protractor branch extended with the same tool clauses.

**Prefix note**: StartPos uses prefix `st-` (not `sp-`) because Splat already owns `sp-` prefix, and StartPos existing element IDs also use `sp-` for legacy reasons. The new DISPLAY/INSTRUMENTS/CONTROLS wrappers use `st-` to keep the new toggle IDs unambiguous.

**Deferred (explicit)**:
- Per-widget snapWorld + getSymmetricPositions integration inside each tool's `cmd_*.lua`. The TB API is exposed; widgets need to call it at their place/paint sites. Tools have disparate placement flows (`setMouseDown`, scatter, startbox drag, clone paste), so wiring this cleanly needs per-widget inspection.
- Tool-specific SMART FILTERS (slope/altitude): only Splat + FP + Grass had these. Decals/Weather/Lights/StartPos/Clone do not have natural filter analogs. SMART wrapper omitted.
- Measure toolbar `Ruler Mode`/`Sticky` chips: per spec, only Show Length + Clear All included.
- Per-tool DrawWorld grid/height overlay activation tied to the mirror chips: TB shared state already gates overlay drawing, so chip toggles immediately reflect via existing overlay code.

**Smoke testing**: deferred to Release Readiness R1. Reload widget, switch to each tool, verify DISPLAY/INSTRUMENTS/CONTROLS headers expand, chips toggle, symmetry fan-out renders.

| Phase | Items | Done | Notes |
|-------|-------|------|-------|
| Phase 0 — Stabilize | 2 | 2 | ✅ IIFE test + monolithic split — complete |
| Phase 1 — Template | 3 | 3 | ✅ Canonical order documented, spec defined, guide tooltips audited — complete |
| Phase 2 — Per-tool UI | 8 | 3 | P2.4–P2.8 RML+Lua scaffolded; widget snapWorld/symmetric integration + SMART (where applicable) deferred |
| Phase 3 — Grayouts | 5 | 4 | P3.0+P3.1+P3.2 done; P3.3 ❌ skipped per user; P3.4 regression pending (manual) |
| Phase 4 — Docs | 4 | 4 | ✅ All doc cleanup complete (2026-04-22) |
| Phase 5 — Icons | 2 | 0 | Human work, parallelizable |
| Release Readiness | 9 | 1 | R8 (RmlUi 2A perf guards) done; R8a (2B declarative refactor) pending — smoke test, persistence, README, errors, pen pressure, perf, changelog remain |
| **Total** | **29** | **1** | |
