local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Specific Unit Loader",
		desc = "Hold down Alt or Ctrl and give an area load order, centered on a unit of the type to load. Ctrl picks up units of this type from selected team, Alt - only player",
		author = "Google Frog, doo edit for load commands, SuperKitowiec",
		date = "May 12, 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

-- Changelog
-- Sep 2025 SuperKitowiec:
-- Ctrl picks up units of selected team. Alt picks up units of selected player. Units closest to area center will be picked up first

-- Speedups
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitTeam = Spring.GetUnitTeam

local CMD_LOAD_UNITS = CMD.LOAD_UNITS

local gameStarted

function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
	end
end

function widget:GameStart()
	gameStarted = true
	maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	maybeRemoveSelf()
end

function widget:Initialize()
	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		maybeRemoveSelf()
	end
end

function widget:CommandNotify(id, params, options)

	if id ~= CMD_LOAD_UNITS or #params ~= 4 then
		return false
	end

	if not options.alt and not options.ctrl then
		return false
	end

	local cx, cy, cz = params[1], params[2], params[3]

	local mx, my = spWorldToScreenCoords(cx, cy, cz)
	local cType, targetUnitID = spTraceScreenRay(mx, my)

	-- prevent normal pickup if player tried to do a filtered one but missed the unit
	if cType ~= "unit" then
		return true
	end

	local targetUnitAllyTeam = spGetUnitAllyTeam(targetUnitID)
	if not targetUnitAllyTeam then return end
	local targetUnitTeam = spGetUnitTeam(targetUnitID)
	if not targetUnitTeam then return end

	local cr = params[4]
	local targetUnitDefId = spGetUnitDefID(targetUnitID)
	if not targetUnitDefId then return end

	local selUnits = spGetSelectedUnits()
	if #selUnits == 0 then return end

	local allAreaUnits = spGetUnitsInCylinder(cx, cz, cr)
	local cargoUnitsToSort = {}

	for i = 1, #allAreaUnits do
		local unitID = allAreaUnits[i]

		if spGetUnitDefID(unitID) == targetUnitDefId then
			local isCorrectTeam
			if options.ctrl then
				isCorrectTeam = (spGetUnitAllyTeam(unitID) == targetUnitAllyTeam)
			elseif options.alt then
				isCorrectTeam = (spGetUnitTeam(unitID) == targetUnitTeam)
			end

			if isCorrectTeam then
				local ux, _, uz = Spring.GetUnitPosition(unitID)
				-- Calculate squared distance to the center for sorting
				local distSq = (ux - cx) ^ 2 + (uz - cz) ^ 2
				table.insert(cargoUnitsToSort, { id = unitID, dist = distSq })
			end
		end
	end

	table.sort(cargoUnitsToSort, function(a, b)
		return a.dist > b.dist
	end)

	local cmdOpts = {}
	if options.shift then
		cmdOpts = { "shift" }
	end

	for i = 1, #cargoUnitsToSort do
		local cargoUnitID = cargoUnitsToSort[i].id
		local transportIndex = (i - 1) % #selUnits + 1
		local transportUnitID = selUnits[transportIndex]
		Spring.GiveOrderToUnit(transportUnitID, CMD_LOAD_UNITS, { cargoUnitID }, cmdOpts)
	end

	return true
end
