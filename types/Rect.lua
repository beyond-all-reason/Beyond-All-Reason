---@meta

--- Rectangle shapes used across the UI. Several mutually incompatible four-number
--- conventions are in play, and nothing distinguishes them at a glance, so they are
--- collected here to be named at the point of use rather than inferred from the
--- surrounding arithmetic.

--- A rectangle in Spring screen coordinates, in the order the FlowUI drawing
--- helpers take it: `UiElement(left, bottom, right, top)` and
--- `RectRound(left, bottom, right, top, ...)`. Y grows upward, so `[4] >= [2]`.
---@class ScreenRect
---@field [1] number Left edge
---@field [2] number Bottom edge
---@field [3] number Right edge
---@field [4] number Top edge

--- Where a docked UI panel sits on screen, as the `GetPosition` members of the
--- advplayerlist-adjacent widgets return it, so a panel can stack itself against a
--- neighbour.
---@class DockedPanelPosition
---@field [1] number Top edge
---@field [2] number Left edge
---@field [3] number Bottom edge
---@field [4] number Right edge
---@field [5] number UI scale the panel was laid out at

--- A mouse selection box, in the order the engine uses: `Spring.GetSelectionBox`
--- returns these four values and `Spring.GetUnitsInScreenRectangle` takes them.
---@class SelectionBoxRect
---@field [1] number? Left edge
---@field [2] number? Top edge
---@field [3] number? Right edge
---@field [4] number? Bottom edge
