--------------------------------------------------------------------------------
-- IceUI-GL4 - layout engine
--------------------------------------------------------------------------------
-- Turns a container rectangle + a layout spec into a list of child rectangles.
-- Pure geometry: no GPU, no styles, no widget state. The layout layer is what
-- makes "design by data" possible -- a widget describes structure, this module
-- computes pixel rects, the style layer paints them.
--
-- All rectangles are { left, bottom, right, top } in screen pixels,
-- origin bottom-left (matching the GL4 core).
--
-- Two layout modes cover the commands menu and most BAR panels:
--
--   grid  : N columns x M rows of equal cells, with a gap between them.
--           layoutGrid(rect, cols, rows, gap) -> { rect, rect, ... }
--           Cells are returned row-major, TOP row first (reading order).
--
--   row   : a horizontal strip split into weighted segments.
--           layoutRow(rect, weights, gap) -> { rect, ... }
--           weights = {1,1,2} gives a 25% / 25% / 50% split.
--
-- Plus small helpers: inset() (apply padding), hit() (point-in-rect test).
--------------------------------------------------------------------------------

local Layout = {}

local mathFloor = math.floor

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------

-- Shrink a rect by padding (l,b,r,t pixels). Returns a new rect.
function Layout.inset(rect, l, b, r, t)
	return {
		rect[1] + (l or 0),
		rect[2] + (b or 0),
		rect[3] - (r or 0),
		rect[4] - (t or 0),
	}
end

-- Point-in-rect test. Returns true if (x,y) is inside `rect`.
function Layout.hit(rect, x, y)
	return x >= rect[1] and x <= rect[3] and y >= rect[2] and y <= rect[4]
end

-- Width / height of a rect.
function Layout.size(rect)
	return rect[3] - rect[1], rect[4] - rect[2]
end

--------------------------------------------------------------------------------
-- grid
--------------------------------------------------------------------------------

-- Split `rect` into cols x rows equal cells separated by `gap` pixels.
-- Returns cells row-major, top row first: index 1 is top-left, index
-- (cols) is top-right, index (cols+1) starts the next row down.
-- Cell edges are floored to whole pixels to keep the SDF crisp.
function Layout.grid(rect, cols, rows, gap)
	gap = gap or 0
	local left, bottom, right, top = rect[1], rect[2], rect[3], rect[4]

	local totalW = right - left
	local totalH = top - bottom
	local cellW  = (totalW - gap * (cols - 1)) / cols
	local cellH  = (totalH - gap * (rows - 1)) / rows

	local cells = {}
	local idx   = 0
	for r = 0, rows - 1 do
		-- row 0 is the TOP row
		local cellTop    = top - r * (cellH + gap)
		local cellBottom = cellTop - cellH
		for c = 0, cols - 1 do
			local cellLeft  = left + c * (cellW + gap)
			local cellRight = cellLeft + cellW
			idx = idx + 1
			cells[idx] = {
				mathFloor(cellLeft + 0.5),
				mathFloor(cellBottom + 0.5),
				mathFloor(cellRight + 0.5),
				mathFloor(cellTop + 0.5),
			}
		end
	end
	return cells
end

--------------------------------------------------------------------------------
-- weighted row
--------------------------------------------------------------------------------

-- Split `rect` horizontally into segments sized by `weights` (a list of
-- numbers), separated by `gap` pixels. Returns segments left-to-right.
function Layout.row(rect, weights, gap)
	gap = gap or 0
	local left, bottom, right, top = rect[1], rect[2], rect[3], rect[4]

	local n = #weights
	local totalWeight = 0
	for i = 1, n do totalWeight = totalWeight + weights[i] end

	local available = (right - left) - gap * (n - 1)
	local segments  = {}
	local x = left
	for i = 1, n do
		local w = available * (weights[i] / totalWeight)
		segments[i] = {
			mathFloor(x + 0.5),
			bottom,
			mathFloor(x + w + 0.5),
			top,
		}
		x = x + w + gap
	end
	return segments
end

-- Split `rect` vertically into stacked segments sized by `weights`,
-- separated by `gap`. Returns segments TOP-to-bottom (reading order).
function Layout.column(rect, weights, gap)
	gap = gap or 0
	local left, bottom, right, top = rect[1], rect[2], rect[3], rect[4]

	local n = #weights
	local totalWeight = 0
	for i = 1, n do totalWeight = totalWeight + weights[i] end

	local available = (top - bottom) - gap * (n - 1)
	local segments  = {}
	local y = top
	for i = 1, n do
		local h = available * (weights[i] / totalWeight)
		segments[i] = {
			left,
			mathFloor(y - h + 0.5),
			right,
			mathFloor(y + 0.5),
		}
		y = y - h - gap
	end
	return segments
end

return Layout
