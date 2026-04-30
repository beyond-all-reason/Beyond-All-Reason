function widget:GetInfo()
	return {
		name = "Build Placement Extension",
		desc = "Extends the build placement with preview of buildability in surrounding cells.",
		author = "Floris",
		date = "April 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Tunables
--------------------------------------------------------------------------------
local MARGIN_CELLS = 0 -- number of build-squares of preview around the unit footprint
local CELL = 16 -- engine build square size (elmos)

local OUTLINE_ENABLED = false -- draw the thick footprint outline
local OUTLINE_WIDTH = 3.0 -- line width of footprint outline
local OUTLINE_Y_OFFSET = 0.4 -- small lift above ground to avoid z-fight with engine grid

local INNER_CELL_ALPHA = 0.33 -- alpha of inner (footprint) cells
local CELL_ALPHA_BEGIN = 0.18 -- alpha of closest margin cells (near footprint)
local CELL_ALPHA_END = 0.07 -- alpha of farthest margin cells
local CELL_Y_OFFSET = 0.6 -- raise margin cell quads slightly above ground
local CELL_INSET = 0.19 -- fraction to shrink each cell inward (0 = full, 0.5 = point)
local CELL_CHAMFER = 0.12 -- fraction of cell size to cut off each corner
local INNER_CELL_INSET = 0.12 -- inset for inner (footprint) cells
local INNER_CELL_CHAMFER = 0.09 -- chamfer for inner (footprint) cells

local CELL_OUTLINE = true -- draw an outline around each cell octagon
local CELL_OUTLINE_WIDTH = 2.0 -- line width of per-cell outline
local CELL_OUTLINE_ALPHA = 0.5 -- multiplier on cell alpha for the outline (clamped to 1)

local ONLY_WHEN_BLOCKED = true -- when true, only show the extension when the building can't be placed
local SHOW_NEAR_BLOCKED = false -- when ONLY_WHEN_BLOCKED, still show if any adjacent margin cell is blocked
local DRAW_INNER_CELLS = true -- also draw cells inside the footprint (where the engine grid is)

local COLOR_FREE = { 0.3, 1.0, 0.3 }
local COLOR_RECLAIM = { 0.3, 1.0, 0.3 }
local COLOR_MOBILE = { 0.5, 1.0, 0.3 }
local COLOR_BLOCKED = { 1.0, 0.25, 0.2 }

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local spGetActiveCommand = SpringUnsynced.GetActiveCommand
local spGetMouseState = SpringUnsynced.GetMouseState
local spTraceScreenRay = SpringUnsynced.TraceScreenRay
local spPos2BuildPos = SpringShared.Pos2BuildPos
local spTestBuildOrder = SpringShared.TestBuildOrder
local spGetBuildFacing = SpringUnsynced.GetBuildFacing
local spGetGroundHeight = SpringShared.GetGroundHeight

local glColor = gl.Color
local glVertex = gl.Vertex
local glBeginEnd = gl.BeginEnd
local glLineWidth = gl.LineWidth
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask

local GL_QUADS = GL.QUADS
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN

local activeUnitDefID
local UnitDefs = UnitDefs

-- Cache: only recompute cell statuses when input changes or after CACHE_INTERVAL
local CACHE_INTERVAL = 0.25
local cache = {
	unitDefID = nil,
	facing = nil,
	cx = nil,
	cz = nil,
	lastUpdate = nil,
	hx = 0,
	hz = 0,
	cy = 0,
}
local cellDisplayList = nil
local outlineDisplayList = nil
local spGetTimer = SpringUnsynced.GetTimer
local spDiffTimers = SpringUnsynced.DiffTimers
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- footprint half-extents in elmos (accounts for facing rotation)
local function getHalfExtents(unitDefID, facing)
	local ud = UnitDefs[unitDefID]
	if not ud then
		return 0, 0
	end
	local xs, zs = ud.xsize, ud.zsize
	if facing % 2 == 1 then
		xs, zs = zs, xs
	end
	-- xsize/zsize are in 8-elmo half-cells, footprint = xs * 8
	return xs * 4, zs * 4
end

local function statusToColor(status)
	if status == 3 then
		return COLOR_FREE
	end
	if status == 2 then
		return COLOR_RECLAIM
	end
	if status == 1 then
		return COLOR_MOBILE
	end
	return COLOR_BLOCKED
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function drawCellOctagon(x1, z1, x2, z2, inset, chamfer)
	-- Inset: shrink the quad toward its center
	local inX = (x2 - x1) * inset
	local inZ = (z2 - z1) * inset
	x1 = x1 + inX
	z1 = z1 + inZ
	x2 = x2 - inX
	z2 = z2 - inZ
	-- Chamfer offset
	local cw = (x2 - x1) * chamfer
	local ch = (z2 - z1) * chamfer
	local yo = CELL_Y_OFFSET
	-- Center point
	local mx = (x1 + x2) * 0.5
	local mz = (z1 + z2) * 0.5
	glVertex(mx, spGetGroundHeight(mx, mz) + yo, mz)
	-- 8 vertices of the octagon, clockwise from top-left chamfer start
	-- top edge
	glVertex(x1 + cw, spGetGroundHeight(x1 + cw, z1) + yo, z1)
	glVertex(x2 - cw, spGetGroundHeight(x2 - cw, z1) + yo, z1)
	-- right edge
	glVertex(x2, spGetGroundHeight(x2, z1 + ch) + yo, z1 + ch)
	glVertex(x2, spGetGroundHeight(x2, z2 - ch) + yo, z2 - ch)
	-- bottom edge
	glVertex(x2 - cw, spGetGroundHeight(x2 - cw, z2) + yo, z2)
	glVertex(x1 + cw, spGetGroundHeight(x1 + cw, z2) + yo, z2)
	-- left edge
	glVertex(x1, spGetGroundHeight(x1, z2 - ch) + yo, z2 - ch)
	glVertex(x1, spGetGroundHeight(x1, z1 + ch) + yo, z1 + ch)
	-- close the fan back to first vertex
	glVertex(x1 + cw, spGetGroundHeight(x1 + cw, z1) + yo, z1)
end

local function drawCellOutlineOctagon(x1, z1, x2, z2, inset, chamfer)
	-- Emit the same 8 octagon vertices for a GL_LINE_LOOP
	local inX = (x2 - x1) * inset
	local inZ = (z2 - z1) * inset
	x1 = x1 + inX
	z1 = z1 + inZ
	x2 = x2 - inX
	z2 = z2 - inZ
	local cw = (x2 - x1) * chamfer
	local ch = (z2 - z1) * chamfer
	local yo = CELL_Y_OFFSET
	glVertex(x1 + cw, spGetGroundHeight(x1 + cw, z1) + yo, z1)
	glVertex(x2 - cw, spGetGroundHeight(x2 - cw, z1) + yo, z1)
	glVertex(x2, spGetGroundHeight(x2, z1 + ch) + yo, z1 + ch)
	glVertex(x2, spGetGroundHeight(x2, z2 - ch) + yo, z2 - ch)
	glVertex(x2 - cw, spGetGroundHeight(x2 - cw, z2) + yo, z2)
	glVertex(x1 + cw, spGetGroundHeight(x1 + cw, z2) + yo, z2)
	glVertex(x1, spGetGroundHeight(x1, z2 - ch) + yo, z2 - ch)
	glVertex(x1, spGetGroundHeight(x1, z1 + ch) + yo, z1 + ch)
end

local function drawOutlineRect(x1, z1, x2, z2)
	-- Sample at cell corners (every CELL elmos) so the outline follows the same
	-- discrete heights the engine uses for its per-cell quads. This makes the
	-- outline look connected to the engine grid instead of curving smoothly.
	local nx = math.max(1, math.floor((x2 - x1) / CELL + 0.5))
	local nz = math.max(1, math.floor((z2 - z1) / CELL + 0.5))
	-- top edge (z1) left->right
	for i = 0, nx - 1 do
		local x = x1 + (x2 - x1) * (i / nx)
		glVertex(x, spGetGroundHeight(x, z1) + OUTLINE_Y_OFFSET, z1)
	end
	-- right edge (x2) top->bottom
	for i = 0, nz - 1 do
		local z = z1 + (z2 - z1) * (i / nz)
		glVertex(x2, spGetGroundHeight(x2, z) + OUTLINE_Y_OFFSET, z)
	end
	-- bottom edge (z2) right->left
	for i = 0, nx - 1 do
		local x = x2 - (x2 - x1) * (i / nx)
		glVertex(x, spGetGroundHeight(x, z2) + OUTLINE_Y_OFFSET, z2)
	end
	-- left edge (x1) bottom->top
	for i = 0, nz - 1 do
		local z = z2 - (z2 - z1) * (i / nz)
		glVertex(x1, spGetGroundHeight(x1, z) + OUTLINE_Y_OFFSET, z)
	end
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:Update()
	local _, cmdID = spGetActiveCommand()
	local udID = (cmdID and cmdID < 0) and -cmdID or nil
	-- Pre-gamestart build queue: no active command exists yet, so fall back to
	-- the unit selected in the pregame build menu (gui_pregame_build).
	if not udID and WG["pregame-build"] and WG["pregame-build"].getPreGameDefID then
		udID = WG["pregame-build"].getPreGameDefID()
	end
	activeUnitDefID = udID
end

function widget:DrawWorldPreUnit()
	local unitDefID = activeUnitDefID
	if not unitDefID then
		-- Clean up display lists when not building
		if cellDisplayList then
			glDeleteList(cellDisplayList)
			cellDisplayList = nil
		end
		if outlineDisplayList then
			glDeleteList(outlineDisplayList)
			outlineDisplayList = nil
		end
		cache.lastUpdate = nil
		return
	end
	local ud = UnitDefs[unitDefID]
	if not ud then
		return
	end

	local mx, my = spGetMouseState()
	local _, mp = spTraceScreenRay(mx, my, true, false, false, true)
	if not mp then
		return
	end

	local facing = spGetBuildFacing() or 0
	local cx, cy, cz = spPos2BuildPos(unitDefID, mp[1], mp[2], mp[3], facing)
	if not cx then
		return
	end

	local hx, hz = getHalfExtents(unitDefID, facing)
	if hx == 0 then
		return
	end

	-- Early out: if option set, skip when placement is valid
	-- status: 0=blocked, 1=mobile unit in way, 2=reclaimable feature, 3=open
	-- The engine considers 1, 2, and 3 as "can be placed" (shows green grid)
	if ONLY_WHEN_BLOCKED then
		local placementStatus = spTestBuildOrder(unitDefID, cx, cy, cz, facing)
		if placementStatus >= 1 then
			local showAnyway = false
			if SHOW_NEAR_BLOCKED then
				-- Check one ring of margin cells for any blocked status
				local fpCellsX = math.floor((hx * 2) / CELL + 0.5)
				local fpCellsZ = math.floor((hz * 2) / CELL + 0.5)
				local baseX = cx - hx
				local baseZ = cz - hz
				local mapX = Game.mapSizeX
				local mapZ = Game.mapSizeZ
				for ix = -1, fpCellsX do
					for iz = -1, fpCellsZ do
						if ix < 0 or ix >= fpCellsX or iz < 0 or iz >= fpCellsZ then
							local hypoX = baseX + ix * CELL + CELL * 0.5
							local hypoZ = baseZ + iz * CELL + CELL * 0.5
							local sxs, sys, szs = spPos2BuildPos(unitDefID, hypoX, cy, hypoZ, facing)
							if sxs - hx < 0 then
								sxs = sxs + CELL * math.ceil((hx - sxs) / CELL)
							end
							if sxs + hx > mapX then
								sxs = sxs - CELL * math.ceil((sxs + hx - mapX) / CELL)
							end
							if szs - hz < 0 then
								szs = szs + CELL * math.ceil((hz - szs) / CELL)
							end
							if szs + hz > mapZ then
								szs = szs - CELL * math.ceil((szs + hz - mapZ) / CELL)
							end
							if spTestBuildOrder(unitDefID, sxs, sys, szs, facing) == 0 then
								showAnyway = true
								break
							end
						end
					end
					if showAnyway then
						break
					end
				end
			end
			if not showAnyway then
				if cellDisplayList then
					glDeleteList(cellDisplayList)
					cellDisplayList = nil
				end
				if outlineDisplayList then
					glDeleteList(outlineDisplayList)
					outlineDisplayList = nil
				end
				cache.lastUpdate = nil
				return
			end
		end
	end

	-- Decide whether to rebuild the display lists
	local now = spGetTimer()
	local needRebuild = cache.unitDefID ~= unitDefID or cache.facing ~= facing or cache.cx ~= cx or cache.cz ~= cz or cache.lastUpdate == nil or spDiffTimers(now, cache.lastUpdate) >= CACHE_INTERVAL

	if needRebuild then
		cache.unitDefID = unitDefID
		cache.facing = facing
		cache.cx = cx
		cache.cz = cz
		cache.cy = cy
		cache.hx = hx
		cache.hz = hz
		cache.lastUpdate = now

		-- Status of the actual placement (drives outline color)
		local placementStatus = spTestBuildOrder(unitDefID, cx, cy, cz, facing)
		local outlineColor = statusToColor(placementStatus)

		-- Build cell display list
		if cellDisplayList then
			glDeleteList(cellDisplayList)
		end
		cellDisplayList = glCreateList(function()
			local fpCellsX = math.floor((hx * 2) / CELL + 0.5)
			local fpCellsZ = math.floor((hz * 2) / CELL + 0.5)
			local baseX = cx - hx
			local baseZ = cz - hz
			local mapX = Game.mapSizeX
			local mapZ = Game.mapSizeZ
			-- Collect cell data for fill + optional outline pass
			local cells = {}
			for ix = -MARGIN_CELLS, fpCellsX + MARGIN_CELLS - 1 do
				for iz = -MARGIN_CELLS, fpCellsZ + MARGIN_CELLS - 1 do
					local isInner = ix >= 0 and ix < fpCellsX and iz >= 0 and iz < fpCellsZ
					if not isInner or DRAW_INNER_CELLS then
						local wx1 = baseX + ix * CELL
						local wz1 = baseZ + iz * CELL
						local wx2 = wx1 + CELL
						local wz2 = wz1 + CELL
						if wx2 > 0 and wz2 > 0 and wx1 < mapX and wz1 < mapZ then
							local hypoX = wx1 + CELL * 0.5
							local hypoZ = wz1 + CELL * 0.5
							local sxs, sys, szs = spPos2BuildPos(unitDefID, hypoX, cy, hypoZ, facing)
							if sxs - hx < 0 then
								sxs = sxs + CELL * math.ceil((hx - sxs) / CELL)
							end
							if sxs + hx > mapX then
								sxs = sxs - CELL * math.ceil((sxs + hx - mapX) / CELL)
							end
							if szs - hz < 0 then
								szs = szs + CELL * math.ceil((hz - szs) / CELL)
							end
							if szs + hz > mapZ then
								szs = szs - CELL * math.ceil((szs + hz - mapZ) / CELL)
							end
							local status = spTestBuildOrder(unitDefID, sxs, sys, szs, facing)
							local c = statusToColor(status)
							local alpha
							if isInner then
								alpha = INNER_CELL_ALPHA
							else
								local dx = (ix < 0) and -ix or (ix >= fpCellsX and (ix - fpCellsX + 1) or 0)
								local dz = (iz < 0) and -iz or (iz >= fpCellsZ and (iz - fpCellsZ + 1) or 0)
								local dist = math.sqrt(dx * dx + dz * dz)
								local t = math.min((dist - 1) / math.max(1, MARGIN_CELLS - 1), 1)
								alpha = CELL_ALPHA_BEGIN + (CELL_ALPHA_END - CELL_ALPHA_BEGIN) * t
							end
							cells[#cells + 1] = { wx1, wz1, wx2, wz2, c, alpha, isInner }
						end
					end
				end
			end
			-- Fill pass
			for i = 1, #cells do
				local cl = cells[i]
				local ins = cl[7] and INNER_CELL_INSET or CELL_INSET
				local chm = cl[7] and INNER_CELL_CHAMFER or CELL_CHAMFER
				glColor(cl[5][1], cl[5][2], cl[5][3], cl[6])
				glBeginEnd(GL_TRIANGLE_FAN, function()
					drawCellOctagon(cl[1], cl[2], cl[3], cl[4], ins, chm)
				end)
			end
			-- Cell outline pass
			if CELL_OUTLINE then
				glLineWidth(CELL_OUTLINE_WIDTH)
				for i = 1, #cells do
					local cl = cells[i]
					local ins = cl[7] and INNER_CELL_INSET or CELL_INSET
					local chm = cl[7] and INNER_CELL_CHAMFER or CELL_CHAMFER
					local outAlpha = math.min(cl[6] * CELL_OUTLINE_ALPHA, 1)
					glColor(cl[5][1], cl[5][2], cl[5][3], outAlpha)
					glBeginEnd(GL_LINE_LOOP, function()
						drawCellOutlineOctagon(cl[1], cl[2], cl[3], cl[4], ins, chm)
					end)
				end
				glLineWidth(1.0)
			end
		end)

		-- Build outline display list
		if outlineDisplayList then
			glDeleteList(outlineDisplayList)
			outlineDisplayList = nil
		end
		if OUTLINE_ENABLED then
			outlineDisplayList = glCreateList(function()
				glLineWidth(OUTLINE_WIDTH)
				glColor(outlineColor[1], outlineColor[2], outlineColor[3], 0.9)
				glBeginEnd(GL_LINE_LOOP, function()
					drawOutlineRect(cx - hx, cz - hz, cx + hx, cz + hz)
				end)
				glLineWidth(1.0)
			end)
		end
	end

	-- Draw cached display lists
	glDepthTest(false)
	glDepthMask(false)
	if cellDisplayList then
		glCallList(cellDisplayList)
	end

	glDepthTest(true)
	if outlineDisplayList then
		glCallList(outlineDisplayList)
	end

	glColor(1, 1, 1, 1)
	glDepthMask(false)
	glDepthTest(false)
end

function widget:Shutdown()
	if cellDisplayList then
		glDeleteList(cellDisplayList)
	end
	if outlineDisplayList then
		glDeleteList(outlineDisplayList)
	end
end
