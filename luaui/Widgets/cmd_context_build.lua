
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

--- Human friendly list. Automatically converted to unitdef IDs on init
-- this should only ever swap between pairs of (buildable) units
local unitlist = {
	{'armmex','armuwmex'},
	{'cormex','coruwmex'},
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
}

local groundBuildings = {}
local waterBuildings = {}

local GetActiveCommand		= Spring.GetActiveCommand
local SetActiveCommand		= Spring.SetActiveCommand

local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay

local mouseDownPos

local updateRate = 0.1
local timeCounter = 0
local gameStarted

local function distance2dSquared(x1, y1, x2, y2)
	local dx = x1 - x2
	local dy = y1 - y2
	return dx * dx + dy * dy
end

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

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end

	for _,unitNames in ipairs(unitlist) do
		for i, unitName in ipairs(unitNames) do
			local unitDefID = UnitDefNames[unitName].id
			local isWater = i % 2 == 0

			-- Break the unit list into two matching arrays
			if unitDefID then
				if isWater then
					table.insert(waterBuildings,unitDefID)
				else
					table.insert(groundBuildings, unitDefID)
				end
			end
		end

	end
end


local function isBuilding()
	local _, cmdID
	if isPregame and WG['pregame-build'].getPreGameDefID then
		cmdID = WG['pregame-build'].getPreGameDefID()
		cmdID = cmdID and -cmdID or 0 --invert to get the correct negative value
	else
		_, cmdID = GetActiveCommand()
	end

	return cmdID and cmdID < 0 or false
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

function widget:Update(deltaTime)
	timeCounter = timeCounter + deltaTime
	-- update only x times per second
	if timeCounter >= updateRate then
		timeCounter = 0
	else
		return
	end

	local _, cmd_id = GetActiveCommand()
	if not cmd_id or cmd_id>=0 then
		return
	end
	local unitDefID = -cmd_id

	local pos = getCursorWorldPosition()
	if not pos then
		return
	end

	local x, y, lmb, mmb, rmb = spGetMouseState()
	local dist = distance2dSquared(mouseDownPos[1], mouseDownPos[3], pos[1], pos[3])

	if mouseDownPos and lmb and dist > 100 then
		-- currently doing a build drag, don't swap buildings
		return
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

	-- Water level is always 0, but there's minor inaccuracy in the chain, so fuzz it a bit
	if pos[2] < 0.01 then
		if(isGround) then
			SetActiveCommand('buildunit_'..UnitDefs[alt].name)
		end
	else
		if not isGround then
			SetActiveCommand('buildunit_'..UnitDefs[alt].name)
		end
	end
end
