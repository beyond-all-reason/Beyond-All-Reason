
local voidWater = false
local waterLevel = Spring.GetModOptions().map_waterlevel
local waterIsLava = Spring.Lava.isLavaMap
local minHeight, _, _, _ = Spring.GetGroundExtremes()
local success, mapinfo = pcall(VFS.Include,"mapinfo.lua") -- load mapinfo.lua confs
if success and mapinfo then
	voidWater = mapinfo.voidwater
end

local widget = widget ---@type Widget

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

local uDefNames = UnitDefNames

local GetActiveCommand		= Spring.GetActiveCommand
local SetActiveCommand		= Spring.SetActiveCommand
local spGetMouseState 		= Spring.GetMouseState
local spTraceScreenRay 		= Spring.TraceScreenRay
local currentTime 			= os.clock

--- Human friendly list. Automatically converted to unitdef IDs on init
-- this should only ever swap between pairs of (buildable) units
local unitlist = {
	{'armmakr','armfmkr'},
	{'cormakr','corfmkr'},
	{'armdrag','armfdrag'},
	{'cordrag','corfdrag'},
	{'armmstor', 'armuwms'},
	{'armestor', 'armuwes'},
	{'cormstor', 'coruwms'},
	{'corestor', 'coruwes'},
	{'armrl','armfrt'},
	{'corrl','corfrt'},
	{'armhp','armfhp'},
	{'corhp','corfhp'},
	{'armrad','armfrad'},
	{'corrad','corfrad'},
	{'armhlt','armfhlt'},
	{'corhlt','corfhlt'},
	{'armtarg','armfatf'},
	{'cortarg','corfatf'},
	{'armmmkr','armuwmmm'},
	{'cormmkr','coruwmmm'},
	{'armfus','armuwfus'},
	{'corfus','coruwfus'},
	{'armflak','armfflak'},
	{'corflak','corenaa'},
	{'armmoho','armuwmme'},
	{'cormoho','coruwmme'},
	{'armsolar','armtide'},
	{'corsolar','cortide'},
	{'armlab','armsy'},
	{'corlab','corsy'},
	{'armllt','armtl'},
	{'corllt','cortl'},
	{'armnanotc','armnanotcplat'},
	{'cornanotc','cornanotcplat'},
	{'armvp','armamsub'},
	{'corvp','coramsub'},
	{'armap','armplat'},
	{'corap','corplat'},
	{'armgeo','armuwgeo'},
	{'armageo','armuwageo'},
	{'corgeo','coruwgeo'},
	{'corageo','coruwageo'},
}



local legionUnitlist = {
	--{'cormakr','legfmkr'},
	--{'cordrag','corfdrag'},
	--{'cormstor', 'coruwms'},
	--{'corestor', 'coruwes'},
	--{'legrl','corfrt'},--
	{'leghp','legfhp'},
	--{'legrad','corfrad'},--asym pairs cannot overlap with core placeholders
	--{'legmg','corfhlt'},--
	--{'cortarg','corfatf'},
	--{'cormmkr','coruwmmm'},
	--{'corfus','coruwfus'},
	--{'corflak','corenaa'},
	--{'cormoho','coruwmme'},--does this combo actually manifest on anything...?
	{'legsolar','legtide'},
	--{'leglab','corsy'},--soon(tm)
	{'leglht','legtl'},
	{'leghive', 'legfhive'},
	--{'cornanotc','cornanotcplat'},
	{'legvp','legamsub'},
	--{'corap','corplat'},
	--{'corgeo','coruwgeo'},
	--{'corageo','coruwageo'},
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

local function addUnitDefPair(firstUnitName, lastUnitName)
	local firstUnitDef = uDefNames[firstUnitName]
	local lastUnitDef = uDefNames[lastUnitName]

	if not (firstUnitDef and lastUnitDef and firstUnitDef.id and lastUnitDef.id) then
		Spring.Echo(string.format("%s: can't add %s/%s pair", "cmd_context_build", firstUnitName, lastUnitName))
		return
	end

	for i, unitDef in ipairs({firstUnitDef, lastUnitDef}) do
		local unitDefID = unitDef.id
		local isWater = i % 2 == 0

		-- Break the unit list into two matching arrays
		if isWater then
			table.insert(waterBuildings, unitDefID)
		else
			table.insert(groundBuildings, unitDefID)
		end
	end
end

function widget:Initialize()
	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		maybeRemoveSelf()
	end

	if Spring.GetModOptions().experimentallegionfaction then
		for _,v in ipairs(legionUnitlist) do
			table.insert(unitlist, v)
		end
	end


	for _,unitNames in ipairs(unitlist) do
		addUnitDefPair(unitNames[1], unitNames[2])
	end
end
