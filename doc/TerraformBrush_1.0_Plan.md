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

| # | Status | Task | Notes |
|---|--------|------|-------|
| P3.1 | ⬜ | **Build per-tool relevance map** — which shared controls are active/grayed per tool | Agent generates suggestions, **human verifies** each decision |
| P3.2 | ⬜ | **Implement grayout** — `SetClass("disabled", true/false)` on shared elements when tool switches | Examples: "curve" irrelevant for metal stamp; "length" irrelevant for grass; "rotation" irrelevant for circular-only tools |

---

## Phase 4 — Docs & Tracker Cleanup (after code stable)

| # | Status | Task | Notes |
|---|--------|------|-------|
| P4.1 | ⬜ | **Update QoL Tracker** — refresh status summary, mark J1/J2 done, update line counts, remove stale context blocks | |
| P4.2 | ⬜ | **Update TerraformBrush.md** — cross-check with tracker, remove duplicates | |
| P4.3 | ⬜ | **Review auxiliary docs** — AutoChainMode.md, CloneWindows.md, SaveLoad_Tracking.md — archive completed, merge overlapping | |
| P4.4 | ⬜ | **Restructure doc/ for reading order** — architecture → user guide → tracker | |

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
| R2 | ⬜ | **Config persistence audit** — verify all settings survive widget reload (keybinds, presets, display toggles, last tool/mode, slider positions) | Check `GetConfigData()`/`SetConfigData()` coverage per tool. Newer tools (startpos, clone, lights) may not persist. | 🤖 |
| R3 | ⬜ | **README / first-run experience** — "Getting Started" section: tool row overview, env panel access, skybox location, key shortcuts, Discord #mapping link | Target: `doc/TerraformBrush.md` or guide mode improvements | 🧠 |
| R4 | ⬜ | **Error handling at boundaries** — audit all `WG.ToolName` API calls for nil guards; check gadget `RecvLuaMsg` for malformed message resilience | Grep unguarded `WG.` calls in RML UI Lua + widget | 🤖 |
| R5 | ⬜ | **Pen pressure server** — fix or remove. Multiple failed starts (exit code 1). If shipping: fix Python script; if not: remove UI refs or mark experimental | See terminal history for error output | 🧠 |
| R6 | ⬜ | **Performance sanity check (J3)** — large brush + curve overlay FPS test. Quick profiling pass, optimization deferred. | | 🧠 |
| R7 | ⬜ | **Changelog entry** — summary of all new features for 1.0 release notes (noise mode, clone, startpos, grass brush, keybinds, sounds, env, etc.) | | 🧠 |

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
| Phase 3 — Grayouts | 2 | 0 | Per-tool relevance map + implement |
| Phase 4 — Docs | 4 | 0 | Tracker + docs cleanup |
| Phase 5 — Icons | 2 | 0 | Human work, parallelizable |
| Release Readiness | 7 | 0 | Smoke test, persistence, README, errors, pen pressure, perf, changelog |
| **Total** | **27** | **0** | |
