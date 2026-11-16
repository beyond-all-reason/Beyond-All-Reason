---@meta

-- Temporary declarations for RecoilEngine#3753 until recoil-lua-library includes it.
-- This file is only read by tooling; older engines still disable the widget.

---@type integer?
CMD.OPT_KEEP_HEIGHT = 1

---@class CommandOptions
---@field keepheight boolean? Preserve the explicit height of a positional target.

---@alias GhostTraceScreenRay fun(screenX: integer, screenY: integer, onlyCoords?: boolean, useMinimap?: boolean, includeSky?: boolean, ignoreWater?: boolean, heightOffset?: number, includeGhosts?: boolean): ("unit"|"feature"|"ground"|"sky"|"ghost"|nil), (UnitID|FeatureID|xyz|nil), (xyz|nil)

---@type (fun(x?: number, y?: number, z?: number))?
Spring.SetGhostHighlight = nil
