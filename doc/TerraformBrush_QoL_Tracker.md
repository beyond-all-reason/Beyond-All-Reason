# Terraform Brush — QoL & Polish Tracker

> Created: 2026-04-06 · Restructured: 2026-04-08
> Status legend: ⬜ Todo · 🔧 In Progress · ✅ Done · ❌ Won't Fix
> Automatable: 🤖 = agent can implement autonomously · 🧠 = needs human design decisions

---

## Completed Work (Archive)

<details><summary>38 items completed or rejected — click to expand</summary>

| # | Fix | Status |
|---|-----|--------|
| P1 | Fix `setBrushOpacity()` — always sets 1.0, ignores parameter | ✅ |
| P2 | Add missing fields to preset save/load (`ringInnerRatio`, overlays) | ✅ |
| P3 | Add stamp-mode visual indicator | ✅ |
| P4 | Wire persistent grid-snap toggle | ✅ |
| P5 | Add configurable grid-snap size slider | ✅ |
| P6 | Splat texture previews — diffuse detail tex discovery, mapinfo fallback | ✅ |
| P7 | Preset data validation — tonumber guards, pcall wrapper, type checks | ✅ |
| 41 | Environment sub-windows: "open" indicator on launcher buttons | ✅ |
| 42 | Environment RGB sliders: ± buttons | ✅ |
| 43 | Color accent consolidation (`#fbbf24` / `#2a2a0a` unified) | ✅ |
| 44 | Font size stops cleanup (0.85→0.9rem, 0.8→0.75rem) | ✅ |
| 45 | Spacing rhythm cleanup (mt-1-5 → mt-2 for 8dp section gaps) | ✅ |
| 46 | Focus ring consistency (already `#6a6a6acc` everywhere) | ✅ |
| 47 | Slider thumb hover glow (box-shadow per variant) | ✅ |
| 48 | Collapsible advanced sections (HEIGHT CAP, SMART FILTER, PRESETS) | ✅ |
| 49 | Keybind badge visibility (color bump + pill bg) | ✅ |
| 40 | Environment accordion (superseded by UX11 dockable panels) | ❌ |
| A1 | Import fallback uses `Spring.GetGroundExtremes()` instead of hardcoded [-200,800] | ✅ |
| A2 | Preset name sanitization — added whitespace trim | ✅ |
| B1 | `heightColormap` implemented — topographic colormap + contour lines in brush footprint | ✅ |
| B2 | Import/Load button greyed out with `opacity:0.5; pointer-events:none` | ✅ |
| B4 | Env panel IDs verified — all 6 match between Lua and RML | ✅ |
| I1 | `gl.GetSun()` nil checks — `or 0` fallbacks on all direct calls in env init | ✅ |
| I2 | Guide mode toggle-off clears `currentHint`, `lastRenderedHint`, `inner_rml` | ✅ |
| I3 | Skybox texture `VFS.FileExists()` check + warning echo | ✅ |
| I5 | Redo stack — verified already capped at `MAX_UNDO` + vertex budget eviction | ✅ |
| T1 | Grass editing tool — paint/fill brush for GL4 grass density, integrated into tools row with density slider, shape/size/rotation/curve controls, and TGA export. Widget: `cmd_grass_brush.lua`, API extension in `map_grass_gl4.lua`. | ✅ |
| B3 | Splat export format button — fully wired. `cycleExportFormat()` + `setExportFormat()` in `cmd_splat_painter.lua`; supports PNG/TGA/BMP. | ✅ |
| I4 | Skybox fade transition — verified active. `skyFade` state machine + `tickSkyboxFade(dt)` called from main update loop. | ✅ |
| D2 | Restore strength live readout — `restore-strength-label` element in rml L924, updated live via `inner_rml` at gui_terraform_brush.lua L3417. Shows percentage. | ✅ |
| G2 | Numbox input affordance — Enter-to-confirm (`keydown` + `KEY_RETURN`), blur-to-apply, `SDLStartTextInput()` on focus, `:focus` border styling. Wired generically for all `tf-slider-numbox` elements via `attachSliderInputBoxes()`. | ✅ |
| N1 | **Noise terrain mode** — elevated from render overlay to full terrain modification mode. CPU noise evaluation in gadget via `$terraform_noise$` protocol. 5 algorithms (perlin, ridged, voronoi, fbm, billow); scale, octaves, persistence, lacunarity, seed controls. 6th mode button added to TERRAIN row. | ✅ |
| N2 | **Built-in brush presets** — 8 curated presets (Ditch Digger, Sandworm, Crater, Mesa, Ball, Moat, Badlands, Dunes) bundled with the brush; non-deletable; shown alongside user presets in the preset dropdown. | ✅ |
| N3 | **Start Positions tool** — full tool panel with Express/Shape/Startbox sub-modes; shape templates (circle/square/hexagon/triangle); ally-teams/position-count/size/rotation sliders; random positions button; save/load. Via `WG.StartPosBrush`. | ✅ |
| N4 | **Clone tool** — COPY/PASTE/CLEAR with 8-layer toggles (Terrain/Metal/Features/Splats/Grass/Decals/Weather/Lights); paste transform controls (quality, scale, flip H/V). Gadget: `cmd_clone_tool.lua`; via `WG.CloneTool`. | ✅ |
| N5 | **UI sound effects** — 15 sound event types (modeSwitch, shapeSwitch, toolSwitch, toggleOn/Off, click, tick, undo, save, dropdown, panelOpen, reset, exit, sliderLock); mute toggle (`btn-sound`) in header; per-type cooldown prevents spam. | ✅ |
| N6 | **Passthrough mode** — `btn-passthrough` header button deactivates all tools while panel stays visible; saves/restores prior tool+mode on re-activate; play/pause icons toggle accordingly. | ✅ |
| N7 | **Slider wheel-lock** — double-click any slider to lock it against accidental scroll changes; pulse animation on locked sliders; sound feedback (`sliderLock`); Escape or double-click to unlock. | ✅ |
| N8 | **Ring inner-ratio scroll control** — `ringInnerRatio` promoted from compile-time constant (0.6) to runtime variable; `LCTRL+R+Scroll` adjusts ring brush hole size; `RING_WIDTH_STEP = 0.05` per tick. | ✅ |

</details>

---

## Remaining Work

> **File shorthand key:**
> - **widget** = `luaui/Widgets/cmd_terraform_brush.lua` (client-side logic)
> - **RML UI Lua** = `luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.lua` (~8300 lines, UI logic)
> - **rml** = `luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.rml` (markup)
> - **rcss** = `luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.rcss` (styles, tokens L11-87)
> - **gadget** = `luarules/gadgets/cmd_terraform_brush.lua` (server-side terrain ops)
> - **engine types** = `recoil-lua-library/library/` (Lua API type stubs for Spring/RmlUI)

### A. Bug Fixes

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| A1 | ✅ | **Import metadata range fallback assumes [-200, 800]** — now uses `Spring.GetGroundExtremes()` when metadata file is missing. | widget ~L1265 | Small | Medium | 🤖 |

> **Context:** Read `doImportHeightmapRead()` at widget L958-L1240. The metadata `.txt` companion
> is written by `doExportHeightmap()` (L970-L1008) — shows format. The fallback range is applied
> when the `.txt` is missing. Fix: scan pixel min/max before mapping, or show an RML dialog.
> RML dialog pattern: see `gui_feature_placer.lua` for modal-style popups.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| A2 | ✅ | **Preset name sanitization post-write** — added whitespace trim; guards already before `io.open()`. | widget ~L714 | Trivial | Low | 🤖 |

> **Context:** Read `savePresetAs()` at widget L750-L792. The empty-name guard should move before
> the `io.open()` call. Also see `loadPresetsFromDisk()` at L688 for the file format.

### B. Dead Code / Stub Cleanup

> These can all be done in one pass. Items marked "remove" are cheaper than "implement."

| # | Status | Issue | Recommendation | File | Effort | Impact | Auto |
|---|--------|-------|----------------|------|--------|--------|------|
| B1 | ✅ | **`heightColormap` toggle now functional** — renders topographic colormap overlay (9-stop USGS-style ramp + marching-squares contour lines at 10% intervals) inside brush footprint. `dustEffects` kept as placeholder. | Implemented heightColormap; dustEffects still placeholder | widget | Small | Medium | 🤖 |

> **Context:** Toggle state vars at widget L275-L276. Grep for `dustEffects` and `heightColormap`
> across widget + gadget to find every reference. Remove UI elements in rml, toggle handlers in
> RML UI Lua, and the flag fields from the message protocol in gadget. The gadget `RecvLuaMsg()`
> parses these fields positionally — update format comment at gadget top.

| # | Status | Issue | Recommendation | File | Effort | Impact | Auto |
|---|--------|-------|----------------|------|--------|--------|------|
| B2 | ✅ | **Import/Load button "Coming soon"** — added `opacity: 0.5; pointer-events: none` to `.tf-load-btn-disabled`. | Grey out with disabled styling | RML UI ~L2578 | Trivial | Medium | 🤖 |

> **Context:** RML element at rml L535: `id="btn-import"`, class `tf-action-btn tf-load-btn-disabled`.
> Disabled styling already exists in rcss L839-L847. Just ensure no misleading hover tooltip remains.
> Pattern: see how clay button uses `.unavailable` class at rcss L620-L630.

| # | Status | Issue | Recommendation | File | Effort | Impact | Auto |
|---|--------|-------|----------------|------|--------|--------|------|
| B3 | ✅ | **Splat export format button** — fully wired. `EXPORT_FORMATS = {"png", "tga", "bmp"}` in `cmd_splat_painter.lua` L96-98; `cycleExportFormat()` at L772, `setExportFormat(fmt)` at L776; export at L613 retrieves active format. | Verified functional | splat widget | Small | Low | 🤖 |

| # | Status | Issue | Recommendation | File | Effort | Impact | Auto |
|---|--------|-------|----------------|------|--------|--------|------|
| B4 | ✅ | **6 env panel IDs grabbed but never created** — verified all 6 IDs match between Lua `getElementById` calls and RML elements. Already resolved. | Remove dead refs or create placeholders | RML UI Lua | Trivial | Low | 🤖 |

> **Context:** The 6 env floating windows DO exist now in rml: `tf-env-sun-root` (L1609),
> `tf-env-fog-root` (L1726), `tf-env-ground-lighting-root` (L1922), `tf-env-unit-lighting-root`
> (L2019), `tf-env-map-root` (L2116), `tf-env-water-root` (L2176). This may already be resolved —
> verify that the Lua `getElementById` calls in RML UI Lua ~L137-L215 (`widgetState` init) match
> these IDs. If they do, mark as done.

### C. RCSS Consistency Pass

> All items below are pure RCSS/RML and can be batched into a single agent-driven session.
> Phase 9 (done 2026-04-08) handled spacing+typography partially; this finishes the job.
> **Start by reading:** rcss L11-L87 (design tokens) to understand the existing variable system.
> Also reference the weather brush RCSS: `luaui/RmlWidgets/gui_weather_brush/gui_weather_brush.rcss`
> for consistency with sibling widgets.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| C1 | ✅ | **Standardize disabled/unavailable styling** — Normalized all 4 disabled patterns (`.tf-shape-btn.disabled`, `.tf-clay-btn.unavailable`, `.tf-load-btn-disabled`, `.tf-preset-delete-disabled`) to consistent `opacity: 0.45` + `pointer-events: none` + `cursor: default`. | RCSS | Small | Low | 🤖 |

> **Context:** Three patterns to audit: `tf-load-btn-disabled` (rcss L839-847), `.unavailable`
> (rcss L620-630), and `.hidden` (display:none utility). Pick one semantic class (e.g., `.disabled`)
> with consistent `opacity` + `pointer-events: none` + desaturated color. Apply to all disable sites.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| C2 | ✅ | **Button height inconsistencies** — Verified: `.tf-lp-dist-btn` = 32dp (Distribution), `.tf-sm-btn` = 22dp (Small), both match token spec. Tracker values were stale. | RCSS | Trivial | Low | 🤖 |

> **Context:** Search rcss for `tf-lp-dist-btn` and `tf-sm-btn` height definitions. Reference the
> button height scale documented in rcss token block: Mode 54dp, Sub-mode 40dp, Compact 28dp,
> Distribution 32dp, Action 32dp, Env 36dp, Small 20dp. Normalize to nearest scale step.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| C3 | ✅ | **Remaining font size inconsistency** — Converted `16dp` → `1.5rem` (metal icon), `0.72rem` → `0.75rem` (clone segment keybind). All font sizes now use rem scale. | RCSS | Small | Low | 🤖 |

> **Context:** Phase 9 (#44) remapped `0.85rem→0.9rem`, `0.8rem→0.75rem`. Grep rcss + weather rcss
> for remaining `dp` font sizes (`10dp`, `11dp`). Convert to nearest rem stop: `0.75rem`, `0.9rem`,
> `1rem`. Check `body` `font-size` definition to confirm rem base.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| C4 | ✅ | **Hardcoded colors in `.ll-preset-item`** — Replaced: border `#40404a60` → `#55556040` (secondary token), hover bg `#2a2a1a` → `#2a2a0a` (accent), name color `#e0e0e0` → `#e5e7eb` (text-light), desc color `#888` → `#9ca3af` (muted). | RCSS | Small | Low | 🤖 |

> **Context:** Preset list styling at rcss L147-174. Compare hex values against the design token
> block (L11-87) and replace with matching token vars. If no token matches, add one to the block.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| C5 | ✅ | **Z-index overlap** — Bumped `.tf-noise-root`, `.tf-skybox-library-root`, `.tf-env-float-window` from 900 → 910. Main panel stays 900; light library already 910. | RCSS | Trivial | Low | 🤖 |

> **Context:** `.tf-root` at rcss L93, `.tf-noise-root` at rcss L103, both `z-index: 900`. Noise
> panel should layer above main panel. Bump noise to 910 or use a stacking token.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| C6 | ✅ | **Panel width mixed units** — Changed RCSS `.tf-root` from `15vw` → `162dp` to match Lua `BASE_WIDTH_DP`. Added comment noting Lua overrides width dynamically via `buildRootStyle()`. Sub-panels keep `15vw`. | RCSS + Lua | Small | Low | 🤖 |

> **Context:** `BASE_WIDTH_DP` used in widget for draw-/placement calculations. The rcss `width`
> controls the RML panel. These must agree. Decide: dp (fixed) or vw (responsive). If dp, set rcss
> `width: 162dp`. If vw, compute `BASE_WIDTH_DP` from `vsx` at runtime. Check how weather brush
> handles this: `gui_weather_brush.rcss`.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| C7 | ✅ | **Slider track fill** — Lua-side DOM injection approach. At init, iterates all `<input type="range">`, finds `slidertrack` child element, injects a `<div class="tf-slider-fill">` with absolute positioning. Change listeners + `syncAndFlash()` update fill width as percentage. Previous CSS-only box-shadow approach failed (RmlUI doesn't clip box-shadow with overflow:hidden). | RCSS + Lua | Low | Medium | 🤖 |

> **Context:** RmlUI slider structure: `<input type="range">` renders a track + thumb. RmlUI docs:
> `recoil-lua-library/library/generated/rts/Rml/SolLua/bind/ElementForm.cpp.lua`. RCSS pseudo-elements
> for range: `slidertrack`, `sliderbar`, `sliderarrowdec`, `sliderarrowinc`. However RmlUI may not
> support `::fill` pseudo — check engine source or test with `sliderbar` background gradient.
> **Alternative:** Lua-side: on each `change` event, set a `style.background` gradient on the track
> element proportional to value. See Material Design 3 slider spec for visual reference.
> **External ref:** Blender's property sliders use filled tracks; Unreal's Detail panels do too.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| C8 | ✅ | **Consistent 4dp spacing grid** — Normalized 12 off-grid values: `1dp 5dp` → `2dp 4dp`, `6dp` margins → `8dp`, `3dp` gaps/margins → `4dp`, `5dp 7dp` padding → `4dp 8dp`, `10dp` padding → `8dp`, `5dp` margin → `4dp`. Structural values (slider thumb centering) preserved. | RCSS | Low | Low | 🤖 |

> **Context:** Phase 9 (#45) normalized section headings to `mt-2` (8dp). Grep rcss for `margin`,
> `padding`, `gap` values not on 4dp multiples. Also check rml inline `style` attributes and utility
> classes (`mt-1`, `mt-1-5`, `mt-2`, etc.) defined in rcss. Target: 4, 8, 12, 16, 24dp only.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| C9 | ✅ | **Unified active-state indicator** — Added consistent `box-shadow` glow to all 38 active button states that lacked one. Mode buttons: `6dp 1dp #ffffff18`; sub-mode/toggle buttons: `5dp 0dp #ffffff18`. Buttons with themed glows (`.tf-shape-btn`, `.tf-clay-btn`, `.tf-cl-toggle`) retained their existing colored glows. | RCSS | Low | Medium | 🤖 |

> **Context:** Search rcss for `.active`, `:active`, `.selected` classes on button types. Terrain
> mode buttons have per-mode `.raise-active`, `.lower-active` etc. Tools/Shape use generic green.
> Design decision: keep mode colors for the keybind badge pill but use ONE glow color (e.g., white
> or the Phase 9 accent `#fbbf24`) for the button border/bg active state.
> **External ref:** Unity Inspector uses uniform blue selection; Blender uses consistent accent.

### D. Feedback & Readouts

> UX14 (status summary line) would subsume D2 and partially D1 — implement together or UX14 first.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| D1 | ✅ | **Velocity-intensity live readout** — `velocity-factor-label` shows ×N.N when enabled; `dragVelocityFactor` added to `getState()`. Also shown in D4 summary. | widget + RML | Small | Medium | 🤖 |

> **Context:** `velocityIntensity` flag at widget L279, `dragVelocityFactor` computed at widget L438.
> The factor value is calculated each frame during drag. Surface it: add a small label element in rml
> near the velocity checkbox, update its `inner_rml` from the widget's `DrawScreen()` or via
> `WG.TerraformBrush_SetUIValue()` callback. Pattern: see how `restoreStrength` is wired (D2).

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| D2 | ✅ | **Restore strength live readout** — `restore-strength-label` in rml L924, updated live via Lua L3417. Shows percentage. | widget + RML | Trivial | Medium | 🤖 |

> **Context:** `restoreStrength` at widget L285 in `extraState`. Value range 0.0-1.0. Widget sets
> it but no UI element displays it. Add a readout element in rml near the Restore mode UI, update
> from `DrawScreen()`. Pattern: identical to how `brushRadius` is shown next to the size slider.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| D3 | ✅ | **RMB temporary-lower mode echo** — now echoes on RMB press and restore on release. | widget | Trivial | Low | 🤖 |

> **Context:** RMB press handler at widget L2559-L2591: sets `savedModeBeforeRMB` and switches to
> Lower. Other mode switches probably call `Spring.Echo()`. Add the same echo here. Search widget
> for `Echo` to see the existing pattern for mode-switch announcements.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| D4 | ✅ | **Contextual status summary line** — `#status-summary` div below header shows `MODE · Shape · R:N · Int:N · Crv:N` with optional Vel/Str suffixes. Clears for non-terraform modes. | RML + Lua | Low | Medium | 🤖 |

> **Context:** Add a `<div>` at the top of `.tf-root` in rml with `id="status-summary"`. In RML UI
> Lua, build a string from current mode, shape, radius, intensity, curve values on every param
> change callback. Use `element.inner_rml = summaryString`. State vars are all in widget top-level
> locals (L250-290) and `extraState`. Separator style: see Photoshop's brush tooltip bar.
> **External ref:** Photoshop Options Bar, Blender header active-tool summary.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| D5 | ✅ | **Cursor-anchored value HUD** — `extraState.paramHudText` + `paramHudTimer` (1.5s). `extraState.setParamHud(text)` called from `MouseWheel` on every param change (radius, intensity, curve, rotation, length, ring-width, protractor spoke). Rendered in `DrawScreenEffects` via `gl.Text` at cursor + (20,6)px offset; shadow pass + white pass; alpha fades over final 0.35s. Suppressed when `paramHudTimer ≤ 0`. All state in `extraState` table (no new chunk locals). | widget | Small | High | 🤖 |

### E. Axis-Lock (Shift-Constrain)

> Items are tightly coupled — implement as one unit.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| E1 | ✅ | **Screen-space axis-lock threshold** — Threshold now 25 screen-pixels via `WorldToScreenCoords`. Zoom-independent. | widget ~L369 | Small | High | 🤖 |

> **Context:** `AXIS_LOCK_THRESHOLD = 16` at widget L367. Used in `constrainToAxis()` at L394-L419.
> The threshold is in world-space elmos — at high zoom it's huge, at low zoom it's sub-pixel.
> Fix: use `Spring.WorldToScreenCoords()` to convert to screen pixels, then apply a pixel-space
> threshold (~20-30px). Engine API: `recoil-lua-library/library/Spring.lua` → WorldToScreenCoords.
> **External ref:** Photoshop Shift-constrain uses ~5px screen threshold. Figma uses 3px.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| E2 | ✅ | **Mid-drag axis switch** — Once locked, axis flips when new axis exceeds 2× threshold AND 2× ratio over current axis. Hysteresis prevents flickering. | widget ~L403-440 | Small | High | 🤖 |

> **Context:** Same `constrainToAxis()` function. Currently once `shiftState.lockAxis` is set to
> `"x"` or `"z"`, it stays until Shift is released. Fix: track rolling displacement over last N
> samples; if dominant axis flips with sufficient delta, update `lockAxis`. Keep a small hysteresis
> zone to prevent flickering. Photoshop does NOT support mid-drag axis switch (it locks on first
> movement) — this would be a UX improvement beyond industry standard.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| E3 | ⬜ | **No 45° diagonal constraint** — only X/Z. Add diagonal (X+Z, X-Z) for ramps/trenches. | widget ~L399-417 | Medium | Medium | 🧠 |

> **Context:** Same axis-lock block. Currently constrains to axis-aligned only. Add detection for
> |dx| ≈ |dz| → lock to nearest diagonal. Constrain point: project onto the 45° line through origin.
> **Design decision:** How to activate — auto-detect from angle, or require modifier (e.g., Ctrl+Shift)?
> How to visualize — draw a diagonal guide line? What snap angles: just 45° or 30°/60° too?
> **External ref:** AutoCAD ortho mode + polar tracking; SketchUp axis inference.

### F. Layout & Progressive Disclosure

> **Core UX win.** UX1/UX3 from the original analysis were the same idea — merged here.
> Implementing F1 naturally cleans up B1 (dead toggles hidden), and partially addresses D1/D2
> (mode-relevant readouts only shown in their modes).

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| F1 | ⬜ | **Mode-specific control visibility** — Each terrain mode shows only its relevant controls: Level hides Curve/Length; Restore shows Restore% prominently; Ramp shows Length+Rotation; Noise shows noise params. Non-essential controls behind "Advanced ▸" expander. *(Merged: old UX1 + UX3.)* | RML + Lua | Medium | High | 🧠 |

> **Context:** Mode switch is handled in widget — search for `setMode` or `activeMode`. The RML UI
> Lua already toggles noise panel visibility on mode change (see `envActive` at RML UI Lua L193,
> L490-510 — similar pattern). Extend this: define a table mapping each mode to visible section IDs,
> then in the mode-change handler call `SetClass("hidden", true/false)` on each section.
> **Prerequisite:** Decide the mapping table (which controls per mode). Suggested:
> - **Raise/Lower:** Shape, Radius, Curve, Intensity, Height Cap (collapsed)
> - **Level:** Shape, Radius, Intensity (Curve forced to 5.0 — hide slider, show note)
> - **Ramp:** Shape (circle/square only), Radius, Length, Rotation, Clay
> - **Restore:** Shape, Radius, Curve, Restore%, Intensity
> - **Noise:** Shape, Radius, Curve, Intensity + Noise sub-panel (already done)
> **External ref:** Photoshop tool options bar changes per tool. Unity terrain brush inspector
> shows different params per PaintMode. Blender sculpt tool options vary per brush type.
> **Caution:** J1 (200-local limit). Any new locals needed for section refs must go in `extraState`.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| F2 | ⬜ | **Visual grouping with bounded regions** — Group controls into Brush Shape ∣ Parameters ∣ Height Constraints ∣ Presets with subtle background differentiation. Section headers with distinct weight. | RCSS + RML | Low | High | 🤖 |

> **Context:** The rml already has some section dividers (headings like TERRAIN, SHAPE, etc.). Add
> wrapper `<div class="tf-section-group">` around each logical group. In rcss, add:
> `.tf-section-group { background: var(--surface-raised); border-radius: 4dp; padding: 4dp; margin-bottom: 4dp; }`
> Use the existing design tokens at rcss L11-87 for colors. Section headers: bump to `1rem` weight
> or add a 2dp left accent bar via `border-left`.
> **External ref:** Material Design 3 "card" grouping; Apple HIG "grouped list" style.
> Existing pattern: the collapsible sections from #48 already group HEIGHT CAP, etc.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| F3 | ✅ | **Collapsible display-options section** — OVERLAYS renamed to DISPLAY (default closed). Velocity (`~Velocity`) and Falloff Show (`btn-curve-overlay`) chips moved into this section from their inline slider rows. INSTRUMENTS also defaults closed. `warningToggle` tracking extended to include both chips. | RML + Lua | Low | Medium | 🤖 |

> **Context:** The collapsible pattern was just implemented in #48 for HEIGHT CAP, SMART FILTER,
> PRESETS. Read the implementation: search rml for `btn-toggle-` (e.g., `btn-toggle-presets` at rml
> L514-528) and the corresponding click handler in RML UI Lua that toggles a `section-*` element's
> `hidden` class. Replicate for a new `section-display-options` wrapping the 6 checkbox toggles
> (Grid Overlay, Grid Snap, Dust Effects, Height Colormap, Curve Overlay, Velocity Intensity).
> Set `hidden` by default. Store open/closed state in `extraState` for persistence.

### G. Power User Features

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| G1 | ❌ | **Brush shape preview widget** — Cancelled (out of scope). | RML + Lua + GL | Medium | High | 🧠 |

> **Context:** The widget already computes per-vertex falloff heights for brush rendering — see
> `DrawScreen()` in widget and the display list cache (`isDrawCacheValid()`). A preview widget
> would render a top-down 2D version into a small area. Two approaches:
> 1. **GL render to texture** — use `gl.RenderToTexture()` to draw the falloff as a grayscale
>    image into an FBO, then display as `background-image` on an RML `<img>` element. Engine API:
>    `recoil-lua-library/library/generated/rts/Lua/LuaOpenGL.cpp.lua` → RenderToTexture, Texture.
> 2. **Canvas-style in DrawScreen** — draw directly at a fixed screen position overlapping the panel.
>    Simpler but doesn't integrate with RML layout.
> **External ref:** Photoshop Brush Settings preview panel; Blender sculpt brush falloff curve;
> GIMP brush editor preview; Krita brush tip visualization.
> **Design decision:** Top-down (plan view) or side-profile (cross-section)? Or both?

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| G2 | ✅ | **Numbox input affordance** — Enter-to-confirm via `keydown` + `KEY_RETURN`, blur-to-apply, `SDLStartTextInput` on focus, `:focus` border styling. Wired generically via `attachSliderInputBoxes()`. | RCSS + Lua | Low | Medium | 🤖 |

> **Context:** Numbox elements are `<input type="text">` siblings to the `<input type="range">`
> sliders. The RCSS styling is generic input styling. Add `:hover` border rule. For keyboard entry:
> RML UI Lua event handlers on these inputs likely already handle `blur`/`change` — search for
> `numbox` or the input IDs. Add `keydown` handler to commit on Enter key.
> RmlUI input events: `recoil-lua-library/library/generated/rts/Rml/SolLua/bind/Element.cpp.lua`.
> **External ref:** Any DAW parameter input (Ableton, FL Studio) — subtle box on hover, direct entry.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| G3 | ✅ | **Shortcut discoverability tips** — Toast after 3+ mouse interactions: "Tip: use Space+Scroll for intensity." Hover tooltips on shortcut labels. | Lua | Medium | High | 🧠 |

> **Context:** Need an interaction counter per slider (e.g., `extraState.sliderDragCounts = {}`).
> Increment in the slider `change` handler. When count hits threshold, show toast. Toast rendering:
> see `luaui/Widgets/snd_notifications.lua` for BAR's existing notification/toast system — check if
> it exposes an API via `WG.notifications` or similar. If not, draw via `gl.Text()` in `DrawScreen()`
> with a timed fade-out. Hover tooltips: RmlUI supports `title` attribute on elements for native
> tooltips, or use a custom tooltip div shown on `:hover` via RCSS.
> **Design decision:** Toast position (near slider? top of panel? near cursor?), duration, frequency
> cap (show once per session? once ever? store in config?).
> **External ref:** VS Code "Did You Know" tips; Figma's contextual shortcut hints.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| G4 | ✅ | **Ramp-to-measure auto-chain** — After every ramp stroke (spline or straight), a persistent amber-colored chain is auto-added to the measure layer. Visible whenever Measure is active. Endpoint or bezier-handle drag in measure mode **re-applies the ramp** at the new path using stored radius/clay. New in measure toolbar: `Auto Ramp` toggle chip and `Clear Ramps` button. `rampAutoAttach` exposed via `WG.TerraformBrush`. Widget: `extraState.attachRampChain`, `extraState.reapplyRampChain`, `extraState.tessellateRampChain`. | widget + RML + Lua | Medium | High | 🤖 |

> **Context:** Constants at widget L302-L303: `SPLINE_SAMPLE_DIST = 24`, `SPLINE_MAX_POINTS = 40`.
> Used in ramp spline collection during drag. Move these into `extraState` as configurable values.
> Add sliders to the rml in the ramp-mode section (or Advanced expander). Wire via same pattern as
> other slider params. Consider sensible ranges: SAMPLE_DIST 8-64, MAX_POINTS 10-100.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| G5 | ✅ | **Keybind badges from actual bindings** — Badges now read from configurable keybind system. `BADGE_ACTION_MAP` maps button IDs to keybind actions; `initBadgeElements()` + `updateAllKeybindBadges()` refresh on init and after settings changes. Custom keybind config persisted to `Terraform Brush/keybinds.lua`. Settings window with keybind editor (gear button in header) allows rebinding, save/restore defaults/apply/cancel. | RML + Lua + Widget | Medium | Low | 🤖 |

> **Context:** Keybind badge text is hardcoded in rml as inner text on badge elements (e.g., "C",
> "S", "H", "O" for shapes). To read actual bindings: `Spring.GetKeyBindings(action)` returns the
> bound keys for a given action name. Engine API:
> `recoil-lua-library/library/Spring.lua` → GetKeyBindings. First, identify what action names the
> terraform brush registers — search widget for `Spring.SetAction` or `widgetHandler:AddAction`.
> Then in RML UI Lua init, query bindings and set badge text dynamically.
> **Complexity:** BAR keybind system may use `uikeys.txt` — check `luaui/` for keybind registration
> patterns. Other widgets that do this: search for `GetKeyBindings` across all widget files.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| G6 | ⬜ | **Undo timeline action descriptions** — Hover tooltip on undo slider positions: "Undo: Raise terrain at 1024,512." | Lua + Gadget | Medium | Medium | 🧠 |

> **Context:** Undo/redo stacks in gadget at L55-L56. Currently stores only vertex snapshots. To
> add descriptions: modify `pushSnapshot()` (gadget L234+) to also store an action label string
> (mode name + center coords). Send the label back to the widget via `RecvFromSynced()` (gadget
> L16-L19) alongside the stack counts. The widget/RML UI already has an undo slider — search rml
> for `undo` or `history` to find the slider, then add a `title` attribute or tooltip div.
> **Complexity:** Requires gadget-side changes + protocol extension. The `SendToUnsynced()` →
> `RecvFromSynced()` pathway carries `TerraformBrushStackUpdate` messages — extend that format.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| G7 | ✅ | **Preset browser with previews** — Each row in the dropdown now shows a 2-line layout: preset name + delete on line 1, compact param summary on line 2 (`Raise · Circle · R:80 · I:2.5 · Apr 13`). `savedAt = os.time()` persisted to preset file on save; date shown for user presets. `WG.TerraformBrush.getPreset(name)` API added. RCSS: `.tf-preset-row` → column flex; new `.tf-preset-row-top` (name+delete row) and `.tf-preset-summary` (0.75rem muted text). | widget + RML + RCSS | Medium | Medium | 🤖 |

> **Context:** Preset system: `loadPresetsFromDisk()` at widget L688, `savePresetAs()` at L750-792,
> browse dropdown at rml L514-528 (`preset-dropdown`). Presets are stored as plaintext files in the
> Spring write directory. To add previews: on hover over a dropdown item, read the preset file,
> parse its params, and show a summary tooltip. For thumbnails: would need to save a small screenshot
> at preset-save time via `gl.SaveImage()`. For last-modified: use `VFS.GetFileAbsolutePath()` +
> `os.time` or `Spring.GetFileModifiedTime()` if available.
> VFS API: `recoil-lua-library/library/generated/rts/Lua/LuaVFS.cpp.lua`.
> **External ref:** Blender preset browser; Substance Painter smart material previews.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| G8 | ✅ | **Tool-specific cursor shapes** — Mode glyphs drawn via `gl.Text` near cursor in `DrawScreenEffects`: Raise=↑, Lower=↓, Level=─, Ramp=/, Restore=↺, Noise=~. Color-coded per mode via `getModeRGB()`. Shadow layer for readability. Suppressed during measure-drawing mode. Persists in F5 (hidden UI) mode. `extraState.modeGlyphs` table added (no new chunk-level locals). | widget | Low | Medium | 🤖 |

> **Context:** BAR's cursor system: `luaui/Widgets/gui_cursor.lua`. Check how it renders custom
> cursors — likely uses `Spring.SetMouseCursor(cursorName)` or gl draws. Also see `anims/` directory
> for cursor animation frames and `anims/cursornormal.txt` for the format.
> Spring API: `Spring.AssignMouseCursor(name, filename)` and `Spring.SetMouseCursor(name)`.
> Simplest: draw a small glyph via `gl.Text()` near cursor in `DrawScreen()` without replacing the
> actual cursor. More polished: create cursor image files in `anims/` per mode.
> **External ref:** Blender sculpt mode cursor icons; Photoshop tool-specific cursors.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| G9 | ✅ | **Grass brush pipette (color picker)** — Click terrain to sample diffuse color for texture filter. Re-implemented using proven 1x1 FBO single-point method (same as gui_terraform_brush.lua splat sampler). `sampleDiffuseAtPoint(wx,wz)` queued in `MousePress`, executed in `DrawWorld` GL context. COLOR FILTER section added to grass panel: toggle checkbox, color swatch (live background-color update), PICK button, Tolerance slider (0–150), Edge Pad slider (0–200). | cmd_grass_brush + RML + RCSS + gui_terraform_brush.lua | Medium | High | 🤖 |

> **Context:** Multiple implementation attempts failed:
> 1. NxN FBO batch render + batch ReadPixels — distortion increasing from center (TexRect region mapping unreliable)
> 2. Per-cell inside single RenderToTexture — mirror/axis issues persisted
> 3. Per-cell with individual RenderToTexture calls — still mirrored
> The 1x1 single-point formula (`u=wx/msX, v=1-wz/msZ, TexRect(-1,-1,1,1,u,v,u,v)`) works correctly
> in `gui_terraform_brush.lua` splat sampler for individual samples, but the grid cache approach has
> unresolved mapping problems when rendering many cells per frame.
> **Possible approaches to investigate:**
> - Use `Spring.GetGroundDiffuseColor(x,z)` if available in Recoil engine (eliminates FBO entirely)
> - Use `gl.SaveImage` to dump `$minimap` to disk once, load as regular texture, sample via ReadPixels
> - Render `$minimap` to a large FBO once at widget init, use that as a stable lookup texture
> - Investigate whether the engine's `gl.ReadPixels` on `$minimap` directly (without FBO) works
> **UI was in:** rml btn-gb-pipette, rcss pipette styles, lua startPipette/processPipetteSample.
> All removed; re-add when sampling approach is proven reliable.

### H. Environment Panel Redesign

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| H1 | ⬜ | **Dockable/accordion environment panels** — Replace 7+ chaotic floating windows with single scrollable inspector panel. Collapsible sections per env category (Sun, Fog, Ground, Unit, Map, Water). *(Supersedes old #40.)* | RML + Lua | High | High | 🧠 |

> **Context:** Current env panels at rml: 6 floating `<div>` roots (L1609-L2176) each with absolute
> positioning and independent toggle logic in RML UI Lua (L490-510). The env toggling reads from
> `envWindowToggle()` in RML UI Lua.
> **Approach:** Replace all 6 floating roots with a single `<div id="tf-env-inspector">` containing
> collapsible `<div>` sections (reuse the #48 collapse pattern). Each section header is a clickable
> bar that toggles its body. The inspector panel itself can be a fixed-position right sidebar or
> overlay. Move all slider/button content from the 6 floating divs into the sections.
> **Key concern:** This is a large RML restructure. Wire env window buttons to scroll-to-section
> instead of toggle-window. Keep all existing event listener IDs so Lua handlers don't break.
> Reference existing env control API: see `/memories/repo/bar_environment_settings_api.md` for the
> full Spring API surface. Also see `gui_options.lua` for how BAR's main settings widget organizes
> similar env controls (scrollable panel with sections).
> **External ref:** Unity Inspector (collapsible component sections); Unreal Details panel; Godot
> Inspector. The Clone Windows doc (`doc/TerraformBrush_CloneWindows.md`) documents why the
> multi-window approach was problematic — read for pitfalls to avoid.

### I. Minor Robustness Fixes

> All trivial, all agent-automatable. Batch in one session.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| I1 | ✅ | **`gl.GetSun()` nil check** — added `or 0` fallbacks to all direct calls in envDefaults init (L955-961, L968-969), lightingSlider onChange, and sun intensity slider. | RML UI Lua | Trivial | Low | 🤖 |

> **Context:** `getSunColor()` wrapper at RML UI Lua L344-349. Called to populate defaults table.
> If `gl.GetSun("ambient")` returns nil (e.g., called before map init), the table stores nil values
> which later cause arithmetic errors. Fix: add `or {0,0,0}` fallback after each `gl.GetSun()` call.
> Full API: see `/memories/repo/bar_environment_settings_api.md` for all `gl.GetSun()` variants.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| I2 | ✅ | **Guide mode `currentHint` not cleared** on toggle-off — added `lastRenderedHint = nil` and `floatingTipEl.inner_rml = ""` cleanup. | RML UI Lua | Trivial | Low | 🤖 |

> **Context:** `guideMode` flag at RML UI Lua L129, `currentHint` at L131. Search for the
> guide-toggle handler (likely a button click setting `guideMode = false`). Add
> `currentHint = nil; floatingTipEl.inner_rml = ""` in the off-branch.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| I3 | ✅ | **Skybox texture error feedback** — added `VFS.FileExists()` check + `Spring.Echo` warning in `applySkybox()`. | RML UI Lua | Trivial | Low | 🤖 |

> **Context:** Search RML UI Lua for `skybox` or `SetAtmosphere.*skyBox`. When setting a skybox
> path, if `VFS.FileExists(path)` is false, show a warning. Use `Spring.Echo()` for console
> feedback or set an error class on the skybox input element.
> VFS API: `recoil-lua-library/library/generated/rts/Lua/LuaVFS.cpp.lua` → FileExists.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| I4 | ✅ | **Skybox fade transition** — verified active. State machine at RML UI Lua L285-310 (`skyFade` object, phases `fadeout`→`fadein`→`idle`, speed 3.0 ≈ 0.33s). `tickSkyboxFade(dt)` at L457 drives transitions; called from main update loop at L7577. Lighting dims via `setSunColorScaled()` at L463 during fadeout, texture swap at midpoint. | Verified functional | RML UI Lua | Small | Low | 🧠 |

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| I5 | ✅ | **Redo stack unbounded** — verified: already capped at `MAX_UNDO` (L1178) + `evictOldSnapshots()` covers redo. | gadget | Trivial | Low | 🤖 |

> **Context:** `MAX_UNDO = 400` at gadget L52. `undoStack` and `redoStack` at L55-56.
> `evictOldSnapshots()` at L197-213 handles eviction but check if it covers redo. If not, add
> `while #redoStack > MAX_UNDO do table.remove(redoStack, 1) end` in the same eviction path.
> Also check `MAX_SNAPSHOT_VERTICES` (L53, 4M) — redo entries count toward the vertex budget.

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| I6 | ⬜ | **Undo split on large drags** — `MAX_MERGE_VERTICES = 40000` silently splits single drags. Surface feedback or raise limit. | gadget | Small | Medium | 🧠 |

> **Context:** `MAX_MERGE_VERTICES = 40000` at gadget L65. Used in `pushSnapshot()` (L234+) — when
> a merge exceeds this count, a new undo entry is started. The user experiences this as "undo only
> goes back partway through my drag." Options: (a) raise the limit (costs more memory per undo slot),
> (b) expose the split to the UI so the user knows, (c) add a "macro undo" concept that groups all
> sub-entries from one drag. Option (c) is most complex but best UX.
> **Design decision:** Raising to 80000 is simple and may be sufficient. True "macro undo" needs a
> drag-session-ID sent from widget to gadget to group entries.

### J. Architecture / Tech Debt

> Not user-facing but blocks future feature work. Effort here is ongoing overhead, not one-shot.

| # | Status | Issue | Notes | Urgency |
|---|--------|-------|-------|---------|
| J1 | ✅ | **200-local limit mitigations landed** — IIFE fix brought chunk to 162/200; per-tool split (J2) moved most state into module-local scope. `extraState` table pattern + `do...end` scoping documented. | Constraint still applies to future work but no current file is at limit. See `/memories/bar_lua_constraints.md`. | Ongoing discipline, not blocking |

> **Context:** Run `python tools/count_locals.py <file>` to check current counts. Widget chunk is at
> the limit — verified. RML UI Lua `attachEventListeners()` section is similarly constrained.
> **Mitigation patterns already in use:** `extraState` table (widget L283+), `do...end` blocks in
> RML UI Lua to scope temporaries. See `/memories/bar_lua_constraints.md` for full constraints doc.
> Strategies: (a) consolidate related locals into tables, (b) `do...end` for any new control wiring,
> (c) for widget, move helper functions to a separate require'd module (J2).

| # | Status | Issue | Notes | Urgency |
|---|--------|-------|-------|---------|
| J2 | ✅ | **Monolithic RML UI Lua split** — Plan P0.2 completed. 12 per-tool modules extracted (`tf_metal.lua`, `tf_grass.lua`, `tf_splat.lua`, `tf_decals.lua`, `tf_weather.lua`, `tf_environment.lua`, `tf_lights.lua`, `tf_startpos.lua`, `tf_clone.lua`, `tf_settings.lua`, `tf_features.lua`, `tf_guide.lua`). Main `gui_terraform_brush.lua` reduced 12,595→~5,600 lines. | Each module exposes `M.attach(doc, ctx)` + `M.sync(doc, ctx, state, setSummary)`; shared helpers live on `ctx` in main widget. | Done 2026-04-20 |

| # | Status | Issue | Notes | Urgency |
|---|--------|-------|-------|---------|
| J3 | ⬜ | **Falloff curve rendering unoptimized** — 1000+ GL calls/frame with curveOverlay on large brushes. | Batch into single drawcall or compute offset in shader. | Low (perf only, niche scenario) |

> **Context:** Falloff rendering is in widget's `DrawScreen()` — search for `curveOverlay` or
> `falloff`. Each vertex of the arc + curtain is a separate `gl.Vertex()` call inside a
> `gl.BeginEnd()` block. For large brushes (radius 2000, 64 segments), this is 1000+ calls.
> **Optimization approaches:** (a) Use `gl.Shape()` with a pre-built vertex array (fewer Lua→C
> crossings), (b) use a GL4 VBO via `gl.GetVBO()` — see `luaui/Widgets/` for VBO examples (grep
> `GetVBO`), (c) render every-other vertex for radii > 500.
> Engine GL API: `recoil-lua-library/library/generated/rts/Lua/LuaOpenGL.cpp.lua`.

### K. Aspirational (Stretch Goals)

| # | Status | Issue | File | Effort | Impact | Auto |
|---|--------|-------|------|--------|--------|------|
| K1 | ⬜ | **PIN bar as customizable quick-access** — Drag presets to 8 PIN slots for one-click recall. | RML + Lua | Medium | Medium | 🧠 |

### L. Release Readiness

| # | Status | Issue | Notes | Effort | Impact | Auto |
|---|--------|-------|-------|--------|--------|------|
| L1 | ⬜ | **Smoke test all tools** — Systematically activate each tool (terraform modes, metal, grass, splat, decals, weather, env, lights, startpos, clone) and verify basic operations: place, undo, save/load, mode switching, slider interactions. | Test matrix needed — one row per tool × operation. | Medium | Critical | 🧠 |
| L2 | ⬜ | **Config persistence audit** — Verify all tool settings survive widget reload: keybinds, presets, display toggles, last-used tool/mode, slider positions. Some newer tools (startpos, clone, lights) may not persist state yet. | Check `widget:GetConfigData()` / `SetConfigData()` coverage per tool. | Small | High | 🤖 |
| L3 | ⬜ | **README / first-run experience** — Brief "Getting Started" section: what each tool row does, how to access env panel, where skyboxes go, key shortcuts overview, link to Discord #mapping. | Target: `doc/TerraformBrush.md` or in-panel guide mode improvements. | Small | High | 🧠 |
| L4 | ⬜ | **Error handling at boundaries** — Audit all `WG.ToolName` API calls for nil guards. Newer tools (clone, startpos, lights) may lack `WG.X and WG.X.method()` protection. Also check gadget `RecvLuaMsg` for malformed message resilience. | Grep for unguarded `WG.` calls in RML UI Lua + widget. | Small | Medium | 🤖 |

> **Context:** The PIN row is mentioned in design docs but may not exist in rml yet — search rml for
> `pin` or 8 slot elements. If not present, create a `<div class="tf-pin-bar">` with 8 child `<div>`
> slots. Each slot stores a preset name. On click, call `loadPreset(slotPresetName)` (widget L794).
> Drag-to-assign: use `mousedown`/`mouseup` events on preset list items + slot elements; track
> drag state in `extraState`.
> **External ref:** Photoshop Tool Presets; Blender Quick Favorites (Q menu); DAW macro pads.

---

## Recommended Execution Order

> Grouped into batches that can be done concurrently. Each batch targets a coherent theme.

### Batch 1 — Quick Wins (all 🤖, ~1 session) ✅ DONE 2026-04-08
`A1` `A2` `B1` `B2` `B3` `B4` `I1` `I2` `I3` `I4` `I5`
> All 11 items completed or verified. B3 (splat export format) confirmed fully wired. B4, I4, I5 were already resolved (verified). 7 code changes applied, 4 verified-as-done.

### Batch 2 — RCSS Consistency Pass (all 🤖, ~1 session) ✅ DONE 2026-04-11
`C1` `C2` `C3` `C4` `C5` `C6` `C7` `C8` `C9`
> 9 of 9 items completed. C2 verified correct. C7 reimplemented with Lua-side DOM injection after CSS box-shadow approach failed.

### Batch 3 — Feedback & Axis-Lock (~1-2 sessions) ✅ DONE 2026-04-11
`D1` `D2` `D3` `D4` · `E1` `E2`
> 5 of 5 remaining items completed (D2 was already done). D1: velocity-factor readout label + getState field. D3: RMB echo on press/release. D4: status summary bar below header. E1: screen-space axis threshold via WorldToScreenCoords. E2: mid-drag axis switch with 2× hysteresis.

### Batch 3.5 — Major Restructure + New Tools ✅ DONE 2026-04-12
`N1` `N2` `N3` `N4` `N5` `N6` `N7` `N8`
> 8 new features in the major restructure commit. Full UI restructure (TERRAIN + TOOLS rows). Noise elevated to a real terrain mode. Start Positions tool and Clone tool added. UI sounds + mute toggle. Passthrough mode. Slider wheel-lock. Ring inner-ratio scroll. Gadget: MAX_UNDO 100→400, MAX_SNAPSHOT_VERTICES 500K→4M, numeric vertex keys, scratch tables for GC reduction.

### Batch 4 — Layout Restructure (🧠, needs design spec first)
`F1` `F2` `F3`
> The biggest UX win. F1 (mode-specific controls) needs a mapping table designed first:
> which controls are visible in which mode. F2 and F3 are supportive layout work.

### Batch 5 — Power User Features (mix, pick from backlog)
`G3` `G6` then `G5` `G9`
> G3 (tips) is remaining highest impact. G5/G6/G9 are medium. G4 done. G1 cancelled.

### Batch 6 — Big Projects (🧠, separate planning)
`H1` (env panel redesign) · `E3` (diagonal constraint) · `D5` (cursor HUD) · `K1` (PIN bar)
> Each is a standalone feature needing its own design. H1 is the largest remaining item.

### Ongoing
`J1` `J2` `J3` — tech debt addressed opportunistically as features touch affected code.

---

## Status Summary

> Updated: 2026-04-22
> Last audit: 2026-04-22 — Plan Phase 3 grayouts (P3.0–P3.2) wired across all 10 tools; extends C1 disabled styling with state-aware `ctx.setDisabled`/`setDisabledIds` per-tool sync (see `TerraformBrush_1.0_Plan.md` § P3.2 Implementation Notes). P3.3 (guide-mode "why disabled") + P3.4 (regression pass) pending.
> Previous: 2026-04-15 — F3 (display-options), G1 (cancelled), G4 (ramp measure chains) implemented

| Category | Remaining | Done | Notes |
|----------|-----------|------|-------|
| Bug Fixes (A) | 0 | 2 | All fixed |
| Dead Code (B) | 0 | 4 | B3 verified wired; all closed |
| RCSS Consistency (C) | 0 | 9 | Batch 2 complete |
| Feedback & Readouts (D) | 0 | 5 | D5 cursor HUD implemented |
| Axis-Lock (E) | 1 | 2 | E3 (diagonal constraint) remains |
| Layout (F) | 2 | 1 | F3 done; F1/F2 need design spec |
| Power User (G) | 1 | 7 | G2/G3/G4/G5/G7/G8/G9 done; G1 cancelled; G6 remaining |
| Env Panel (H) | 1 | 0 | H1 is largest item |
| Minor Robustness (I) | 1 | 5 | I4 verified active; I6 remains |
| Architecture (J) | 1 | 2 | J1 mitigated (IIFE + split), J2 done (P0.2 12-module extract); J3 perf remains |
| Aspirational (K) | 1 | 0 | Stretch |
| Release Readiness (L) | 4 | 0 | Smoke test, persistence, README, error handling |
| **Total** | **13** | **36** | **+38 archived** |
