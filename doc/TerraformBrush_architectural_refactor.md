# Plan: RmlUi PR Architectural Refactor Before 1.0
## Scope

**IN** — four "new" widgets + context manager:
- `luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.lua` (CRITICAL, ~4200 LOC, 80+ DOM pokes, 30+ `AddEventListener`, own drag+snap)
- `luaui/RmlWidgets/gui_feature_placer/gui_feature_placer.lua` (imperative list build, reads `WG.TerraformBrushPanel`)
- `luaui/RmlWidgets/gui_weather_brush/gui_weather_brush.lua` (own drag, reads `WG` mirror)
- `luaui/RmlWidgets/gui_decal_placer/gui_decal_placer.lua` (same)
- `luaui/RmlWidgets/rml_context_manager.lua` (lightweight accessor only)

**OUT** — `cmd_terraform_brush.lua` widget + gadget, pre-existing widgets, theming system (reviewer owns), widget selector/options, context-manager document-retrieval/theme work (lands with reviewer's branch).

## Baseline findings (from deep code audit)

| Widget | LOC | GetElementById | AddEventListener | SetAttribute | inner_rml | SetClass | OpenDataModel? | WG pos mirror? | Theme imports |
|---|---|---|---|---|---|---|---|---|---|
| gui_terraform_brush | ~4200 → **split across 12 modules** | 80+ → **~20 remaining** | 30+ → **~0 in attach** | 50+ | 40+ | 50+ | YES (7 fields) | YES (writes) | YES (4 files) |
| gui_feature_placer | ~900 | 25+ | 15+ | 10+ | 10+ | 15+ | NO | YES (reads) | YES |
| gui_weather_brush | ~330 | 12+ | 10+ | 8+ | 5+ | 5+ | YES (partial) | YES (reads) | YES |
| gui_decal_placer | ~700 | 20+ | 15+ | 12+ | 8+ | 8+ | NO | YES (reads) | YES |

`rml_context_manager.lua` today: 46 LOC, manages shared context + DP_RATIO on ViewResize. No public API surface — widgets re-derive scale independently with their own `BASE_RESOLUTION = 1920` math.

Cross-widget positional mirror: `gui_terraform_brush` writes `WG.TerraformBrushPanel = {left,top,width,height}`; weather/feature/decal read it back for edge-snap. Four near-identical drag+snap loops scattered across widgets.

## Progress (April 2026)

### Adopted pattern: widget-method onclick/onchange (intermediate; superseded by model-king after PR #7527 review)

First-pass pattern that landed in tf_* sub-modules:

- **RML**: every static button gets `onclick="widget:methodName()"` (or `onclick="widget:method('arg')"` for parameterised calls); every slider gets `onchange="widget:onXxxChange(element); event:StopPropagation()"`.
- **Lua**: each per-tool module (`M.attach`) registers methods on `ctx.widget` (e.g. `w.fpSetMode`, `w.dcRotCW`). `ctx.widget` is the live widget table set before any `.attach()` call.
- **Active-state** still set imperatively via `setActiveClass(table, key)` called from the method — not `data-class-*`.
- **Section show/hide** previously used `SetClass("hidden", ...)` in `M.sync` — **NOW REQUIRED to migrate** to `data-if` + `document:Hide()/Show()` (see PR #7527 paradigm shift below).
- **Labels / readouts** still use `inner_rml = tostring(v)` in `M.sync` — to be migrated to `{{interpolation}}` per phase 2.

This eliminated all `AddEventListener` handler wiring from `M.attach()`. Phase 2 steps 2–4 are no longer deferred — see paradigm shift below.

### Paradigm shift after PR #7527 review (April 2026)

Reviewer (mupersega) submitted a full declarative refactor of `gui_decal_placer` as a reference implementation. Aligned outcomes:

**Promoted from deferred to required pre-1.0:**
- `data-class-*` for active-state. Replaces `setActiveClass()` imperative writes.
- `data-if` for section show/hide. Replaces `SetClass("hidden", ...)` in `M.sync` — explicitly called out as wrong, not deferred.
- `document:Hide()/Show()` for whole-panel show/hide. Replaces `SetClass("hidden", ...)` on root.
- `{{interpolation}}` for label readouts. Replaces `inner_rml = tostring(v)` in `M.sync`.
- **Model-king callbacks**: handlers register on `dm.onFoo = function(event, ...)` rather than `ctx.widget`. `data-event-click="onFoo(arg)"` over `onclick="widget:foo(arg)"`. The 548 existing `widget:` sites in `gui_terraform_brush.rml` get a single sweep migration as a phase-2-finisher.
- **No `gl.*` over RmlUi**: `DrawScreen/DrawScreenPost` while a panel is open punches through and renders OVER all RmlUi panels (engine layer-order bug). Bake to image + `<img data-attr-src>` instead. Audit pre-1.0: tf-brush passthrough icons, weather brush ceg preview, light placer ring, decal placer (already fixed in #7527 via `dp_preview_bake.lua`).
- **No `px` in RCSS**. Use `dp` (or `vw/vh` where viewport-proportional makes sense). Open: `vw + min/max-width` clamps for ultrawide vs 1080p — pending decision.
- **Theme imports**: strip `theme-armada/cortex/legion`, keep `theme-base.rcss` only.
- **Naming**: `dmHandle` (camelCase) locked in across all BAR widgets. ⚠️ PR #7527 (mupersega) uses `dm_handle` (snake_case) in `widgetState.dm_handle` — rename on merge.
- **`document:ReloadStyleSheet()`** mandatory in every widget Initialize.
- **No imperative tile-packing math**. `data-for` + flex/grid in RCSS. Only legitimate Lua-side pixel math is virtual-scroll row offsets.
- **`mousedown` for tool-press**, `click` for destructive (Quit/Delete/Reset) — UX nuance agreed.

**Engine-specific gotchas (now in skill doc):**
- `data-for` outer element must carry ONLY `data-for` — `d.X` bindings on the same element spam warnings during shrink. Inner-wrapper pattern.
- `data-event-X` injects `event` as implicit first arg.
- `data-for="d, i : items"` is 0-indexed.
- `data-value` updates AFTER change event fires; read `element:GetAttribute("value")` directly in `onchange`.

**Open items pending alignment with reviewer:**
- `vw + clamp` vs pure `dp` for panel width. PtaQ pushing back: raw `vw` breaks at 32:9 ultrawide and 1080p extremes.
- `widgetState.rootElement` cache vs re-resolve via `GetElementById` per call. Drag helper needs writable element ref.
- `mousedown` blanket vs mixed (mousedown for tool-pick, click for destructive). PtaQ proposed mixed.

### Completed work

| Sub-module / Widget | Phase 2 step 1 (onclick) | Phase 2 step 5 (onchange sliders) | AddEventListener remaining | Notes |
|---|---|---|---|---|
| `tf_splat.lua` | ✅ | ✅ | 0 | Done prior to April 2026 sprint |
| `tf_metal.lua` | ✅ | ✅ | 0 | 64 `w.mbXxx` methods; warn chip sync also added |
| `tf_features.lua` | ✅ | ✅ | 3 | 46 `w.fpXxx` methods; ~600 LOC of wiring removed; ~3 remaining are justified (SDL text / drag) |
| `tf_decals.lua` | ✅ | ✅ | 0 | 39 `w.dcXxx` methods; `dcStep`/`dcSliderChange` helpers |
| `tf_grass.lua` | ✅ | ✅ | 0 | 67 `w.gbXxx` methods; ~1100→~570 LOC |
| `tf_noise.lua` | ✅ | ✅ | 0 | 18 widget methods |
| `tf_clone.lua` | ✅ | ✅ | 0 | 17 widget methods |
| `tf_startpos.lua` | ✅ | ✅ | 0 | 23 widget methods |
| `tf_weather.lua` | ✅ | ✅ | 0 | 23 widget methods |
| `tf_lights.lua` | ✅ | ✅ | 10 | 49 `w.lpXxx` methods; slider sync-back added; 10 remaining are all justified: list-item click/dblclick (dynamic library), drag mousedown/mousemove/mouseup, SDL text focus/blur/keydown |
| `gui_terraform_brush.lua` (main panel) | ✅ | ✅ | 0 | Mode/shape/tab/stepper buttons → `onclick=`; `w.tfXxx` methods; `attachEventListeners` ~992→~446 LOC; **548 onclick/onchange in RML total** |
| `tf_environment.lua` | ✅ | ✅ | 32 | 24 bespoke 1-1 click bindings → `w.envXxx` inline handlers (mixed mousedown/click per mupersega UX rule). 32 remaining are all justified: reusable helpers (envSlider, envCheckbox, envWindowToggle, envSectionToggle, wireColorGroup, wireFilterToggleChip, wireMutexChipPair, wireVisibilityChip, wirePillTabs, wireGbFilterChip, chipToggle, warningToggle, _attachHintDots) wire many elements with shared logic — get rewritten as `data-class-*` / `data-if` in Phase 2 steps 2–3; runtime loops (skybox thumbs, color swatches, water-type presets, ± steppers, splatscale) are dynamic data tables; SDL focus/blur kept imperative. |
| `tf_guide.lua` | ✅ | ✅ | 3 | 22 `w.guideXxx` methods (header buttons, settings open/close, keybind save/apply/defaults/cancel, tab-switch, dj/dust/seismic/pen/wiggle/curve/disable-tips). 3 remaining are justified: per-element hint mouseover/mouseout loop (`guideHints`) and g3 mousedown discovery loop. |
| `gui_feature_placer.lua` (standalone) | ✅ | ✅ | 4 | ~4 remaining are justified (drag, SDL text) |
| `gui_weather_brush.lua` (standalone) | ✅ | ✅ | 4 | ~4 remaining are justified (drag, SDL text) |
| `gui_decal_placer.lua` (standalone) | ✅ | ✅ | ~4 | PR #7527 (mupersega) merged. Post-merge: renamed `dm_handle`→`dmHandle`, removed dead `refreshUIFromState`, replaced broken `data-for="d : currentDecals"` (Recoil struct-scope limitation) with imperative DOM builder + `dp-tile-host` RCSS wrapper. `dp_preview_bake.lua` bakes BMP atlases to PNG; `<img>` renders them. ~4 remaining justified after merge: drag mousedown/mouseup, SDL focus/blur. |

**Also landed (not in original scope):**
- `ctx.syncWarnChip(doc, chipId, sectionId, anyActive)` — shared helper for "Active" warn chips on collapsed DISPLAY/INSTRUMENTS headers. Used by tf_splat, tf_metal, and synced via `ctx.syncTBMirrorControls`.
- `gui_decal_placer`: normal-map auto-pairing (`isNormalName`/`normalBaseKey`), `getNormalPartner` API, `loadfile`-first decal load, automatic `SetGroundDecalTexture(id, norm, false)` on placement.
- `dp_preview_bake.lua` (PR #7527): extracted bake module — channel-encoded BMP atlases composited through one-shot shader into RGBA PNGs; widget renders via `<img data-attr-src>`. Bake runs from `DrawScreen` (4/frame); widget re-syncs when queue drains. Pattern reusable for other mask-encoded assets.
- `map_grass_gl4`: `WG.grassgl4.loadGrass(filename)` + `clearGrass()` API exposed.
- `cmd_light_placer`: Ctrl+Scroll mode-aware (point mode → lightRadius, other modes → brushRadius); per-light elevation preserved on load.
- `cmd_terraform_brush.lua`: ramp reapply uses atomic `MSG.UNDO_STROKE` (one message pops entire stroke) instead of per-tick UNDO spam; `~3 frames` vs `~120 frames` to complete cycle.
- Gadget DIAG flag defaulted to false.

---

## Phases

### Phase 0 — Trivial must-do (parallel, ~30min commit)

**Status: DONE**
- `BASE_RESOLUTION` constant deleted from all 4 widgets. ✅
- `WG.RmlContextManager.getDpRatio()` accessor added to `rml_context_manager.lua`. ✅
- Theme `<link>` imports: only `theme-base.rcss` remains in all 4 widget RMLs. ✅ (verified — no armada/cortex/legion imports present)
- `scaleFactor` math: ✅ renamed to `dpRatio` in `gui_feature_placer.lua` for consistency with other call sites. All 4 widgets now read `getDpRatio()` directly.

1. Strip `theme-armada`, `theme-cortex`, `theme-legion` `<link>` imports; keep `theme-base.rcss` — confirmed by reviewer. ✅ (already only `theme-base.rcss` referenced in all 4 widget RMLs)
2. Replace per-widget `BASE_RESOLUTION`/`scaleFactor` math with reads of `context.dp_ratio`. ✅ done for all 4 widgets.
3. Audit utility-class usage — no code change, just confirm we don't regress `rml-utility-classes.rcss` + `palette-standard-global.rcss` usage (reviewer called this out positively).

### Phase 1.5 — RCSS-owned widths (DONE)

- Panel widths moved to RCSS: `width: 15vw; min-width: 220px; max-width: 360px;` (18vw/300/460 for `.fp-root`). Same on `.tf-env-float-window`, `.tf-noise-root`, `.tf-skybox-library-root`, `.tf-light-library-root`.
- `buildRootStyle()` now emits only `left/top` — no more inline width writes from Lua.
- `applyEnvWindowWidths()` + both callers deleted from terraform_brush.
- feature_placer px-conversion sites (virtual-scroll `rowHeightPx`) now use `getDpRatio()` from `WG.RmlContextManager.getDpRatio()`.
- `clampPanelPosition()` now prefers `rootElement.offset_width`, falls back to `panelWidthDp` constant on first frame.
- Tried `162dp` first — on 4K dp_ratio made it 324px (too thin vs original `15vw` = 576px). Reverted to `vw` base.

### Phase 1 — Kill the `WG.*` positional mirror (MOSTLY DONE; drag consolidation deferred)

**Status:** Mirror killed ✅, context manager enriched ✅, standalone widgets migrated ✅. Drag loop consolidation deliberately deferred as follow-up.

1. ✅ `WG.TerraformBrushPanel` had NO writer in the codebase — all 6 reads in weather/feature/decal were dead code. Confirmed gone.
2. ✅ Added to `rml_context_manager.lua`: `registerDocument` / `unregisterDocument` / `getDocument` / `getElementRect(docName, elementId)` → `{left, top, width, height}` via live `offset_*` reads.
3. ✅ All 4 widgets register on LoadDocument, unregister on Shutdown (`terraform_brush`, `weather_brush`, `feature_placer`, `decal_placer`). Registration is defensive for load-order robustness.
4. ✅ 6 `WG.TerraformBrushPanel` reads in 3 follower widgets replaced with `WG.RmlContextManager.getElementRect("terraform_brush", "tf-root")`. Snap-to-terraform now actually works (was dead before).
5. ⬜ **DEFERRED**: consolidate the 4 near-identical drag loops (weather ~L230, decal ~L660, feature ~L800, terraform ~L4000) into a shared `attachDraggable()` helper in `rml_context_manager.lua`. Kept out of Phase 1 to keep the diff reviewable.

### Phase 2 — Declarative events + state (reviewer's #1 red line — THE pattern fix)

**Status: Step 1 + Step 5 ✅ done for all `tf_*.lua` sub-modules. Standalone widgets also done. Steps 2–4 deliberately deferred — now PROMOTED to required pre-1.0 (see paradigm shift).**

Per widget (parallelisable; sub-steps 1-5 must land together per widget to avoid half-refactored state):

1. ✅ **Static buttons → `onclick="widget:methodName()"`** in RML. Delete matching `AddEventListener` sites. **Done for all tf_* sub-modules. 548 onclick/onchange attributes in gui_terraform_brush.rml. Standalone widgets also converted (gui_feature_placer, gui_weather_brush, gui_decal_placer).** **Sweep migration to `data-event-X` + model functions queued as phase-2-finisher.**
2. 🟡 **Active-state loops → `data-class-active="activeMode == 'raise'"`** bound to `dm.activeMode` / `dm.activeShape` / `dm.activeChannel`. Removes ~70% of `:SetClass` calls. **PROMOTED to required pre-1.0 (PR #7527 review).** **In progress (Apr 2026)** — pilot landed for tf-mode/shape/ramp/smoothSub buttons; remaining: sub-mode buttons in tf_metal/grass/features/weather/noise/decals/lights/startpos.
3. 🟡 **Section collapse / show-hide → `data-if="sectionTerrainOpen"`** for banners / notice dots / passthrough play/pause icons; **whole-panel show/hide → `document:Hide()/Show()`**. **PROMOTED to required pre-1.0 (PR #7527 review). `SetClass("hidden", ...)` is wrong, not deferred.** **In progress (Apr 2026)** — see per-file table below.

#### Phase 2 step 3 per-file progress

| File | Sites done / total | Status |
|---|---|---|
| `tf_guide.lua` | 13 / 13 | ✅ pilot |
| `tf_noise.lua` | 1 / 1 | ✅ (`noiseWindowVisible` dm flag) |
| `gui_decal_placer.lua` | 1 / 1 | ✅ (dead code removed) |
| `tf_startpos.lua` | 8 / 8 | ✅ (`stpSubMode`, `stpStartboxMode`) |
| `tf_splat.lua` | 8 / 8 | ✅ (12 dm flags incl. `sp*` instruments) |
| `tf_features.lua` | 12 / 12 | ✅ (`fpAvoidCliffs`, `fpPreferSlopes`, `fpAltMinEnable`, `fpAltMaxEnable`, `fpSymmetryActive`, `fpSymmetryRadial`, `fpSymmetryMirrorAny`, `fpSaveLoadOpen`) |
| `tf_lights.lua` | 11 / 11 | ✅ (`lpLightType`, `lpMode`, `lpLibraryOpen`, `lpLibraryTab`) |
| `tf_metal.lua` | 11 / 11 | ✅ (`mbGridSnap`, `mbAngleSnap`, `mbMeasureActive`, `mbSymmetryActive`, `mbSymmetryRadial`, `mbSymmetryMirrorAny`, `mbAngleSnapAuto`, `mbInspectorOpen`, `mbClusterOpen`, `mbLassoOpen`, `mbAxisOpen`) |
| `tf_grass.lua` | 19 / 19 | ✅ (gbGridSnap/gbAngleSnap/gbMeasureActive/gbSymmetryActive/gbSymmetryRadial/gbSymmetryMirrorAny/gbAngleSnapAuto + gbSlopeActive/gbAvoidCliffs/gbPreferSlopes/gbAltActive/gbAltMinEnable/gbAltMaxEnable/gbColorOpen; local syncSectionWarn → ctx.syncWarnChip) |
| `tf_environment.lua` | 18 / 18 | ✅ (`envWindowToggle` dmKey param + skybox toggle/close dm writes) |
| `gui_terraform_brush.lua` | 74 / 74 | ✅ (29 dm flags added; all floating windows, instrument sub-rows, pen pills, shape/ramp/clay/restore rows → data-if; tf_environment sub-windows all data-if driven) |

4. ⬜ **Labels → `{{radius}}` interpolation**; replaces `.inner_rml = tostring(v)` sites (~40 in terraform_brush alone). **PROMOTED to required pre-1.0 (PR #7527 review).**
5. ✅ **Sliders**: keep `updatingFromCode` feedback guard + log-curve handlers; `onchange="widget:onXxxChange(element)"` added to all sliders in converted panels.
6. ⬜ **Model-function migration of existing `widget:` sites**. 548 `onclick="widget:foo()"` in `gui_terraform_brush.rml` swap to `data-event-click="onFoo()"` with handlers registered on `dm.*`. Single-sweep PR after 2–4 land.

### Phase 3 — `data-for` dynamic lists

> ⚠️ **Recoil limitation discovered Apr 2026**: `data-for="d : array"` does NOT scope `d` into child element bindings. All `{{d.field}}`, `data-class-active="d.foo"` etc. fail — Recoil registers bindings against the top-level model at parse time, not per-clone. Struct tile lists MUST be built imperatively. Phase 3 goals below revised accordingly.

- **feature_placer** feature tiles (~L430) → already imperative DOM (`CreateElement`/`AppendChild`). ✅ **Correct pattern** — do NOT migrate to `data-for`.
- **decal_placer** decal grid → similarly migrated to imperative DOM (post PR #7527 fix). ✅ **Correct pattern**. PR #7527 (mupersega) used `data-for="d : currentDecals"` with `{{d.displayName}}` etc. — this produced literal `{{d.displayName}}` text (binding silently dropped). Fixed by replacing with imperative builder + `dp-tile-host` wrapper for RCSS sizing.
- **weather_brush** CEG library grid (L326, full `inner_rml = ""` + rebuild) → defer (smaller surface, less copied).
- **terraform_brush** preset list / history — audit during implementation.

### Phase 4 — Post-1.0

- Deeper terraform_brush model (animation state, status summary, drag-ghost preview).
- Migrate pre-existing `gui_quick_start` / `gui_tech_points` / `gui_territorial_domination` inline styles to `data-style-*` (NOT in PR scope).
- Context manager enrichment — document retrieval, theme management (reviewer owns, lands with his branch).
- Full two-way slider binding.
- **Terrain-filtered intelligent noise painting**: noise brush respects terrain classification (slope, altitude, texture type) — only paints cells that pass a configurable filter set. UI: per-filter threshold sliders + enable chips inside `tf_noise` panel. Backend: sample terrain data per-cell before applying noise delta.
- **Fullmap parameterised noise apply**: one-shot "apply noise to entire map" action with the current `tf_noise` parameters (scale, octaves, amplitude, seed, filter mask). Progress bar via dm flag; runs over N ticks to avoid engine stall. Accessible as a button in `tf_noise` panel and via keybind.

## Release recommendation — what blocks 1.0

- **Must land**: Phase 0, 1, 2 — these set THE pattern others copy (reviewer's explicit worry about "vibing contributors using this PR as context").
- **Strongly recommended**: Phase 3 for feature_placer + decal_placer (their UX *is* a dynamic list — ideal `data-for` showcase).
- **Safe to defer**: weather_brush library `data-for`, full slider two-way, terraform_brush deep model, all Phase 4.

**Tag 1.0 only after Phase 0-2 land.** Phase 3 partials can ship as 1.0.x without re-establishing bad patterns.

### Remaining pre-1.0 work (as of April 2026)

| Item | Effort | Notes |
|---|---|---|
| Phase 1 — `attachDraggable` drag consolidation | Small-Medium | 4 near-identical drag loops; context manager home agreed; deferred from Phase 1 to keep diff small |
| Phase 2 step 2 — `data-class-*` for active state | Large | **PROMOTED pre-1.0** (PR #7527). All `setActiveClass()` sites → `data-class-active="x == 'foo'"`. |
| Phase 2 step 3 — `data-if` + `document:Hide/Show` | Medium | ✅ **COMPLETE (Apr 2026)** — 11/11 files done. All `SetClass("hidden",…)` sites in tf-brush package converted to dm flags + `data-if` bindings. |
| Phase 2 step 4 — `{{interpolation}}` for labels | Medium | **PROMOTED pre-1.0** (PR #7527). ~40 `inner_rml = tostring(v)` sites in tf-brush. |
| Phase 2 step 6 — model-function migration | Large | Sweep 548 `widget:foo()` → `data-event-click="onFoo()"` with `dm.*` handlers. After steps 2–4. |
| Phase 2.5 — `gl.*` over RmlUi audit | Small-Medium | **PROMOTED pre-1.0** (PR #7527). tf-brush passthrough icons, weather ceg preview, light placer ring. Bake-to-image pattern. |
| Phase 3 feature_placer data-for | Medium | Ideal showcase; target pre-1.0 |
| Phase 3 decal_placer data-for | ~~Medium~~ | ✅ **Done via PR #7527** (mupersega) — pending merge + `dm_handle` → `dmHandle` rename |

## Verification

1. `grep themes/theme-` in `luaui/RmlWidgets/` → 0 matches.
2. `grep BASE_RESOLUTION|ui_scale` in the four widgets → 0 matches; window-resize rescales all four identically.
3. `grep WG.TerraformBrushPanel` → 0 matches; dragging terraform panel still live-snaps the other three windows.
4. `grep ':AddEventListener('` per widget drops ≥70%; remaining sites justified (SDL text input focus/blur, drag mousedown if not moved into helper).
5. `grep ':SetClass('` per widget drops ≥70%; mode/shape switching still visibly highlights.
6. `grep '\.inner_rml = '` drops significantly; live values (radius, intensity, etc.) still update during brush use.
7. `python tools/count_locals.py` on refactored files — 200-local limit still respected (should IMPROVE as handlers leave Lua; `cmd_terraform_brush.lua` and `gui_terraform_brush.lua attachEventListeners()` are already at the edge per repo memory).
8. Utility class regression guard — `rml-utility-classes.rcss` + `palette-standard-global.rcss` imports remain at top of every widget RML.
9. Per-widget smoke: open → drag → snap → every button/mode/shape → slider scrub; infolog clean of RmlUi warnings.

## Decisions

- Scope stays strict to reviewer's boundary: only the four "new" RmlWidgets + context-manager accessor. No touching `cmd_terraform_brush.lua`, engine gadget, or pre-existing RML widgets.
- `data-for` adoption scoped, not blanket: feature_placer + decal_placer pre-1.0; others defer.
- Drag/snap: plan is centralised AEL-based helper in context manager. Reviewer's review also mentions `data-event-mousedown` for drag handles — open question whether document-level mousemove/mouseup capture needed for drag is feasible declaratively. Pending clarification before `attachDraggable` is built.
- Theming work not started here — reviewer explicitly owns theming, imports are removed only.
- Slider pattern compromise: keep existing `updatingFromCode` feedback guard + log-curve handlers.
- **[April 2026 addition]** Widget-method onclick pattern adopted over full data-model binding: methods registered on `ctx.widget` in each `M.attach()`; RML calls `widget:methodName()`. Data-model binding (steps 2–4) deferred to Phase 4. This satisfies the reviewer's primary concern (no AddEventListeners in attach) while keeping M.sync imperative. Revisit after 1.0.
- **[April 2026 addition]** `gui_terraform_brush` widget now split into 12 per-tool sub-modules (`tf_*.lua`). The `gui_terraform_brush.lua` main file hosts shared `ctx` helpers (`syncWarnChip`, `syncTBMirrorControls`, `setDisabledIds`, etc.) and the `attachEventListeners` function that calls each module's `M.attach(doc, ctx)`.

## Further considerations

1. **Drag helper home** — Option A: extend `rml_context_manager.lua`. Option B: standalone `luaui/RmlWidgets/rml_drag.lua`. Option C: defer inline until reviewer's enriched context manager lands. **→ A tentatively**, matches reviewer's stated direction, avoids second migration. ⚠️ Open question: reviewer's review also calls for `data-event-mousedown` on drag handles — need to confirm whether RmlUi supports document-level capture for mousemove/mouseup from a declarative starting point before committing to AEL-based helper.
2. **`onclick` vs `data-event-click`** — reviewer showed both. **→** `onclick="Widget:Foo('arg')"` for static buttons (terser); `data-event-click="foo"` inside `data-for` where item context is needed.

## Relevant files

- `luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.lua` — main offender; drag snap ~L4000-L4150, DOM-poke sync loops ~L350-900, event wiring throughout
- `luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.rml` — header imports (L6-9), needs `onclick`/`data-class-*`/`data-if` conversions on nearly every button
- `luaui/RmlWidgets/gui_feature_placer/gui_feature_placer.lua` — imperative list build ~L430-L460, drag ~L808, reads `WG.TerraformBrushPanel`
- `luaui/RmlWidgets/gui_feature_placer/gui_feature_placer.rml` — needs `data-for` feature template
- `luaui/RmlWidgets/gui_weather_brush/gui_weather_brush.lua` — drag ~L163-L212, inner_rml library rebuild L326, reads `WG.TerraformBrushPanel`
- `luaui/RmlWidgets/gui_weather_brush/gui_weather_brush.rml` — header imports, event listeners
- `luaui/RmlWidgets/gui_decal_placer/gui_decal_placer.lua` — drag ~L670, SetClass loops L201
- `luaui/RmlWidgets/gui_decal_placer/gui_decal_placer.rml` — same pattern
- `luaui/RmlWidgets/rml_context_manager.lua` — proposed home for `getDpRatio()` accessor + `getElementRect(docName, elementId)` + `attachDraggable()` helpers