# Issue 1242 – Underwater metal spot labels obscured by high water quality

## Summary
- When water quality is set to **High**, water distortion makes underwater metal spot numbers difficult to read.
- Goal: render the metal spot numbers late enough that they are not warped by water distortion, while keeping behavior consistent across maps with and without water.

## Proposed solution
- Adjust the rendering order so metal spot numbers (labels) draw after the water distortion step. This should bypass distortion while keeping the existing water effects.
- Chosen approach (Lua-only): draw the “High Visibility Metal Spots” path in `DrawWorld` (a late world pass) instead of relying on `DrawWaterPost`.

## Current understanding / hypotheses
- Water distortion likely occurs in a post-process step; labels may currently be rendered before this pass, causing warping.
- If label rendering is already decoupled from water rendering, changing draw order may be a small update. If not, separating these passes could require deeper engine changes.

## Investigation plan
1. Map the rendering pipeline for water (shaders, post-process order) and locate where labels for metal spots are drawn.
2. Check whether label rendering can be moved to a later pass (post-distortion) without breaking depth/visibility rules.
3. Assess whether the engine cleanly separates water distortion from other overlays; estimate if the change is minor (ordering tweak) or major (requires restructuring shared buffers/passes).
4. Prototype a post-distortion label render path (even if temporary) to validate legibility and performance impact.

## Investigation findings (updated)
- Metal spot labels are drawn by the LuaUI widget in world space during `DrawWorldPreUnit`, via the GL4 billboard shader pipeline in [luaui/Widgets/gui_metalspots.lua](luaui/Widgets/gui_metalspots.lua#L504-L528) and [luaui/Shaders/metalspots_gl4.vert.glsl](luaui/Shaders/metalspots_gl4.vert.glsl). `DrawWorldPreUnit` content is sampled by the water refraction buffer, so labels warp when water quality is High.
- The engine exposes `DrawWaterPost`, invoked right after `water->Draw()` and before above-water alpha passes, only when water rendering is active ([tools/RecoilEngine/rts/Rendering/WorldDrawer.cpp](tools/RecoilEngine/rts/Rendering/WorldDrawer.cpp#L410-L449)). The callin is defined and surfaced to Lua in [tools/RecoilEngine/rts/System/Events.def](tools/RecoilEngine/rts/System/Events.def#L139), [tools/RecoilEngine/rts/Lua/LuaHandle.cpp](tools/RecoilEngine/rts/Lua/LuaHandle.cpp#L2728-L2750), and [tools/RecoilEngine/rts/Lua/LuaHandle.h](tools/RecoilEngine/rts/Lua/LuaHandle.h#L248-L270); it shipped in the 105-1775 changelog [tools/RecoilEngine/doc/site/content/changelogs/changelog-105-1775.markdown](tools/RecoilEngine/doc/site/content/changelogs/changelog-105-1775.markdown#L39-L47).
- Because refraction samples the pre-water color buffer, content drawn in `DrawWaterPost` does not get warped by the water pass. This makes it a suitable hook for crisp metal spot labels when water quality is High.
- Caveats: `DrawWaterPost` is skipped when water rendering is off or the map has no visible water; a fallback path is needed. Water depth state depends on the water renderer—verify whether labels should respect water occlusion.
- We verified `DrawWorld` is called late enough to serve as a consistent “post-water when present” hook, and it is available on maps without water. The widget now uses `DrawWorld` for the high-visibility path.

## Feasibility assessment
- Recommended Lua-only change (implemented): Use `DrawWorld` to draw the existing world-space GL4 billboards late, avoiding water refraction distortion and keeping consistent behavior on maps with and without water.
- Alternative Lua-only change: Use `DrawWaterPost` to draw after water when available, but it requires a robust fallback (since it does not run on no-water/water-off maps) and introduces layering inconsistency risks unless land vs water spots are split.
- Alternative Lua-only change: Render a screen-space overlay in `DrawScreen` using projected positions. Avoids distortion but loses reliable world-depth cues and depends on depth access; keep as a secondary fallback only.
- Engine-level changes (not needed if `DrawWaterPost` suffices): add a dedicated post-water world hook or a “no-refract” flag/layer. These are larger C++ changes outside this repo.

## Follow-up bug: inconsistent land metal spot layering
- Status: Resolved in the Lua-only implementation by drawing the high-visibility path in `DrawWorld` on all maps (water and no-water).
- Historical note: The earlier `DrawWaterPost` approach improved readability on water maps, but `DrawWaterPost` is not called when water rendering is off or the map has no visible water, causing inconsistent layering/fallback behavior.

## Follow-up bug: `DrawWorld` metal spot numbers add UI clutter

### Problem
- The current Lua-only fix uses the **high-visibility path** in `DrawWorld` ([luaui/Widgets/gui_metalspots.lua](luaui/Widgets/gui_metalspots.lua)), which makes the metal spot numbers/circles appear **above essentially everything**.
- This is desirable *sometimes* (e.g., when placing buildings and deciding which mex spot to use), but it is **too visually loud during normal gameplay**.

### Desired behavior
- Default/normal gameplay: use the **legacy** metalspot render path (`DrawWorldPreUnit`).
- When the player is attempting to place a building (i.e. when the **building grid is visible**): temporarily switch to the **high-visibility** render path (`DrawWorld`).

### Existing hook to reuse (building grid visibility)
- The build grid is controlled by the widget [luaui/Widgets/gui_building_grid_gl4.lua](luaui/Widgets/gui_building_grid_gl4.lua).
- Internally it renders the grid when either:
	- a build command is active (`Spring.GetActiveCommand()` returns a negative `cmdID`), or
	- another widget requests it via `WG.buildinggrid.setForceShow(reason, enabled, unitDefID)`.
- Example: blueprint placement explicitly forces the grid on/off via `WG.buildinggrid.setForceShow(...)` in [luaui/Widgets/cmd_blueprint.lua](luaui/Widgets/cmd_blueprint.lua).

### Possible solution directions
1. **Split land vs water spots (Lua-only):**
	- Determine whether a spot is “underwater” (or affected by refraction) and render underwater spots in `DrawWaterPost` while keeping land spots in the legacy path.
	- Requires additional logic to classify spots (e.g., compare spot height to sea level / waterline, or query map/water state).
2. **Provide a consistent post-water hook even without water (engine or workaround):**
	- Use an alternative callin/order that is available on maps without water, or ensure `DrawWaterPost` is invoked even when no water is rendered (e.g., by inserting a minimal/fake water pass).
	- Would keep draw ordering consistent across all maps, but likely needs engine work or a rendering workaround.

### Feasibility (Group 1: split land vs water, Lua-only)
If we ever want to go back to a `DrawWaterPost`-specific solution (instead of the current `DrawWorld` approach), the goal for Group 1 would be: **land spots always draw in the same pass** (so they layer consistently on maps with and without water), while **underwater spots use `DrawWaterPost`** on water maps to avoid distortion.

#### Classification (how to detect “water spots”)
- **Option C1 (simple / recommended):** classify a spot as underwater when `groundHeight < waterLevel` at the spot center.
	- Water level sources seen in this codebase:
		- `Spring.GetWaterPlaneLevel()` when available (used elsewhere in LuaUI).
		- Fallback to `Spring.GetModOptions().map_waterlevel` or `0`.
	- Difficulty: low.
	- Risk: spots near shore or with large footprint may be partially submerged but misclassified by center-only sampling.

- **Option C2 (more robust):** multi-sample within spot footprint (center + 4/8 offsets based on extractor radius * spot scale) and treat it as “water spot” if **any** sample is below water level.
	- Difficulty: low-to-medium (done at init; negligible runtime cost).
	- Risk: may classify some mostly-land spots as water spots; tune sample radius/threshold.

#### Rendering split (how to actually draw them in different passes)
1. **Option R1: two instance VBOs (lowest risk, no shader changes)**
	- Maintain `landSpotInstanceVBO` and `waterSpotInstanceVBO` with the same layout.
	- `DrawWorldPreUnit`:
		- If `DrawWaterPost` is active that frame, draw **land only**.
		- If `DrawWaterPost` is not active (no water / water off), draw **both land + water** (so underwater labels still appear even though they may not need the post-water path).
	- `DrawWaterPost`: draw **water only**.
	- Requires: tagging each `mySpot` with which VBO it belongs to and updating occupancy/value updates against the correct VBO.
	- Difficulty: medium (touches init + update paths), complexity is contained to Lua.
	- Pros: keeps existing shaders and per-instance data format unchanged; easiest to reason about.
	- Cons: duplicates some VBO management code.

2. **Option R2: single VBO + per-instance “isWater” flag + shader discard (more invasive shaders, less Lua duplication)**
	- Extend the instance layout to include an `isWater` float (0/1).
	- Render the same VBO in both passes:
		- PreUnit pass sets uniform `drawWater = 0` and shader discards instances where `isWater = 1`.
		- WaterPost pass sets uniform `drawWater = 1` and shader discards instances where `isWater = 0`.
	- Difficulty: medium-to-high (requires updating GL4 VBO layout + vertex/fragment shaders + all push/update code indices).
	- Pros: one VBO, no need to track “which VBO” per spot.
	- Cons: higher risk of breakage; draws twice (extra vertex work) even though half the instances are discarded.

3. **Option R3: dynamic repacking (not recommended)**
	- Keep a single VBO but rebuild/re-upload instance lists when water becomes active/inactive.
	- Difficulty: high, likely not worth it; adds complexity and potential hitches.

#### Recommendation
- Start with **C1 + R1**: center-height classification + two VBOs.
	- It’s pure Lua, no shader churn, and should fully resolve the land/water layering inconsistency.
- If shore/partial-water spots are a real issue, upgrade classification from **C1 → C2**.

### Feasibility (Group 2: provide a post-water equivalent without water)
The goal for Group 2 is: **keep the same draw ordering regardless of whether the map has water**, by using a hook that is (a) available on no-water maps and (b) as close as possible to the “after-water” timing of `DrawWaterPost`.

#### Option G2.1: Use `DrawWorld` (Lua-only fallback on no-water maps)
- Engine documentation:
	- `DrawWorld`: “Spring draws command queues, 'map stuff', and map marks.”
	- `DrawWorldPreUnit`: “Spring draws units, features, some water types, cloaked units, and the sun.”
- Engine call order (Recoil/Spring): `DrawWorld` is invoked **after** the main world draw has already rendered terrain, units/features (opaque), alpha objects, and (if present) the water pass.
	- This means `DrawWorld` is a *late* world hook relative to units.
- Practical implication for Metalspots:
	- Because the Metalspots widget currently draws with depth testing disabled (purely order-based occlusion), switching the fallback from `DrawWorldPreUnit` → `DrawWorld` will make markers appear **on top of units/buildings** on no-water maps.
	- That can be desirable (it matches the “high visibility / not blocked” goal), but it is a deliberate behavior change from the legacy “units can cover markers” behavior.
	- It should also avoid water distortion (since it runs after the water draw), potentially making `DrawWorld` a viable unified hook for both water and non-water maps.
- Difficulty: low-to-medium (new callin + minor state/order refactor).
- Risks:
	- Interaction/order with other late world overlays (map marks, queued commands, etc.)—Metalspots may end up behind/above them depending on desired UX.
	- Needs verification across render paths (deferred/forward, different water renderers) to ensure `DrawWorld` timing is stable.

#### Option G2.2: Use `DrawWorldPreParticles` second phase (Lua-only, potentially best match)
- Observation: in BAR’s widget handler, `DrawWorldPreParticles(...)` is documented as being called **twice per draw frame**, “once before water and once after, even if no water is present”.
- Approach: implement `widget:DrawWorldPreParticles(drawAboveWater, drawBelowWater, drawReflection, drawRefraction)` and draw metal spots only in the invocation that corresponds to the **post-water** phase.
	- This could provide a consistent “late world overlay” callin even on maps without water.
- Difficulty: medium (must correctly identify which invocation is “post-water”; add robust gating to avoid multiple draws per frame).
- Risks:
	- The parameter combinations vary by engine settings (reflection/refraction). Misidentifying the phase can reintroduce distortion or cause duplicates.
	- Requires careful per-frame bookkeeping (e.g., track drawFrame + whether we already drew this frame).

#### Option G2.3: Use a screen-space hook (`DrawScreenEffects` / `DrawScreenPost`) (Lua-only, behavior guaranteed but visual tradeoffs)
- Approach: render in a guaranteed-late screen pass so ordering is consistent everywhere.
- Difficulty: medium-to-high (projection, depth/occlusion handling, performance tuning).
- Pros: completely decoupled from water pipeline; consistent layering.
- Cons: easy to lose correct world depth/occlusion unless depth sampling is reliable; may look “UI-ish” compared to world-space billboards.

#### Option G2.4: Force water rendering to make `DrawWaterPost` run (workaround, high risk)
- Approach: attempt to enable a minimal water pass on no-water maps ("fake water") so the engine calls `DrawWaterPost`.
- Difficulty: high and likely not viable as a pure LuaUI solution.
- Risks:
	- May require engine settings / restart; may have visual side effects (unwanted water plane/ocean).
	- May not be controllable from Lua in a safe, player-friendly way.

#### Option G2.5: Engine change (cleanest long-term if Group 2 is preferred)
- Add a new callin such as `DrawWorldPostWater` (always fired, even when no water is rendered) or make `DrawWaterPost` fire unconditionally.
- Difficulty: medium-to-high (engine-side C++ work + testing across water modes).
- Pros: deterministic ordering across all maps; minimal Lua complexity.
- Cons: requires engine distribution and version gating.

#### Recommendation
- If we want a **Lua-only** Group 2 path, start with **G2.1** (safe) and investigate **G2.2** (potentially best match) once we validate the call timing.
- If we are willing to do engine work, **G2.5** is the cleanest and most robust.

### DrawScreen overlay considerations
- Alignment with world positions: Project each metal spot’s world coords to screen every frame (Spring.WorldToScreenCoords) and place the label at that screen position; this preserves alignment across camera angles, similar to the current `DrawWorldPreUnit` billboard positioning but executed after water.
- Occlusion/stacking vs. units/terrain: Sample depth at the target screen pixel and discard/fade the label when the recorded depth is nearer than the spot’s depth (plus a small epsilon). That keeps units/buildings in front of the label if the current behavior already occludes them. If depth sampling proves unreliable in `DrawScreen`, fall back to ray tests (trace to ground, compare expected depth) or accept that labels are always visible.
- Z-order with other UI: Ensure labels render in a dedicated layer after world but before HUD text that should sit on top; set a consistent blend/alpha policy to avoid fighting with other overlays.
- Potential DrawScreen pitfalls:
	- Depth buffer availability/precision: Some configurations may not expose depth in `DrawScreen`; if depth reads fail, labels would float over units/terrain. Mitigation: feature-detect depth access; if missing, either keep current `DrawWorldPreUnit` path for occlusion or accept always-visible labels with an option toggle.
	- Camera FOV and projection drift: World-to-screen projection must use the current camera matrices each frame; if the camera changes after projection (e.g., UI-initiated camera lerp), labels can momentarily desync. Mitigation: compute per-frame just before draw, and avoid caching across frames.
	- Performance at scale: Per-spot projection and depth sampling each frame may cost more than the current instanced world-space draw. Mitigation: throttle updates (only when camera moves or every N frames) or cull off-screen spots before projection.

### Suitability note
- Given the above pitfalls, the DrawScreen overlay may not be appropriate if we require consistent depth-based occlusion, low per-frame cost for many spots, and broad compatibility with depth access. It remains a fallback option, but not the primary recommendation.

### Alternative solutions
- Engine hook after water: Add an engine-level callin (e.g., world-space draw after water refraction) so the existing instanced world draw can run post-water without refraction. Minimal Lua churn; requires engine change.
- Engine exclusion layer for refraction: Let certain draw layers bypass the water distortion buffer (e.g., labels marked “no refract”). Keeps world-space alignment and depth, avoids water warp. Requires engine feature support.

### Engine exclusion layer for refraction – feasibility
- Concept: allow specific draw submissions to skip inclusion in the water refraction/distortion buffer (e.g., a “no-refract” mask/layer). Labels stay in world space, keep depth correctness, but aren’t sampled by the water pass, so they remain crisp.
- Likely engine touch points: water/refraction composition stage and the render queue/layering that feeds it. Spring has multiple world draw callins (e.g., `DrawWorld`, `DrawWorldPreUnit`, `DrawWorldRefraction`, `DrawWorldReflection`, `DrawWorldShadow`). A “no-refract” path could be a flag on submissions or a dedicated callin that renders after the main opaque world but before water refraction uses the color buffer.
- Expected work: add a flag or new callin that routes certain draw calls to a buffer not sampled by refraction; ensure depth writes remain valid so labels still occlude/are occluded correctly. May require splitting the current G-buffer/color buffer usage so the water shader excludes tagged primitives.
- Complexity: moderate-to-high. Less intrusive than adding a full post-water hook, but still engine-side C++ and pipeline changes. Needs careful ordering to avoid breaking reflection/refraction passes and to keep performance stable.
- Risks: renderer compatibility (GL4 vs legacy), added state changes or extra buffers increasing GPU cost, and unintended interactions with other widgets/gadgets that assume current layering. A feature flag/toggle would limit blast radius.
- Hybrid runtime toggle: Retain current `DrawWorldPreUnit` path by default for correct occlusion; offer an opt-in DrawScreen overlay for players who prefer legibility over strict depth correctness when water is High or when depth access is unavailable.
- Visual tweaks without reordering: Increase label contrast/outline or add a subtle background plate in the existing world-space shader to improve readability under distortion. Does not fully solve warp but may mitigate legibility issues without pipeline changes.

### Engine hook after water – feasibility
- Current repo has no engine sources; implementing a post-water hook requires changes in the Spring engine (C++). Likely areas: the water renderer/refraction pass and Lua callin dispatch (adding a new world-space draw phase after water, or a flag to skip refraction for specific layers).
- Expected work: add a new callin (e.g., `DrawWorldPostWater`) or a render layer flag that renders after water distortion but before UI; wire it into the GL4 pipeline and expose depth/state needed for world overlays.
- Complexity: moderate-to-high. An engine dev familiar with the rendering pipeline would need to plumb the new pass, ensure it respects depth buffers and does not regress existing water effects. Rough estimate: a few days to implement and test if no major refactors are needed; longer if the water pipeline is tightly coupled.
- Risks: compatibility across renderers (GL4 vs legacy), maintaining performance, avoiding unintended interactions with existing widgets/gadgets that assume the current pass order, and ensuring the new hook is optional/behind a feature flag.

## Open questions / risks
- Does rendering labels after distortion conflict with depth testing or fog for submerged objects?
- Are the label shaders compatible with the post-process pipeline (e.g., requires different buffers or blending states)?
- Could UI/overlay ordering regressions occur if other elements rely on the current sequence?

## Implementation plan

### Updated plan (Jan 2026)

1. Expose “is grid visible?” from Building Grid GL4
	 - In [luaui/Widgets/gui_building_grid_gl4.lua](luaui/Widgets/gui_building_grid_gl4.lua), extend the existing `WG['buildinggrid']` API with a read-only helper, e.g.:
		 - `WG.buildinggrid.getShownUnitDefID()` → returns `getForceShowUnitDefID() or cmdShowForUnitDefID`.
		 - `WG.buildinggrid.getIsVisible()` → returns boolean (`getShownUnitDefID() ~= nil`).
	 - Rationale: metalspots should not re-implement grid-visibility logic or duplicate the “force show” reasoning spread across widgets.

2. Drive metalspot draw mode from building grid visibility
	 - In [luaui/Widgets/gui_metalspots.lua](luaui/Widgets/gui_metalspots.lua):
		 - Keep the existing dual-callin structure:
			 - legacy path: `widget:DrawWorldPreUnit()`
			 - high-visibility path: `widget:DrawWorld()`
		 - Split “saved setting” from “effective runtime behavior”:
			 - `useDrawWaterPost` remains the user-configurable preference (“always high visibility”).
			 - Add `autoHighVisibility` computed per-frame: `autoHighVisibility = (WG.buildinggrid and WG.buildinggrid.getIsVisible and WG.buildinggrid.getIsVisible())`.
			 - Compute `effectiveHighVisibility = useDrawWaterPost or autoHighVisibility`.
		 - Gate the draw callins using `effectiveHighVisibility` instead of the raw config value:
			 - If `effectiveHighVisibility` is true → draw in `DrawWorld`, return early from `DrawWorldPreUnit`.
			 - If false → draw in `DrawWorldPreUnit`, return early from `DrawWorld`.
	 - Outcome: players get low-clutter “legacy” metalspots by default, but get the “numbers above everything” behavior exactly when the build grid is visible (placing buildings).

3. Validate edge cases
	 - Pregame building placement: ensure the same “grid visible” signal works (pregame build widgets already interact with `WG.buildinggrid.setForceShow`).
	 - Blueprint / formation placement modes: they force-show the grid; metalspots should follow automatically.
	 - Widget ordering: confirm the metalspot `DrawWorld` path still executes late enough to avoid water distortion when it is enabled.

## Test plan
- Map with visible water and High water quality (e.g., a deep-water map): confirm labels remain crisp and legible with post-water rendering, and verify occlusion against terrain/units behaves as before.
- Map with Low/Off water or no-water maps: confirm behavior matches water maps (no reliance on `DrawWaterPost`).
- Toggle any new widget option: confirm both paths function and that switching does not leak GL state (no broken transparencies elsewhere).
- Regression check other overlays rendered around the same time (alpha objects above water) for ordering issues when labels are drawn post-water.

### Additional regression checks for the Jan 2026 change
- Start placing any building (grid appears): metal spot numbers should switch to the high-visibility `DrawWorld` path.
- Cancel building placement / return to default command (grid disappears): metal spots should immediately revert to the legacy path.
- Verify the switch does not “stick” due to saved config; it should be purely runtime-driven unless the player explicitly enables the always-on high visibility option.
