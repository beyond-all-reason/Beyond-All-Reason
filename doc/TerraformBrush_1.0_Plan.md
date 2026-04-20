# Terraform Brush — 1.0 Release Plan

> Created: 2026-04-20
> Status legend: ⬜ Todo · 🔧 In Progress · ✅ Done · ❌ Won't Fix
> Dependencies flow top-to-bottom: each phase depends on the one above.

---

## Per-Tool UI Audit (Verified 2026-04-20)

Verified against actual RML markup (`gui_terraform_brush.rml`) and Lua (`gui_terraform_brush.lua`).

| Tool | RML Overlays section | RML Instruments section | RML Controls section | Symmetry | Undo | Notes |
|------|:---:|:---:|:---:|:---:|:---:|-------|
| **Terraform** | ✅ `section-overlays` | ✅ `section-instruments` | — | ✅ (inside instruments) | ✅ `section-undo` | Complete — the reference template |
| **Feature Placer** | ✅ `section-fp-overlays` | ✅ `section-fp-instruments` | ✅ `section-fp-controls` | ❌ | ✅ | Complete — second reference template |
| **Metal** | ❌ | ❌ | — | ❌ | ✅ `section-mb-undo` | Lua stubs exist (L2348-2349) but NO RML elements — dead code |
| **Grass** | ❌ | ❌ | — | ❌ | ✅ `section-gb-undo` | Lua stubs exist (L2351-2352) but NO RML elements — dead code |
| **Splat** | ❌ | ❌ | — | ❌ | ✅ `section-sp-undo` | Lua stubs exist (L2415-2416) but NO RML elements — dead code |
| **Decals** | ❌ | ❌ | — | ❌ | ✅ `section-dc-undo` | Lua stubs exist (L2418-2419) but NO RML elements — dead code |
| **Weather** | ❌ | ❌ | — | ❌ | — | Lua stubs exist (L2411-2412) but NO RML elements — dead code |
| **Lights** | ❌ | ❌ | — | ❌ | ✅ `section-lp-undo` | Lua stubs exist (L2421-2422) but NO RML elements — dead code |
| **StartPos** | ❌ | ❌ | — | ❌ | — | No Lua stubs, no RML elements — blank slate |
| **Clone** | ❌ | ❌ | — | ❌ | ✅ `section-cl-undo` | Has Mirror X/Z paste transforms (not symmetry). No overlays/instruments stubs |

**Key finding:** The Lua at L2348-2422 registers `envSectionToggle()` calls for mb/gb/wb/sp/dc/lp overlays+instruments, but the corresponding RML `<div>` elements were never created. Those toggle calls silently fail (`getElementById` returns nil). Only **Terraform** and **Feature Placer** have actual working overlays/instruments in the UI.

---

## Phase 0 — Stabilize (blocks everything)

| # | Status | Task | Notes |
|---|--------|------|-------|
| P0.1 | ⬜ | **Test IIFE fix** — Reload game, confirm widget loads with 4 IIFEs applied. | 162/200 locals. If crash → check infolog for line number, wrap more sections. |
| P0.2 | ⬜ | **Split monolithic Lua** (~11,700 lines → per-tool files) | Prerequisite for every subsequent task. Smaller diffs, isolated testing, no merge conflicts. |

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
| P1.1 | ⬜ | **Document canonical section order** from terraform + feature placer panels | These are the finished reference implementations |
| P1.2 | ⬜ | **Define the "tool panel spec"** — standard sections every tool should have | See spec below |

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
| P2.1 | ⬜ | **Metal** | Add RML: overlays section, instruments section, symmetry. Remove dead Lua stubs, replace with real wiring. |
| P2.2 | ⬜ | **Grass** | Add RML: overlays section, instruments section, symmetry. Remove dead Lua stubs, replace with real wiring. |
| P2.3 | ⬜ | **Splat** | Add RML: overlays section, instruments section, symmetry. Remove dead Lua stubs, replace with real wiring. |
| P2.4 | ⬜ | **Decals** | Add RML: overlays section, instruments section, symmetry. Remove dead Lua stubs, replace with real wiring. |
| P2.5 | ⬜ | **Weather** | Add RML: overlays section, instruments section, symmetry. Remove dead Lua stubs, replace with real wiring. |
| P2.6 | ⬜ | **Lights** | Add RML: overlays section, instruments section, symmetry. Remove dead Lua stubs, replace with real wiring. |
| P2.7 | ⬜ | **StartPos** | Full UI scaffolding: overlays, instruments, symmetry. Blank slate — no existing stubs. |
| P2.8 | ⬜ | **Clone** | Full UI scaffolding: overlays, instruments, symmetry. Has mirror X/Z already (paste transforms) — evaluate whether symmetry applies differently here. |

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

> Updated: 2026-04-20

| Phase | Items | Done | Notes |
|-------|-------|------|-------|
| Phase 0 — Stabilize | 2 | 0 | IIFE test + monolithic split |
| Phase 1 — Template | 2 | 0 | Document spec from reference tools |
| Phase 2 — Per-tool UI | 8 | 0 | Add overlays/instruments/symmetry to 8 tools |
| Phase 3 — Grayouts | 2 | 0 | Per-tool relevance map + implement |
| Phase 4 — Docs | 4 | 0 | Tracker + docs cleanup |
| Phase 5 — Icons | 2 | 0 | Human work, parallelizable |
| Release Readiness | 7 | 0 | Smoke test, persistence, README, errors, pen pressure, perf, changelog |
| **Total** | **27** | **0** | |
