# Terraform Brush — Auto Segment & Spline Chaining (Idea)

## Concept

While terraforming, automatically attach a measure-tool-style segment (straight)
or spline (curved) chain that mirrors the actual brush path. The chain becomes
a draggable handle set, exactly like the measure tool's chains, so the user can:

- Re-position a stroke after applying it (drag handle → undo+reapply at new spot).
- Reshape a curved spline by dragging midpoints / endpoints.
- Delete or duplicate strokes via the measure-layer UI.
- Snap new strokes to existing chains (rulerMode/sticky already exist).

## Modes

- **Segment mode**: every continuous LMB drag becomes a 2-point straight chain
  (origin → release point). Useful for level/raise/lower lines and walls.
- **Spline mode**: every continuous LMB drag samples N intermediate points (same
  density as ramp+circle uses) and stores them as a multi-point spline chain.
  Useful for free-form raise/lower paths (rivers, ridges, trenches).

## Reusing existing infrastructure

Most pieces already exist:

- `extraState.attachRampChain(pts, radius, clay)` already attaches a chain to
  the measure layer for ramps. Generalize: `attachStrokeChain(pts, radius,
  mode, params)`.
- `recordLinkedStroke(...)` (sticky mode) already snapshots stroke parameters.
  Re-use for replay-on-drag: when a handle moves, undo the linked group, then
  re-emit each stroke at offset positions.
- `extraState.lastAppliedX/Z` (added for path interpolation) is exactly the
  per-segment sample list we need — extend to push each interpolated `(ix, iz)`
  into the chain's `pts` table during the drag.

## Suggested API additions

- `WG.TerraformBrush.setAutoChainMode(mode)` where mode ∈ `nil | "segment" |
  "spline"`.
- Per-chain metadata: `{strokeMode, radius, intensity, shape, rotation, curve,
  clay, …}` so re-apply on drag uses identical brush settings.

## Behavior on drag handle

1. User drags chain handle (existing measure-tool behavior).
2. On release, widget computes delta translation/rotation per segment.
3. Sticky-mode replay path executes: undo old strokes (newest-first to avoid
   stripy-terrain bug — see `bar_stripy_terrain_bug.md`), then re-apply each
   recorded stroke at the new offset.

## Open questions

- Granularity: segment-per-tick vs segment-per-drag-stroke?  Probably
  drag-stroke, with N sample points along the path.
- UX: indicator while drag is active showing the chain about to be created
  (faint preview line that follows the cursor).
- Should other modes (restore, noise) also auto-attach? Probably opt-in.
- Spline simplification: downsample if >X points before storing.

## Discovered during

Investigating "fast mouse stroke connectivity" feature (April 2026): the
interpolation-stamp implementation accidentally stitched strokes across mouse
release+press. That artifact is exactly what this auto-chain feature would
intentionally formalize.
