# Clone Windows — Approach & Challenges

**Status:** Removed (experimental). See [TerraformBrush.md](TerraformBrush.md) for current feature reference.

This documents the "clone window" feature that was prototyped and removed from the Terraform Brush UI. The goal was to let users drag toolbar buttons to spawn floating copies of tool control panels, allowing multiple tool sections to be visible simultaneously.

---

## Concept

- **Drag-to-spawn**: Long-press + drag a toolbar button (e.g. Raise, Features, Splat) past a 40px threshold to spawn a floating clone window at the mouse release position.
- **Clone windows** contained copies of the tool's controls (sliders, numboxes, toggle buttons) and could be positioned anywhere on screen.
- **Active/inactive state**: Clone windows showed whether their tool was currently active and provided header click-to-activate.
- **Close**: Each window had a close button that destroyed the clone and returned controls to the main panel.

---

## Implementation

### DOM Cloning (RmlUI)
- Used `Element:Clone()` to deep-copy tool section DOM trees into clone window body containers.
- `Clone()` returns an `ElementPtr` (owned pointer) accepted by `Element:AppendChild()`.
- Original sections were hidden with `SetClass("hidden", true)` while detached.

### Event Forwarding
Since `Clone()` copies DOM structure but **not** event listeners, all interactivity had to be manually forwarded:

1. **Sliders**: `change` event listener on clone slider → `SetAttribute("value", ...)` on original slider (which auto-fires the original's `change` handler).
2. **Numboxes**: `blur`/`keydown` listeners on clone → `SetAttribute("value", ...)` on paired original slider.
3. **Buttons**: `Click()` method call on original element (forwarding the click programmatically).
4. **Visual sync**: Per-frame loop copying `active`/`env-open` CSS classes from originals to clones, and syncing slider/numbox values back from originals to clones.

### Drag Ghost & Overlay
- A fullscreen transparent overlay (`position: fixed; 100vw × 100vh`) captured `mouseup` anywhere on screen during drag.
- A small "ghost" label followed the cursor during drag showing the tool name.

### DOM Structure (RML)
- 8 clone window containers (`cw-terrain`, `cw-metal`, etc.) with header, body, and close button.
- 1 drag ghost element + 1 fullscreen overlay, all starting hidden.

### State Management
- ~14 `widgetState` fields tracked clone window state (open/closed map, root/body/section element caches, drag state, forwarding flags, sync guards).
- Visibility logic in `DrawScreen` had to account for "detached" tools — a tool section detached to a clone window shouldn't hide other sections in the main panel.

---

## Challenges & Why It Was Removed

### 1. `Clone()` Doesn't Copy Event Listeners
This was the fundamental problem. Every interactive element (sliders, numboxes, buttons) needed manual event forwarding. With ~100+ button IDs and multiple element types, the forwarding code was extensive and fragile.

### 2. `DispatchEvent` Incompatibility
Initial attempts used `Element:DispatchEvent("click", {})` to forward events. This caused crashes because RmlUI's C++ `DispatchEvent` expects a C++ `flat_map` userdata, not a Lua table. The workaround was using `Element:Click()` for buttons and `Element:SetAttribute("value", ...)` for sliders.

### 3. Type Coercion Issues
`Element:GetAttribute("value")` returns numbers for range inputs but `SetAttribute` expected strings. This caused `"expected string, received number"` errors. Required wrapping all values with `tostring()`.

### 4. Bidirectional Sync Loops
Setting a clone's value fires its `change` event, which forwards to the original, which fires its `change` event. A `cwSyncing` guard flag was needed to break the loop, but this added complexity and was error-prone.

### 5. 200-Local Limit Pressure
The widget was already near Lua 5.1's 200-local limit per chunk. Clone window code required moving functions to `widgetState` table methods and splitting into separate setup functions (`attachCloneWindowListeners`) to stay under the limit.

### 6. Visibility Logic Complexity
Each section's visibility had to distinguish between "another tool is active" vs "another tool is active in a clone window". This required `cwDet` (detached tools map) and `nonDet*` variables for every tool, significantly complicating the DrawScreen visibility toggle block.

### 7. Splat Texture Preview Rendering
Splat texture previews use OpenGL shader rendering into RML element positions. Cloned preview elements needed separate tracking (`spClonePreviewEls`) and dual-pass rendering for both original and clone positions.

### 8. Maintenance Burden
Any new button, slider, or control section added to any tool would need corresponding updates to the clone forwarding tables (`cwAllBtnIds`, `cwSharedSectionIds`, section ID maps). This created a high ongoing maintenance cost.

---

## Future Exploration

If revisiting this concept, consider:

- **Engine-level support**: Request `Clone()` to optionally copy event listeners, or add a `CloneWithEvents()` API.
- **Iframe/sub-document approach**: If RmlUI supports nested documents, each clone window could load a separate RML document sharing the same Lua backend, avoiding the event forwarding problem entirely.
- **Simpler scope**: Instead of cloning full tool panels, clone only the most-used controls (e.g. brush size/intensity sliders) into a minimal floating palette.
- **Data-binding**: If RmlUI's data-binding model matures, bind clone and original controls to the same data model, eliminating manual sync.

---

## AI Disclosure

This document was drafted with AI assistance (GitHub Copilot, Claude) based on the actual implementation code and debugging sessions that led to the feature's removal. Reviewed by a human contributor.
