local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mex Splitting",
		desc = "Under Map Assigned mex income: the map's regions in their holders' colours, pregame and whenever a mex is being placed",
		author = "BAR modules",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = true,
	}
end

local TransferEnums = VFS.Include("modules/transfer/enums.lua")
if Spring.GetModOptions()[TransferEnums.ModOptions.MexSplitting] ~= TransferEnums.MexSplitting.MapAssigned then
	return false
end

local Deal = VFS.Include("modules/transfer/mex_splitting/deal.lua") ---@type MexRegionsDealLib
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry
local Shared = VFS.Include("modules/transfer/mex_splitting/shared.lua") ---@type MexRegionsShared
local readDeal = Deal.Reader()

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glText = gl.Text
local GL_LINE_LOOP = GL.LINE_LOOP
local GetGroundHeight = Spring.GetGroundHeight
local WorldToScreenCoords = Spring.WorldToScreenCoords

local isMex = {} ---@type table<integer, boolean>
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.extractsMetal > 0 then
		isMex[unitDefID] = true
	end
end

local function placingAMex()
	local _, cmdID = Spring.GetActiveCommand()
	return cmdID ~= nil and (cmdID == GameCMD.AREA_MEX or (cmdID < 0 and isMex[-cmdID] == true))
end

local function showing()
	return Spring.GetGameFrame() <= 0 or placingAMex()
end

local UNHELD = { 0.6, 0.6, 0.6 }
local MINE = { 0.3, 1.0, 0.3 }
local THEIRS = { 1.0, 0.55, 0.55 }
local SPOT_RING = (Game.extractorRadius or 80) * 0.75

---@param teamID integer
---@return string
local function holderName(teamID)
	local players = Spring.GetPlayerList(teamID)
	local name = players and players[1] and Spring.GetPlayerInfo(players[1], false) or nil
	return name or ("team " .. teamID)
end

-- The metal spots my side's holdings name, by spot key: mine and my allies', which is all a player may read.
local spotHolders = {} ---@type table<string, integer[]>
local sinceRead = math.huge
function widget:Update(dt)
	sinceRead = sinceRead + dt
	if sinceRead >= 1 then
		sinceRead = 0
		spotHolders = Shared.HoldersBySpot(Spring, Spring.GetTeamList())
	end
end

---@return { x: number, z: number }[]
local function metalSpots()
	local finder = WG.resource_spot_finder
	return finder and not finder.isMetalMap and finder.metalSpotsList or {}
end

---@param teamID integer|nil
---@return number[]
local function colourOf(teamID)
	if teamID == nil then
		return UNHELD
	end
	local r, g, b = Spring.GetTeamColor(teamID)
	return { r or 1, g or 1, b or 1 }
end

local styledFor = nil ---@type table|nil the deal these styles were built for
local styles = {} ---@type { colour: number[], label: string, x: number, z: number }[]
---@param deal MexRegionsDealRecord
local function stylesFor(deal)
	if styledFor == deal then
		return styles
	end
	styledFor = deal
	styles = {}
	for i, region in ipairs(deal.regions) do
		local holder = deal.holders[region.id]
		local label = region.name
		if holder ~= nil then
			label = label .. " · " .. holderName(holder)
		else
			label = label .. " · open"
		end
		local cx, cz = Geometry.Centroid(region.vertices)
		styles[i] = { colour = colourOf(holder), label = label, x = cx, z = cz }
	end
	return styles
end

function widget:DrawWorldPreUnit()
	if not showing() then
		return
	end
	local deal = readDeal(Spring)
	if not deal then
		return
	end
	local style = stylesFor(deal)
	glLineWidth(3.0)
	for i, region in ipairs(deal.regions) do
		local c = style[i].colour
		glColor(c[1], c[2], c[3], 0.9)
		glBeginEnd(GL_LINE_LOOP, function()
			local poly = region.vertices
			for i, v in ipairs(poly) do
				local vn = poly[(i % #poly) + 1] or v
				local vx, vz, nx, nz = v.x or 0, v.z or 0, vn.x or 0, vn.z or 0
				local segLen = math.sqrt((nx - vx) ^ 2 + (nz - vz) ^ 2)
				local steps = math.max(1, math.ceil(segLen / 64))
				for s = 0, steps - 1 do
					local t = s / steps
					local x, z = vx + (nx - vx) * t, vz + (nz - vz) * t
					glVertex(x, (GetGroundHeight(x, z) or 0) + 6, z)
				end
			end
		end)
	end
	local myTeamID = Spring.GetMyTeamID()
	for _, spot in ipairs(metalSpots()) do
		local holders = spotHolders[Shared.SpotKey(spot.x, spot.z)]
		if holders ~= nil then
			local c = table.contains(holders, myTeamID) and MINE or THEIRS
			glColor(c[1], c[2], c[3], 0.9)
			gl.DrawGroundCircle(spot.x, 0, spot.z, SPOT_RING, 24)
		end
	end
	glLineWidth(1.0)
	glColor(1, 1, 1, 1)
end

-- Over a spot another team holds, while a mex is being placed: say whose it is, in the game's own tooltip.
local function explainSpotUnderCursor()
	if not (placingAMex() and WG.tooltip and WG.tooltip.ShowTooltip) then
		return
	end
	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if not pos then
		return
	end
	local reach = (Game.extractorRadius or 80) ^ 2
	for _, spot in ipairs(metalSpots()) do
		if (spot.x - pos[1]) ^ 2 + (spot.z - pos[3]) ^ 2 <= reach then
			local holders = spotHolders[Shared.SpotKey(spot.x, spot.z)]
			if holders ~= nil and not table.contains(holders, Spring.GetMyTeamID()) then
				local names = {}
				for i, holder in ipairs(holders) do
					names[i] = holderName(holder)
				end
				WG.tooltip.ShowTooltip(
					"mex_regions",
					"This metal spot belongs to " .. table.concat(names, " and ") .. ": Mex Splitting is Map Assigned."
				)
			end
			return
		end
	end
end

function widget:DrawScreenEffects()
	if not showing() then
		return
	end
	explainSpotUnderCursor()
	local deal = readDeal(Spring)
	if not deal then
		return
	end
	local style = stylesFor(deal)
	for _, s in ipairs(style) do
		local gy = GetGroundHeight(s.x, s.z) or 0
		local sx, sy, sz = WorldToScreenCoords(s.x, gy, s.z)
		if sz and sz > 0 and sz < 1 then
			local c = s.colour
			glColor(c[1], c[2], c[3], 1)
			glText(s.label, sx, sy, 14, "cdo")
		end
	end
	glColor(1, 1, 1, 1)
end
