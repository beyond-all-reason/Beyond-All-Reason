local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Orbit Command",
		desc      = "Captures area guard commands and turns them into orbit commands (circle around a unit)",
		author    = "Google Frog",
		date      = "11 August 2015",
		license   = "GNU GPL, v2 or later",
		handler = true,
		layer     = 0,
		enabled   = true  --  loaded by default?

	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

<<<<<<< Updated upstream
--local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits
--local spWorldToScreenCoords = Spring.WorldToScreenCoords
--local spTraceScreenRay = Spring.TraceScreenRay
=======
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spTraceScreenRay = Spring.TraceScreenRay
>>>>>>> Stashed changes

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local FACING_SIZE = math.pi*2/7 -- size of the directional facing

--local Spring.Utilities.CMD = VFS.Include("LuaRules/Configs/customcmds.lua", nil, VFS.GAME)

local env = getfenv()
local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua", nil, VFS.GAME)
for cmdName, cmdID in pairs(customCmds) do
	env["CMD_" .. cmdName] = cmdID
end

--local customCmds = Spring.Utilities.CMD
-- Legacy synonym, not present in the main table
env.CMD_SETHAVEN = customCmds.RETREAT_ZONE


local CMD_ORBIT      = customCmds.ORBIT
<<<<<<< Updated upstream
--local CMD_ORBIT_DRAW = customCmds.ORBIT_DRAW
--local CMD_AREA_GUARD = customCmds.AREA_GUARD



--widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
function widget:CommandNotify(cmdID, params, options)
	if (cmdID == 25) and (#params == 1) and options.ctrl then
		
		local targetID = params[1]
		local selUnits = spGetSelectedUnits()
		local unitCount = #selUnits
		if unitCount == 0 then
			return
		end
		local radius = 300
		local facing = Spring.GetUnitHeading(targetID)/2^15*math.pi
		if unitCount == 1 then
			Spring.Echo( unitCount)
			Spring.GiveOrderToUnit(selUnits[1], CMD_ORBIT, {targetID, radius, facing}, options)
		else
			unitCount = unitCount - 1
			for i = 1, #selUnits do
				local offset = (2*(i-1)/unitCount - 1)*FACING_SIZE

				Spring.GiveOrderToUnit(selUnits[i], CMD_ORBIT, {targetID, radius, facing + offset}, options)
			end
=======
local CMD_ORBIT_DRAW = customCmds.ORBIT_DRAW
local CMD_AREA_GUARD = customCmds.AREA_GUARD

local function LOG(text)
	if log==true then
		Spring.Echo(text)
	end
end


local function GiveFacingOrder(targetID, cx, cz, radius, options)
	Spring.Echo( 'GiveFacingOrder')
	local mx, my = Spring.GetMouseState()
	local _, pos = spTraceScreenRay(mx, my, true)
	if not pos then
		return
	end
	
	local facing = -Spring.GetHeadingFromVector(pos[1] - cx, pos[3] - cz)/2^15*math.pi + math.pi*9/2
	local selUnits = spGetSelectedUnits()
	
	local unitCount = #selUnits
	
	if unitCount == 0 then
		return
	end
	
	if options.ctrl then
		facing = facing + Spring.GetUnitHeading(targetID)/2^15*math.pi
	end
	
	if unitCount == 1 then
		Spring.GiveOrderToUnit(selUnits[1], CMD_ORBIT, {targetID, radius, facing}, options)
	else
		unitCount = unitCount - 1
		for i = 1, #selUnits do
			local offset = (2*(i-1)/unitCount - 1)*FACING_SIZE
			Spring.GiveOrderToUnit(selUnits[i], CMD_ORBIT, {targetID, radius, facing + offset}, options)
		end
	end
	
	options.shift = true
	spGiveOrderToUnitArray(selUnits, CMD_ORBIT_DRAW, {targetID}, options)
	
	return true
end
--widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
function widget:CommandNotify(cmdID, params, options)
--function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	--local params = cmdParams
	--local options = cmdOpts
	Spring.Echo( tostring(#params))
	Spring.Echo( tostring(cmdID))
	if (cmdID == CMD_AREA_GUARD) and (#params == 4) then
		Spring.Echo( 'CMD_AREA_GUARD')
		local cx, cy, cz = params[1], params[2], params[3]
		local pressX, pressY = spWorldToScreenCoords(cx, cy, cz)
		local cType, targetID = spTraceScreenRay(pressX, pressY)
		
		if (cType == "unit") then
			if options.alt and GiveFacingOrder(targetID, cx, cz, params[4], options) then
				return true
			end
			
			local selUnits = spGetSelectedUnits()
			spGiveOrderToUnitArray(selUnits, CMD_ORBIT, {targetID, params[4], -1}, options)
			options.shift = true
			spGiveOrderToUnitArray(selUnits, CMD_ORBIT_DRAW, {targetID}, options)
			return true
>>>>>>> Stashed changes
		end
	end
end
