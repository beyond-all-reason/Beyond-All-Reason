
local voidWater = false
local waterLevel = Spring.GetModOptions().map_waterlevel
local waterIsLava = Spring.GetModOptions().map_waterislava
local minHeight, _, _, _ = Spring.GetGroundExtremes()
local success, mapinfo = pcall(VFS.Include,"mapinfo.lua") -- load mapinfo.lua confs
if success and mapinfo then
	voidWater = mapinfo.voidwater
end

function widget:GetInfo()
	return {
		name = "Context Build",
		desc = "Toggles buildings between water/ground equivalent buildings automagically" ,
		author = "Rebuilt by Hobo Joe, original by dizekat and BrainDamage",
		date = "Dec 2023",
		license = "GNU LGPL, v2.1 or later",
		layer = 1,
		enabled = true
	}
end

local isPregame = Spring.GetGameFrame() == 0 and not isSpec

local GetActiveCommand		= Spring.GetActiveCommand
local SetActiveCommand		= Spring.SetActiveCommand
local spGetMouseState 		= Spring.GetMouseState
local spTraceScreenRay 		= Spring.TraceScreenRay
local GetSelectedUnits      = Spring.GetSelectedUnits
local GetUnitDefID          = Spring.GetUnitDefID
local currentTime 			= os.clock

--- Human friendly list. Automatically converted to unitdef IDs on init
-- this should only ever swap between pairs of (buildable) units
local unitlist = {
	{'armada_energyconverter','armada_navalenergyconverter'},
	{'cortex_energyconverter','cortex_navalenergyconverter'},
	{'armada_dragonsteeth','armada_sharksteeth'},
	{'cortex_dragonsteeth','cortex_sharksteeth'},
	{'armada_metalstorage', 'armada_navalmetalstorage'},
	{'armada_energystorage', 'armada_navalenergystorage'},
	{'cortex_metalstorage', 'cortex_navalmetalstorage'},
	{'cortex_energystorage', 'cortex_navalenergystorage'},
	{'armada_nettle','armada_navalnettle'},
	{'cortex_thistle','cortex_slingshot'},
	{'armada_hovercraftplatform','armada_navalhovercraftplatform'},
	{'cortex_hovercraftplatform','cortex_navalhovercraftplatform'},
	{'armada_radartower','armada_navalradarsonar'},
	{'cortex_radartower','cortex_radarsonartower'},
	{'armada_overwatch','armada_manta'},
	{'cortex_warden','cortex_coral'},
	{'armada_pinpointer','armada_navalpinpointer'},
	{'cortex_pinpointer','cortex_navalpinpointer'},
	{'armada_advancedenergyconverter','armada_navaladvancedenergyconverter'},
	{'cortex_advancedenergyconverter','cortex_navaladvancedenergyconverter'},
	{'armada_fusionreactor','armada_navalfusionreactor'},
	{'cortex_fusionreactor','cortex_navalfusionreactor'},
	{'armada_arbalest','armada_navalarbalest'},
	{'cortex_birdshot','cortex_navalbirdshot'},
	{'armada_advancedmetalextractor','armada_navaladvancedmetalextractor'},
	{'cortex_advancedmetalextractor','cortex_navaladvancedmetalextractor'},
	{'armada_solarcollector','armada_tidalgenerator'},
	{'cortex_solarcollector','cortex_tidalgenerator'},
	{'armada_botlab','armada_shipyard'},
	{'cortex_botlab','cortex_shipyard'},
	{'armada_sentry','armada_harpoon'},
	{'cortex_guard','cortex_urchin'},
	{'armada_constructionturret','armada_navalconstructionturret'},
	{'cortex_constructionturret','cortex_navalconstructionturret'},
	{'armada_vehicleplant','armada_amphibiouscomplex'},
	{'cortex_vehicleplant','cortex_amphibiouscomplex'},
	{'armada_aircraftplant','armada_seaplaneplatform'},
	{'cortex_aircraftplant','cortex_seaplaneplatform'},
	{'cortex_airrepairpad','cortex_floatingairrepairpad'},
	{'armada_airrepairpad','armada_floatingairrepairpad'},
	{'armada_geothermalpowerplant','armada_geothermalpowerplant'},
	{'armada_advancedgeothermalpowerplant','armada_advancedgeothermalpowerplant'},
	{'cortex_geothermalpowerplant','cortex_navalgeothermalpowerplant'},
	{'cortex_advancedgeothermalpowerplant','cortex_advancednavalgeothermalpowerplant'},
	{'armada_sentry', 'armada_harpoon2'}, -- for the amphibious construction vehicles trying to build ptls on land
	{'cortex_guard', 'cortex_oldurchin'},
}

local ptlCons = {
	['armada_beaver'] = true,
	['cortex_muskrat'] = true,
}

local groundBuildings = {}
local waterBuildings = {}

local unitName = {}
for udid, ud in pairs(UnitDefs) do
	unitName[udid] = ud.name
end
local mouseDownPos

local updateRate = 0.1
local lastUpdateTime = 0
local gameStarted


local function maybeRemoveSelf()
	if waterIsLava or voidWater or waterLevel < minHeight then
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

local function setPreGamestartDefID(uDefID)
	if WG["pregame-build"] and WG["pregame-build"].setPreGamestartDefID then
		WG["pregame-build"].setPreGamestartDefID(uDefID)
	end
end

-- returns the unitDefID of the selected building, or false if there is no selected building
local function isBuilding()
	local _, cmdID
	if isPregame and WG['pregame-build'] and WG['pregame-build'].getPreGameDefID then
		cmdID = WG['pregame-build'].getPreGameDefID()
		cmdID = cmdID and -cmdID or 0 --invert to get the correct negative value
	else
		_, cmdID = GetActiveCommand()
	end

	if cmdID and cmdID < 0 then
		return -cmdID
	else
		return false
	end
end


local function getCursorWorldPosition()
	local mx, my = spGetMouseState()
	local _, pos = spTraceScreenRay(mx, my, true, false)
	return pos
end

function widget:MousePress(mx, my, button)
	if isBuilding and button == 1 then
		mouseDownPos = getCursorWorldPosition()
	end
end


-- Return the first index with the given value (or nil if not found).
local function indexOf(array, value)
	for i, v in ipairs(array) do
		if v == value then
			return i
		end
	end
	return nil
end

-- DrawWorld because update doesn't run pregame
function widget:DrawWorld()

	-- update only x times per second
	if lastUpdateTime > currentTime() + updateRate then
		return
	end

	local unitDefID = isBuilding()
	if not unitDefID then
		return
	end

	local pos = getCursorWorldPosition()
	if not pos then
		return
	end

	local x, y, lmb, mmb, rmb = spGetMouseState()

	if mouseDownPos and lmb then
		-- currently doing a build drag, don't swap buildings
		if math.distance2dSquared(mouseDownPos[1], mouseDownPos[3], pos[1], pos[3]) > 100 then
			return
		end
	end

	-- Check both arrays for a match with the current building cmd
	local isGround = false
	local alt = nil
	local index = indexOf(groundBuildings, unitDefID)
	if index then
		isGround = true
		alt = waterBuildings[index]
	end

	if not index then
		isGround = false
		index = indexOf(waterBuildings, unitDefID)
		alt = groundBuildings[index]
	end

	if not index or not alt then
		return
	end

	local name = unitName[alt]

	-- Check for amphibious constructors
	local selectedUnits = GetSelectedUnits()
	local amphibCons = 0
	for _, unitID in ipairs(selectedUnits) do
		if ptlCons[unitName[GetUnitDefID(unitID)]] then
			amphibCons = amphibCons + 1
		end
	end

	if amphibCons > 0 then
		local amphibBuildings = {
			['cortex_urchin'] = 'cortex_oldurchin',
			['armada_harpoon'] = 'armada_harpoon2',
		}
		name = amphibBuildings[name] or name
	end

	-- Water level is always 0, but there's minor inaccuracy in the chain, so fuzz it a bit
	if pos[2] < 0.01 then
		if isGround then
			if isPregame then
				setPreGamestartDefID(alt)
			else
				SetActiveCommand('buildunit_'..name)
			end
		end
	else
		if not isGround then
			if isPregame then
				setPreGamestartDefID(alt)
			else
				SetActiveCommand('buildunit_'..unitName[alt])
			end
		end
	end
	lastUpdateTime = currentTime()
end

function widget:GameStart()
	isPregame = false
end

function widget:Initialize()
	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		maybeRemoveSelf()
	end
	local uDefNames = UnitDefNames
	for _,unitNames in ipairs(unitlist) do
		for i, unitName in ipairs(unitNames) do
			if uDefNames[unitName] then
				local unitDefID = uDefNames[unitName].id
				local isWater = i % 2 == 0

				-- Break the unit list into two matching arrays
				if unitDefID then
					if isWater then
						table.insert(waterBuildings, unitDefID)
					else
						table.insert(groundBuildings, unitDefID)
					end
				end
			end
		end
	end
end
