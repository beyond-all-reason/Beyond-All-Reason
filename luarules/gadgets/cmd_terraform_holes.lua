local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Terraform Holes",
		desc = "Units cannot path into terrain holes cut with the Terraform Brush. Requires /cheat.",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	-- runtime cuts: hand the shape to the widget that draws the holes
	local function forward(_, op, x, z, radius)
		if Script.LuaUI("TerrainHoleRuntime") then
			Script.LuaUI.TerrainHoleRuntime(op, x, z, radius)
		end
	end
	function gadget:Initialize()
		gadgetHandler:AddSyncAction("tf_hole_runtime", forward)
	end
	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("tf_hole_runtime")
	end
	return
end

local HEADER = "$tf_holes$"
local HEADER_LEN = #HEADER
local CHEAT_SIG = "$c$"
local CHEAT_SIG_LEN = #CHEAT_SIG

-- The mapeditor modoption comes from the start script, so a client cannot forge it.
local MAP_EDITOR_SESSION = false
do
	local opt = (Spring.GetModOptions() or {}).mapeditor
	MAP_EDITOR_SESSION = opt == true or opt == 1 or opt == "1"
end

local function isAllowed(certified)
	return Spring.IsCheatingEnabled() or (certified and MAP_EDITOR_SESSION)
end

-- One terrain type is used for holes: no ground or water unit can move on it.
-- It is picked on the first hole, from the indices the map's typemap leaves free.
local holeType
local CELL = 16
local CELLS_X = math.floor(Game.mapSizeX / CELL)
local CELLS_Z = math.floor(Game.mapSizeZ / CELL)

-- the terrain type each blocked cell had before, by cell index
local before = {}
local blockedCount = 0
-- who wants a cell blocked: the painted mask, and cuts made while the game runs
local painted = {}
local runtime = {}

local spSetType = Spring.SetMapSquareTerrainType
-- building mask per cell: 0 lets nothing be built there, 1 is the engine default
local spSetBuildMask = Spring.SetSquareBuildingMask
local byte = string.byte
local ONE = byte("1")

local function pickHoleType()
	-- an exported map brings its own hole type (index 1, all speeds 0)
	local _, name, _, tank, kbot, hover, ship = Spring.GetTerrainTypeData(1)
	if name == "Hole" and tank == 0 and kbot == 0 and hover == 0 and ship == 0 then
		holeType = 1
		Spring.SetGameRulesParam("tf_holes_type", holeType)
		return
	end
	local used = {}
	local spGetGroundInfo = Spring.GetGroundInfo
	for cz = 0, CELLS_Z - 1 do
		for cx = 0, CELLS_X - 1 do
			used[spGetGroundInfo(cx * CELL, cz * CELL)] = true
		end
	end
	holeType = 255
	for i = 255, 0, -1 do
		if not used[i] then
			holeType = i
			break
		end
	end
	Spring.SetTerrainTypeData(holeType, 0, 0, 0, 0)
	Spring.SetGameRulesParam("tf_holes_type", holeType)
end

local function setCell(cx, cz, source, on)
	local idx = cz * CELLS_X + cx
	source[idx] = on or nil
	local blocked = painted[idx] or runtime[idx]
	local was = before[idx]
	if blocked and not was then
		if not holeType then
			pickHoleType()
		end
		local was0 = spSetType(cx * CELL, cz * CELL, holeType) or 0
		-- a cell the map itself blocks goes back to plain ground
		before[idx] = (was0 == holeType) and 0 or was0
		spSetBuildMask(cx, cz, 0)
		blockedCount = blockedCount + 1
	elseif was and not blocked then
		spSetType(cx * CELL, cz * CELL, was)
		spSetBuildMask(cx, cz, 1)
		before[idx] = nil
		blockedCount = blockedCount - 1
	end
end

-- Drops the painted holes; cuts made while the game runs stay.
local function clearAll()
	local cells = {}
	for idx in pairs(painted) do
		cells[#cells + 1] = idx
	end
	for _, idx in ipairs(cells) do
		setCell(idx % CELLS_X, math.floor(idx / CELLS_X), painted, false)
	end
end

-- Runtime cuts: a disc of ground goes or comes back while the game runs.
local function runtimeDisc(x, z, radius, on)
	local r2 = radius * radius
	for cz = math.max(0, math.floor((z - radius) / CELL)), math.min(CELLS_Z - 1, math.floor((z + radius) / CELL)) do
		for cx = math.max(0, math.floor((x - radius) / CELL)), math.min(CELLS_X - 1, math.floor((x + radius) / CELL)) do
			local dx, dz = (cx + 0.5) * CELL - x, (cz + 0.5) * CELL - z
			if dx * dx + dz * dz <= r2 then
				setCell(cx, cz, runtime, on)
			end
		end
	end
	SendToUnsynced("tf_hole_runtime", on and "cut" or "restore", x, z, radius)
	Spring.SetGameRulesParam("tf_holes_blocked", blockedCount)
end

-- for missions and other gadgets
GG.TerrainHoles = {
	Cut = function(x, z, radius)
		runtimeDisc(x, z, radius, true)
	end,
	Restore = function(x, z, radius)
		runtimeDisc(x, z, radius, false)
	end,
}

function gadget:Shutdown()
	GG.TerrainHoles = nil
end

function gadget:Initialize()
	Spring.SetGameRulesParam("tf_holes_blocked", 0)
	-- an exported map blocks units through its typemap; keep buildings out of the same cells
	local _, name = Spring.GetTerrainTypeData(1)
	if name == "Hole" then
		local spGetGroundInfo = Spring.GetGroundInfo
		for cz = 0, CELLS_Z - 1 do
			for cx = 0, CELLS_X - 1 do
				if spGetGroundInfo(cx * CELL, cz * CELL) == 1 then
					spSetBuildMask(cx, cz, 0)
				end
			end
		end
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, HEADER_LEN) ~= HEADER then
		return
	end
	local rest = msg:sub(HEADER_LEN + 1)
	local certified = rest:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
	if certified then
		rest = rest:sub(CHEAT_SIG_LEN + 1)
	end
	if not isAllowed(certified) then
		return
	end
	local op = rest:sub(1, 1)
	if op == "c" then
		clearAll()
	elseif op == "k" or op == "u" then
		-- k x z radius cuts at runtime, u puts it back: the editor's way to try GG.TerrainHoles
		local x, z, radius = rest:match("^. (%d+) (%d+) (%d+)$")
		if not x then
			return
		end
		runtimeDisc(tonumber(x), tonumber(z), tonumber(radius), op == "k")
	elseif op == "r" then
		-- r x0 z0 w h bits: a rectangle of cells, "1" = blocked, rows from z0 down
		local x0, z0, w, h, bits = rest:match("^r (%d+) (%d+) (%d+) (%d+) ([01]+)$")
		x0, z0, w, h = tonumber(x0), tonumber(z0), tonumber(w), tonumber(h)
		if not (bits and x0 + w <= CELLS_X and z0 + h <= CELLS_Z and #bits == w * h) then
			return
		end
		local i = 0
		for cz = z0, z0 + h - 1 do
			for cx = x0, x0 + w - 1 do
				i = i + 1
				setCell(cx, cz, painted, byte(bits, i) == ONE)
			end
		end
	end
	Spring.SetGameRulesParam("tf_holes_blocked", blockedCount)
	return true
end
