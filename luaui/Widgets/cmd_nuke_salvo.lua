local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Nuke Salvo Controller",
		desc = "With multiple nuke silos selected, each attack command launches one missile (round-robin) instead of all silos firing at once. Shows a ready-missile counter at the cursor.",
		author = "jaendres",
		date = "August 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local reticleRadius = 26
local fontSize = 15

-- Localized Spring API for performance
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitStockpile = Spring.GetUnitStockpile
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetMouseState = Spring.GetMouseState
local spGetActiveCommand = Spring.GetActiveCommand
local spGetSelectedUnits = Spring.GetSelectedUnits
local spIsGUIHidden = Spring.IsGUIHidden

local mathCos = math.cos
local mathSin = math.sin

local CMD_ATTACK = CMD.ATTACK

local font
local siloDefIDs = {} -- unitDefID -> true for units with a stockpiled nuclear weapon
local selectedSilos = {} -- selected silo unitIDs
local selCount = 0 -- total units in current selection
local lastFiredIdx = 0 -- round-robin pointer into selectedSilos

for udid, ud in pairs(UnitDefs) do
	for _, w in ipairs(ud.weapons) do
		local wd = WeaponDefs[w.weaponDef]
		if wd and wd.stockpile and wd.customParams and wd.customParams.nuclear then
			siloDefIDs[udid] = true
			break
		end
	end
end

function widget:ViewResize()
	font = WG.fonts.getFont(1, 1.5)
end

function widget:Initialize()
	widget:ViewResize()
	widget:SelectionChanged(spGetSelectedUnits())
end

function widget:SelectionChanged(sel)
	selectedSilos = {}
	selCount = #sel
	for i = 1, selCount do
		local udid = spGetUnitDefID(sel[i])
		if udid and siloDefIDs[udid] then
			selectedSilos[#selectedSilos + 1] = sel[i]
		end
	end
	lastFiredIdx = 0
end

-- Dead units return nil from GetUnitStockpile and are skipped
local function getSalvoState()
	local ready, building = 0, 0
	for i = 1, #selectedSilos do
		local stocked, queued = spGetUnitStockpile(selectedSilos[i])
		if stocked then
			ready = ready + stocked
			building = building + (queued or 0)
		end
	end
	return ready, building
end

function widget:CommandNotify(cmdID, params, opts)
	if cmdID ~= CMD_ATTACK then
		return false
	end
	-- Only take over with 2+ silos selected; single silos keep normal behavior
	local n = #selectedSilos
	if n < 2 then
		return false
	end

	-- Non-silo units in a mixed selection still get the attack order as usual
	if selCount > n then
		local sel = spGetSelectedUnits()
		for i = 1, #sel do
			local udid = spGetUnitDefID(sel[i])
			if not (udid and siloDefIDs[udid]) then
				spGiveOrderToUnit(sel[i], CMD_ATTACK, params, opts.coded)
			end
		end
	end

	-- Round-robin: the next silo with a ready missile fires, the rest hold
	for i = 1, n do
		local idx = (lastFiredIdx + i - 1) % n + 1
		local stocked = spGetUnitStockpile(selectedSilos[idx])
		if stocked and stocked > 0 then
			spGiveOrderToUnit(selectedSilos[idx], CMD_ATTACK, params, opts.coded)
			lastFiredIdx = idx
			return true
		end
	end

	-- Nothing ready: hand the order to a single silo so it fires once built
	lastFiredIdx = lastFiredIdx % n + 1
	spGiveOrderToUnit(selectedSilos[lastFiredIdx], CMD_ATTACK, params, opts.coded)
	return true
end

local function drawRing(x, y, radius)
	gl.BeginEnd(GL.LINE_LOOP, function()
		local segments = 32
		for i = 0, segments - 1 do
			local a = (i / segments) * math.pi * 2
			gl.Vertex(x + mathCos(a) * radius, y + mathSin(a) * radius)
		end
	end)
end

function widget:DrawScreen()
	if #selectedSilos == 0 or spIsGUIHidden() then
		return
	end

	local ready, building = getSalvoState()
	local mx, my = spGetMouseState()
	local _, activeCmd = spGetActiveCommand()

	if activeCmd == CMD_ATTACK then
		gl.LineWidth(2)
		if ready > 0 then
			gl.Color(1, 0.35, 0.2, 0.9)
		else
			gl.Color(0.6, 0.6, 0.6, 0.7)
		end
		drawRing(mx, my, reticleRadius)
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
	end

	local label
	if ready > 0 then
		label = "\255\255\255\255" .. ready .. " READY"
	else
		label = "\255\255\090\090" .. "0 READY"
	end
	if building > 0 then
		label = label .. "\255\160\160\160  +" .. building .. " building"
	end
	font:Begin()
	font:Print(label, mx + reticleRadius - 6, my + reticleRadius - 10, fontSize, "os")
	font:End()
end
